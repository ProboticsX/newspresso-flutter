import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the environment variables from the .env file
  await dotenv.load(fileName: ".env");

  // Read Supabase credentials safely
  final String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint("Error: Missing Supabase credentials in .env file");
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Newspresso',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFC8936A),
          surface: Colors.black,
        ),
        scaffoldBackgroundColor: Colors
            .transparent, // Background will be handled by container gradient
        useMaterial3: true,
        fontFamily: 'Inter', // Try to use a clean modern font if available
      ),
      home: const NewsListPage(),
    );
  }
}

class NewsListPage extends StatefulWidget {
  const NewsListPage({super.key});

  @override
  State<NewsListPage> createState() => _NewsListPageState();
}

class _NewsListPageState extends State<NewsListPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> _newsList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    try {
      final response = await supabase
          .from('newspresso_aggregated_news_in')
          .select(
            'content_title, url_to_image, content_summary, timestamp, articles',
          )
          .order('timestamp', ascending: false);

      setState(() {
        _newsList = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatTimeAgo(dynamic timestampField) {
    if (timestampField == null) return 'Unknown';
    try {
      DateTime? date;

      if (timestampField is String) {
        // Try to parse as an ISO-8601 string like "2026-02-25 20:49:32.13597+00"
        date = DateTime.tryParse(timestampField);

        // If it failed, maybe it's a string representation of a unix epoch
        if (date == null) {
          final doubleVal = double.tryParse(timestampField);
          if (doubleVal != null) {
            int epochValue = doubleVal.toInt();
            if (epochValue < 10000000000) epochValue *= 1000;
            date = DateTime.fromMillisecondsSinceEpoch(epochValue);
          }
        }
      } else if (timestampField is int || timestampField is double) {
        int epochValue = (timestampField as num).toInt();
        // Check if magnitude is likely seconds rather than ms
        if (epochValue < 10000000000) {
          epochValue *= 1000;
        }
        date = DateTime.fromMillisecondsSinceEpoch(epochValue);
      }

      if (date == null) return 'Unknown';

      final difference = DateTime.now().difference(date);
      if (difference.inDays > 7) {
        return '${difference.inDays ~/ 7} weeks ago';
      } else if (difference.inDays > 1) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays == 1) {
        return '1 day ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
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
          'Newspresso',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Main List Content
              Expanded(
                child: _isLoading
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
                    : _newsList.isEmpty
                    ? const Center(
                        child: Text(
                          'No news available.',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _newsList.length,
                        itemBuilder: (context, index) {
                          final item = _newsList[index] as Map<String, dynamic>;
                          final contentTitle =
                              item['content_title']?.toString() ?? 'No title';
                          final imageUrl = item['url_to_image']?.toString();
                          final contentSummary =
                              item['content_summary']?.toString() ?? '';
                          final timestampField = item['timestamp'];

                          // Safely parse articles from Supabase format
                          List<dynamic> articlesList = [];
                          final dynamic articlesField = item['articles'];
                          if (articlesField is List) {
                            articlesList = articlesField;
                          } else if (articlesField is Map &&
                              articlesField.containsKey('items')) {
                            // Some postgrest JSON array configs parse this way
                            articlesList =
                                articlesField['items'] as List<dynamic>? ?? [];
                          } else if (articlesField != null) {
                            // Last resort, try to see if it's already an array representation
                            try {
                              articlesList = List.from(
                                articlesField as Iterable,
                              );
                            } catch (e) {
                              // Ignore formatting errors gracefully
                            }
                          }

                          final int totalSources = articlesList.length;

                          final publishedText =
                              'Published ${_formatTimeAgo(timestampField)}';

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF0F0F0F,
                              ), // Absolute dark background for card
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
                                      // Feed Image
                                      imageUrl != null && imageUrl.isNotEmpty
                                          ? Image.network(
                                              imageUrl,
                                              height: 260,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => Container(
                                                    height: 260,
                                                    color: Colors.grey[800],
                                                    child: const Icon(
                                                      Icons.broken_image,
                                                      size: 50,
                                                      color: Colors.white54,
                                                    ),
                                                  ),
                                            )
                                          : Container(
                                              height: 260,
                                              color: Colors.grey[800],
                                              child: const Icon(
                                                Icons.article,
                                                size: 50,
                                                color: Colors.white54,
                                              ),
                                            ),
                                      // Gradient to blend image with card bottom text
                                      Container(
                                        height: 260,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.black.withOpacity(0.0),
                                              Colors.black.withOpacity(0.8),
                                              const Color(0xFF0F0F0F),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            stops: const [0.5, 0.85, 1.0],
                                          ),
                                        ),
                                      ),
                                      // Title and Published Date Overlay Bottom
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
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  height: 1.2,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  // Sources avatars cluster
                                                  Row(
                                                    children: [
                                                      if (articlesList.isEmpty)
                                                        const SizedBox() // No sources to show
                                                      else
                                                        // Map up to 3 article items to overlapping circular images
                                                        ...articlesList.take(3).toList().asMap().entries.map((
                                                          entry,
                                                        ) {
                                                          final index =
                                                              entry.key;
                                                          final sourceItem =
                                                              entry.value
                                                                  as Map<
                                                                    String,
                                                                    dynamic
                                                                  >? ??
                                                              {};
                                                          final faviconUrl =
                                                              sourceItem['source_favicon_url']
                                                                  ?.toString();

                                                          return Transform.translate(
                                                            // Shift each subsequent avatar slightly to the left to overlap
                                                            offset: Offset(
                                                              index * -8.0,
                                                              0,
                                                            ),
                                                            child: Container(
                                                              width: 22,
                                                              height: 22,
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .grey[800],
                                                                shape: BoxShape
                                                                    .circle,
                                                                border: Border.all(
                                                                  color: Colors
                                                                      .black, // Dark border to define overlap
                                                                  width: 1.5,
                                                                ),
                                                                image:
                                                                    faviconUrl !=
                                                                            null &&
                                                                        faviconUrl
                                                                            .isNotEmpty
                                                                    ? DecorationImage(
                                                                        image: NetworkImage(
                                                                          faviconUrl,
                                                                        ),
                                                                        fit: BoxFit
                                                                            .cover,
                                                                      )
                                                                    : null,
                                                              ),
                                                              child:
                                                                  faviconUrl ==
                                                                          null ||
                                                                      faviconUrl
                                                                          .isEmpty
                                                                  ? const Icon(
                                                                      Icons
                                                                          .public,
                                                                      size: 12,
                                                                      color: Colors
                                                                          .white54,
                                                                    )
                                                                  : null,
                                                            ),
                                                          );
                                                        }),

                                                      // Render total additional sources text like "+24"
                                                      if (totalSources > 0)
                                                        Transform.translate(
                                                          // Adjust start layout since the overlapping avatars push bounding box slightly
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
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white70,
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),

                                                  // Publish Date Text
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
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
