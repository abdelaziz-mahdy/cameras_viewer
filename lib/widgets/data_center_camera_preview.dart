import 'dart:async';

import 'package:automated_attendance/camera_providers/i_camera_provider.dart';
import 'package:flutter/material.dart';

class DataCenterCameraPreview extends StatefulWidget {
  final ICameraProvider provider;
  final String providerName;

  const DataCenterCameraPreview({
    super.key,
    required this.provider,
    required this.providerName,
  });

  @override
  State<DataCenterCameraPreview> createState() =>
      _DataCenterCameraPreviewState();
}

class _DataCenterCameraPreviewState extends State<DataCenterCameraPreview> {
  Timer? _timer;
  Image? _image;
  double fps = 1; // poll every second, for example

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(
      Duration(milliseconds: (1000 / fps).round()),
      (timer) async {
        final frameBytes = await widget.provider.getFrame();
        if (frameBytes != null) {
          // Optionally do some local CV preprocessing here:
          // e.g. decode -> face detect -> re-encode
          // For demonstration, we just show the raw frame:

          setState(() {
            _image = Image.memory(frameBytes, gaplessPlayback: true);
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Data Center: ${widget.providerName}"),
      ),
      body: Center(
        child: _image != null ? _image! : CircularProgressIndicator(),
      ),
    );
  }
}