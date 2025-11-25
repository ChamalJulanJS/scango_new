import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? username;
  final String? pin;
  final DateTime timestamp;
  final String?
      password; // Note: This should not be stored in app memory for security reasons

  UserModel({
    required this.uid,
    required this.email,
    this.username,
    this.pin,
    required this.timestamp,
    this.password,
  });

  // Convert User model to JSON for storing in Firestore
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'pin': pin,
      'timestamp': Timestamp.fromDate(timestamp),
      // We don't include password in toJson for security reasons
    };
  }

  // Create User model from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      username: data['username'],
      pin: data['pin'],
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      // Password should not be retrieved from Firestore
    );
  }

  // Create a copy of the user with updated fields
  UserModel copyWith({
    String? username,
    String? pin,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      username: username ?? this.username,
      pin: pin ?? this.pin,
      timestamp: timestamp,
    );
  }
}
