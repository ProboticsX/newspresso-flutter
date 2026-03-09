import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'news_detail_page.dart';
import 'news_assistant_page.dart';
import 'user_preferences.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  List<String> _favIds = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
  }

  Future<void> _fetchFavorites() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }
      final userData = await _supabase
          .from('users')
          .select('news_items_favorited')
          .eq('id', userId)
          .maybeSingle();
      final raw = userData?['news_items_favorited'];
      _favIds = raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
      if (_favIds.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      final items = await _supabase
          .from('newspresso_aggregated_news_in')
          .select(
            'id, content_title, url_to_image, content_summary, content_description, timestamp, articles, questions, translations',
          )
          .inFilter('id', _favIds);
      setState(() {
        _items =
            (items as List<dynamic>)
                .map((e) => e as Map<String, dynamic>)
                .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatTimeAgo(dynamic ts) {
    if (ts == null) return 'Unknown';
    try {
      DateTime? date;
      if (ts is String) date = DateTime.tryParse(ts);
      if (date == null) return 'Unknown';
      final diff = DateTime.now().toUtc().difference(date.toUtc());
      if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()}w ago';
      if (diff.inDays >= 1) return '${diff.inDays}d ago';
      if (diff.inHours >= 1) return '${diff.inHours}h ago';
      return '${diff.inMinutes}m ago';
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        title: const Text(
          'Favorites',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6B4E38), Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.35],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFC8936A),
                    ),
                  )
                  : _error != null
                  ? Center(
                    child: Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.white),
                    ),
                  )
                  : _items.isEmpty
                  ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            color: Colors.white38,
                            size: 56,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No favorites yet',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap the heart on any news item to save it here.',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.only(top: 16, bottom: 24),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final raw = _items[index];
                      final item = UserPreferences.resolveContent(
                          raw, UserPreferences.instance.language);
                      final itemId = raw['id']?.toString() ?? '';
                      final contentTitle =
                          item['content_title']?.toString() ?? 'No title';
                      final imageUrl = raw['url_to_image']?.toString();
                      final contentSummary =
                          item['content_summary']?.toString() ?? '';
                      final contentDescription =
                          item['content_description']?.toString();
                      final publishedText =
                          'Published ${_formatTimeAgo(raw['timestamp'])}';

                      List<dynamic> articlesList = [];
                      final af = raw['articles'];
                      if (af is List) articlesList = af;

                      List<String> questionsList = [];
                      final qf = item['questions'];
                      if (qf is List) {
                        questionsList =
                            qf.map((e) => e.toString()).toList();
                      }

                      final totalSources = articlesList.length;

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NewsDetailPage(
                              contentTitle: contentTitle,
                              imageUrl: imageUrl,
                              contentSummary: contentSummary,
                              contentDescription: contentDescription,
                              articlesList: articlesList,
                              publishedText: publishedText,
                              totalSources: totalSources,
                              questionsList: questionsList,
                              newsItemId: itemId.isEmpty ? null : itemId,
                            ),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F0F0F),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                                child: Stack(
                                  children: [
                                    // Image
                                    imageUrl != null && imageUrl.isNotEmpty
                                        ? Image.network(
                                          imageUrl,
                                          height: 220,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, e, st) => Container(
                                                height: 220,
                                                color: Colors.grey[800],
                                                child: const Icon(
                                                  Icons.broken_image,
                                                  size: 50,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                        )
                                        : Container(
                                          height: 220,
                                          color: Colors.grey[800],
                                          child: const Icon(
                                            Icons.article,
                                            size: 50,
                                            color: Colors.white54,
                                          ),
                                        ),
                                    // Gradient overlay
                                    Container(
                                      height: 220,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.black.withValues(alpha: 0.0),
                                            Colors.black.withValues(alpha: 0.75),
                                            const Color(0xFF0F0F0F),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          stops: const [0.5, 0.85, 1.0],
                                        ),
                                      ),
                                    ),
                                    // Title + sources at bottom
                                    Positioned(
                                      bottom: 0,
                                      left: 16,
                                      right: 16,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              contentTitle,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    ...articlesList
                                                        .take(3)
                                                        .toList()
                                                        .asMap()
                                                        .entries
                                                        .map((e) {
                                                          final idx = e.key;
                                                          final src =
                                                              e.value
                                                                  as Map<
                                                                    String,
                                                                    dynamic
                                                                  >? ??
                                                              {};
                                                          final fav =
                                                              src['source_favicon_url']
                                                                  ?.toString();
                                                          return Transform.translate(
                                                            offset: Offset(
                                                              idx * -8.0,
                                                              0,
                                                            ),
                                                            child: Container(
                                                              width: 22,
                                                              height: 22,
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    Colors
                                                                        .grey[800],
                                                                shape:
                                                                    BoxShape
                                                                        .circle,
                                                                border: Border.all(
                                                                  color:
                                                                      Colors
                                                                          .black,
                                                                  width: 1.5,
                                                                ),
                                                                image:
                                                                    fav !=
                                                                                null &&
                                                                            fav
                                                                                .isNotEmpty
                                                                        ? DecorationImage(
                                                                          image: NetworkImage(
                                                                            fav,
                                                                          ),
                                                                          fit: BoxFit
                                                                              .cover,
                                                                        )
                                                                        : null,
                                                              ),
                                                              child:
                                                                  fav ==
                                                                              null ||
                                                                          fav
                                                                              .isEmpty
                                                                      ? const Icon(
                                                                        Icons
                                                                            .public,
                                                                        size:
                                                                            12,
                                                                        color: Colors
                                                                            .white54,
                                                                      )
                                                                      : null,
                                                            ),
                                                          );
                                                        }),
                                                    if (articlesList.isNotEmpty)
                                                      Transform.translate(
                                                        offset: Offset(
                                                          (articlesList.length >
                                                                      3
                                                                  ? 3
                                                                  : articlesList
                                                                      .length) *
                                                              -4.0,
                                                          0,
                                                        ),
                                                        child: Text(
                                                          '+$totalSources',
                                                          style: const TextStyle(
                                                            color:
                                                                Colors.white70,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                Text(
                                                  publishedText,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Questions capsules
                              if (questionsList.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    top: 12,
                                  ),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  NewsAssistantPage(
                                                    newsTitle: contentTitle,
                                                    prefillQuestion: '',
                                                  ),
                                            ),
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            margin: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.05,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.chat_bubble_outline,
                                                  size: 14,
                                                  color: Colors.white54,
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Ask Assistant',
                                                  style: TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        ...questionsList.map(
                                          (q) => GestureDetector(
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    NewsAssistantPage(
                                                      newsTitle: contentTitle,
                                                      prefillQuestion: q,
                                                    ),
                                              ),
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                              margin: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.05,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                q,
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // Summary text
                              if (contentSummary.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    contentSummary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ),
    );
  }
}
