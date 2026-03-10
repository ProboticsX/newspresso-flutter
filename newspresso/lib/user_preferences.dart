import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserPreferences {
  static final UserPreferences instance = UserPreferences._();
  UserPreferences._();

  final ValueNotifier<String> languageNotifier = ValueNotifier('en');
  String get language => languageNotifier.value;

  Future<void> load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final result = await Supabase.instance.client
          .from('users')
          .select('language_selected')
          .eq('id', userId)
          .maybeSingle();
      languageNotifier.value =
          result?['language_selected']?.toString() ?? 'en';
    } catch (_) {}
  }

  Future<void> setLanguage(String lang) async {
    languageNotifier.value = lang;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('users')
          .update({'language_selected': lang})
          .eq('id', userId);
    } catch (_) {}
  }

  /// Resolves translated content fields from a news item map.
  /// Falls back to the original English fields if the translation is absent.
  static Map<String, dynamic> resolveContent(
      Map<String, dynamic> item, String lang) {
    if (lang == 'en') return item;
    final trans = item['translations'];
    if (trans is! Map) return item;
    final langData = trans[lang];
    if (langData is! Map) return item;
    return {
      ...item,
      'content_title': langData['content_title'] ?? item['content_title'],
      'content_summary': langData['content_summary'] ?? item['content_summary'],
      'content_description':
          langData['content_description'] ?? item['content_description'],
      'questions': langData['questions'] ?? item['questions'],
    };
  }

  /// Resolves translated fields from a podcast item map.
  /// Falls back to English fields if the translation is absent.
  static Map<String, dynamic> resolvePodcast(
      Map<String, dynamic> item, String lang) {
    if (lang == 'en') return item;
    final trans = item['translations'];
    if (trans is! Map) return item;
    final langData = trans[lang];
    if (langData is! Map) return item;
    return {
      ...item,
      'podcast_title': langData['podcast_title'] ?? item['podcast_title'],
      'podcast_summary': langData['podcast_summary'] ?? item['podcast_summary'],
      'public_url': langData['public_url'] ?? item['public_url'],
      'podcast_questions':
          langData['podcast_questions'] ?? item['podcast_questions'],
    };
  }
}
