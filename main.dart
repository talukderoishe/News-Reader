import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

// ================= Mouse drag scroll (preview fix) =================
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

// ================= MODEL =================
class Article {
  final int id;
  final String title;
  final String summary;
  final String imageUrl;
  final String newsSite;
  final String publishedAt;

  Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.newsSite,
    required this.publishedAt,
  });

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        id: json['id'] ?? 0,
        title: json['title'] ?? '',
        summary: json['summary'] ?? '',
        imageUrl: json['image_url'] ?? '',
        newsSite: json['news_site'] ?? 'News',
        publishedAt: json['published_at'] ?? '',
      );

  String get dateText {
    final d = DateTime.tryParse(publishedAt)?.toLocal();
    if (d == null) return '';
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }
}

// ================= PROVIDER (business logic) =================
class NewsProvider extends ChangeNotifier {
  List<Article> _articles = [];
  final Set<int> _favorites = {};
  bool _isLoading = false;
  String? _error;
  String _query = '';

  bool get isLoading => _isLoading;
  String? get error => _error;
  int get favoriteCount => _favorites.length;
  bool isFavorite(int id) => _favorites.contains(id);

  List<Article> get articles {
    if (_query.isEmpty) return _articles;
    return _articles
        .where((a) => a.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  Future<void> fetchArticles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await http
          .get(Uri.parse(
              'https://api.spaceflightnewsapi.net/v4/articles/?limit=30'))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final List results = data['results'];
        _articles = results.map((e) => Article.fromJson(e)).toList();
      } else {
        _error = 'Server error: ${res.statusCode}';
      }
    } catch (e) {
      _error = 'Could not load news. Please check your internet connection.';
    }
    _isLoading = false;
    notifyListeners();
  }

  void search(String q) {
    _query = q;
    notifyListeners();
  }

  void toggleFavorite(int id) {
    _favorites.contains(id) ? _favorites.remove(id) : _favorites.add(id);
    notifyListeners();
  }
}

// ================= APP =================
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => NewsProvider()..fetchArticles(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'News Reader',
        scrollBehavior: AppScrollBehavior(),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)),
          scaffoldBackgroundColor: const Color(0xFFF4F6FA),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            centerTitle: false,
            titleTextStyle: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
        home: const NewsListScreen(),
      ),
    ),
  );
}

// ================= Reusable widgets =================
class NewsImage extends StatelessWidget {
  final String url;
  const NewsImage({super.key, required this.url});

  Widget _placeholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
            child: Icon(Icons.rocket_launch, color: Colors.white70, size: 48)),
      );

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (c, child, p) => p == null ? child : _placeholder(),
      errorBuilder: (c, e, s) => _placeholder(),
    );
  }
}

class FavButton extends StatelessWidget {
  final int id;
  const FavButton({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final fav = context.watch<NewsProvider>().isFavorite(id);
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.read<NewsProvider>().toggleFavorite(id),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            fav ? Icons.favorite : Icons.favorite_border,
            color: Colors.redAccent,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ================= LIST SCREEN =================
class NewsListScreen extends StatelessWidget {
  const NewsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NewsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.newspaper, size: 26),
            SizedBox(width: 8),
            Text('News Reader'),
          ],
        ),
        actions: [
          // favorites count in AppBar
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                const SizedBox(width: 6),
                Text('${p.favoriteCount}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: _buildBody(context, p),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NewsProvider p) {
    // 1) Loading state
    if (p.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading latest news...'),
          ],
        ),
      );
    }

    // 2) Error state with Retry button
    if (p.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.red),
              const SizedBox(height: 12),
              const Text('Oops! Something went wrong',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(p.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.read<NewsProvider>().fetchArticles(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // 3) Success state
    final list = p.articles;
    return Column(
      children: [
        // search box
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: TextField(
            onChanged: (v) => context.read<NewsProvider>().search(v),
            decoration: InputDecoration(
              hintText: 'Search news by title...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No articles found'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                  itemCount: list.length,
                  itemBuilder: (context, i) => NewsCard(article: list[i]),
                ),
        ),
      ],
    );
  }
}

// ================= NEWS CARD =================
class NewsCard extends StatelessWidget {
  final Article article;
  const NewsCard({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ArticleDetailScreen(article: article)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Positioned.fill(child: NewsImage(url: article.imageUrl)),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(article.newsSite,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  Positioned(
                      top: 6, right: 6, child: FavButton(id: article.id)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.3)),
                  const SizedBox(height: 8),
                  Text(article.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[700], height: 1.4)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 15, color: c.primary),
                      const SizedBox(width: 4),
                      Text(article.dateText,
                          style: TextStyle(fontSize: 12, color: c.primary)),
                      const Spacer(),
                      Text('Read more',
                          style: TextStyle(
                              fontSize: 13,
                              color: c.primary,
                              fontWeight: FontWeight.w600)),
                      Icon(Icons.arrow_forward_rounded,
                          size: 16, color: c.primary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= DETAIL SCREEN =================
class ArticleDetailScreen extends StatelessWidget {
  final Article article;
  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NewsProvider>();
    final fav = p.isFavorite(article.id);
    final c = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            flexibleSpace: FlexibleSpaceBar(
              background: NewsImage(url: article.imageUrl),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: Icon(
                      fav ? Icons.favorite : Icons.favorite_border,
                      color: Colors.redAccent,
                    ),
                    onPressed: () =>
                        context.read<NewsProvider>().toggleFavorite(article.id),
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: c.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(article.newsSite,
                                style: TextStyle(
                                    color: c.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.schedule,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(article.dateText,
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(article.title,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.3)),
                      const Divider(height: 32),
                      Text(article.summary,
                          style: const TextStyle(fontSize: 17, height: 1.7)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
