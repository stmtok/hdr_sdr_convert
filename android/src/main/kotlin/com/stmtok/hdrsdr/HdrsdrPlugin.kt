package com.stmtok.hdrsdr

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ColorSpace
import android.graphics.ImageDecoder
import android.os.Build
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
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
    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val opts = BitmapFactory.Options().apply {
            inPreferredColorSpace = ColorSpace.get(ColorSpace.Named.SRGB)
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val decoded = BitmapFactory.decodeByteArray(data, 0, data.size, opts) ?: return data
        return ByteArrayOutputStream().use { bos ->
            decoded.compress(Bitmap.CompressFormat.JPEG, jpegQuality, bos)
            decoded.recycle()
            bos.toByteArray()
        }
    } else {
        val decoded = BitmapFactory.decodeByteArray(data, 0, data.size) ?: return data
        val argb = if (decoded.config != Bitmap.Config.ARGB_8888)
            decoded.copy(Bitmap.Config.ARGB_8888, false).also { decoded.recycle() }
        else decoded

        return ByteArrayOutputStream().use { bos ->
            argb.compress(Bitmap.CompressFormat.JPEG, jpegQuality.coerceIn(0, 100), bos)
            argb.recycle()
            bos.toByteArray()
        }
    }
}