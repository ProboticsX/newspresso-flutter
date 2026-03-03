import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'news_assistant_page.dart';
import 'sources_modal.dart';

// TODO: Swap back to real IDs once AdMob account is approved
// Android real: ca-app-pub-6690667089410073/1778742522
// iOS real:     ca-app-pub-6690667089410073/4164790845
const String _androidBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
const String _iosBannerAdUnitId = 'ca-app-pub-3940256099942544/2934735716';

class NewsDetailPage extends StatefulWidget {
  final String contentTitle;
  final String? imageUrl;
  final String contentSummary;
  final List<dynamic> articlesList;
  final String publishedText;
  final int totalSources;
  final List<String> questionsList;

  const NewsDetailPage({
    super.key,
    required this.contentTitle,
    this.imageUrl,
    required this.contentSummary,
    required this.articlesList,
    required this.publishedText,
    required this.totalSources,
    this.questionsList = const [],
  });

  @override
  State<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  BannerAd? _bannerAd;
  bool _bannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoadAd();
  }

  Future<void> _checkAndLoadAd() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final result = await Supabase.instance.client
            .from('users')
            .select('is_premium')
            .eq('id', userId)
            .maybeSingle();
        if (result?['is_premium'] == true) return; // premium: no ad
      }
    } catch (_) {
      // fall through and load ad if check fails
    }
    _loadBannerAd();
  }

  void _loadBannerAd() {
    final adUnitId =
        Platform.isAndroid ? _androidBannerAdUnitId : _iosBannerAdUnitId;

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _bannerAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _bannerAdLoaded && _bannerAd != null
          ? Container(
              color: Colors.black,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          : null,
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6B4E38), Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Back button
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.5),
                        color: Colors.white.withValues(alpha: 0.0),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6.0),
                        child: Icon(
                          Icons.arrow_back_ios,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Image Card
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: const Color(0xFF0F0F0F),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          widget.imageUrl != null &&
                                  widget.imageUrl!.isNotEmpty
                              ? Image.network(
                                  widget.imageUrl!,
                                  height: 240,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        height: 240,
                                        color: Colors.grey[800],
                                        child: const Icon(
                                          Icons.broken_image,
                                          size: 50,
                                          color: Colors.white54,
                                        ),
                                      ),
                                )
                              : Container(
                                  height: 240,
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.article,
                                    size: 50,
                                    color: Colors.white54,
                                  ),
                                ),

                          Container(
                            height: 240,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withValues(alpha: 0.0),
                                  Colors.black.withValues(alpha: 0.95),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.4, 1.0],
                              ),
                            ),
                          ),

                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Text(
                              widget.contentTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Publisher & Sources Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.publishedText,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (widget.articlesList.isNotEmpty) {
                            showSourcesModal(context, widget.articlesList);
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            if (widget.articlesList.isNotEmpty)
                              ...widget.articlesList
                                  .take(3)
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                    final index = entry.key;
                                    final sourceItem =
                                        entry.value as Map<String, dynamic>? ??
                                        {};
                                    final faviconUrl =
                                        sourceItem['source_favicon_url']
                                            ?.toString();
                                    return Transform.translate(
                                      offset: Offset(index * -8.0, 0),
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[800],
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.black,
                                            width: 1.5,
                                          ),
                                          image:
                                              faviconUrl != null &&
                                                  faviconUrl.isNotEmpty
                                              ? DecorationImage(
                                                  image: NetworkImage(
                                                    faviconUrl,
                                                  ),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child:
                                            faviconUrl == null ||
                                                faviconUrl.isEmpty
                                            ? const Icon(
                                                Icons.public,
                                                size: 10,
                                                color: Colors.white54,
                                              )
                                            : null,
                                      ),
                                    );
                                  }),

                            if (widget.totalSources > 0)
                              Transform.translate(
                                offset: Offset(
                                  (widget.articlesList.length > 3
                                          ? 3
                                          : widget.articlesList.length) *
                                      -4.0,
                                  0,
                                ),
                                child: Text(
                                  ' +${widget.totalSources} Sources',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                            Transform.translate(
                              offset: Offset(
                                (widget.articlesList.length > 3
                                        ? 3
                                        : widget.articlesList.length) *
                                    -4.0,
                                0,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.only(left: 4.0),
                                child: Icon(
                                  Icons.chevron_right,
                                  color: Colors.white54,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Summary/Content
                  Text(
                    widget.contentSummary,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Follow Up Section
                  if (widget.questionsList.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Follow up',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NewsAssistantPage(
                                  newsTitle: widget.contentTitle,
                                  prefillQuestion: '',
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 15,
                                  color: Colors.white60,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Ask Assistant',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    ...widget.questionsList.map((q) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NewsAssistantPage(
                                newsTitle: widget.contentTitle,
                                prefillQuestion: q,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  q,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white38,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
