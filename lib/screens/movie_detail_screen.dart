import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Import for Android specific features
import 'package:webview_flutter_android/webview_flutter_android.dart';
// Import for iOS/WebKit specific features
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/movie_model.dart';
import '../services/my_list_service.dart'; // Import the My List Service

class MovieDetailScreen extends StatefulWidget {
  final MovieModel movie;

  const MovieDetailScreen({required this.movie, Key? key}) : super(key: key);

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  late final WebViewController _webViewController;
  bool isLoading = true;

  // ---------------------------------------------------------
  // MY LIST STATE & SERVICE
  // ---------------------------------------------------------
  bool _isInMyList = false;
  final MyListService _listService = MyListService();

  // ---------------------------------------------------------
  // CORE LOGIC
  // ---------------------------------------------------------
  String convertToDrivePreview(String url) {
    if (url.contains("drive.google.com")) {
      final regex = RegExp(r'/d/([a-zA-Z0-9_-]+)');
      final match = regex.firstMatch(url);

      if (match != null) {
        final fileId = match.group(1);
        return "https://drive.google.com/file/d/$fileId/preview";
      }
    }
    return url;
  }

  // ---------------------------------------------------------
  // BUTTON ACTIONS
  // ---------------------------------------------------------

  // Updated: Handles adding/removing from Firestore
  void _handleMyList() async {
    if (_isInMyList) {
      await _listService.remove(widget.movie.id);
      if (mounted) setState(() => _isInMyList = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Removed from My List"),
          backgroundColor: Colors.grey[900],
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      await _listService.add(widget.movie);
      if (mounted) setState(() => _isInMyList = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Added to My List"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _handleRate() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Rate this Movie",
            style: TextStyle(color: Colors.white)),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return IconButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("You rated it ${index + 1} stars!")),
                );
              },
              icon: const Icon(Icons.star_border, color: Colors.amber, size: 30),
            );
          }),
        ),
      ),
    );
  }

  void _handleShare() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Sharing ${widget.movie.title}..."),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  // Check if movie is already in list
  void _checkMyListStatus() async {
    bool exists = await _listService.isAdded(widget.movie.id);
    if (mounted) {
      setState(() {
        _isInMyList = exists;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    // Check My List Status on Init
    _checkMyListStatus();

    String videoUrl = convertToDrivePreview(widget.movie.videoUrl);

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
    WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                isLoading = false;
              });
            }
          },
          onWebResourceError: (error) {
            debugPrint("WebView Error: ${error.description}");
          },
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController androidController =
      controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    final WebViewCookieManager cookieManager = WebViewCookieManager();
    if (cookieManager.platform is AndroidWebViewCookieManager) {
      (cookieManager.platform as AndroidWebViewCookieManager)
          .setAcceptThirdPartyCookies(
          controller.platform as AndroidWebViewController, true);
    }

    _webViewController = controller;

    _webViewController.loadHtmlString(
      '''
      <!DOCTYPE html>
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { margin: 0; padding: 0; background-color: black; height: 100vh; display: flex; justify-content: center; align-items: center; }
            iframe { width: 100%; height: 100%; border: none; }
          </style>
        </head>
        <body>
          <iframe 
            src="$videoUrl" 
            allow="autoplay; encrypted-media"
          >
          </iframe>
        </body>
      </html>
      ''',
      baseUrl: "https://drive.google.com",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // MODIFIED APP BAR
      appBar: AppBar(
        title: Text(
          widget.movie.title.toUpperCase(),
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        // Make background transparent to show content behind
        backgroundColor: Colors.transparent,
        // Ensure the back button and title are white
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
        // Add a gradient to ensure visibility
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent],
              stops: [0.0, 1.0],
            ),
          ),
        ),
      ),
      // Extend body behind AppBar
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------- VIDEO PLAYER STACK ----------------
            SizedBox(
              // Increased height slightly to account for transparent app bar
              height: 260,
              child: Stack(
                children: [
                  Container(
                    color: Colors.black,
                    child: WebViewWidget(controller: _webViewController),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 60,
                      height: 60,
                      color: Colors.transparent,
                    ),
                  ),
                  if (isLoading)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
            ),

            // ---------------- MAIN CONTENT AREA ----------------
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HEADER (Title & Rating)
                  Text(
                    widget.movie.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .slideX(begin: -0.2, end: 0),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        "${widget.movie.rating} Rating",
                        style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      const SizedBox(width: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("HD",
                            style:
                            TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 2. RESUME BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _webViewController.reload(),
                      icon: const Icon(Icons.play_arrow, color: Colors.black),
                      label: const Text(
                        "Resume",
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 24),

                  // 3. SYNOPSIS
                  const Text(
                    "Synopsis",
                    style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 8),

                  Text(
                    widget.movie.description,
                    textAlign: TextAlign.justify,
                    style: const TextStyle(
                        fontSize: 16, color: Colors.white70, height: 1.5),
                  ).animate().fadeIn(delay: 350.ms),

                  const SizedBox(height: 30),

                  // 4. DETAILS SECTION
                  const Text(
                    "Details",
                    style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 16),

                  _buildDetailRow("Year:", widget.movie.year),
                  _buildDetailRow("Runtime:", widget.movie.runtime),
                  _buildDetailRow("Genres:", widget.movie.genres.join(", ")),
                  _buildDetailRow("Language:", widget.movie.language),
                  _buildDetailRow("Studio:", widget.movie.studio),
                  _buildDetailRow("IMDb:", widget.movie.imdb, isLink: true),

                  const SizedBox(height: 30),

                  // 5. CAST SECTION
                  if (widget.movie.cast.isNotEmpty) ...[
                    const Text(
                      "Cast",
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ).animate().fadeIn(delay: 500.ms),
                    const SizedBox(height: 16),

                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.movie.cast.length,
                        itemBuilder: (context, index) {
                          final actor = widget.movie.cast[index];
                          final String? imageUrl = actor['image'];
                          final String name = actor['name'] ?? "Unknown";

                          return Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: Column(
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.greenAccent,
                                  ),
                                  child: ClipOval(
                                    child: Container(
                                      color: Colors.grey[800],
                                      child: (imageUrl != null &&
                                          imageUrl.isNotEmpty)
                                          ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        width: 70,
                                        height: 70,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return const Icon(Icons.person,
                                              color: Colors.white54,
                                              size: 30);
                                        },
                                      )
                                          : const Icon(Icons.person,
                                          color: Colors.white54,
                                          size: 30),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 75,
                                  child: Text(
                                    name,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ).animate().fadeIn(delay: 600.ms).slideX(),
                  ],

                  const SizedBox(height: 30),

                  // 6. ACTION RIBBON (UPDATED FOR MY LIST)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Updated Button: Changes Icon and Color based on state
                      _buildActionIcon(
                        _isInMyList ? Icons.check : Icons.add,
                        "My List",
                        _handleMyList,
                        color: _isInMyList ? Colors.greenAccent : Colors.white,
                      ),
                      _buildActionIcon(
                          Icons.thumb_up_alt_outlined, "Rate", _handleRate),
                      _buildActionIcon(Icons.share, "Share", _handleShare),
                    ],
                  ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.5, end: 0),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widget for Details Row
  Widget _buildDetailRow(String label, String value, {bool isLink = false}) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isLink ? Colors.greenAccent : Colors.white,
                fontSize: 15,
                fontWeight: isLink ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (isLink)
            const Padding(
              padding: EdgeInsets.only(left: 4.0),
              child: Icon(Icons.open_in_new, color: Colors.greenAccent, size: 14),
            )
        ],
      ),
    );
  }

  // Helper Widget for Action Buttons
  // Updated to accept optional Color
  Widget _buildActionIcon(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}