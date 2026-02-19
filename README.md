# Face Recognition App

A lightweight offline face recognition app using MobileFaceNet and Flutter.

## Features
- Offline face recognition
- Works with/without accessories (glasses, earrings, etc.)
- Secure local storage
- Real-time face detection
- Anti-spoofing capabilities

## Setup Instructions

1. **Place your TFLite model:**
   - Create an `assets` folder in the root directory
   - Copy `mobile_facenet.tflite` into the `assets` folder

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

## How It Works

1. **Enrollment:** User registers by capturing 3-5 face images
2. **Embedding:** Each face is converted to a 192-dimensional vector
3. **Storage:** Embeddings stored locally in encrypted SQLite database
4. **Verification:** New face is compared using cosine similarity
5. **Decision:** If similarity > 0.6, user is authenticated

## Model Details
- **Model:** MobileFaceNet with ArcFace
- **Input:** 112x112 RGB image
- **Output:** 192-dimensional embedding vector
- **Size:** ~4-5MB
