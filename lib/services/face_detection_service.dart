import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

/// Service for detecting faces in camera frames using Google ML Kit
class FaceDetectionService {
  late FaceDetector _faceDetector;
  bool _isInitialized = false;

  /// Initialize the face detector
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('Initializing face detector...');
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          enableClassification: false,
          enableTracking: false,
          minFaceSize: 0.15, // Minimum face size (15% of image)
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
      _isInitialized = true;
      print('Face detector initialized successfully!');
    } catch (e) {
      print('Error initializing face detector: $e');
      throw Exception('Failed to initialize face detector: $e');
    }
  }

  /// Detect faces in a camera image
  /// Returns a list of detected faces
  Future<List<Face>> detectFaces(InputImage inputImage) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final faces = await _faceDetector.processImage(inputImage);
      return faces;
    } catch (e) {
      print('Error detecting faces: $e');
      return [];
    }
  }

  /// Convert CameraImage to InputImage for ML Kit processing
  InputImage? convertCameraImage(CameraImage cameraImage, CameraDescription camera) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in cameraImage.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(
        cameraImage.width.toDouble(),
        cameraImage.height.toDouble(),
      );

      final InputImageRotation imageRotation = _rotationIntToImageRotation(
        camera.sensorOrientation,
      );

      final InputImageFormat inputImageFormat = InputImageFormat.nv21;

      final planeData = cameraImage.planes.map((Plane plane) {
        return InputImageMetadata(
          size: Size(plane.width!.toDouble(), plane.height!.toDouble()),
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: plane.bytesPerRow,
        );
      }).toList();

      final inputImageMetadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: cameraImage.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageMetadata,
      );
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  /// Convert sensor orientation to InputImageRotation
  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  /// Crop face from image using detected face bounding box
  /// Returns the cropped face image with some padding
  img.Image? cropFace(img.Image fullImage, Face face, {double padding = 0.2}) {
    try {
      final boundingBox = face.boundingBox;
      
      // Add padding around the face
      final paddingX = (boundingBox.width * padding).toInt();
      final paddingY = (boundingBox.height * padding).toInt();

      int x = (boundingBox.left - paddingX).toInt().clamp(0, fullImage.width);
      int y = (boundingBox.top - paddingY).toInt().clamp(0, fullImage.height);
      int width = (boundingBox.width + 2 * paddingX).toInt();
      int height = (boundingBox.height + 2 * paddingY).toInt();

      // Ensure we don't go beyond image boundaries
      width = width.clamp(0, fullImage.width - x);
      height = height.clamp(0, fullImage.height - y);

      return img.copyCrop(
        fullImage,
        x: x,
        y: y,
        width: width,
        height: height,
      );
    } catch (e) {
      print('Error cropping face: $e');
      return null;
    }
  }

  /// Check if face quality is good enough for recognition
  /// Returns true if face is frontal, well-lit, and large enough
  bool isFaceQualityGood(Face face, Size imageSize) {
    // Check face size (at least 20% of image height)
    final faceHeight = face.boundingBox.height;
    final minHeight = imageSize.height * 0.2;
    if (faceHeight < minHeight) {
      return false;
    }

    // Check if face has landmarks (indicates frontal face)
    if (face.landmarks.isEmpty) {
      return false;
    }

    // Check head rotation angles (optional, may need adjustment)
    final headEulerAngleY = face.headEulerAngleY;
    final headEulerAngleZ = face.headEulerAngleZ;
    
    if (headEulerAngleY != null && headEulerAngleY.abs() > 30) {
      return false; // Face is turned too much left/right
    }
    
    if (headEulerAngleZ != null && headEulerAngleZ.abs() > 30) {
      return false; // Face is tilted too much
    }

    return true;
  }

  /// Dispose resources
  void dispose() {
    if (_isInitialized) {
      _faceDetector.close();
      _isInitialized = false;
    }
  }

  bool get isInitialized => _isInitialized;
}
