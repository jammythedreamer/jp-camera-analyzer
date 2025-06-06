import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';

import '../providers/text_analysis_provider.dart';
import 'text_analysis_screen.dart';

/// Screen for capturing photos and extracting text
class CameraScreen extends StatefulWidget {
  final CameraDescription camera;
  
  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isFlashOn = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we initialized the camera
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }
  
  Future<void> _initializeCamera() async {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller!.initialize();
    
    if (mounted) {
      setState(() {});
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take a Photo'),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              children: [
                Expanded(
                  child: _controller!.value.isInitialized
                      ? CameraPreview(_controller!)
                      : const Center(child: Text('Camera initializing...')),
                ),
                Container(
                  color: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 50),
                      FloatingActionButton(
                        heroTag: 'takePicture',
                        onPressed: _takePicture,
                        backgroundColor: Colors.white,
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 50),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  /// Toggle flash on/off
  void _toggleFlash() async {
    if (_controller != null && _controller!.value.isInitialized) {
      if (_controller!.value.flashMode == FlashMode.off) {
        await _controller!.setFlashMode(FlashMode.torch);
        setState(() {
          _isFlashOn = true;
        });
      } else {
        await _controller!.setFlashMode(FlashMode.off);
        setState(() {
          _isFlashOn = false;
        });
      }
    }
  }

  /// Take picture with the camera
  Future<void> _takePicture() async {
    try {
      // Ensure camera is initialized
      await _initializeControllerFuture;

      // Take the picture
      final image = await _controller?.takePicture();
      
      if (image != null && mounted) {
        // Clear previous data
        Provider.of<TextAnalysisProvider>(context, listen: false).clearData();
        
        // Navigate to text analysis screen with the captured image
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TextAnalysisScreen(
              imageFile: File(image.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: $e')),
        );
      }
    }
  }
}
