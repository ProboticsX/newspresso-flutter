import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'analytics_service.dart';

class NewsAssistantPage extends StatefulWidget {
  final String newsTitle;
  final String prefillQuestion;
  /// Where the assistant was opened from: 'shots', 'detail', 'podcast', 'favorites', 'explore'
  final String source;

  const NewsAssistantPage({
    super.key,
    required this.newsTitle,
    required this.prefillQuestion,
    this.source = 'direct',
  });

  @override
  State<NewsAssistantPage> createState() => _NewsAssistantPageState();
}

class _NewsAssistantPageState extends State<NewsAssistantPage> {
  late final TextEditingController _controller;
  final ScrollController _scrollController = ScrollController();
  final List<String> _messages = [];

  BannerAd? _bannerAd;
  bool _bannerAdLoaded = false;
  RewardedInterstitialAd? _rewardedAd;
  bool _isPremium = false;
  int? _questionsRemaining; // null while loading
  int _sessionQuestionCount = 0;
  bool _limitHitLogged = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.prefillQuestion);
    _loadUserData();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _bannerAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final result = await Supabase.instance.client
            .from('users')
            .select('is_premium, newspresso_assistant_limit')
            .eq('id', userId)
            .maybeSingle();
        final premium = result?['is_premium'] == true;
        final limit = premium ? null : (result?['newspresso_assistant_limit'] as int? ?? 0);
        if (mounted) {
          setState(() {
            _isPremium = premium;
            _questionsRemaining = limit;
          });
        }
        if (premium) return; // premium: no ads
      }
    } catch (_) {
      // fall through and load ad if check fails
      if (mounted) setState(() => _questionsRemaining = 0);
    }
    _loadBannerAd();
    _loadRewardedAd();
  }

  void _loadBannerAd() {
    final adUnitId = Platform.isAndroid
        ? (dotenv.env['ADMOB_ANDROID_ASSISTANT_BANNER'] ?? '')
        : (dotenv.env['ADMOB_IOS_ASSISTANT_BANNER'] ?? '');
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _bannerAdLoaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  void _loadRewardedAd() {
    final adUnitId = Platform.isAndroid
        ? (dotenv.env['ADMOB_ANDROID_ASSISTANT_REWARDED'] ?? '')
        : (dotenv.env['ADMOB_IOS_ASSISTANT_REWARDED'] ?? '');
    RewardedInterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _rewardedAd = ad);
        },
        onAdFailedToLoad: (_) {},
      ),
    );
  }

  Future<void> _watchRewardedAd() async {
    if (_rewardedAd == null) return;
    bool rewardEarned = false;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        if (mounted) setState(() => _rewardedAd = null);
        _loadRewardedAd();
        if (rewardEarned) {
          const newLimit = 3;
          if (mounted) setState(() => _questionsRemaining = newLimit);
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            await Supabase.instance.client
                .from('users')
                .update({'newspresso_assistant_limit': newLimit})
                .eq('id', userId);
          }
        }
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (mounted) setState(() => _rewardedAd = null);
        _loadRewardedAd();
      },
    );
    await _rewardedAd!.show(
      onUserEarnedReward: (_, reward) {
        rewardEarned = true;
        AnalyticsService.instance.logAssistantRewardedAdWatched();
      },
    );
  }

  bool get _canSend =>
      _isPremium || (_questionsRemaining != null && _questionsRemaining! > 0);

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || !_canSend) return;
    final newLimit = (!_isPremium && _questionsRemaining != null)
        ? _questionsRemaining! - 1
        : _questionsRemaining;
    _sessionQuestionCount++;
    AnalyticsService.instance.logAssistantQuestionSent(
      source: widget.source,
      sessionQuestionCount: _sessionQuestionCount,
    );
    setState(() {
      _messages.add(text);
      _controller.clear();
      _questionsRemaining = newLimit;
    });
    if (!_isPremium && newLimit == 0 && !_limitHitLogged) {
      _limitHitLogged = true;
      AnalyticsService.instance.logAssistantLimitHit(source: widget.source);
    }
    if (!_isPremium) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('users')
            .update({'newspresso_assistant_limit': newLimit})
            .eq('id', userId);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6B4E38), Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.35],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.arrow_back_ios,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.newsTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (!_isPremium && _questionsRemaining != null) ...[
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.help_outline_rounded,
                            size: 16,
                            color: _questionsRemaining! > 0
                                ? Colors.white60
                                : Colors.red.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_questionsRemaining!}',
                            style: TextStyle(
                              color: _questionsRemaining! > 0
                                  ? Colors.white60
                                  : Colors.red.shade400,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ── Messages area ──
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                        child: Opacity(
                          opacity: 0.12,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [Colors.brown.shade300, Colors.black],
                              ),
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.78,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3D2B1F),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                _messages[index],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // ── Watch ad button (shown when free user has 0 questions left) ──
              // Uses Visibility (not `if`) so the slot stays in the Column and
              // the banner AdWidget below never shifts index — prevents the
              // "AdWidget already in widget tree" error on rebuild.
              Visibility(
                visible: !_isPremium && _questionsRemaining == 0,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  color: Colors.black.withValues(alpha: 0.4),
                  child: GestureDetector(
                    onTap: _rewardedAd != null ? _watchRewardedAd : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _rewardedAd != null
                            ? const Color(0xFFC8936A)
                            : Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            color: _rewardedAd != null
                                ? Colors.white
                                : Colors.white38,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _rewardedAd != null
                                ? 'Watch an ad for 3 more questions'
                                : 'Loading ad…',
                            style: TextStyle(
                              color: _rewardedAd != null
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Banner ad ──
              if (_bannerAdLoaded && _bannerAd != null)
                Container(
                  color: Colors.black,
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),

              // ── Input bar ──
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Ask anything…',
                            hintStyle: TextStyle(
                              color: Colors.white38,
                              fontSize: 15,
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _canSend ? _sendMessage : null,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _canSend
                              ? const Color(0xFFC8936A)
                              : Colors.grey.shade800,
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: _canSend ? Colors.white : Colors.white30,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
