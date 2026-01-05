import 'package:flutter_riverpod/flutter_riverpod.dart';

class JobLogController extends StateNotifier<List<String>> {
  JobLogController() : super(const []);

  void addLine(String line) {
    final next = [...state, line];
    if (next.length > 1000) {
      state = next.sublist(next.length - 1000);
    } else {
      state = next;
    }
  }

  void addLines(Iterable<String> lines) {
    if (lines.isEmpty) {
      return;
    }
    final next = [...state, ...lines];
    if (next.length > 1000) {
      state = next.sublist(next.length - 1000);
    } else {
      state = next;
    }
  }

  void clear() {
    state = const [];
  }
}

final jobLogProvider = StateNotifierProvider<JobLogController, List<String>>(
  (ref) => JobLogController(),
);
