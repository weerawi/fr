# Where to Get Free Face Recognition Models

## Your Main Model: MobileFaceNet

### Option 1: GitHub Repository (Easiest)
**Repository**: https://github.com/AvishakeAdhikary/FaceRecognitionFlutter

**Steps**:
1. Go to: https://github.com/AvishakeAdhikary/FaceRecognitionFlutter
2. Navigate to `assets/` folder
3. Download `mobile_facenet.tflite` (should be ~4-5MB)
4. Place in your project's `assets/` folder

**This is the EXACT model configured for this app!**

---

### Option 2: InsightFace (Most Popular)
**Repository**: https://github.com/deepinsight/insightface

**Steps**:
1. Clone repository:
   ```bash
   git clone https://github.com/deepinsight/insightface
   cd insightface/model_zoo
   ```

2. Download pre-trained models:
   ```bash
   # Buffalo_L model pack (includes MobileFaceNet)
   wget https://github.com/deepinsight/insightface/releases/download/v0.7/buffalo_l.zip
   unzip buffalo_l.zip
   ```

3. Convert to TFLite if needed (ONNX format provided):
   ```python
   import onnx
   from onnx_tf.backend import prepare
   import tensorflow as tf
   
   onnx_model = onnx.load("mobilefacenet.onnx")
   tf_model = prepare(onnx_model)
   tf_model.export_graph("mobilefacenet_tf")
   
   converter = tf.lite.TFLiteConverter.from_saved_model("mobilefacenet_tf")
   tflite_model = converter.convert()
   
   with open("mobile_facenet.tflite", "wb") as f:
       f.write(tflite_model)
   ```

---

### Option 3: Direct Download Links

**Pre-converted TFLite models** (community-provided):

1. **MobileFaceNet TFLite** (192D embeddings):
   - Search Google: "mobile_facenet.tflite download"
   - Look for GitHub repositories with `assets/mobile_facenet.tflite`
   - Verify file size is 3-5MB

2. **Alternative sources**:
   - https://github.com/sirius-ai/MobileFaceNet_TF
   - https://github.com/MuggleWang/CosFace_pytorch (has conversion scripts)

---

## Liveness Detection Models (Optional but Recommended)

### Silent Face Anti-Spoofing
**Repository**: https://github.com/minivision-ai/Silent-Face-Anti-Spoofing

**Models available**:
1. **MiniFASNetV1** (~500KB)
2. **MiniFASNetV2** (~300KB)
3. **MiniFASNetV1SE** (~500KB, better accuracy)

**Download**:
```bash
git clone https://github.com/minivision-ai/Silent-Face-Anti-Spoofing
cd Silent-Face-Anti-Spoofing/resources

# You'll find .tflite models here
# Or download from releases
```

**Pre-converted TFLite**:
- Search: "MiniFASNet tflite" on GitHub
- Look in `android/assets/` folders of repositories

---

## Alternative Face Recognition Models

### 1. FaceNet (Google)
**TensorFlow Hub**: https://tfhub.dev/google/facenet/1

**Download**:
```python
import tensorflow_hub as hub

model = hub.load("https://tfhub.dev/google/facenet/1")
# Convert to TFLite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()
```

**Specifications**:
- Input: 160×160×3
- Output: 128D embeddings
- Size: ~20-30MB

### 2. ArcFace (Various Backbones)
**Repositories**:
- https://github.com/deepinsight/insightface (official)
- https://github.com/onnx/models/tree/main/vision/body_analysis/arcface (ONNX format)

**Available backbones**:
- MobileFaceNet (4MB) ⭐ **Recommended**
- ResNet18 (25MB)
- ResNet50 (98MB)
- ResNet100 (250MB)

### 3. GhostFaceNet (Ultra-lightweight)
**Repository**: Search GitHub for "GhostFaceNet"

**Specifications**:
- Size: ~2MB
- Output: 128-192D embeddings
- Slightly lower accuracy than MobileFaceNet
- Good for very low-end devices

---

## Face Detection Models (If Not Using ML Kit)

### 1. BlazeFace (Google)
**TensorFlow Hub**: https://tfhub.dev/tensorflow/blazeface/1

**Specifications**:
- Input: 128×128×3
- Ultra-fast (5-10ms)
- Size: ~200KB

### 2. MTCNN (Multi-task CNN)
**Repository**: https://github.com/timesler/facenet-pytorch

**TFLite conversion** available in various repos
**Specifications**:
- 3-stage cascade
- Very accurate
- Slower than BlazeFace

### 3. RetinaFace
**Repository**: https://github.com/ternaus/retinaface

**Mobile variant**:
- MobileNet0.25 backbone
- ~1MB model
- Very accurate

### 4. SCRFD (InsightFace)
**Repository**: https://github.com/deepinsight/insightface/tree/master/detection/scrfd

**Models**:
- SCRFD_500M (~2MB)
- SCRFD_1G (~3MB)
- SCRFD_2.5G (~4MB)

---

## Hugging Face Model Hub

**Search**: https://huggingface.co/models

### Face Recognition Models:
1. **buffalo_l** (InsightFace full suite):
   ```python
   from huggingface_hub import hf_hub_download
   
   model = hf_hub_download(
       repo_id="public-data/insightface",
       filename="models/buffalo_l/w600k_r50.onnx"
   )
   ```

2. **FaceNet models**:
   - Search: "facenet" on Hugging Face
   - Many pre-converted variations available

3. **ArcFace models**:
   - Search: "arcface" on Hugging Face
   - Multiple backbone options

---

## Model Verification Checklist

Before using any downloaded model, verify:

✅ **Input shape**: Should be (1, 112, 112, 3) for MobileFaceNet
✅ **Output shape**: Should be (1, 192) for embeddings
✅ **File size**: 3-6MB for MobileFaceNet
✅ **File type**: `.tflite` extension
✅ **Test inference**: Run on sample image and check output

**Test code**:
```dart
import 'package:tflite_flutter/tflite_flutter.dart';

Future<void> testModel() async {
  final interpreter = await Interpreter.fromAsset('assets/mobile_facenet.tflite');
  
  print('Input tensors: ${interpreter.getInputTensors()}');
  print('Output tensors: ${interpreter.getOutputTensors()}');
  
  // Expected:
  // Input: [1, 112, 112, 3] (Float32)
  // Output: [1, 192] (Float32)
  
  interpreter.close();
}
```

---

## Quick Start: Complete Download Guide

### Step-by-Step for Absolute Beginners:

1. **Download MobileFaceNet**:
   ```
   Go to: https://github.com/AvishakeAdhikary/FaceRecognitionFlutter
   Click: Code → Download ZIP
   Extract ZIP
   Find: assets/mobile_facenet.tflite
   Copy to: Your project's assets/ folder
   ```

2. **Download Liveness Model (Optional)**:
   ```
   Go to: https://github.com/minivision-ai/Silent-Face-Anti-Spoofing
   Click: Code → Download ZIP
   Extract ZIP
   Find: resources/anti_spoof_models/*.tflite
   Copy to: Your project's assets/ folder
   ```

3. **Verify Files**:
   ```
   Your project structure should be:
   
   facerecognition/
   ├── assets/
   │   ├── mobile_facenet.tflite          (3-5MB)
   │   └── mini_fas_net.tflite           (Optional, ~500KB)
   ├── lib/
   │   └── ... (your Dart files)
   └── pubspec.yaml
   ```

4. **Update pubspec.yaml** (if adding liveness):
   ```yaml
   flutter:
     assets:
       - assets/
       - assets/mobile_facenet.tflite
       - assets/mini_fas_net.tflite      # Add this line
   ```

5. **Run**:
   ```bash
   flutter pub get
   flutter run
   ```

---

## Troubleshooting Model Issues

### "Cannot load model" error:
- ✅ Check file path in code matches actual location
- ✅ Ensure `pubspec.yaml` has `assets/` listed
- ✅ Run `flutter clean` then `flutter pub get`
- ✅ Verify file is actually .tflite (not renamed from .onnx)

### "Input shape mismatch" error:
- ✅ Check model expects 112×112×3 input
- ✅ Verify you're resizing images correctly
- ✅ Ensure RGB format (not BGR or RGBA)

### "Model output unexpected" error:
- ✅ Verify output shape is (1, 192)
- ✅ Check if normalization is needed
- ✅ Ensure you downloaded correct model variant

### "Wrong embeddings" (high dissimilarity for same person):
- ✅ Check input normalization (should be [-1, 1] for MobileFaceNet)
- ✅ Verify face alignment is working
- ✅ Ensure proper image format conversion
- ✅ Test with a known-good reference implementation

---

## Recommended Model Combination

For best results with this app:

**Face Detection**: 
- ✅ Google ML Kit (built-in, no download needed) ⭐ **Easiest**
- OR SCRFD mobile variant (if you need more control)

**Face Recognition**:
- ✅ MobileFaceNet from AvishakeAdhikary repo ⭐ **Recommended**
- OR InsightFace buffalo_l pack (more comprehensive)

**Liveness Detection**:
- ✅ MiniFASNetV2 from Silent-Face-Anti-Spoofing ⭐ **Best for mobile**

**Total size**: ~5-6MB (all models combined)
**Total inference time**: ~40-60ms on mid-range phone

---

## Need Help Finding Models?

If you can't find a specific model:

1. **GitHub Code Search**:
   - Search: `"mobile_facenet.tflite" language:Python`
   - Look in `assets/` or `models/` folders

2. **Google Advanced Search**:
   - Search: `site:github.com mobile_facenet.tflite`

3. **Ask Community**:
   - Reddit: r/computervision, r/MachineLearning
   - Stack Overflow: tag `face-recognition` + `tflite`

4. **Convert Yourself**:
   - Download ONNX/PyTorch/TensorFlow model
   - Use conversion tools (see ALGORITHMS_AND_RESEARCH.md)

---

## License Considerations

Most face recognition models are released under permissive licenses:

- **MobileFaceNet**: MIT/Apache 2.0 (check repository)
- **InsightFace**: MIT
- **Silent-Face-Anti-Spoofing**: Apache 2.0
- **Google ML Kit**: Free tier available, check terms

**Always verify** the license before commercial use!

---

**You're now ready to download and use the models! 🎉**

Start with the AvishakeAdhikary repository - it's the easiest path and exactly matches this app's configuration.
