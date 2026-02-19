import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../services/face_detection_service.dart';
import '../services/ml_service.dart';
import '../services/database_service.dart';

/// Screen for verifying users (face unlock/authentication)
class VerificationScreen extends StatefulWidget {
  final CameraDescription camera;

  const VerificationScreen({Key? key, required this.camera}) : super(key: key);

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  CameraController? _cameraController;
  final FaceDetectionService _faceDetectionService = FaceDetectionService();
  final MLService _mlService = MLService();
  final DatabaseService _databaseService = DatabaseService();

  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _faceDetected = false;
  bool _isVerified = false;
  
  String _statusMessage = 'Look at the camera to verify';
  String _verifiedUserName = '';
  double _matchScore = 0.0;
  
  // Verification threshold (adjust based on testing)
  final double _verificationThreshold = 0.6;

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
    if (_isProcessing || _isVerified) return;
    
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
          _statusMessage = 'No face detected';
        });
        _isProcessing = false;
        return;
      }

      if (faces.length > 1) {
        setState(() {
          _faceDetected = false;
          _statusMessage = 'Multiple faces detected';
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
          _statusMessage = 'Face the camera directly';
        });
        _isProcessing = false;
        return;
      }

      setState(() {
        _faceDetected = true;
        _statusMessage = 'Verifying...';
      });

      // Convert camera image to img.Image
      final fullImage = _convertYUV420ToImage(cameraImage);
      if (fullImage == null) {
        _isProcessing = false;
        return;
      }

      // Crop face
      final croppedFace = _faceDetectionService.cropFace(fullImage, face);
      if (croppedFace == null) {
        _isProcessing = false;
        return;
      }

      // Generate embedding
      final currentEmbedding = await _mlService.generateEmbedding(croppedFace);

      // Get all registered users
      final allUsers = await _databaseService.getAllUsers();

      if (allUsers.isEmpty) {
        setState(() {
          _statusMessage = 'No users registered';
        });
        _isProcessing = false;
        return;
      }

      // Find best match
      UserFaceData? bestMatch;
      double bestSimilarity = 0.0;

      for (var user in allUsers) {
        // Compare with all embeddings of this user and take maximum
        double maxSimilarity = 0.0;
        for (var storedEmbedding in user.embeddings) {
          final similarity = _mlService.calculateSimilarity(
            currentEmbedding,
            storedEmbedding,
          );
          if (similarity > maxSimilarity) {
            maxSimilarity = similarity;
          }
        }

        if (maxSimilarity > bestSimilarity) {
          bestSimilarity = maxSimilarity;
          bestMatch = user;
        }
      }

      // Check if best match exceeds threshold
      if (bestMatch != null && bestSimilarity >= _verificationThreshold) {
        await _cameraController?.stopImageStream();
        setState(() {
          _isVerified = true;
          _verifiedUserName = bestMatch!.userName;
          _matchScore = bestSimilarity;
          _statusMessage = 'Verified!';
        });

        // Show success for 2 seconds then go back
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, {
            'verified': true,
            'userName': _verifiedUserName,
            'score': _matchScore,
          });
        }
      } else {
        setState(() {
          _statusMessage = 'Face not recognized (Score: ${(bestSimilarity * 100).toStringAsFixed(1)}%)';
        });
        
        // Wait a bit before trying again
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } catch (e) {
      print('Error processing frame: $e');
      setState(() {
        _statusMessage = 'Error: $e';
      });
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

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Verification'),
        backgroundColor: Colors.green,
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Camera preview
                if (_cameraController != null && _cameraController!.value.isInitialized)
                  Positioned.fill(
                    child: CameraPreview(_cameraController!),
                  ),

                // Face detection indicator
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isVerified
                            ? Colors.green
                            : (_faceDetected ? Colors.blue : Colors.red),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(125),
                    ),
                  ),
                ),

                // Status overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        if (_isVerified) ...[
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 60,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Welcome, $_verifiedUserName!',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Match: ${(_matchScore * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                            ),
                          ),
                        ] else ...[
                          Text(
                            _statusMessage,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Threshold adjustment button (for testing)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Threshold: ${(_verificationThreshold * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
