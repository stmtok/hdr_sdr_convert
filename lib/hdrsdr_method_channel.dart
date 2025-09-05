import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hdrsdr_platform_interface.dart';

/// An implementation of [HdrSdrPlatform] that uses method channels.
class MethodChannelHdrSdr extends HdrSdrPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('hdr_sdr');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<Uint8List> convert(Uint8List image, {int quality = 100}) async {
    final out = await methodChannel.invokeMethod<Uint8List>('convert', {
      'image': image,
      'quality': quality,
    });
    if (out == null) {
      throw PlatformException(code: 'NULL', message: 'conversion failed');
    }

    return out;
  }
}
