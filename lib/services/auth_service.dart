import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scan_go/models/user_model.dart';
import 'package:scan_go/services/firebase_service.dart';

class AuthService {
  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Get the current authenticated user
  User? get currentUser => FirebaseService.currentUser;

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => FirebaseService.auth.authStateChanges();

  // Sign up with email and password
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      // Create user with email and password
      final UserCredential userCredential =
          await FirebaseService.signUp(email, password);
      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('Failed to create user');
      }

      // Create user profile in Firestore
      final UserModel userModel = UserModel(
        uid: user.uid,
        email: email,
        username: username,
        timestamp: DateTime.now(),
      );

      // Save user data to Firestore
      await FirebaseService.createUserProfile(user.uid, userModel.toJson());

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Failed to sign up: ${e.toString()}');
    }
  }

  // Sign in with email and password
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in with email and password
      final UserCredential userCredential =
          await FirebaseService.signIn(email, password);
      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('Failed to sign in');
      }

      // Get user profile from Firestore
      final DocumentSnapshot doc =
          await FirebaseService.getUserProfile(user.uid);

      return UserModel.fromFirestore(doc);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await FirebaseService.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }

  // Get user profile
  Future<UserModel?> getUserProfile() async {
    try {
      if (currentUser == null) return null;

      final DocumentSnapshot doc =
          await FirebaseService.getUserProfile(currentUser!.uid);
      log(doc.data().toString());
      log(currentUser!.uid.toString());
      if (!doc.exists) return null;

      return UserModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get user profile: ${e.toString()}');
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? username,
    String? pin,
  }) async {
    try {
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      final Map<String, dynamic> updates = {};
      if (username != null) updates['username'] = username;
      if (pin != null) updates['pin'] = pin;

      await FirebaseService.getUsersCollection()
          .doc(currentUser!.uid)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update user profile: ${e.toString()}');
    }
  }

  // Check if username already exists
  Future<bool> usernameExists(String username) async {
    try {
      final querySnapshot = await FirebaseService.getUsersCollection()
          .where('username', isEqualTo: username)
          .get();

      // If there's at least one document and it's not the current user
      if (querySnapshot.docs.isNotEmpty) {
        // If any document doesn't belong to current user, username exists
        for (var doc in querySnapshot.docs) {
          if (doc.id != currentUser?.uid) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      throw Exception('Failed to check username: ${e.toString()}');
    }
  }

  // Handle Firebase Auth exceptions
  Exception _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No user found with this email');
      case 'wrong-password':
        return Exception('Wrong password');
      case 'email-already-in-use':
        return Exception('Email is already in use');
      case 'weak-password':
        return Exception('Password is too weak');
      case 'invalid-email':
        return Exception('Invalid email format');
      case 'operation-not-allowed':
        return Exception('Operation not allowed');
      case 'user-disabled':
        return Exception('User has been disabled');
      default:
        return Exception('Authentication error: ${e.message}');
    }
  }
}
