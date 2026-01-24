import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/backend/query_params.dart';
import '../../core/models/config.dart';
import '../../core/models/var_models.dart';
import 'models.dart';

class VarsQueryNotifier extends Notifier<VarsQueryParams> {
  @override
  VarsQueryParams build() {
    ref.listen<AppConfig?>(appConfigProvider, (previous, next) {
      if (next == null) return;
      final previousDefault = previous?.uiPerPageVars ?? 50;
      if (state.perPage == previousDefault &&
          state.perPage != next.uiPerPageVars) {
        state = state.copyWith(page: 1, perPage: next.uiPerPageVars);
      }
    });
    final perPage = ref.read(appConfigProvider)?.uiPerPageVars ?? 50;
    return VarsQueryParams(perPage: perPage);
  }

  void update(VarsQueryParams Function(VarsQueryParams) updater) {
    state = updater(state);
  }

  void set(VarsQueryParams value) {
    state = value;
  }

  void reset() {
    final perPage = ref.read(appConfigProvider)?.uiPerPageVars ?? 50;
    state = VarsQueryParams(perPage: perPage);
  }
}

final varsQueryProvider = NotifierProvider<VarsQueryNotifier, VarsQueryParams>(
  VarsQueryNotifier.new,
);

final varsListProvider = FutureProvider<VarsListResponse>((ref) async {
  final client = ref.watch(backendClientProvider);
  final query = ref.watch(varsQueryProvider);
  return client.listVars(query);
});

class SelectedVarsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void setSelection(Set<String> value) {
    state = value;
  }

  void clear() {
    state = <String>{};
  }
}

final selectedVarsProvider = NotifierProvider<SelectedVarsNotifier, Set<String>>(
  SelectedVarsNotifier.new,
);

class FocusedVarNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFocused(String? value) {
    state = value;
  }

  void clear() {
    state = null;
  }
}

final focusedVarProvider = NotifierProvider<FocusedVarNotifier, String?>(
  FocusedVarNotifier.new,
);

final previewItemsProvider =
    FutureProvider.autoDispose.family<List<PreviewItem>, String>(
        (ref, varName) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 3), link.close);
  ref.onDispose(timer.cancel);
  final client = ref.watch(backendClientProvider);
  try {
    final previews = await client.listVarPreviews([varName]);
    return previews.items
        .map((item) => PreviewItem(
              varName: item.varName,
              atomType: item.atomType,
              previewPic: item.previewPic,
              scenePath: item.scenePath,
              isPreset: item.isPreset,
              isLoadable: item.isLoadable,
              installed: item.installed,
            ))
        .toList();
  } catch (_) {
    return <PreviewItem>[];
  }
});
