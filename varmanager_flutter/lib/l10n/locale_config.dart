import 'package:flutter/widgets.dart';

const String kFallbackLocaleTag = 'en';
const String kChineseLocaleTag = 'zh';
const String kEnglishLocaleTag = 'en';

const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('zh'),
];

class LocaleInitResult {
  const LocaleInitResult(this.tag, this.persistOnStart);

  final String tag;
  final bool persistOnStart;
}

Locale localeFromTag(String tag) {
  switch (normalizeLocaleTag(tag)) {
    case kChineseLocaleTag:
      return const Locale('zh');
    case kEnglishLocaleTag:
    default:
      return const Locale('en');
  }
}

String localeTagFromLocale(Locale locale) {
  final language = locale.languageCode.toLowerCase();
  if (language == 'zh') {
    return kChineseLocaleTag;
  }
  return kEnglishLocaleTag;
}

String? normalizeLocaleTag(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final lower = trimmed.toLowerCase();
  if (lower == 'zh' || lower == 'zh_cn' || lower == 'zh-hans') {
    return kChineseLocaleTag;
  }
  if (lower.startsWith('zh')) {
    return kChineseLocaleTag;
  }
  if (lower == 'en' || lower.startsWith('en')) {
    return kEnglishLocaleTag;
  }
  return null;
}

String? localeTagFromSystemLocales(List<Locale> locales) {
  for (final locale in locales) {
    final tag = normalizeLocaleTag(locale.languageCode);
    if (tag != null) {
      return tag;
    }
  }
  return null;
}

LocaleInitResult resolveInitialLocale({
  required String? configTag,
  required List<Locale> systemLocales,
}) {
  final normalizedConfig = normalizeLocaleTag(configTag);
  if (normalizedConfig != null) {
    return LocaleInitResult(normalizedConfig, false);
  }

  final systemTag = localeTagFromSystemLocales(systemLocales);
  if (systemTag != null) {
    return LocaleInitResult(systemTag, true);
  }

  return const LocaleInitResult(kFallbackLocaleTag, true);
}
