import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;

  void initialize() {
    try {
      _analytics = FirebaseAnalytics.instance;
    } catch (_) {}
  }

  // Article events
  Future<void> logArticleView({required String articleId, String? title, String? category}) {
    final params = <String, Object>{'article_id': articleId};
    if (title != null) params['title'] = title;
    if (category != null) params['category'] = category;
    return _analytics?.logEvent(name: 'article_view', parameters: params) ?? Future.value();
  }

  Future<void> logArticleShare({required String articleId, String? method}) {
    final params = <String, Object>{'article_id': articleId};
    if (method != null) params['method'] = method;
    return _analytics?.logEvent(name: 'article_share', parameters: params) ?? Future.value();
  }

  Future<void> logArticleFavorite({required String articleId, required bool added}) =>
      _analytics?.logEvent(
        name: added ? 'article_favorite_add' : 'article_favorite_remove',
        parameters: {'article_id': articleId},
      ) ?? Future.value();

  // Podcast events
  Future<void> logPodcastPlay({required String podcastId, String? title}) {
    final params = <String, Object>{'podcast_id': podcastId};
    if (title != null) params['title'] = title;
    return _analytics?.logEvent(name: 'podcast_play', parameters: params) ?? Future.value();
  }

  Future<void> logPodcastPause({required String podcastId}) =>
      _analytics?.logEvent(name: 'podcast_pause', parameters: {'podcast_id': podcastId}) ?? Future.value();

  // Navigation events
  Future<void> logTabSwitch({required String tabName}) =>
      _analytics?.logEvent(name: 'tab_switch', parameters: {'tab_name': tabName}) ?? Future.value();

  Future<void> logScreenView({required String screenName}) =>
      _analytics?.logScreenView(screenName: screenName) ?? Future.value();

  // Auth events
  Future<void> logLogin({String method = 'google'}) =>
      _analytics?.logLogin(loginMethod: method) ?? Future.value();

  Future<void> logOnboardingComplete() =>
      _analytics?.logEvent(name: 'onboarding_complete') ?? Future.value();

  // Search
  Future<void> logSearch({required String query}) =>
      _analytics?.logSearch(searchTerm: query) ?? Future.value();
}
