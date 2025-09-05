import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'hdrsdr_method_channel.dart';

abstract class HdrSdrPlatform extends PlatformInterface {
  /// Constructs a HdrsdrPlatform.
  HdrSdrPlatform() : super(token: _token);

  static final Object _token = Object();

  static HdrSdrPlatform _instance = MethodChannelHdrSdr();

  /// The default instance of [HdrSdrPlatform] to use.
  ///
  /// Defaults to [MethodChannelHdrSdr].
  static HdrSdrPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [HdrSdrPlatform] when
  /// they register themselves.
  static set instance(HdrSdrPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<Uint8List> convert(Uint8List image, {int quality = 100}) {
    throw UnimplementedError('convert() has not been implemented.');
  }
}
