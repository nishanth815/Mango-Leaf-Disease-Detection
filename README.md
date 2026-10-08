# Mango Leaf Doctor (offline Flutter app)

Single mobile app: Flutter UI + the AI backend running **on the phone** via TensorFlow Lite.
No server, no internet permission.

Pipeline (port of `ai_backend/scripts/predict.py`): image quality check -> leaf/non-leaf model ->
INT8 disease model (8 classes) -> HSV severity estimate -> treatment advice (`treatment_data.json`).

## Get the APK
**Option A - no setup (GitHub Actions):** push this folder to a GitHub repo, open the *Actions* tab,
run "Build Android APK", download `MangoLeafDoctor-apk` -> `app-release.apk`, copy to the phone and install.

**Option B - local:** install Flutter, then
```
flutter pub get
flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
# or: flutter run   (phone connected, USB debugging on)
```

## Layout
- `lib/services/mango_classifier.dart` - on-device pipeline (background isolate)
- `lib/services/image_analysis.dart` - blur/brightness check + severity (pure Dart, OpenCV-equivalent)
- `assets/models/` - `mango_disease_int8.tflite`, `leaf_non_leaf.tflite` (converted from the .keras model)
- `assets/data/` - class names + treatment data
- `tools/` - leaf-model conversion script, and the check that the Dart image maths matches OpenCV
