import 'dart:typed_data';

import 'hdrsdr_platform_interface.dart';

class HdrSdr {
  Future<String?> getPlatformVersion() {
    return HdrSdrPlatform.instance.getPlatformVersion();
  }

  static Future<Uint8List> convert(Uint8List image, {int quality = 100}) {
    return HdrSdrPlatform.instance.convert(image, quality: quality);
  }
}
