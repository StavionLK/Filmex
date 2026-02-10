import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPanel extends StatefulWidget {
  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  // ---------------- CONTROLLERS ----------------
  final _descriptionController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _thumbnailController = TextEditingController();
  final _keywordsController = TextEditingController();
  final _ratingController = TextEditingController();

  final _yearController = TextEditingController();
  final _runtimeController = TextEditingController();
  final _genresController = TextEditingController();
  final _languageController = TextEditingController();
  final _studioController = TextEditingController();
  final _imdbController = TextEditingController();

  final _castNameController = TextEditingController();
  final _castImageController = TextEditingController();

  final _movieTitleController = TextEditingController();

  final _newShowTitleController = TextEditingController();
  final _seasonController = TextEditingController();
  final _episodeController = TextEditingController();

  // ---------------- STATE VARIABLES ----------------
  bool isUploading = false;
  String _selectedCategory = 'Movie';
  String? _selectedTvShowId;
  final String adminEmail = "tharushaedu123@gmail.com";

  List<Map<String, String>> _castList = [];

  // ----------------------------------------------------------------------
  // CAST MANAGEMENT
  // ----------------------------------------------------------------------
  void _addCastMember() {
    if (_castNameController.text.isEmpty || _castImageController.text.isEmpty) {
      _showError("Please enter both Name and Image URL");
      return;
    }
    setState(() {
      _castList.add({
        'name': _castNameController.text.trim(),
        'image': _castImageController.text.trim(),
      });
      _castNameController.clear();
      _castImageController.clear();
    });
  }

  void _removeCastMember(int index) {
    setState(() => _castList.removeAt(index));
  }

  // ----------------------------------------------------------------------
  // UPLOAD FUNCTION
  // ----------------------------------------------------------------------
  Future<void> uploadContent() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showError("You are not logged in");
      return;
    }
    if (user.email != adminEmail) {
      _showError("Only admin can upload content");
      return;
    }

    if (_selectedCategory == 'Movie') {
      await _uploadMovie();
    } else {
      await _uploadTVShowEpisode();
    }
  }

  Future<void> _uploadMovie() async {
    if (_movieTitleController.text.isEmpty ||
        _videoUrlController.text.isEmpty ||
        _thumbnailController.text.isEmpty) {
      _showError("Please fill Title, Video URL and Thumbnail");
      return;
    }

    setState(() => isUploading = true);

    try {
      await FirebaseFirestore.instance.collection('movies').add({
        'title': _movieTitleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'videoUrl': _videoUrlController.text.trim(),
        'thumbnailUrl': _thumbnailController.text.trim(),
        'keywords': _keywordsController.text.split(',').map((e) => e.trim()).toList(),
        'category': 'Movie',
        'uploadedAt': FieldValue.serverTimestamp(),
        'rating': double.tryParse(_ratingController.text) ?? 0.0,
        'year': _yearController.text.trim(),
        'runtime': _runtimeController.text.trim(),
        'genres': _genresController.text.split(',').map((e) => e.trim()).toList(),
        'language': _languageController.text.trim(),
        'studio': _studioController.text.trim(),
        'imdb': _imdbController.text.trim(),
        'cast': _castList,
      });

      _showSuccess("Movie Uploaded Successfully");
      _clearAllFields();
    } catch (e) {
      _showError("Upload failed: $e");
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> _uploadTVShowEpisode() async {
    if (_selectedTvShowId == null && _newShowTitleController.text.isEmpty) {
      _showError("Select a show or enter a new title");
      return;
    }
    if (_seasonController.text.isEmpty || _episodeController.text.isEmpty || _videoUrlController.text.isEmpty) {
      _showError("Please enter Season, Episode, and Video URL");
      return;
    }

    setState(() => isUploading = true);

    try {
      String showId;

      if (_selectedTvShowId == 'new') {
        DocumentReference newShowRef = await FirebaseFirestore.instance.collection('tv_shows').add({
          'title': _newShowTitleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'thumbnailUrl': _thumbnailController.text.trim(),
          'keywords': _keywordsController.text.split(',').map((e) => e.trim()).toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'rating': double.tryParse(_ratingController.text) ?? 0.0,
          'year': _yearController.text.trim(),
          'runtime': _runtimeController.text.trim(),
          'genres': _genresController.text.split(',').map((e) => e.trim()).toList(),
          'language': _languageController.text.trim(),
          'studio': _studioController.text.trim(),
          'imdb': _imdbController.text.trim(),
          'cast': _castList,
        });
        showId = newShowRef.id;
      } else {
        showId = _selectedTvShowId!;
      }

      await FirebaseFirestore.instance
          .collection('tv_shows')
          .doc(showId)
          .collection('episodes')
          .add({
        'season': int.tryParse(_seasonController.text) ?? 1,
        'episode': int.tryParse(_episodeController.text) ?? 1,
        'videoUrl': _videoUrlController.text.trim(),
        'title': "S${_seasonController.text} E${_episodeController.text}",
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      _showSuccess("TV Show Episode Uploaded");
      _clearAllFields();
    } catch (e) {
      _showError("Upload failed: $e");
    } finally {
      setState(() => isUploading = false);
    }
  }

  // ----------------------------------------------------------------------
  // HELPER FUNCTIONS
  // ----------------------------------------------------------------------
  void _clearAllFields() {
    _movieTitleController.clear();
    _newShowTitleController.clear();
    _descriptionController.clear();
    _videoUrlController.clear();
    _thumbnailController.clear();
    _keywordsController.clear();
    _ratingController.clear();
    _yearController.clear();
    _runtimeController.clear();
    _genresController.clear();
    _languageController.clear();
    _studioController.clear();
    _imdbController.clear();
    _seasonController.clear();
    _episodeController.clear();
    _castNameController.clear();
    _castImageController.clear();
    setState(() {
      _selectedTvShowId = null;
      _castList.clear();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showMetadataFields = _selectedCategory == 'Movie' || _selectedTvShowId == 'new';

    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Panel"),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------------- CATEGORY SELECTOR ----------------
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  items: ['Movie', 'TV Show'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedCategory = newValue!;
                      if (_selectedCategory == 'Movie') _selectedTvShowId = null;
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 20),

            // ---------------- TV SHOW SELECTION ----------------
            if (_selectedCategory == 'TV Show') ...[
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('tv_shows').snapshots(),
                builder: (context, snapshot) {
                  // Initialize the items list with "Create New" option immediately
                  // This ensures the UI never buffers/blocks
                  List<DropdownMenuItem<String>> items = [];
                  items.add(DropdownMenuItem(
                    value: 'new',
                    child: Text("+ Create New TV Show", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  ));

                  // If data is loading or empty, we simply show the "Create New" option
                  // If data exists, we append it to the list
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    for (var show in snapshot.data!.docs) {
                      var data = show.data() as Map<String, dynamic>;
                      items.add(DropdownMenuItem(
                        value: show.id,
                        child: Text(data['title'] ?? 'Unknown Title'),
                      ));
                    }
                  } else if (snapshot.connectionState == ConnectionState.waiting) {
                    // Optional: You could add a disabled "Checking..." item if you want visual feedback
                    // items.add(DropdownMenuItem(value: 'loading', enabled: false, child: Text("Checking for shows...")));
                  }

                  // Safety check: ensure selected value is valid
                  String? safeSelectedValue = _selectedTvShowId;
                  // If currently selected ID is not in the new list (and not 'new'), reset it
                  if (safeSelectedValue != null && safeSelectedValue != 'new') {
                    bool exists = items.any((item) => item.value == safeSelectedValue);
                    if (!exists) safeSelectedValue = null;
                  }

                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        hint: Text("Select TV Show to add Episode"),
                        value: safeSelectedValue, // Use safe value
                        isExpanded: true,
                        items: items,
                        onChanged: (val) {
                          // Prevent selecting dummy 'loading' items if you added any
                          if (val == 'loading') return;
                          setState(() {
                            _selectedTvShowId = val;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 15),
            ],

            // ---------------- TITLE FIELDS ----------------
            if (_selectedCategory == 'Movie')
              TextField(
                controller: _movieTitleController,
                decoration: InputDecoration(labelText: "Movie Title", border: OutlineInputBorder()),
              ),

            if (_selectedCategory == 'TV Show' && _selectedTvShowId == 'new')
              TextField(
                controller: _newShowTitleController,
                decoration: InputDecoration(
                  labelText: "New TV Show Main Title",
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.blue.withOpacity(0.1),
                ),
              ),

            SizedBox(height: 15),

            // ---------------- METADATA & CAST FIELDS ----------------
            // Show metadata inputs if:
            // 1. It's a Movie
            // 2. OR It's a NEW TV Show (we need to create the show details)
            if (showMetadataFields) ...[
              Text("Details & Metadata", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: "Year", border: OutlineInputBorder()),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _ratingController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: "Rating (0-10)", border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _runtimeController,
                      decoration: InputDecoration(labelText: "Runtime (e.g. 2h 30m)", border: OutlineInputBorder()),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _languageController,
                      decoration: InputDecoration(labelText: "Language", border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              TextField(
                controller: _genresController,
                decoration: InputDecoration(labelText: "Genres (comma separated)", border: OutlineInputBorder()),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _studioController,
                      decoration: InputDecoration(labelText: "Studio", border: OutlineInputBorder()),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _imdbController,
                      decoration: InputDecoration(labelText: "IMDb ID / Score", border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // ---------------- CAST MEMBER SECTION ----------------
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Add Cast Members", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _castNameController,
                            decoration: InputDecoration(labelText: "Actor Name", border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _castImageController,
                            decoration: InputDecoration(labelText: "Image URL", border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _addCastMember,
                          child: Text("Add"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),

                    // Display Added Cast
                    if (_castList.isNotEmpty)
                      Container(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _castList.length,
                          itemBuilder: (context, index) {
                            final member = _castList[index];
                            return Stack(
                              children: [
                                Container(
                                  width: 80,
                                  margin: EdgeInsets.only(right: 10),
                                  child: Column(
                                    children: [
                                      CircleAvatar(
                                        backgroundImage: NetworkImage(member['image']!),
                                        radius: 30,
                                        onBackgroundImageError: (_, __) {},
                                        child: member['image']!.isEmpty ? Icon(Icons.person) : null,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        member['name']!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () => _removeCastMember(index),
                                    child: CircleAvatar(
                                      radius: 10,
                                      backgroundColor: Colors.red,
                                      child: Icon(Icons.close, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    else
                      Text("No cast members added yet.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              // ---------------- END CAST SECTION ----------------

              SizedBox(height: 20),

              TextField(
                controller: _keywordsController,
                decoration: InputDecoration(labelText: "Search Keywords (comma separated)", border: OutlineInputBorder()),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: "Description / Synopsis", border: OutlineInputBorder()),
                maxLines: 3,
              ),
              SizedBox(height: 10),
              TextField(
                controller: _thumbnailController,
                decoration: InputDecoration(labelText: "Thumbnail / Poster URL", border: OutlineInputBorder()),
              ),
              SizedBox(height: 20),
              Divider(thickness: 2),
              SizedBox(height: 20),
            ],

            // ---------------- EPISODE SPECIFIC FIELDS ----------------
            if (_selectedCategory == 'TV Show') ...[
              Text("Episode Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _seasonController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: "Season #", border: OutlineInputBorder()),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _episodeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: "Episode #", border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
            ],

            // ---------------- VIDEO URL ----------------
            TextField(
              controller: _videoUrlController,
              decoration: InputDecoration(
                labelText: _selectedCategory == 'Movie' ? "Movie Video URL" : "Episode Video URL",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.video_library),
              ),
            ),

            SizedBox(height: 30),

            // ---------------- UPLOAD BUTTON ----------------
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: isUploading ? null : uploadContent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedCategory == 'Movie' ? Colors.redAccent : Colors.blueAccent,
                ),
                child: isUploading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                  "Upload ${_selectedCategory == 'Movie' ? 'Movie' : 'Episode'}",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}