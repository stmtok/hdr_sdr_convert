package com.stmtok.hdrsdr

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ColorSpace
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Build
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

/** HdrsdrPlugin */
class HdrsdrPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "hdr_sdr")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${Build.VERSION.RELEASE}")
            }

            "convert" -> {
                val image = call.argument<ByteArray>("image") ?: run {
                    return result.error("arg", "no image", null)
                }
                val quality = call.argument<Int>("quality") ?: 100
                try {
                    val out = convertHDRtoSDR(image, quality)
                    result.success(out)
                } catch (t: Throwable) {
                    result.error("conv", t.message, null)
                }

            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}

/**
 * HDR/広色域画像をSDR (sRGB, 8bit, JPEG) に変換する
 */

fun convertHDRtoSDR(data: ByteArray, jpegQuality: Int): ByteArray {
    val orientation = runCatching {
        ExifInterface(ByteArrayInputStream(data))
            .getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
    }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        val source = ImageDecoder.createSource(ByteBuffer.wrap(data))
        val sdrBitmap = ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
            val isWide = info.colorSpace?.isWideGamut ?: false
            if (isWide) {
                decoder.setTargetColorSpace(ColorSpace.get(ColorSpace.Named.SRGB))
            }
        }

        val outputStream = ByteArrayOutputStream()
        sdrBitmap.compress(Bitmap.CompressFormat.JPEG, jpegQuality, outputStream)

        return outputStream.toByteArray()
    } else {
        val opts = BitmapFactory.Options().apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                inPreferredColorSpace = ColorSpace.get(ColorSpace.Named.SRGB)
            }
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val decoded = BitmapFactory.decodeByteArray(data, 0, data.size, opts) ?: return data
        val argb = if (decoded.config != Bitmap.Config.ARGB_8888)
            decoded.copy(Bitmap.Config.ARGB_8888, false).also { decoded.recycle() }
        else decoded

        val rotated = applyExifOrientation(argb, orientation).also {
            if (it !== argb) argb.recycle()
        }
        return ByteArrayOutputStream().use { bos ->
            rotated.compress(Bitmap.CompressFormat.JPEG, jpegQuality, bos)
            rotated.recycle()
            bos.toByteArray()
        }
    }
}

fun applyExifOrientation(src: Bitmap, o: Int): Bitmap {
    val m = Matrix()
    when (o) {
        ExifInterface.ORIENTATION_ROTATE_90 -> m.postRotate(90f)
        ExifInterface.ORIENTATION_ROTATE_180 -> m.postRotate(180f)
        ExifInterface.ORIENTATION_ROTATE_270 -> m.postRotate(270f)
        ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> m.preScale(-1f, 1f)
        ExifInterface.ORIENTATION_FLIP_VERTICAL -> m.preScale(1f, -1f)
        ExifInterface.ORIENTATION_TRANSPOSE -> {
            m.preScale(-1f, 1f); m.postRotate(270f)
        }

        ExifInterface.ORIENTATION_TRANSVERSE -> {
            m.preScale(-1f, 1f); m.postRotate(90f)
        }

        else -> return src
    }
    return try {
        Bitmap.createBitmap(src, 0, 0, src.width, src.height, m, true)
    } catch (_: Throwable) {
        src
    }
}