class MovieModel {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final String category;
  final double rating;

  // Metadata
  final String year;
  final String runtime;
  final List<String> genres;
  final String language;
  final String studio;
  final String imdb;

  // NEW: Cast List
  final List<Map<String, String>> cast;

  MovieModel({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.category,
    required this.rating,
    required this.year,
    required this.runtime,
    required this.genres,
    required this.language,
    required this.studio,
    required this.imdb,
    required this.cast,
  });

  factory MovieModel.fromMap(String id, Map<String, dynamic> map) {
    return MovieModel(
      id: id,
      title: map['title'] ?? 'No Title',
      description: map['description'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? map['thumbnail'] ?? map['image'] ?? 'https://via.placeholder.com/150',
      category: map['category'] ?? 'Movie',
      rating: (map['rating'] ?? 0).toDouble(),
      year: map['year'] ?? '',
      runtime: map['runtime'] ?? '',
      genres: List<String>.from(map['genres'] ?? ['Genre']),
      language: map['language'] ?? '',
      studio: map['studio'] ?? '',
      imdb: map['imdb'] ?? '',
      // Safely parse the cast list from Firestore
      cast: (map['cast'] as List<dynamic>?)
          ?.map((item) => Map<String, String>.from(item as Map))
          .toList() ?? [],
    );
  }
}