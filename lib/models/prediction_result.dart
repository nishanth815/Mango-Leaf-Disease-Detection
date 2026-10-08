/// Treatment advice for one disease (mirrors `treatment_data.json`).
class Treatment {
  final List<String> chemical;
  final List<String> organic;
  final List<String> management;

  /// Advice keyed by severity category: "Mild" | "Moderate" | "Severe".
  final Map<String, String> bySeverity;

  const Treatment({
    this.chemical = const [],
    this.organic = const [],
    this.management = const [],
    this.bySeverity = const {},
  });

  factory Treatment.fromJson(Map<String, dynamic> json) {
    List<String> list(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : const [];
    final sev = json['severity'];
    return Treatment(
      chemical: list(json['chemical_treatment']),
      organic: list(json['organic_treatment']),
      management: list(json['management']),
      bySeverity: sev is Map
          ? sev.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
    );
  }

  bool get isEmpty =>
      chemical.isEmpty && organic.isEmpty && management.isEmpty;
}

class ClassScore {
  final String label;

  /// Percentage 0-100.
  final double percent;

  const ClassScore(this.label, this.percent);
}

enum AnalysisStatus { success, rejected, error }

/// Result of the on-device pipeline. Plain fields only, so it can be sent
/// back from a background isolate.
class PredictionResult {
  final AnalysisStatus status;

  /// Why the image was rejected, or the error message.
  final String? reason;

  final String disease;
  final double confidence;
  final double severity;
  final String severityCategory;
  final Treatment treatment;

  /// All classes sorted by probability (highest first).
  final List<ClassScore> scores;

  const PredictionResult._({
    required this.status,
    this.reason,
    this.disease = '',
    this.confidence = 0,
    this.severity = 0,
    this.severityCategory = 'Unknown',
    this.treatment = const Treatment(),
    this.scores = const [],
  });

  factory PredictionResult.success({
    required String disease,
    required double confidence,
    required double severity,
    required String severityCategory,
    required Treatment treatment,
    required List<ClassScore> scores,
  }) =>
      PredictionResult._(
        status: AnalysisStatus.success,
        disease: disease,
        confidence: confidence,
        severity: severity,
        severityCategory: severityCategory,
        treatment: treatment,
        scores: scores,
      );

  factory PredictionResult.rejected(String reason) =>
      PredictionResult._(status: AnalysisStatus.rejected, reason: reason);

  factory PredictionResult.error(String message) =>
      PredictionResult._(status: AnalysisStatus.error, reason: message);

  bool get isHealthy => disease == 'Healthy';

  /// Advice for the detected severity, if the treatment table has it.
  String? get severityAdvice => treatment.bySeverity[severityCategory];
}
