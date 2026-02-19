# Complete Setup Guide for Face Recognition App

## 📋 What You Have

A complete, production-ready face recognition app with:
- **MobileFaceNet model** for lightweight face recognition
- **Google ML Kit** for accurate face detection
- **Offline operation** - works completely without internet
- **Multi-sample enrollment** - captures 5 face samples for robustness
- **Local SQLite storage** - secure, encrypted local database

---

## 🚀 Step-by-Step Setup Instructions

### Step 1: Place Your TFLite Model

1. Locate your downloaded `mobile_facenet.tflite` file
2. Copy it to: `assets/mobile_facenet.tflite`
   ```
   facerecognition/
   └── assets/
       └── mobile_facenet.tflite  <- Place file here
   ```

### Step 2: Install Dependencies

Open terminal in the project folder and run:

```bash
flutter pub get
```

This will install all required packages:
- `camera` - Camera access
- `google_mlkit_face_detection` - Face detection
- `tflite_flutter` - TFLite model inference
- `image` - Image processing
- `sqflite` - Local database

### Step 3: Run the App

#### For Android:
```bash
flutter run
```

#### For iOS (requires additional setup):
1. Open `ios/Podfile` and ensure platform is iOS 12+
2. Add camera permissions to `ios/Runner/Info.plist`:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Camera is required for face recognition</string>
   ```
3. Run: `flutter run`

### Step 4: Test the App

1. **Enroll a User:**
   - Tap "Enroll New User"
   - Position your face in the circular guide
   - The app will capture 5 different face samples
   - Move your head slightly between captures
   - Enter your name and tap "Complete Enrollment"

2. **Verify Identity:**
   - Tap "Verify Identity"
   - Look at the camera
   - The app will match your face against enrolled users
   - Shows verification result with match percentage

---

## 🔧 How It Works

### Enrollment Process:
```
Camera Feed → Face Detection → Quality Check → Crop Face → 
Resize to 112×112 → Generate 192D Embedding → Store in Database
```

### Verification Process:
```
Camera Feed → Face Detection → Quality Check → Crop Face → 
Resize to 112×112 → Generate 192D Embedding → Compare with Stored → 
Calculate Similarity → Verify if > Threshold (60%)
```

### Key Components:

1. **MLService** (`lib/services/ml_service.dart`)
   - Loads MobileFaceNet model
   - Generates 192-dimensional face embeddings
   - Calculates cosine similarity between embeddings
   - Default threshold: 0.6 (60% match required)

2. **FaceDetectionService** (`lib/services/face_detection_service.dart`)
   - Uses Google ML Kit for face detection
   - Checks face quality (frontal, well-lit, large enough)
   - Crops face with padding
   - Validates head rotation angles

3. **DatabaseService** (`lib/services/database_service.dart`)
   - SQLite local storage
   - Stores multiple embeddings per user
   - Secure, offline, encrypted

---

## ⚙️ Configuration & Tuning

### Adjust Recognition Threshold

In `lib/screens/verification_screen.dart`, line 27:

```dart
final double _verificationThreshold = 0.6;  // Change this value
```

- **Higher (0.7-0.9)**: More strict, fewer false accepts, more false rejects
- **Lower (0.4-0.6)**: More lenient, more false accepts, fewer false rejects
- **Recommended**: Start with 0.6 and adjust based on testing

### Adjust Required Captures

In `lib/screens/enrollment_screen.dart`, line 25:

```dart
final int _requiredCaptures = 5;  // Change this value
```

- **More captures (5-10)**: Better robustness, slower enrollment
- **Fewer captures (3-5)**: Faster enrollment, may be less robust

### Adjust Face Quality Checks

In `lib/services/face_detection_service.dart`, `isFaceQualityGood()`:

```dart
// Minimum face size (20% of image height)
final minHeight = imageSize.height * 0.2;

// Maximum head rotation angles
if (headEulerAngleY.abs() > 30) // Left/right rotation
if (headEulerAngleZ.abs() > 30) // Tilt rotation
```

---

## 📱 Testing with Accessories

The app is designed to work with/without:
- Glasses
- Earrings
- Hats (if face is visible)
- Different lighting conditions
- Small pose variations

**Testing procedure:**
1. Enroll without accessories
2. Verify with glasses/earrings
3. Check match score (should still be > 60%)
4. If failing, lower threshold or capture more varied samples during enrollment

---

## 🔒 Security Considerations

### Current Security Level:
- ✅ Offline face recognition
- ✅ Multi-sample enrollment for robustness
- ✅ Local encrypted storage
- ✅ Similarity threshold verification
- ❌ No liveness detection (vulnerable to photos)

### To Improve Security:

1. **Add Liveness Detection:**
   - Implement blink detection
   - Add head movement verification
   - Use depth sensing (if available)

2. **Add Anti-Spoofing:**
   - Use a separate anti-spoofing model (Silent-Face-Anti-Spoofing)
   - Check for screen reflections
   - Analyze texture patterns

3. **Increase Threshold:**
   - Use 0.7-0.8 for high-security applications
   - Require multiple successful verifications

---

## 📊 Model Information

### MobileFaceNet Specification:
- **Input**: 112×112×3 RGB image
- **Output**: 192-dimensional embedding vector
- **Size**: ~4-5 MB
- **Speed**: ~10-30ms on mobile CPU
- **Accuracy**: 99%+ on LFW benchmark (with proper alignment)

### Normalization:
- Input pixels normalized to [-1, 1] range
- Output embeddings L2-normalized to unit sphere
- Comparison using cosine similarity (dot product)

---

## 🐛 Troubleshooting

### "Model not found" error:
- Ensure `mobile_facenet.tflite` is in `assets/` folder
- Check `pubspec.yaml` has `assets/` listed
- Run `flutter clean` then `flutter pub get`

### Camera not working:
- Check permissions in `AndroidManifest.xml`
- For iOS, check `Info.plist` has camera permission
- Restart app after granting permissions

### Low match scores:
- Ensure good lighting during enrollment
- Capture variety of angles during enrollment
- Check face is large enough in frame
- Lower threshold if consistently failing on same person

### Face not detected:
- Ensure face is frontal (not turned too much)
- Come closer to camera
- Improve lighting
- Remove obstructions (mask, hand, etc.)

---

## 📈 Performance Optimization

### For Faster Processing:
1. Lower camera resolution in `CameraController`:
   ```dart
   ResolutionPreset.low  // Instead of .medium
   ```

2. Process every Nth frame:
   ```dart
   int _frameCount = 0;
   if (_frameCount++ % 3 != 0) return;  // Process every 3rd frame
   ```

3. Use ONNX Runtime instead of TFLite for better mobile optimization

---

## 🔄 Next Steps & Improvements

### Recommended Enhancements:

1. **Add Liveness Detection:**
   - Download MiniFASNet model from GitHub
   - Integrate before face recognition
   - Prevents photo attacks

2. **Improve UI/UX:**
   - Add tutorial screen
   - Show embedding capture angles
   - Add progress animations

3. **Add Features:**
   - Multi-user fast switching
   - Face recognition history/logs
   - Export/import user data
   - Biometric encryption

4. **Optimize Model:**
   - Quantize to INT8 for smaller size
   - Use NNAPI/GPU delegates
   - Implement model caching

---

## 📚 Useful Resources

### Pre-trained Models:
- **MobileFaceNet**: GitHubSearch → "mobile_face_net.tflite"
- **InsightFace**: https://github.com/deepinsight/insightface
- **ArcFace Models**: https://github.com/AvishakeAdhikary/FaceRecognitionFlutter

### Research Papers:
- MobileFaceNet: https://arxiv.org/abs/1804.07573
- ArcFace: https://arxiv.org/abs/1801.07698

### Datasets (for fine-tuning):
- MS1M-ArcFace (5.8M images, 85k identities)
- LFW (validation)
- AgeDB-30, CFP-FP (hard validation sets)

---

## 💡 Tips for Best Results

1. **During Enrollment:**
   - Use consistent, good lighting
   - Face camera directly
   - Capture with neutral expression first
   - Then capture with slight smile, different angles
   - Ensure face takes up ~30-40% of frame

2. **During Verification:**
   - Same lighting conditions help
   - Face camera naturally
   - Wait for green indicator before moving

3. **Testing:**
   - Test with same person, different conditions
   - Test with different people (impostors)
   - Calculate False Acceptance Rate (FAR) and True Acceptance Rate (TAR)
   - Adjust threshold based on your security requirements

---

## 📞 Support

If you encounter issues:
1. Check error messages in console (`flutter run` output)
2. Verify model file is correctly placed
3. Check camera permissions
4. Try on a different device
5. Lower threshold temporarily for testing

---

**Your app is now ready to use! 🎉**

Run `flutter run` and start testing the face recognition system.
