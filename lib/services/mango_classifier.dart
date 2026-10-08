import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/prediction_result.dart';
import 'image_analysis.dart';

/// Fully offline replacement for the FastAPI backend (`ai_backend/main.py`).
///
/// Pipeline (same order as `run_prediction` in `predict.py`):
///   1. image quality check        (blur / dark / overexposed)
///   2. leaf vs non-leaf check     (leaf_non_leaf.tflite)
///   3. disease classification     (mango_disease_int8.tflite)
///   4. severity estimation        (HSV colour thresholds)
///   5. treatment lookup           (treatment_data.json)
///
/// All heavy work runs in a background isolate so the UI stays smooth.
class MangoClassifier {
  MangoClassifier._();
  static final MangoClassifier instance = MangoClassifier._();

  static const _diseaseModelAsset = 'assets/models/mango_disease_int8.tflite';
  static const _leafModelAsset = 'assets/models/leaf_non_leaf.tflite';
  static const _classNamesAsset = 'assets/data/class_names.json';
  static const _treatmentAsset = 'assets/data/treatment_data.json';

  _Assets? _assets;

  /// Names of all diseases the model knows (for the offline guide screen).
  Future<List<String>> classNames() async => (await _load()).classNames;

  /// Treatment advice for one class (for the offline guide screen).
  Future<Treatment> treatmentFor(String disease) async {
    final a = await _load();
    final raw = a.treatment[disease];
    return raw is Map
        ? Treatment.fromJson(Map<String, dynamic>.from(raw))
        : const Treatment();
  }

  Future<_Assets> _load() async {
    final cached = _assets;
    if (cached != null) return cached;

    final disease = (await rootBundle.load(_diseaseModelAsset)).buffer;
    final leaf = (await rootBundle.load(_leafModelAsset)).buffer;
    final names = (jsonDecode(await rootBundle.loadString(_classNamesAsset))
            as List)
        .map((e) => e.toString())
        .toList();
    final treatment = Map<String, dynamic>.from(
      jsonDecode(await rootBundle.loadString(_treatmentAsset)) as Map,
    );

    return _assets = _Assets(
      diseaseModel: disease.asUint8List(),
      leafModel: leaf.asUint8List(),
      classNames: names,
      treatment: treatment,
    );
  }

  /// Runs the whole pipeline on the image at [imagePath].
  Future<PredictionResult> analyze(String imagePath) async {
    try {
      final assets = await _load();
      final bytes = await File(imagePath).readAsBytes();
      final job = _Job(bytes, assets);
      return await Isolate.run(() => _runPipeline(job));
    } catch (e) {
      return PredictionResult.error(e.toString());
    }
  }
}

class _Assets {
  final Uint8List diseaseModel;
  final Uint8List leafModel;
  final List<String> classNames;
  final Map<String, dynamic> treatment;
  _Assets({
    required this.diseaseModel,
    required this.leafModel,
    required this.classNames,
    required this.treatment,
  });
}

class _Job {
  final Uint8List imageBytes;
  final _Assets assets;
  _Job(this.imageBytes, this.assets);
}

// ===========================================================================
// Everything below runs inside the background isolate.
// ===========================================================================

const int _inputSize = 224;

// Quantisation parameters of mango_disease_int8.tflite (read from the model:
// input scale 1.0 / zero-point -128, output scale 1/256 / zero-point -128).
const double _inScale = 1.0;
const int _inZero = -128;
const double _outScale = 0.00390625;
const int _outZero = -128;

PredictionResult _runPipeline(_Job job) {
  final a = job.assets;

  var decoded = img.decodeImage(job.imageBytes);
  if (decoded == null) {
    return PredictionResult.error('Could not read image');
  }
  decoded = img.bakeOrientation(decoded);

  // 1. QUALITY -------------------------------------------------------------
  final quality = checkImageQuality(decoded);
  if (!quality.ok) {
    return PredictionResult.rejected(quality.message);
  }

  // Model input: 224x224 RGB. Area averaging approximates the anti-aliased
  // resize used by PIL in the Python backend.
  final resized = img.copyResize(
    decoded,
    width: _inputSize,
    height: _inputSize,
    interpolation: img.Interpolation.average,
  );

  // 2. LEAF / NON-LEAF -----------------------------------------------------
  final leafProb = _predictLeaf(a.leafModel, resized);
  // Directory order in training: leaf = 0, non_leaf = 1.
  final isLeaf = leafProb < 0.5;
  if (!isLeaf) {
    return PredictionResult.rejected(
      'Image does not appear to contain a leaf',
    );
  }

  // 3. DISEASE -------------------------------------------------------------
  final probs = _predictDisease(a.diseaseModel, resized);
  var best = 0;
  for (var i = 1; i < probs.length; i++) {
    if (probs[i] > probs[best]) best = i;
  }
  final disease =
      best < a.classNames.length ? a.classNames[best] : 'Class $best';

  final scores = <ClassScore>[
    for (var i = 0; i < probs.length; i++)
      ClassScore(
        i < a.classNames.length ? a.classNames[i] : 'Class $i',
        probs[i] * 100,
      ),
  ]..sort((x, y) => y.percent.compareTo(x.percent));

  // 4. SEVERITY ------------------------------------------------------------
  final sev = estimateSeverity(decoded);

  // 5. TREATMENT -----------------------------------------------------------
  final raw = a.treatment[disease];
  final treatment = raw is Map
      ? Treatment.fromJson(Map<String, dynamic>.from(raw))
      : const Treatment();

  return PredictionResult.success(
    disease: disease,
    confidence: probs[best] * 100,
    severity: sev.percent,
    severityCategory: sev.category,
    treatment: treatment,
    scores: scores,
  );
}

/// Returns the raw sigmoid output (>= 0.5 means "not a leaf").
/// The model expects raw 0-255 pixel values (no /255 scaling).
double _predictLeaf(Uint8List modelBytes, img.Image im) {
  final input = Float32List(_inputSize * _inputSize * 3);
  var i = 0;
  for (var y = 0; y < _inputSize; y++) {
    for (var x = 0; x < _inputSize; x++) {
      final p = im.getPixel(x, y);
      input[i++] = p.r.toDouble();
      input[i++] = p.g.toDouble();
      input[i++] = p.b.toDouble();
    }
  }

  final interpreter = Interpreter.fromBuffer(
    modelBytes,
    options: InterpreterOptions()..threads = 2,
  );
  try {
    final output = List.filled(1, 0.0).reshape([1, 1]);
    interpreter.run(input.reshape([1, _inputSize, _inputSize, 3]), output);
    return (output[0][0] as num).toDouble();
  } finally {
    interpreter.close();
  }
}

/// INT8 inference + de-quantisation + probability normalisation, matching
/// `predict_disease` in the backend.
List<double> _predictDisease(Uint8List modelBytes, img.Image im) {
  final input = Int8List(_inputSize * _inputSize * 3);
  var i = 0;
  int q(num v) => ((v / _inScale) + _inZero).round().clamp(-128, 127).toInt();
  for (var y = 0; y < _inputSize; y++) {
    for (var x = 0; x < _inputSize; x++) {
      final p = im.getPixel(x, y);
      input[i++] = q(p.r);
      input[i++] = q(p.g);
      input[i++] = q(p.b);
    }
  }

  final interpreter = Interpreter.fromBuffer(
    modelBytes,
    options: InterpreterOptions()..threads = 2,
  );
  try {
    final classes = interpreter.getOutputTensor(0).shape.last;
    final output = List.filled(classes, 0).reshape([1, classes]);
    interpreter.run(input.reshape([1, _inputSize, _inputSize, 3]), output);

    final preds = <double>[
      for (final v in (output[0] as List))
        ((v as num).toInt() - _outZero) * _outScale,
    ];
    return _normalise(preds);
  } finally {
    interpreter.close();
  }
}

List<double> _normalise(List<double> p) {
  final mn = p.reduce(math.min);
  final mx = p.reduce(math.max);

  if (mn < 0 || mx > 1) {
    // logits -> softmax
    final e = [for (final v in p) math.exp(v - mx)];
    final s = e.fold<double>(0, (a, b) => a + b);
    return [for (final v in e) v / s];
  }
  final total = p.fold<double>(0, (a, b) => a + b);
  return total > 0 ? [for (final v in p) v / total] : p;
}
