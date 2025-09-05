import Flutter
import UIKit
import CoreImage
import ImageIO
import MobileCoreServices
import UniformTypeIdentifiers

public class HdrsdrPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "hdr_sdr", binaryMessenger: registrar.messenger())
        let instance = HdrsdrPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "convert":
            guard
                let args = call.arguments as? [String: Any],
                let bytes = args["image"] as? FlutterStandardTypedData
            else { result(FlutterError(code:"ARG", message:"invalid args", details:nil)); return }
            
            let q = (args["quality"] as? NSNumber)?.floatValue ?? 85
            do {
                let out = try convertHDRToSDR_sRGB(data: bytes.data, jpegQuality: CGFloat(q)/100.0)
                result(FlutterStandardTypedData(bytes: out as Data))
            } catch {
                result(FlutterError(code:"CONVERT", message:"\(error)", details:nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func convertHDRToSDR_sRGB(data: Data, jpegQuality: CGFloat) throws -> Data {
        guard let ciImage = CIImage(data: data) else {
            throw NSError(domain: "enc", code: -1)
        }

        if let colorSpace = ciImage.colorSpace, colorSpace.name == CGColorSpace.sRGB {
            print("Image is already SDR (sRGB). Returning original data.")
            return data
        }
        
        let exifOrientation = ciImage.properties[kCGImagePropertyOrientation as String] as? NSNumber ?? 1
        let orientedCIImage = ciImage.oriented(forExifOrientation: exifOrientation.int32Value)

        guard let srgbColorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw NSError(domain: "enc", code: -3)
        }
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(orientedCIImage, from: orientedCIImage.extent, format: .RGBA8, colorSpace: srgbColorSpace) else {
            throw NSError(domain: "enc", code: -4)
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        guard let result = uiImage.jpegData(compressionQuality: jpegQuality) else {
            throw NSError(domain: "enc", code: -5)
        }
        return result
    }
}
