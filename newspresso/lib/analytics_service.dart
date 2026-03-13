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

  // ── Article events ────────────────────────────────────────────────────────

  Future<void> logArticleView({required String articleId, String? title, String? category, String source = 'explore'}) {
    final params = <String, Object>{'article_id': articleId, 'source': source};
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

  Future<void> logArticleReadModeSelected({required String articleId, required String mode}) =>
      _analytics?.logEvent(
        name: 'article_read_mode_selected',
        parameters: {'article_id': articleId, 'mode': mode},
      ) ?? Future.value();

  Future<void> logArticleSourcesViewed({required String articleId}) =>
      _analytics?.logEvent(
        name: 'article_sources_viewed',
        parameters: {'article_id': articleId},
      ) ?? Future.value();

  Future<void> logArticleQuestionTapped({required String articleId, required int questionIndex}) =>
      _analytics?.logEvent(
        name: 'article_question_tapped',
        parameters: {'article_id': articleId, 'question_index': questionIndex},
      ) ?? Future.value();

  // ── Shots events ──────────────────────────────────────────────────────────

  Future<void> logShotDismissed({required String itemId, required int sessionSwipeCount}) =>
      _analytics?.logEvent(
        name: 'shot_dismissed',
        parameters: {'item_id': itemId, 'session_swipe_count': sessionSwipeCount},
      ) ?? Future.value();

  Future<void> logShotTapped({required String itemId}) =>
      _analytics?.logEvent(
        name: 'shot_tapped',
        parameters: {'item_id': itemId},
      ) ?? Future.value();

  Future<void> logShotUndo({required String itemId}) =>
      _analytics?.logEvent(
        name: 'shot_undo',
        parameters: {'item_id': itemId},
      ) ?? Future.value();

  Future<void> logShotAssistantOpened({required String itemId, required bool hasPrefillQuestion}) =>
      _analytics?.logEvent(
        name: 'shot_assistant_opened',
        parameters: {'item_id': itemId, 'has_prefill_question': hasPrefillQuestion ? 1 : 0},
      ) ?? Future.value();

  // ── Podcast events ────────────────────────────────────────────────────────

  Future<void> logPodcastPlay({required String podcastId, String? title}) {
    final params = <String, Object>{'podcast_id': podcastId};
    if (title != null) params['title'] = title;
    return _analytics?.logEvent(name: 'podcast_play', parameters: params) ?? Future.value();
  }

  Future<void> logPodcastPause({required String podcastId}) =>
      _analytics?.logEvent(name: 'podcast_pause', parameters: {'podcast_id': podcastId}) ?? Future.value();

  Future<void> logPodcastCompleted({required String podcastId}) =>
      _analytics?.logEvent(
        name: 'podcast_completed',
        parameters: {'podcast_id': podcastId},
      ) ?? Future.value();

  Future<void> logPodcastSeeked({required String podcastId, required String direction, required int seconds}) =>
      _analytics?.logEvent(
        name: 'podcast_seeked',
        parameters: {'podcast_id': podcastId, 'direction': direction, 'seconds': seconds},
      ) ?? Future.value();

  Future<void> logPodcastUnlocked({required String podcastId, required int unlocksRemaining}) =>
      _analytics?.logEvent(
        name: 'podcast_unlocked',
        parameters: {'podcast_id': podcastId, 'unlocks_remaining': unlocksRemaining},
      ) ?? Future.value();

  Future<void> logPodcastLimitHit() =>
      _analytics?.logEvent(name: 'podcast_limit_hit') ?? Future.value();

  Future<void> logPodcastSourcesViewed({required String podcastId}) =>
      _analytics?.logEvent(
        name: 'podcast_sources_viewed',
        parameters: {'podcast_id': podcastId},
      ) ?? Future.value();

  Future<void> logPodcastFollowupTapped({required String podcastId, required int questionIndex}) =>
      _analytics?.logEvent(
        name: 'podcast_followup_tapped',
        parameters: {'podcast_id': podcastId, 'question_index': questionIndex},
      ) ?? Future.value();

  // ── Assistant events ──────────────────────────────────────────────────────

  Future<void> logAssistantQuestionSent({required String source, required int sessionQuestionCount}) =>
      _analytics?.logEvent(
        name: 'assistant_question_sent',
        parameters: {'source': source, 'session_question_count': sessionQuestionCount},
      ) ?? Future.value();

  Future<void> logAssistantLimitHit({required String source}) =>
      _analytics?.logEvent(
        name: 'assistant_limit_hit',
        parameters: {'source': source},
      ) ?? Future.value();

  Future<void> logAssistantRewardedAdWatched() =>
      _analytics?.logEvent(name: 'assistant_rewarded_ad_watched') ?? Future.value();

  // ── Navigation events ─────────────────────────────────────────────────────

  Future<void> logTabSwitch({required String tabName}) =>
      _analytics?.logEvent(name: 'tab_switch', parameters: {'tab_name': tabName}) ?? Future.value();

  Future<void> logScreenView({required String screenName}) =>
      _analytics?.logScreenView(screenName: screenName) ?? Future.value();

  Future<void> logFavoritesPageViewed() =>
      _analytics?.logEvent(name: 'favorites_page_viewed') ?? Future.value();

  Future<void> logDeepLinkOpened({required String itemId}) =>
      _analytics?.logEvent(
        name: 'deep_link_opened',
        parameters: {'item_id': itemId},
      ) ?? Future.value();

  Future<void> logNotificationTapped({required String itemId}) =>
      _analytics?.logEvent(
        name: 'notification_tapped',
        parameters: {'item_id': itemId},
      ) ?? Future.value();

  // ── Plan / monetization events ────────────────────────────────────────────

  Future<void> logPlanPageViewed({required String source}) =>
      _analytics?.logEvent(
        name: 'plan_page_viewed',
        parameters: {'source': source},
      ) ?? Future.value();

  Future<void> logPlanUpgradeTapped() =>
      _analytics?.logEvent(name: 'plan_upgrade_tapped') ?? Future.value();

  Future<void> logPlanUpgraded() =>
      _analytics?.logEvent(name: 'plan_upgraded') ?? Future.value();

  Future<void> logPlanDowngraded() =>
      _analytics?.logEvent(name: 'plan_downgraded') ?? Future.value();

  // ── Auth events ───────────────────────────────────────────────────────────

  Future<void> logLogin({String method = 'google'}) =>
      _analytics?.logLogin(loginMethod: method) ?? Future.value();

  Future<void> logOnboardingComplete() =>
      _analytics?.logEvent(name: 'onboarding_complete') ?? Future.value();

  Future<void> logOnboardingStepCompleted({required String stepName, required int stepNumber}) =>
      _analytics?.logEvent(
        name: 'onboarding_step_completed',
        parameters: {'step_name': stepName, 'step_number': stepNumber},
      ) ?? Future.value();

  Future<void> logOnboardingLocationMethod({required String method}) =>
      _analytics?.logEvent(
        name: 'onboarding_location_method',
        parameters: {'method': method},
      ) ?? Future.value();

  Future<void> logNotificationPermissionResult({required bool granted}) =>
      _analytics?.logEvent(
        name: 'notification_permission_result',
        parameters: {'granted': granted ? 1 : 0},
      ) ?? Future.value();

  // ── Search ────────────────────────────────────────────────────────────────

  Future<void> logSearch({required String query}) =>
      _analytics?.logSearch(searchTerm: query) ?? Future.value();

  // ── Language ──────────────────────────────────────────────────────────────

  Future<void> logLanguageChanged({required String fromLanguage, required String toLanguage}) =>
      _analytics?.logEvent(
        name: 'language_changed',
        parameters: {'from_language': fromLanguage, 'to_language': toLanguage},
      ) ?? Future.value();

  // ── RecSys events ─────────────────────────────────────────────────────────

  Future<void> logCategoryPreferencesSaved({
    required List<String> categories,
  }) =>
      _analytics?.logEvent(
        name: 'category_preferences_saved',
        parameters: {
          'categories': categories.join(','),
          'count': categories.length,
        },
      ) ?? Future.value();

  Future<void> logCategoryPreferencesUpdated({
    required List<String> categories,
  }) =>
      _analytics?.logEvent(
        name: 'category_preferences_updated',
        parameters: {
          'categories': categories.join(','),
          'count': categories.length,
        },
      ) ?? Future.value();

  // ── Phone OTP events ──────────────────────────────────────────────────────

  Future<void> logPhoneOtpScreenView() =>
      _analytics?.logScreenView(screenName: 'phone_otp') ?? Future.value();

  Future<void> logPhoneOtpSent() =>
      _analytics?.logEvent(name: 'phone_otp_sent') ?? Future.value();

  Future<void> logPhoneOtpResent() =>
      _analytics?.logEvent(name: 'phone_otp_resent') ?? Future.value();

  Future<void> logPhoneOtpVerified({String method = 'manual'}) =>
      _analytics?.logEvent(
        name: 'phone_otp_verified',
        parameters: {'method': method},
      ) ?? Future.value();

  Future<void> logPhoneOtpError({required String code}) =>
      _analytics?.logEvent(
        name: 'phone_otp_error',
        parameters: {'error_code': code},
      ) ?? Future.value();
}
