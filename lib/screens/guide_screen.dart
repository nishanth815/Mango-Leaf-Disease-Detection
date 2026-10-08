import 'package:flutter/material.dart';

import '../models/prediction_result.dart';
import '../services/mango_classifier.dart';
import '../widgets/treatment_sections.dart';

/// Offline reference of every condition the model can recognise.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Disease guide')),
      body: FutureBuilder<List<String>>(
        future: MangoClassifier.instance.classNames(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Could not load guide: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final names = snap.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: names.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final name = names[i];
              final healthy = name == 'Healthy';
              return Card(
                child: ListTile(
                  leading: Icon(
                    healthy ? Icons.check_circle_rounded : Icons.bug_report_rounded,
                    color: healthy ? Colors.green : Colors.deepOrange,
                  ),
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _DiseaseDetail(name: name),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DiseaseDetail extends StatelessWidget {
  final String name;
  const _DiseaseDetail({required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: FutureBuilder<Treatment>(
        future: MangoClassifier.instance.treatmentFor(name),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final t = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TreatmentSections(treatment: t, initiallyExpanded: true),
              if (t.bySeverity.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('By severity',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final e in t.bySeverity.entries)
                  Card(
                    child: ListTile(
                      title: Text(e.key,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(e.value),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
