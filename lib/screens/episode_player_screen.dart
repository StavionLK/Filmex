import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Import for Android specific features
import 'package:webview_flutter_android/webview_flutter_android.dart';
// Import for iOS/WebKit specific features
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class EpisodePlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const EpisodePlayerScreen({
    required this.videoUrl,
    required this.title,
    Key? key,
  }) : super(key: key);

  @override
  State<EpisodePlayerScreen> createState() => _EpisodePlayerScreenState();
}

class _EpisodePlayerScreenState extends State<EpisodePlayerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 1. Force Landscape & Hide System UI for Full Screen Experience
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // 2. Prepare URL (Drive Link Logic)
    String finalUrl = widget.videoUrl;
    if (finalUrl.contains("drive.google.com")) {
      if (finalUrl.contains("/view")) {
        finalUrl = finalUrl.replaceAll("/view", "/preview");
      } else if (finalUrl.contains("/edit")) {
        finalUrl = finalUrl.replaceAll("/edit", "/preview");
      }
    }

    // 3. Initialize Controller with Platform Specifics
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
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (error) {
            debugPrint("WebView Error: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(finalUrl));

    // Android Specific: Allow autoplay without user gesture
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController androidController =
      controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
  }

  @override
  void dispose() {
    // Reset Orientation & System UI when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // WebView Player
          Center(
            child: WebViewWidget(controller: _controller),
          ),

          // Loading Indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            ),

          // Custom Back Button Overlay
          Positioned(
            top: 20,
            left: 20,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}