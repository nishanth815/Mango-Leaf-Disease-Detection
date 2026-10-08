import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        return;
      }

      final camera = cameras.first;

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller!.initialize();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Capture Mango Leaf',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _controller == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CameraPreview(_controller!),
                      ),

                      Center(
                        child: Container(
                          width: 280,
                          height: 380,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),

                      const Positioned(
                        top: 25,
                        left: 20,
                        right: 20,
                        child: Text(
                          'Place the mango leaf inside the frame',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 5,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        bottom: 35,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: FloatingActionButton(
                            onPressed: () async {
                              try {
                                await _initializeControllerFuture;

                                final image =
                                    await _controller!.takePicture();

                                if (!context.mounted) return;

                                Navigator.pop(context, image.path);
                              } catch (e) {
                                debugPrint(
                                  'Error taking picture: $e',
                                );
                              }
                            },
                            backgroundColor: Colors.white,
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.green,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Unable to start camera.',
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                }

                return const Center(
                  child: CircularProgressIndicator(),
                );
              },
            ),
    );
  }
}