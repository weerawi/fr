import 'dart:math';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

/// Service for managing MobileFaceNet model and generating face embeddings
class MLService {
  static const String MODEL_PATH = 'assets/mobilefacenet.tflite';
  static const int INPUT_SIZE = 112; // MobileFaceNet expects 112x112 images
  static const int EMBEDDING_SIZE = 192; // Output dimension

  Interpreter? _interpreter;
  bool _isInitialized = false;

  /// Initialize the TFLite model
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('Loading MobileFaceNet model...');
      _interpreter = await Interpreter.fromAsset(MODEL_PATH);
      
      // Verify input/output shapes
      print('Input shape: ${_interpreter!.getInputTensors()}');
      print('Output shape: ${_interpreter!.getOutputTensors()}');
      
      _isInitialized = true;
      print('MobileFaceNet model loaded successfully!');
    } catch (e) {
      print('Error loading model: $e');
      throw Exception('Failed to load MobileFaceNet model: $e');
    }
  }

  /// Generate a 192-dimensional face embedding from a face image
  /// 
  /// [faceImage] - Cropped face image (will be resized to 112x112)
  /// Returns a normalized embedding vector
  Future<List<double>> generateEmbedding(img.Image faceImage) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Resize to 112x112
    final resizedImage = img.copyResize(
      faceImage,
      width: INPUT_SIZE,
      height: INPUT_SIZE,
    );

    // Convert to normalized float array [1, 112, 112, 3]
    final input = _imageToByteListFloat32(resizedImage);

    // Prepare output buffer [1, 192]
    final output = List.generate(1, (index) => List<double>.filled(EMBEDDING_SIZE, 0.0));

    // Run inference
    _interpreter!.run(input, output);

    // Extract and normalize the embedding
    final embedding = output[0];
    return _normalizeEmbedding(embedding);
  }

  /// Convert image to float32 input array normalized to [-1, 1]
  List<List<List<List<double>>>> _imageToByteListFloat32(img.Image image) {
    var input = List.generate(
      1,
      (index) => List.generate(
        INPUT_SIZE,
        (y) => List.generate(
          INPUT_SIZE,
          (x) {
            final pixel = image.getPixel(x, y);
            return [
              (pixel.r / 127.5) - 1.0,
              (pixel.g / 127.5) - 1.0,
              (pixel.b / 127.5) - 1.0,
            ];
          },
        ),
      ),
    );

    return input;
  }

  /// L2-normalize the embedding vector
  List<double> _normalizeEmbedding(List<double> embedding) {
    double sumSquares = 0.0;
    for (var value in embedding) {
      sumSquares += value * value;
    }
    final norm = sqrt(sumSquares);
    
    if (norm == 0) return embedding;
    
    return embedding.map((value) => value / norm).toList();
  }

  /// Calculate cosine similarity between two embeddings
  /// Returns a value between -1 and 1 (1 = identical, 0 = orthogonal, -1 = opposite)
  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw ArgumentError('Embeddings must have the same length');
    }

    double dotProduct = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }

    // Since embeddings are already L2-normalized, dot product = cosine similarity
    return dotProduct;
  }

  /// Calculate Euclidean distance between two embeddings
  double calculateDistance(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw ArgumentError('Embeddings must have the same length');
    }

    double sumSquares = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      final diff = embedding1[i] - embedding2[i];
      sumSquares += diff * diff;
    }

    return sqrt(sumSquares);
  }

  /// Verify if two embeddings belong to the same person
  /// 
  /// [threshold] - Similarity threshold (default 0.6, adjust based on testing)
  /// Higher threshold = more strict (fewer false accepts, more false rejects)
  bool verify(List<double> embedding1, List<double> embedding2, {double threshold = 0.6}) {
    final similarity = calculateSimilarity(embedding1, embedding2);
    return similarity >= threshold;
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}
