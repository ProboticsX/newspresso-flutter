# Newspresso Analytics Events

All events are sent via Firebase Analytics through `AnalyticsService` (`lib/analytics_service.dart`).

---

## Article Events

| Event | Parameters | Where fired | Why it's useful |
|-------|-----------|-------------|-----------------|
| `article_view` | `article_id`, `source` ('shots'/'explore'/'favorites'), `title` | NewsListPage tap, ShotsPage tap-through | Content impression rate; which surface drives reading |
| `article_share` | `article_id`, `method` ('native') | NewsDetailPage share button | Viral loop measurement |
| `article_favorite_add` | `article_id` | ShotsPage ♥, NewsDetailPage ♥ | Content resonance signal |
| `article_favorite_remove` | `article_id` | ShotsPage ♥, NewsDetailPage ♥ | Content un-resonance |
| `article_read_mode_selected` | `article_id`, `mode` ('deep_dive'/'under_100') | NewsDetailPage mode toggle | Are users skimmers or deep readers? |
| `article_sources_viewed` | `article_id` | NewsDetailPage sources row tap | Deep trust engagement signal |
| `article_question_tapped` | `article_id`, `question_index` | NewsDetailPage follow-up question cards | Which follow-up questions resonate most? |

---

## Shots Events

| Event | Parameters | Where fired | Why it's useful |
|-------|-----------|-------------|-----------------|
| `shot_dismissed` | `item_id`, `session_swipe_count` | ShotsPage swipe-up | Swipe volume = session depth; high swipe count = highly engaged user |
| `shot_tapped` | `item_id` | ShotsPage card tap | Click-through rate on cards |
| `shot_undo` | `item_id` | ShotsPage undo button | Regret signal — content dismissed too fast |
| `shot_assistant_opened` | `item_id`, `has_prefill_question` (0/1) | ShotsPage capsule taps | Which shots drive assistant engagement? |

---

## Podcast Events

| Event | Parameters | Where fired | Why it's useful |
|-------|-----------|-------------|-----------------|
| `podcast_play` | `podcast_id`, `title` | PodcastsPage tap, PodcastDetailScreen play | Core feature usage |
| `podcast_pause` | `podcast_id` | PodcastsPage tap (when playing), PodcastDetailScreen pause | Session interruption patterns |
| `podcast_completed` | `podcast_id` | PodcastDetailScreen (position ≥ duration − 5s) | Content quality signal — did they listen to the end? |
| `podcast_seeked` | `podcast_id`, `direction` ('forward'/'backward'), `seconds` (10) | PodcastDetailScreen skip buttons | Navigation behavior inside episodes |
| `podcast_unlocked` | `podcast_id`, `unlocks_remaining` | PodcastsPage unlock dialog confirm | Key conversion step; how fast do users burn unlocks? |
| `podcast_limit_hit` | — | PodcastsPage when unlock limit is 0 | High-intent upgrade moment |
| `podcast_sources_viewed` | `podcast_id` | PodcastsPage + PodcastDetailScreen sources tap | Deep trust engagement |
| `podcast_followup_tapped` | `podcast_id`, `question_index` | PodcastDetailScreen follow-up question cards | Cross-feature discovery (podcast → assistant) |

---

## Assistant Events

| Event | Parameters | Where fired | Why it's useful |
|-------|-----------|-------------|-----------------|
| `assistant_question_sent` | `source` ('shots'/'detail'/'podcast'/'favorites'/'direct'), `session_question_count` | NewsAssistantPage send button | Which surface drives assistant use? Session depth |
| `assistant_limit_hit` | `source` | NewsAssistantPage when free limit reaches 0 | Free → premium conversion trigger |
| `assistant_rewarded_ad_watched` | — | NewsAssistantPage rewarded ad completion | Strong intent: user wants more and took action |

---

## Navigation Events

| Event | Parameters | Where fired | Why it's useful |
|-------|-----------|-------------|-----------------|
| `tab_switch` | `tab_name` ('shots'/'explore'/'podcasts'/'profile') | Bottom nav bar taps | Tab popularity; feature discovery |
| `favorites_page_viewed` | — | FavoritesPage initState | Save-for-later feature adoption |
| `deep_link_opened` | `item_id` | App link handler in _MainShellState | Viral loop measurement from shares |
| `notification_tapped` | `item_id` | NotificationService._dispatch | Push notification effectiveness / re-engagement |

---

## Onboarding Events

| Event | Parameters | Where fired | Why it's useful |
|-------|-----------|-------------|-----------------|
| `onboarding_step_completed` | `step_name`, `step_number` | Each `_continuePage*` in OnboardingFlow | Drop-off funnel analysis — which step loses users? |
| `onboarding_location_method` | `method` ('auto'/'manual') | OnboardingFlow `_submitOnboarding` | GPS adoption rate |
| `onboarding_complete` | — | OnboardingFlow after profile insert | Total sign-up conversion |
| `notification_permission_result` | `granted` (0/1) | NotificationService.initialize | Notification opt-in rate — critical for retention |

**Step names and numbers:**

| Step | Name | Number |
|------|------|--------|
| Phone OTP | `phone_otp` | 0 |
| Name | `name` | 1 |
| Date of birth | `date_of_birth` | 2 |
| Gender | `gender` | 3 |
| Username | `username` | 4 |
| Location | `location` | 5 |

---

## Plan / Monetization Events

| Event | Parameters | Where fired | Why it's useful |
|-------|-----------|-------------|-----------------|
| `plan_page_viewed` | `source` ('profile'/'podcast_limit'/'assistant_limit') | PlanPage initState | What drives premium consideration? |
| `plan_upgrade_tapped` | — | PlanPage premium card tap | Purchase intent signal |
| `plan_upgraded` | — | PlanPage after DB update to premium | Revenue conversion |
| `plan_downgraded` | — | PlanPage after DB update to free | Churn signal |

---

## Auth Events

| Event | Parameters | Where fired | Why it's useful |
|-------|-----------|-------------|-----------------|
| `login` *(Firebase standard)* | `method` ('google') | LoginScreen Google sign-in | Auth method tracking |
| `phone_otp_sent` | — | OnboardingFlow OTP send | SMS funnel start |
| `phone_otp_resent` | — | OnboardingFlow OTP resend | Friction signal |
| `phone_otp_verified` | `method` ('auto'/'manual') | OnboardingFlow OTP verify | Auto vs manual verification rate |
| `phone_otp_error` | `error_code` | OnboardingFlow OTP failure | Common failure codes |

---

## Miscellaneous Events

| Event | Parameters | Where fired | Why it's useful |
|-------|-----------|-------------|-----------------|
| `language_changed` | `from_language`, `to_language` | UserPreferences language change | Localisation ROI |

---

## Performance Notes

- All events use **fire-and-forget** (`Future<void>` not awaited in UI handlers) — zero UI thread impact.
- `podcast_seeked` fires only on button tap (`+10s` / `-10s`), **not** on continuous slider drag.
- `podcast_completed` fires at most **once per screen lifecycle** via `_completionLogged` flag.
- `assistant_limit_hit` fires at most **once per session** via `_limitHitLogged` flag.
- `notification_permission_result` fires once per app install (on first `NotificationService.initialize()` call).

---

## Firebase DebugView

To verify events during development:

```bash
# Android
adb shell setprop debug.firebase.analytics.app com.newspresso.app

# iOS — add -FIRAnalyticsDebugEnabled to scheme launch arguments
```

Then open **Firebase Console → Analytics → DebugView**.
