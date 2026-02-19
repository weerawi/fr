import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../services/face_detection_service.dart';
import '../services/ml_service.dart';
import '../services/database_service.dart';
import 'dart:typed_data';

/// Screen for enrolling new users (registering their face)
class EnrollmentScreen extends StatefulWidget {
  final CameraDescription camera;

  const EnrollmentScreen({Key? key, required this.camera}) : super(key: key);

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  CameraController? _cameraController;
  final FaceDetectionService _faceDetectionService = FaceDetectionService();
  final MLService _mlService = MLService();
  final DatabaseService _databaseService = DatabaseService();

  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _faceDetected = false;
  
  List<List<double>> _capturedEmbeddings = [];
  final int _requiredCaptures = 5; // Capture 5 different face embeddings
  
  final TextEditingController _nameController = TextEditingController();
  String _statusMessage = 'Position your face in the frame';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize camera
      _cameraController = CameraController(
        widget.camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await _cameraController!.initialize();

      // Initialize ML services
      await _faceDetectionService.initialize();
      await _mlService.initialize();

      setState(() {
        _isInitialized = true;
      });

      // Start processing frames
      _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      print('Error initializing: $e');
      setState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    if (_isProcessing || _capturedEmbeddings.length >= _requiredCaptures) return;
    
    _isProcessing = true;

    try {
      // Convert camera image to InputImage
      final inputImage = _faceDetectionService.convertCameraImage(
        cameraImage,
        widget.camera,
      );

      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      // Detect faces
      final faces = await _faceDetectionService.detectFaces(inputImage);

      if (faces.isEmpty) {
        setState(() {
          _faceDetected = false;
          _statusMessage = 'No face detected. Position your face in frame.';
        });
        _isProcessing = false;
        return;
      }

      if (faces.length > 1) {
        setState(() {
          _faceDetected = false;
          _statusMessage = 'Multiple faces detected. Please ensure only you are in frame.';
        });
        _isProcessing = false;
        return;
      }

      final face = faces.first;
      final imageSize = Size(cameraImage.width.toDouble(), cameraImage.height.toDouble());

      // Check face quality
      if (!_faceDetectionService.isFaceQualityGood(face, imageSize)) {
        setState(() {
          _faceDetected = true;
          _statusMessage = 'Please face the camera directly and come closer.';
        });
        _isProcessing = false;
        return;
      }

      setState(() {
        _faceDetected = true;
        _statusMessage = 'Good! Hold still...';
      });

      // Convert camera image to img.Image for processing
      final fullImage = _convertYUV420ToImage(cameraImage);
      if (fullImage == null) {
        _isProcessing = false;
        return;
      }

      // Crop face from image
      final croppedFace = _faceDetectionService.cropFace(fullImage, face);
      if (croppedFace == null) {
        _isProcessing = false;
        return;
      }

      // Generate embedding
      final embedding = await _mlService.generateEmbedding(croppedFace);

      // Check if this embedding is significantly different from previous ones
      // (to ensure we capture different angles/expressions)
      bool isDifferentEnough = true;
      for (var existingEmbedding in _capturedEmbeddings) {
        final similarity = _mlService.calculateSimilarity(embedding, existingEmbedding);
        if (similarity > 0.95) {
          isDifferentEnough = false;
          break;
        }
      }

      if (isDifferentEnough) {
        _capturedEmbeddings.add(embedding);
        setState(() {
          _statusMessage = 'Captured ${_capturedEmbeddings.length}/$_requiredCaptures. '
              'Move your head slightly for next capture.';
        });

        // Wait a bit before next capture
        await Future.delayed(const Duration(milliseconds: 500));

        if (_capturedEmbeddings.length >= _requiredCaptures) {
          await _cameraController?.stopImageStream();
          setState(() {
            _statusMessage = 'All captures complete! Enter your name to finish.';
          });
        }
      }
    } catch (e) {
      print('Error processing frame: $e');
    }

    _isProcessing = false;
  }

  /// Convert YUV420 camera image to RGB img.Image
  img.Image? _convertYUV420ToImage(CameraImage cameraImage) {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;

      final img.Image rgbImage = img.Image(width: width, height: height);

      final Plane yPlane = cameraImage.planes[0];
      final Plane uPlane = cameraImage.planes[1];
      final Plane vPlane = cameraImage.planes[2];

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int yIndex = y * yPlane.bytesPerRow + x;
          final int uvIndex = (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2);

          final int yValue = yPlane.bytes[yIndex];
          final int uValue = uPlane.bytes[uvIndex];
          final int vValue = vPlane.bytes[uvIndex];

          // YUV to RGB conversion
          int r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
          int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
              .round()
              .clamp(0, 255);
          int b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);

          rgbImage.setPixelRgba(x, y, r, g, b, 255);
        }
      }

      return rgbImage;
    } catch (e) {
      print('Error converting YUV to RGB: $e');
      return null;
    }
  }

  Future<void> _saveUser() async {
    final name = _nameController.text.trim();
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    if (_capturedEmbeddings.length < _requiredCaptures) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Need ${_requiredCaptures - _capturedEmbeddings.length} more captures')),
      );
      return;
    }

    try {
      setState(() {
        _statusMessage = 'Saving...';
      });

      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      final userData = UserFaceData(
        userId: userId,
        userName: name,
        embeddings: _capturedEmbeddings,
      );

      await _databaseService.saveUser(userData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name enrolled successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enroll New User'),
        backgroundColor: Colors.blue,
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Camera preview
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      if (_cameraController != null && _cameraController!.value.isInitialized)
                        CameraPreview(_cameraController!),
                      
                      // Face detection indicator
                      Center(
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _faceDetected ? Colors.green : Colors.red,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(125),
                          ),
                        ),
                      ),

                      // Progress indicator
                      Positioned(
                        top: 20,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _requiredCaptures,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: index < _capturedEmbeddings.length
                                    ? Colors.green
                                    : Colors.grey.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: index < _capturedEmbeddings.length
                                  ? const Icon(Icons.check, color: Colors.white)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Status and controls
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.grey[100],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        
                        if (_capturedEmbeddings.length >= _requiredCaptures) ...[
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Enter your name',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _saveUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 50,
                                vertical: 15,
                              ),
                            ),
                            child: const Text(
                              'Complete Enrollment',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
