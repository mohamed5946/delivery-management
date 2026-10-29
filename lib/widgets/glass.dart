// Shared look for Delivery Management: the same glass language as
// DeliveryFlow (soft white cards, rounded corners, blue accent),
// light theme first, theme-aware throughout.

import 'package:flutter/material.dart';

class GlassTokens {
  static const double radius = 20;
  static const double radiusSmall = 14;
  static const EdgeInsets screenPadding = EdgeInsets.all(16);
  static const Color primaryBlue = Color(0xFF1E6FDB);
  static const Color nearBlack = Color(0xFF0A0A0A);
}

/// A soft card: white surface, hairline border, gentle shadow.
// Never renders the string "null" — callers omit empty fields.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(GlassTokens.radius),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(GlassTokens.radius),
      child: card,
    );
  }
}

/// A labeled value row. Empty values render nothing (never "null").
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final row = Row(
      children: [
        Icon(icon, size: 18, color: GlassTokens.primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// Money text: whole EGP, no decimals noise.
String egp(double value) => '${value.toStringAsFixed(0)} ج.م';

String signedEgp(double value, {required bool isBonus}) {
  final sign = isBonus ? '+' : '−';
  return '$sign${value.toStringAsFixed(0)} ج.م';
}
