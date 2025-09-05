import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hdrsdr/hdrsdr.dart';
import 'package:hdrsdr/hdrsdr_method_channel.dart';
import 'package:hdrsdr/hdrsdr_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHdrSdrPlatform
    with MockPlatformInterfaceMixin
    implements HdrSdrPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<Uint8List> convert(Uint8List image, {int quality = 100}) async {
    return image;
  }
}

void main() {
  final HdrSdrPlatform initialPlatform = HdrSdrPlatform.instance;

  test('$MethodChannelHdrSdr is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHdrSdr>());
  });

  test('getPlatformVersion', () async {
    HdrSdr hdrsdrPlugin = HdrSdr();
    MockHdrSdrPlatform fakePlatform = MockHdrSdrPlatform();
    HdrSdrPlatform.instance = fakePlatform;

    expect(await hdrsdrPlugin.getPlatformVersion(), '42');
  });
}
