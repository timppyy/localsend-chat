import 'package:common/model/device.dart';

Map<String, dynamic> buildRegisterResponseBody({
  required String alias,
  required String version,
  required String? deviceModel,
  required DeviceType? deviceType,
  required String fingerprint,
  required bool download,
}) {
  return {
    'alias': alias,
    'version': version,
    if (deviceModel != null) 'deviceModel': deviceModel,
    if (deviceType != null) 'deviceType': deviceType.toLocalSendV2Json(),
    'fingerprint': fingerprint,
    'download': download,
  };
}

extension LocalSendV2DeviceTypeJson on DeviceType {
  String toLocalSendV2Json() {
    return switch (this) {
      DeviceType.mobile => 'MOBILE',
      DeviceType.desktop => 'DESKTOP',
      DeviceType.web => 'WEB',
      DeviceType.headless => 'HEADLESS',
      DeviceType.server => 'SERVER',
    };
  }
}
