// Confirmations. Every destructive action (block, unblock, role
// change, adjustment delete, sign-out) goes through a confirmation
// dialog first — never on a single accidental tap.
//
// [ConfirmButton] is the dialog's destructive action: the first tap
// arms it (the label visibly changes and a short progress bar runs),
// the second tap confirms. A swipe or a list action alone can never
// confirm anything.

import 'package:flutter/material.dart';

import '../core/strings.dart';

Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(DmStrings.of(ctx).cancel),
        ),
        ConfirmButton(
          label: confirmLabel,
          destructive: destructive,
          onConfirmed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return result == true;
}

class ConfirmButton extends StatefulWidget {
  const ConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.destructive = true,
  });

  final String label;
  final VoidCallback onConfirmed;
  final bool destructive;

  @override
  State<ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<ConfirmButton> {
  bool _armed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.destructive ? scheme.error : scheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextButton(
          key: ValueKey('confirmButton-${widget.label}'),
          onPressed: () {
            if (_armed) {
              widget.onConfirmed();
            } else {
              setState(() => _armed = true);
            }
          },
          child: Text(
            _armed ? DmStrings.of(context).tapAgainToConfirm : widget.label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (_armed)
          SizedBox(
            width: 140,
            child: LinearProgressIndicator(
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
      ],
    );
  }
}
