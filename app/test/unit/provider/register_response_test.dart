import 'package:common/constants.dart';
import 'package:common/model/device.dart';
import 'package:localsend_app/provider/network/server/controller/register_response.dart';
import 'package:test/test.dart';

void main() {
  test('builds a LocalSend v2 compatible register response body', () {
    final body = buildRegisterResponseBody(
      alias: 'Office PC',
      version: protocolVersion,
      deviceModel: 'Windows',
      deviceType: DeviceType.desktop,
      fingerprint: 'device-fingerprint',
      download: true,
    );

    expect(body, {
      'alias': 'Office PC',
      'version': protocolVersion,
      'deviceModel': 'Windows',
      'deviceType': 'DESKTOP',
      'fingerprint': 'device-fingerprint',
      'download': true,
    });
  });

  test('serializes all device types using LocalSend v2 enum names', () {
    expect(DeviceType.mobile.toLocalSendV2Json(), 'MOBILE');
    expect(DeviceType.desktop.toLocalSendV2Json(), 'DESKTOP');
    expect(DeviceType.web.toLocalSendV2Json(), 'WEB');
    expect(DeviceType.headless.toLocalSendV2Json(), 'HEADLESS');
    expect(DeviceType.server.toLocalSendV2Json(), 'SERVER');
  });
}
