import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/study_plan.dart';

/// Optional input for the ECTS the whole degree needs. Empty means no target.
class TargetEctsField extends StatelessWidget {
  const TargetEctsField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const Key('target-ects'),
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: const InputDecoration(
        labelText: 'ECTS fürs ganze Studium (optional)',
        hintText: 'z. B. 180',
        helperText: 'Zeigt, ob deine Planung darüber oder darunter liegt.',
        helperMaxLines: 2,
        suffixText: 'ECTS',
      ),
      validator: (text) {
        try {
          StudyPlan.parseTargetEcts(text ?? '');
          return null;
        } on FormatException catch (e) {
          return e.message;
        }
      },
      onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
    );
  }
}
