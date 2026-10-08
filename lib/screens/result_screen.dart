import 'dart:io';

import 'package:flutter/material.dart';

import '../models/prediction_result.dart';
import '../widgets/treatment_sections.dart';

class ResultScreen extends StatelessWidget {
  final PredictionResult result;
  final String imagePath;

  const ResultScreen({
    super.key,
    required this.result,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final ok = result.status == AnalysisStatus.success;

    return Scaffold(
      appBar: AppBar(title: Text(ok ? 'Diagnosis' : 'Could not analyze')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Colors.black12,
                  child: Center(child: Icon(Icons.broken_image, size: 48)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (ok) ..._success(context) else ..._failure(context),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            icon: const Icon(Icons.camera_alt_rounded),
            label: Text(ok ? 'Check another leaf' : 'Try again'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- success
  List<Widget> _success(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final healthy = result.isHealthy;
    final accent = healthy ? Colors.green.shade700 : Colors.deepOrange.shade700;
    final lowConfidence = result.confidence < 60;

    return [
      Row(
        children: [
          Icon(
            healthy ? Icons.check_circle_rounded : Icons.bug_report_rounded,
            color: accent,
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(healthy ? 'Leaf looks' : 'Detected',
                    style: text.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    )),
                Text(
                  result.disease,
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      if (lowConfidence) ...[
        const SizedBox(height: 12),
        _Banner(
          icon: Icons.help_outline_rounded,
          color: Colors.amber.shade800,
          text: 'The model is not very sure about this result. Retake the '
              'photo in good light, or confirm with an expert.',
        ),
      ],
      const SizedBox(height: 16),
      _MeterCard(
        title: 'Confidence',
        icon: Icons.verified_rounded,
        value: result.confidence,
        label: '${result.confidence.toStringAsFixed(1)}%',
        color: cs.primary,
      ),
      _MeterCard(
        title: 'Affected leaf area',
        icon: Icons.warning_amber_rounded,
        value: result.severity,
        label: '${result.severity.toStringAsFixed(1)}%  -  '
            '${result.severityCategory}',
        color: switch (result.severityCategory) {
          'Mild' => Colors.green,
          'Moderate' => Colors.orange,
          'Severe' => Colors.red,
          _ => Colors.grey,
        },
        footnote: result.severityAdvice,
      ),
      if (result.scores.length > 1) _TopPredictions(result.scores),
      const SizedBox(height: 8),
      Text('What to do',
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      TreatmentSections(
        treatment: result.treatment,
        initiallyExpanded: !healthy,
      ),
      const SizedBox(height: 4),
      Text(
        'This is an AI estimate, not a professional diagnosis. Always follow '
        'product labels and local agricultural advice.',
        style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    ];
  }

  // ---------------------------------------------------------------- failure
  List<Widget> _failure(BuildContext context) {
    final rejected = result.status == AnalysisStatus.rejected;
    final text = Theme.of(context).textTheme;

    return [
      _Banner(
        icon: rejected ? Icons.image_not_supported_rounded : Icons.error_rounded,
        color: rejected ? Colors.orange.shade800 : Colors.red.shade700,
        text: result.reason ?? 'Something went wrong.',
        large: true,
      ),
      if (rejected) ...[
        const SizedBox(height: 18),
        Text('For a good result',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const _Tip('Photograph a single mango leaf, filling most of the frame.'),
        const _Tip('Use bright, even daylight - avoid harsh shadows and flash.'),
        const _Tip('Hold steady and wait for the camera to focus.'),
      ],
    ];
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final bool large;

  const _Banner({
    required this.icon,
    required this.color,
    required this.text,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: large ? 30 : 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: large ? 17 : 14,
                fontWeight: large ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final String text;
  const _Tip(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_rounded,
                size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _MeterCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double value; // 0-100
  final String label;
  final Color color;
  final String? footnote;

  const _MeterCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0.0, 1.0).toDouble(),
                minHeight: 10,
                color: color,
                backgroundColor: color.withValues(alpha: .15),
              ),
            ),
            if (footnote != null) ...[
              const SizedBox(height: 10),
              Text(footnote!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopPredictions extends StatelessWidget {
  final List<ClassScore> scores;
  const _TopPredictions(this.scores);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final top = scores.take(3).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Other possibilities',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final s in top)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: Text(s.label)),
                    Expanded(
                      flex: 5,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (s.percent / 100).clamp(0.0, 1.0).toDouble(),
                          minHeight: 8,
                          color: cs.primary,
                          backgroundColor: cs.primary.withValues(alpha: .12),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text('${s.percent.toStringAsFixed(1)}%',
                          textAlign: TextAlign.end),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
