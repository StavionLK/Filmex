import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/movie_model.dart';

class MyListService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the current user's ID
  String? get _userId => _auth.currentUser?.uid;

  // Reference to the user's 'my_list' collection
  CollectionReference? _getListRef() {
    if (_userId == null) return null;
    return _firestore.collection('users').doc(_userId).collection('my_list');
  }

  // 1. Add to My List
  Future<void> add(MovieModel movie) async {
    final ref = _getListRef();
    if (ref == null) return;

    // We save the entire movie object so we don't need to look it up later
    await ref.doc(movie.id).set({
      'title': movie.title,
      'description': movie.description,
      'videoUrl': movie.videoUrl,
      'thumbnailUrl': movie.thumbnailUrl,
      'category': movie.category,
      'rating': movie.rating,
      'year': movie.year,
      'runtime': movie.runtime,
      'genres': movie.genres,
      'cast': movie.cast,
      'addedAt': FieldValue.serverTimestamp(), // For sorting
    });
  }

  // 2. Remove from My List
  Future<void> remove(String movieId) async {
    final ref = _getListRef();
    if (ref == null) return;
    await ref.doc(movieId).delete();
  }

  // 3. Check if movie is in My List
  Future<bool> isAdded(String movieId) async {
    final ref = _getListRef();
    if (ref == null) return false;
    final doc = await ref.doc(movieId).get();
    return doc.exists;
  }

  // 4. Stream of My List (For Home Screen)
  Stream<List<MovieModel>> getMyListStream() {
    final ref = _getListRef();
    if (ref == null) return const Stream.empty();

    return ref
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MovieModel.fromMap(
            doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }
}