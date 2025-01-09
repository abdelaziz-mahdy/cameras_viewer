import 'dart:async';
import 'package:automated_attendance/camera_providers/i_camera_provider.dart';
import 'package:automated_attendance/camera_providers/remote_camera_provider.dart';
import 'package:automated_attendance/discovery/discovery_service.dart';
import 'package:automated_attendance/discovery/service_info.dart';
import 'package:automated_attendance/widgets/data_center_camera_preview.dart';
import 'package:flutter/material.dart';

class DataCenterView extends StatefulWidget {
  const DataCenterView({Key? key}) : super(key: key);

  @override
  State<DataCenterView> createState() => _DataCenterViewState();
}

class _DataCenterViewState extends State<DataCenterView> {
  final DiscoveryService _discoveryService = DiscoveryService();

  // Timer to periodically refresh service list
  Timer? _refreshTimer;

  List<ServiceInfo> _discoveredProviders = [];
  // key: address (or service.id), value: ICameraProvider
  final Map<String, ICameraProvider> _activeProviders = {};

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  void _startDiscovery() async {
    // Start discovering services
    await _discoveryService.startDiscovery(
      serviceType: '_camera._tcp',
      port: 12345,
      timeout: const Duration(seconds: 8),
      cleanupInterval: const Duration(seconds: 2),
    );

    // Listen for newly discovered services
    _discoveryService.discoveryStream.listen((serviceInfo) async {
      final address = serviceInfo.address;
      if (address == null) return;

      // If not already active, open a new RemoteCameraProvider
      if (!_activeProviders.containsKey(address)) {
        final provider = RemoteCameraProvider(
          serverAddress: address,
          serverPort: 12345,
        );

        final opened = await provider.openCamera();
        debugPrint("Opened remote camera: ${serviceInfo.toJson()}: $opened");

        if (opened && mounted) {
          setState(() {
            _activeProviders[address] = provider;
          });
        }
      }
    });

    // Periodically refresh the active service list and remove stale providers
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;

      setState(() {
        // Update the list of discovered (active) services
        _discoveredProviders = _discoveryService.activeServices;

        // Identify any providers whose service is no longer active
        final activeAddresses = _discoveredProviders
            .map((s) => s.address)
            .whereType<String>()
            .toSet();

        // Remove providers that disappeared from the network
        final inactiveEntries = _activeProviders.entries
            .where((entry) => !activeAddresses.contains(entry.key))
            .toList();

        for (final entry in inactiveEntries) {
          entry.value.closeCamera();
          _activeProviders.remove(entry.key);
        }
      });
    });
  }

  @override
  void dispose() {
    _stopDiscovery();
    super.dispose();
  }

  void _stopDiscovery() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    // Stop discovering
    await _discoveryService.stopDiscovery();

    // Close all active camera providers
    for (var provider in _activeProviders.values) {
      await provider.closeCamera();
    }
    _activeProviders.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Center: Discovered Providers"),
      ),
      body: _discoveredProviders.isEmpty
          ? const Center(child: Text("No active services found."))
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _discoveredProviders.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // You can adjust how many columns you want
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.7, // Adjust to taste (width/height)
              ),
              itemBuilder: (context, index) {
                final service = _discoveredProviders[index];
                final address = service.address ?? '';
                final provider = _activeProviders[address];

                return Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Text(
                          service.name ?? "Unknown Service",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text("Address: $address"),
                        const SizedBox(height: 8),
                        Expanded(
                          // If provider is null, show a placeholder or loader
                          child: provider == null
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : DataCenterCameraPreview(
                                  provider: provider,
                                  providerName:
                                      service.name ?? "Unknown Provider",
                                  // Optionally pass a different 'fps' if you want
                                  // to poll each preview at a different rate
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
