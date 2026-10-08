import 'package:flutter/material.dart';

import '../models/prediction_result.dart';

/// Chemical / organic / management advice as three expandable cards.
class TreatmentSections extends StatelessWidget {
  final Treatment treatment;
  final bool initiallyExpanded;

  const TreatmentSections({
    super.key,
    required this.treatment,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (treatment.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('No treatment information available.'),
        ),
      );
    }
    return Column(
      children: [
        _Section(
          title: 'Chemical treatment',
          icon: Icons.science_rounded,
          items: treatment.chemical,
          open: initiallyExpanded,
        ),
        _Section(
          title: 'Organic treatment',
          icon: Icons.spa_rounded,
          items: treatment.organic,
          open: initiallyExpanded,
        ),
        _Section(
          title: 'Orchard management',
          icon: Icons.agriculture_rounded,
          items: treatment.management,
          open: initiallyExpanded,
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final bool open;

  const _Section({
    required this.title,
    required this.icon,
    required this.items,
    required this.open,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: open,
          leading: Icon(icon, color: cs.primary),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7, right: 10),
                      child: Icon(Icons.circle, size: 6, color: cs.primary),
                    ),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
