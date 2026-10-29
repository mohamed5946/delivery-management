// In-app diagnostics viewer (standing build rule). Every screen
// and the backend log categorized entries with exact failure
// reasons here. The log never contains passwords, tokens, or
// credentials — only operation names and error text.

import 'package:flutter/material.dart';

import '../../core/diagnostics.dart';
import '../../core/strings.dart';
import '../../theme/dm_theme.dart';
import '../../widgets/glass.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  @override
  Widget build(BuildContext context) {
    final s = DmStrings.of(context);
    // DmPage: see TeamScreen — pushed routes need the aurora behind
    // the page itself or they render black.
    return DmPage(
      appBar: AppBar(
        title: Text(s.diagnosticsTitle),
        actions: [
          IconButton(
            key: const ValueKey('diagnosticsClear'),
            icon: const Icon(Icons.delete_rounded),
            tooltip: s.clearLog,
            onPressed: diagnosticsLog.clear,
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: diagnosticsLog.version,
        builder: (context, _, __) {
          final entries = diagnosticsLog.entries;
          if (entries.isEmpty) {
            return Padding(
              padding: GlassTokens.screenPadding,
              child: GlassCard(
                child: Text(
                  s.logEmpty,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: GlassTokens.screenPadding,
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            e.timeLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: GlassTokens.primaryBlue
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              e.category,
                              style: const TextStyle(
                                color: GlassTokens.primaryBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SelectableText(e.message),
                    ],
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
