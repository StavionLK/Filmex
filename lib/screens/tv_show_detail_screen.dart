import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/movie_model.dart';
import 'episode_player_screen.dart'; // Import the new screen

class TvShowDetailScreen extends StatefulWidget {
  final MovieModel show;

  const TvShowDetailScreen({required this.show, Key? key}) : super(key: key);

  @override
  State<TvShowDetailScreen> createState() => _TvShowDetailScreenState();
}

class _TvShowDetailScreenState extends State<TvShowDetailScreen> {

  // UPDATED: Navigate to separate screen
  void _playEpisode(String url, String title) {
    if (url.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EpisodePlayerScreen(videoUrl: url, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // ---------------- 1. APP BAR HEADER ----------------
          SliverAppBar(
            expandedHeight: 450,
            pinned: true,
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.show.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: Colors.grey[900]),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black,
                            Colors.black.withOpacity(0.6),
                            Colors.transparent
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.show.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                          ),
                        ).animate().slideY(begin: 0.2, end: 0, duration: 500.ms),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildTag(widget.show.year),
                            const SizedBox(width: 10),
                            const Icon(Icons.star, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              "${widget.show.rating}",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                widget.show.genres.join(" • "),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---------------- 2. SYNOPSIS & DETAILS ----------------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Synopsis",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.show.description,
                    style: const TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 25),

                  if (widget.show.cast.isNotEmpty) ...[
                    const Text(
                      "Cast",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.show.cast.length,
                        itemBuilder: (context, index) {
                          final actor = widget.show.cast[index];
                          return Container(
                            width: 70,
                            margin: const EdgeInsets.only(right: 15),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundImage: NetworkImage(actor['image'] ?? ''),
                                  backgroundColor: Colors.grey[800],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  actor['name'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],

                  const Text(
                    "Seasons",
                    style: TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // ---------------- 3. EPISODE LIST (Grouped) ----------------
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tv_shows')
                .doc(widget.show.id)
                .collection('episodes')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: Colors.red),
                  )),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("No episodes uploaded yet.", style: TextStyle(color: Colors.white54)),
                  ),
                );
              }

              // Group Episodes
              Map<int, List<DocumentSnapshot>> seasonsMap = {};
              for (var doc in snapshot.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                int seasonNum = data['season'] ?? 1;
                if (!seasonsMap.containsKey(seasonNum)) {
                  seasonsMap[seasonNum] = [];
                }
                seasonsMap[seasonNum]!.add(doc);
              }

              var sortedSeasonKeys = seasonsMap.keys.toList()..sort();

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    int seasonNum = sortedSeasonKeys[index];
                    List<DocumentSnapshot> episodes = seasonsMap[seasonNum]!;

                    // Sort Episodes
                    episodes.sort((a, b) {
                      var da = a.data() as Map<String, dynamic>;
                      var db = b.data() as Map<String, dynamic>;
                      return (da['episode'] ?? 0).compareTo(db['episode'] ?? 0);
                    });

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: Text(
                            "Season $seasonNum",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text(
                            "${episodes.length} Episodes",
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          collapsedIconColor: Colors.white,
                          iconColor: Colors.greenAccent,
                          children: episodes.map((epDoc) {
                            var epData = epDoc.data() as Map<String, dynamic>;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow, color: Colors.greenAccent),
                              ),
                              title: Text(
                                "Episode ${epData['episode']}",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                epData['title'] ?? "Unknown Title",
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                              onTap: () => _playEpisode(epData['videoUrl'] ?? '', epData['title'] ?? ''),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                  childCount: sortedSeasonKeys.length,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}