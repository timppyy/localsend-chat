import 'package:common/model/device.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'nearby_devices_state.mapper.dart';

@MappableClass()
class NearbyDevicesState with NearbyDevicesStateMappable {
  final bool runningFavoriteScan;
  final Set<String> runningIps; // list of local ips
  final Map<String, Device> devices; // ip -> device

  /// Devices that are discovered via signaling server.
  /// The key is the fingerprint of the device.
  /// We do not trust the fingerprint, so we allow multiple devices with the same fingerprint.
  final Map<String, Set<Device>> signalingDevices;

  const NearbyDevicesState({
    required this.runningFavoriteScan,
    required this.runningIps,
    required this.devices,
    required this.signalingDevices,
  });

  Map<String, Device> get allDevices {
    final Map<String, Device> allDevices = {};
    for (final device in devices.values) {
      _addOrMergeDevice(allDevices, device, preferredKey: device.ip ?? device.fingerprint);
    }
    for (final devices in signalingDevices.values) {
      for (final device in devices) {
        _addOrMergeDevice(allDevices, device, preferredKey: device.signalingId ?? device.fingerprint);
      }
    }
    return allDevices;
  }
}

void _addOrMergeDevice(Map<String, Device> devices, Device device, {required String preferredKey}) {
  for (final entry in devices.entries) {
    final currentDevice = entry.value;
    if (currentDevice.fingerprint == device.fingerprint && currentDevice.alias == device.alias) {
      devices[entry.key] = currentDevice.merge(device);
      return;
    }
  }

  var key = preferredKey;
  var suffix = 1;
  while (devices.containsKey(key)) {
    suffix++;
    key = '$preferredKey#$suffix';
  }
  devices[key] = device;
}

extension on Device {
  Device merge(Device other) {
    return Device(
      signalingId: signalingId ?? other.signalingId,
      ip: ip ?? other.ip,
      version: version,
      port: port,
      https: https,
      fingerprint: fingerprint,
      alias: alias,
      deviceModel: deviceModel,
      deviceType: deviceType,
      download: download,
      discoveryMethods: {
        ...discoveryMethods,
        ...other.discoveryMethods,
      },
    );
  }
}
