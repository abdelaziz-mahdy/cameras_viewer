import 'dart:async';

import 'package:automated_attendance/discovery/service_info.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:logging/logging.dart';

final _logger = Logger('DiscoveryService');

class DiscoveryService {
  BonsoirDiscovery? _discovery;
  bool _isDiscovering = false;
  final Map<String, ServiceInfo> _discoveredServices = {};

  final _discoveryStreamController = StreamController<ServiceInfo>.broadcast();

  Stream<ServiceInfo> get discoveryStream => _discoveryStreamController.stream;

  // Stream<BonsoirDiscoveryEvent> get discoveryStream => _discovery?.eventStream ?? Stream.empty();

  Future<void> startDiscovery({
    required String serviceType,
  }) async {
    if (_isDiscovering) {
      _logger.warning('Discovery already in progress');
      return;
    }

    try {
      _discovery = BonsoirDiscovery(type: serviceType);
      await _discovery!.ready;

      _discovery!.eventStream!.listen((event) async {
        String serviceId =
            "${event.service?.name}${event.service?.type}${event.service?.port}";

        if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
          _logger.info('Service found: ${event.service?.toJson()}');
          if (_discoveredServices.containsKey(serviceId)) {
            return;
          }
          await event.service?.resolve(_discovery!.serviceResolver);
        } else if (event.type ==
            BonsoirDiscoveryEventType.discoveryServiceResolved) {
          _logger.info('Service resolved: ${event.service?.toJson()}');
          if (event.service == null) {
            return;
          }
          if (event.service is ResolvedBonsoirService) {
            ResolvedBonsoirService resolvedService = event.service as ResolvedBonsoirService;
            final service = ServiceInfo(
              name: resolvedService.name,
              type: resolvedService.type,
              address: resolvedService.host,
              port: resolvedService.port,
              attributes: resolvedService.attributes,
            );
            _logger.info('Resolved service: ${event.service?.toJson()}');
            _discoveredServices[serviceId] = service;
            _discoveryStreamController.add(service);
          }
        } else if (event.type ==
            BonsoirDiscoveryEventType.discoveryServiceLost) {
          _logger.warning('Service lost: ${event.service?.toJson()}');

          _discoveredServices.remove(serviceId);
        }
      });

      await _discovery!.start();
      _isDiscovering = true;
      _logger.info('Started discovery for service type: $serviceType');
    } catch (e) {
      _logger.severe('Failed to start discovery', e);
      await stopDiscovery();
    }
  }

  Future<void> stopDiscovery() async {
    if (_isDiscovering) {
      await _discovery?.stop();
      _discovery = null;
      _isDiscovering = false;
      _logger.info('Stopped discovery');
    }
  }

  bool get isDiscovering => _isDiscovering;
  List<ServiceInfo> get activeServices => _discoveredServices.values.toList();
}
