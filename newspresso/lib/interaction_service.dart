import 'package:supabase_flutter/supabase_flutter.dart';

class InteractionService {
  InteractionService._();
  static final instance = InteractionService._();
  final _db = Supabase.instance.client;

  void logView(String articleId) => _log(articleId, 'view');
  void logFavorite(String articleId) => _log(articleId, 'favorite');
  void logShare(String articleId) => _log(articleId, 'share');
  void logReadFull(String articleId, {int durationSeconds = 0}) =>
      _log(articleId, 'read_full', durationSeconds: durationSeconds);
  void logAskAssistant(String articleId) => _log(articleId, 'ask_assistant');
  void logSourcesOpen(String articleId) => _log(articleId, 'sources_open');

  void _log(String articleId, String type, {int durationSeconds = 0}) {
    final userId = _db.auth.currentUser?.id;
    if (userId == null || articleId.isEmpty) return;
    _db.rpc('log_interaction', params: {
      'p_user_id': userId,
      'p_article_id': articleId,
      'p_interaction_type': type,
      'p_duration_seconds': durationSeconds,
    }).catchError((_) {});
  }
}
