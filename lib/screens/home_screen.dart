import 'dart:async'; // Required for StreamController
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import Screens & Services
import 'movie_detail_screen.dart';
import 'tv_show_detail_screen.dart';
import '../models/movie_model.dart';
import '../widgets/movie_card.dart';
import '../services/my_list_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // 1. STATE VARIABLES
  int _bottomNavIndex = 0;
  String _selectedTopCategory = "All";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // Pagination State for "All" category
  int _currentPage = 1;
  final int _itemsPerPage = 2; // Limit to 2 items per page

  // ---------------------------------------------------------
  // 2. DATA FETCHING (Sorts and Interleaves by Date)
  // ---------------------------------------------------------
  Stream<List<MovieModel>> _getCombinedStream() {
    final controller = StreamController<List<MovieModel>>();
    List<MovieModel> movies = [];
    List<MovieModel> tvShows = [];

    // Helper to interleave sorted lists
    List<MovieModel> combineAndInterleave(List<MovieModel> listA, List<MovieModel> listB) {
      List<MovieModel> combined = [];
      int indexA = 0;
      int indexB = 0;

      while (indexA < listA.length || indexB < listB.length) {
        if (indexA < listA.length) {
          combined.add(listA[indexA]);
          indexA++;
        }
        if (indexB < listB.length) {
          combined.add(listB[indexB]);
          indexB++;
        }
      }
      return combined;
    }

    // Listen to Movies
    FirebaseFirestore.instance
        .collection('movies')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      movies = snapshot.docs.map((doc) {
        var data = doc.data();
        data['category'] = 'Movie';
        return MovieModel.fromMap(doc.id, data);
      }).toList();

      controller.add(combineAndInterleave(movies, tvShows));
    });

    // Listen to TV Shows
    FirebaseFirestore.instance
        .collection('tv_shows')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      tvShows = snapshot.docs.map((doc) {
        var data = doc.data();
        data['category'] = 'TV Show';
        return MovieModel.fromMap(doc.id, data);
      }).toList();

      controller.add(combineAndInterleave(movies, tvShows));
    });

    return controller.stream;
  }

  // ---------------------------------------------------------
  // 3. NAVIGATION LOGIC
  // ---------------------------------------------------------
  void _navigateToDetail(BuildContext context, MovieModel content) {
    if (content.category == 'TV Show') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TvShowDetailScreen(show: content)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: content)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: StreamBuilder<List<MovieModel>>(
        stream: _getCombinedStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.red));
          }

          List<MovieModel> allContent = snapshot.data ?? [];

          // SWITCH VIEW BASED ON BOTTOM NAV INDEX
          switch (_bottomNavIndex) {
            case 0:
              return _buildHomeTab(allContent);
            case 1:
              return _buildTVShowsTab(allContent);
            case 2:
              return _buildMyListTab(); // Clean function call
            case 3:
              return _buildSearchTab(allContent);
            default:
              return _buildHomeTab(allContent);
          }
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: _bottomNavIndex,
        onTap: (index) {
          setState(() {
            _bottomNavIndex = index;
            if (index != 3) {
              _searchQuery = "";
              _searchController.clear();
            }
            if (index == 0) {
              // If tapping Home again, reset filters
              if (_selectedTopCategory != 'All') {
                _selectedTopCategory = 'All';
              }
              _currentPage = 1;
            }
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.tv), label: "TV Shows"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "My List"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
        ],
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (_bottomNavIndex == 3) return null;
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
      title: Text(
        _bottomNavIndex == 0
            ? "FILMEX"
            : _bottomNavIndex == 1
            ? "TV SHOWS"
            : "MY LIST",
        style: const TextStyle(
            color: Colors.red, fontWeight: FontWeight.bold, fontSize: 26),
      ),
      actions: [
        if (_bottomNavIndex == 0)
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.person, color: Colors.black, size: 18),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // TAB 0: HOME
  // ------------------------------------------------------------------------
  Widget _buildHomeTab(List<MovieModel> allContent) {
    // 1. SPECIAL CASE: If "My List" is selected in the Header Tabs
    if (_selectedTopCategory == "My List") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Tabs
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTopTab("All"),
                _buildTopTab("TV Shows"),
                _buildTopTab("Movies"),
                _buildTopTab("My List"),
              ],
            ),
          ),
          // Expanded My List Grid
          Expanded(child: _buildMyListTab()),
        ],
      );
    }

    // 2. STANDARD FILTERING LOGIC
    List<MovieModel> displayList = [];
    if (_selectedTopCategory == "All") {
      displayList = allContent;
    } else if (_selectedTopCategory == "Movies") {
      displayList = allContent.where((i) => i.category == 'Movie').toList();
    } else if (_selectedTopCategory == "TV Shows") {
      displayList = allContent.where((i) => i.category == 'TV Show').toList();
    }

    // 3. PAGINATION LOGIC
    List<MovieModel> paginatedList = [];
    int totalPages = 0;
    if (_selectedTopCategory == 'All' && displayList.isNotEmpty) {
      totalPages = (displayList.length / _itemsPerPage).ceil();
      if (_currentPage > totalPages) _currentPage = totalPages;
      if (_currentPage < 1) _currentPage = 1;

      int startIndex = (_currentPage - 1) * _itemsPerPage;
      paginatedList = displayList.skip(startIndex).take(_itemsPerPage).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTopTab("All"),
              _buildTopTab("TV Shows"),
              _buildTopTab("Movies"),
              _buildTopTab("My List"),
            ],
          ),
        ),
        Expanded(
          child: displayList.isEmpty
              ? Center(
              child: Text("No $_selectedTopCategory found",
                  style: const TextStyle(color: Colors.grey)))
              : _selectedTopCategory == 'All'
              ? SingleChildScrollView(
            child: Column(
              children: [
                FeaturedMovieCarousel(
                    movies: displayList.take(5).toList()),
                const SizedBox(height: 30),
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow,
                            color: Colors.black, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text("Latest",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                buildSection(
                    allMovies: paginatedList, context: context),
                const SizedBox(height: 20),
                if (totalPages > 1)
                  PaginationControls(
                    currentPage: _currentPage,
                    totalPages: totalPages,
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                  ),
                const SizedBox(height: 40),
              ],
            ),
          )
          // Grid View for filtered content (Movies/TV Shows)
              : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.62,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: displayList.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () =>
                    _navigateToDetail(context, displayList[index]),
                child: MovieCard(movie: displayList[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // TAB 1: TV SHOWS (Grid)
  // ------------------------------------------------------------------------
  Widget _buildTVShowsTab(List<MovieModel> allContent) {
    List<MovieModel> tvShows =
    allContent.where((i) => i.category == 'TV Show').toList();

    if (tvShows.isEmpty) {
      return const Center(
          child: Text("No TV Shows available",
              style: TextStyle(color: Colors.white)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: tvShows.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _navigateToDetail(context, tvShows[index]),
          child: MovieCard(movie: tvShows[index]),
        );
      },
    );
  }

  // ------------------------------------------------------------------------
  // TAB 2: MY LIST (UPDATED WITH STREAM)
  // ------------------------------------------------------------------------
  Widget _buildMyListTab() {
    return StreamBuilder<List<MovieModel>>(
      stream: MyListService().getMyListStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.red));
        }

        final myList = snapshot.data ?? [];

        if (myList.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 60, color: Colors.grey),
                SizedBox(height: 10),
                Text("Your list is empty",
                    style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.62,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: myList.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _navigateToDetail(context, myList[index]),
              child: MovieCard(movie: myList[index]),
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------------------
  // TAB 3: SEARCH
  // ------------------------------------------------------------------------
  Widget _buildSearchTab(List<MovieModel> allMovies) {
    List<MovieModel> results = [];
    if (_searchQuery.isNotEmpty) {
      results = allMovies
          .where(
              (m) => m.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return SafeArea(
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      hintText: "Search...",
                      filled: true,
                      fillColor: Colors.grey.shade900,
                      border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  onChanged: (val) => setState(() => _searchQuery = val))),
          Expanded(
              child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(results[index].title,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(results[index].category,
                        style: const TextStyle(color: Colors.grey)),
                    onTap: () => _navigateToDetail(context, results[index]),
                  )))
        ]));
  }

  // ------------------------------------------------------------------------
  // WIDGET HELPERS
  // ------------------------------------------------------------------------
  Widget _buildTopTab(String title) {
    bool isSelected = _selectedTopCategory == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTopCategory = title;
          if (title == 'All') {
            _currentPage = 1; // Reset page when switching back to All
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: isSelected
            ? const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.red, width: 2)))
            : null,
        child: Text(title,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
      ),
    );
  }

  Widget buildSection(
      {required List<MovieModel> allMovies, required BuildContext context}) {
    if (allMovies.isEmpty) return const SizedBox.shrink();
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = (screenWidth - 48) / 2;
    final double cardHeight = cardWidth / 0.62;

    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: allMovies.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          return Container(
              width: cardWidth,
              margin: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () => _navigateToDetail(context, allMovies[index]),
                child: MovieCard(movie: allMovies[index]),
              ));
        },
      ),
    );
  }
}

// ------------------------------------------------------------------------
// PAGINATION CONTROLS WIDGET
// ------------------------------------------------------------------------
class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Function(int) onPageChanged;

  const PaginationControls({
    Key? key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(totalPages, (index) {
          int pageNumber = index + 1;
          if (totalPages > 5 && pageNumber > 4 && pageNumber != totalPages) {
            return (pageNumber == 5)
                ? const Text("...", style: TextStyle(color: Colors.white))
                : const SizedBox.shrink();
          }
          return _buildPageButton(
            text: "$pageNumber",
            isActive: currentPage == pageNumber,
            onTap: () => onPageChanged(pageNumber),
          );
        }),
        _buildPageButton(
          icon: Icons.arrow_forward_ios,
          isActive: false,
          isEnabled: currentPage < totalPages,
          onTap: () => onPageChanged(currentPage + 1),
        ),
        _buildPageButton(
          icon: Icons.last_page,
          isActive: false,
          isEnabled: currentPage < totalPages,
          onTap: () => onPageChanged(totalPages),
        ),
      ],
    );
  }

  Widget _buildPageButton({
    String? text,
    IconData? icon,
    required bool isActive,
    bool isEnabled = true,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.greenAccent
              : (isEnabled ? const Color(0xFF2C3038) : Colors.grey.shade800),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: text != null
              ? Text(
            text,
            style: TextStyle(
              color: isActive
                  ? Colors.black
                  : (isEnabled ? Colors.white : Colors.grey),
              fontWeight: FontWeight.bold,
            ),
          )
              : Icon(
            icon,
            color: isEnabled ? Colors.white : Colors.grey,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------
// CAROUSEL
// ------------------------------------------------------------------------
class FeaturedMovieCarousel extends StatefulWidget {
  final List<MovieModel> movies;
  const FeaturedMovieCarousel({required this.movies, Key? key})
      : super(key: key);
  @override
  State<FeaturedMovieCarousel> createState() => _FeaturedMovieCarouselState();
}

class _FeaturedMovieCarouselState extends State<FeaturedMovieCarousel> {
  late PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (widget.movies.isEmpty) return;
      if (_currentPage < widget.movies.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(_currentPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.fastOutSlowIn);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 480,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.movies.length,
            onPageChanged: (int page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) {
              final movie = widget.movies[index];
              return GestureDetector(
                onTap: () {
                  if (movie.category == 'TV Show') {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => TvShowDetailScreen(show: movie)));
                  } else {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MovieDetailScreen(movie: movie)));
                  }
                },
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                      image: DecorationImage(
                          image: NetworkImage(movie.thumbnailUrl),
                          fit: BoxFit.cover)),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black, Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: [0.0, 0.5],
                      ),
                    ),
                    alignment: Alignment.bottomCenter,
                    padding:
                    const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(movie.title.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                    color: Colors.black,
                                    blurRadius: 10,
                                    offset: Offset(0, 2))
                              ])),
                      const SizedBox(height: 10),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(movie.year.isNotEmpty ? movie.year : "2024",
                                style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            const Text("•",
                                style: TextStyle(color: Colors.white70)),
                            const SizedBox(width: 8),
                            Text(
                                movie.genres.isNotEmpty
                                    ? movie.genres.first
                                    : "Film",
                                style: const TextStyle(color: Colors.white)),
                          ]),
                      const SizedBox(height: 20),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(children: [
                              Icon(Icons.add, color: Colors.white),
                              SizedBox(height: 5),
                              Text("My List",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12))
                            ]),
                            SizedBox(width: 25),
                            Icon(Icons.play_circle_fill,
                                color: Colors.white, size: 50),
                            SizedBox(width: 25),
                            Column(children: [
                              Icon(Icons.info_outline, color: Colors.white),
                              SizedBox(height: 5),
                              Text("Info",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12))
                            ]),
                          ]),
                    ]),
                  ),
                ),
              );
            },
          ),
          Positioned(
              bottom: 10,
              right: 0,
              left: 0,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      widget.movies.length,
                          (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentPage == index ? 8 : 6,
                          height: _currentPage == index ? 8 : 6,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPage == index
                                  ? Colors.red
                                  : Colors.grey.withOpacity(0.5))))))
        ],
      ),
    );
  }
}

class AllLatestMoviesScreen extends StatelessWidget {
  final List<MovieModel> movies;
  const AllLatestMoviesScreen({required this.movies, Key? key})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text("All Latest",
              style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white)),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.62,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16),
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          return GestureDetector(
            onTap: () {
              if (movie.category == 'TV Show') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TvShowDetailScreen(show: movie)));
              } else {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MovieDetailScreen(movie: movie)));
              }
            },
            child: MovieCard(movie: movie),
          );
        },
      ),
    );
  }
}