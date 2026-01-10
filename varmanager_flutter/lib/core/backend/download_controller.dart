import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../models/download_models.dart';

final downloadListProvider =
    StreamProvider.autoDispose<DownloadListResponse>((ref) async* {
  final client = ref.read(backendClientProvider);
  DownloadListResponse last;

  Future<DownloadListResponse> fetch() async {
    return client.getDownloads();
  }

  try {
    last = await fetch();
  } catch (_) {
    last = DownloadListResponse.empty();
  }
  yield last;

  await for (final _ in Stream.periodic(const Duration(milliseconds: 900))) {
    try {
      last = await fetch();
    } catch (_) {
      // keep last value on error
    }
    yield last;
  }
});
