import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Initialize Firebase
  static Future<void> initializeFirebase() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBiXjUgMpMfgps_Y2_j2y5cBvZ_m7s1QRw",
        authDomain: "rp-2025-20164.firebaseapp.com",
        projectId: "rp-2025-20164",
        storageBucket: "rp-2025-20164.firebasestorage.app",
        messagingSenderId: "802097780498",
        appId: "1:802097780498:web:b9cac9235987950d3ec5cb",
        measurementId: "G-59REJY7ZT8",
      ),
    );
  }

  // Auth services
  static FirebaseAuth get auth => _auth;
  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential> signUp(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() {
    return _auth.signOut();
  }

  // Firestore services
  static FirebaseFirestore get db => _db;

  static CollectionReference getUsersCollection() {
    return _db.collection('Users');
  }

  static Future<void> createUserProfile(
      String userId, Map<String, dynamic> data) {
    return _db.collection('Users').doc(userId).set(data);
  }

  static Future<DocumentSnapshot> getUserProfile(String userId) {
    return _db.collection('Users').doc(userId).get();
  }

  // Storage services
  static FirebaseStorage get storage => _storage;

  static Reference getStorageReference(String path) {
    return _storage.ref().child(path);
  }
}
