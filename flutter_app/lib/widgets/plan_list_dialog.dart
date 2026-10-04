import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/study_plan_provider.dart';
import '../theme/app_theme.dart';

/// Liste der lokalen Pläne: wechseln, neu anlegen, löschen.
///
/// Ein neuer Plan ist noch nicht eingerichtet; der Hauptbildschirm fragt
/// danach wie beim ersten Start nach Name und Semestern.
class PlanListDialog extends StatelessWidget {
  const PlanListDialog({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    StudyPlanProvider provider,
    LocalPlanSummary plan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Plan löschen?'),
        content: Text(
          'Soll der Plan „${plan.name}“ auf diesem Gerät gelöscht werden? '
          'Das lässt sich nicht rückgängig machen. Exportiere ihn vorher, '
          'wenn du ihn behalten möchtest.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.cs.error,
              foregroundColor: context.cs.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.deleteLocalPlan(plan.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudyPlanProvider>();
    final plans = provider.localPlans;
    return AlertDialog(
      title: const Text('Pläne'),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final plan in plans)
              ListTile(
                key: ValueKey('plan-${plan.id}'),
                leading: Icon(
                  plan.id == provider.currentLocalPlanId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: plan.id == provider.currentLocalPlanId
                      ? context.cs.primary
                      : context.cs.onSurfaceVariant,
                ),
                title: Text(plan.name),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: context.tone(Colors.red)),
                  tooltip: 'Plan löschen',
                  onPressed: () => _confirmDelete(context, provider, plan),
                ),
                onTap: () async {
                  await provider.switchLocalPlan(plan.id);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Schließen'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Neuer Plan'),
          onPressed: () async {
            await provider.createLocalPlan();
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
