// In-app diagnostics log (standing build rule: every app ships
// with one from day one).
//
// Screens and the backend record categorized entries with the exact
// failure reason — never a swallowed error. The log lives only in
// memory (nothing sensitive is ever written to it: no passwords,
// tokens, or credentials — only operation names and error text).

import 'package:flutter/foundation.dart';

/// One diagnostics entry.
class DiagnosticEntry {
  const DiagnosticEntry({
    required this.time,
    required this.category,
    required this.message,
  });

  final DateTime time;
  final String category;
  final String message;

  String get timeLabel {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// The app-wide log. A [ValueNotifier] version bumps on every write
/// so the viewer screen rebuilds without a state-management package.
class DiagnosticsLog {
  final List<DiagnosticEntry> _entries = [];
  final ValueNotifier<int> version = ValueNotifier<int>(0);

  List<DiagnosticEntry> get entries => List.unmodifiable(_entries);

  void add(String category, String message) {
    _entries.insert(
      0,
      DiagnosticEntry(
        time: DateTime.now(),
        category: category,
        message: message,
      ),
    );
    if (_entries.length > 300) _entries.removeRange(300, _entries.length);
    version.value++;
  }

  void clear() {
    _entries.clear();
    version.value++;
  }
}

/// The single app-wide log instance.
final diagnosticsLog = DiagnosticsLog();
