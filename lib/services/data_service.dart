import 'dart:developer';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:scan_go/services/firebase_service.dart';
import 'package:scan_go/services/auth_service.dart';

class DataService {
  // Singleton instance
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  final FirebaseFirestore _db = FirebaseService.db;
  final FirebaseStorage _storage = FirebaseService.storage;
  final AuthService _authService = AuthService();

  // User related operations
  Future<void> updateUserPin(String pin) async {
    final String? userId = _authService.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _db.collection('Users').doc(userId).update({
      'pin': pin,
    });
  }

  // Bus collection operations
  CollectionReference get busesCollection => _db.collection('Buses');

  Future addBus({
    required String busNumber,
    required List<String> route,
    required int totalSeats,
  }) async {
    final user = await _authService.getUserProfile();

    if (user == null) {
      throw Exception('User not authenticated');
    }

    final result = await busesCollection.add({
      'busNumber': busNumber,
      'route': route,
      'totalSeats': totalSeats,
      'driver': user.username ?? 'Unknown',
      'userId': user.uid,
      'timestamp': Timestamp.now(),
      'isStarted': false,
      'lastStatusChange': null,
    });

    if (result.id.isNotEmpty) {
      log("Bus added with ID: ${result.id}");
      return 'Bus added successfully';
    }

    log(result.toString());
    return 'Failed to add bus';
  }

  Stream<QuerySnapshot> getAllBuses() {
    return busesCollection.snapshots();
  }

  // Check if a bus number already exists
  Future<bool> isBusNumberExists(String busNumber) async {
    final querySnapshot = await busesCollection
        .where('busNumber', isEqualTo: busNumber)
        .limit(1)
        .get();

    return querySnapshot.docs.isNotEmpty;
  }

  // --- NEW METHOD: Check for active/started bus ---
  Future<DocumentSnapshot?> getActiveBus() async {
    final String? userId = _authService.currentUser?.uid;
    if (userId == null) return null;

    try {
      final querySnapshot = await busesCollection
          .where('userId', isEqualTo: userId)
          .where('isStarted', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first;
      }
      return null;
    } catch (e) {
      debugPrint('Error checking active bus: $e');
      return null;
    }
  }
  // -----------------------------------------------

  Stream<QuerySnapshot> searchBuses({
    String? source,
    String? destination,
    DateTime? date,
  }) {
    Query query = busesCollection;

    if (source != null && source.isNotEmpty) {
      query = query.where('source', isEqualTo: source);
    }

    if (destination != null && destination.isNotEmpty) {
      query = query.where('destination', isEqualTo: destination);
    }

    if (date != null) {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      query = query
          .where('departureTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('departureTime',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }

    return query.snapshots();
  }

  // Tickets collection operations
  CollectionReference get ticketsCollection => _db.collection('Ticket');

  Future<void> saveTicket({
    required String userId,
    required String busNumber,
    required String source,
    required String destination,
    required double amount,
    required DateTime travelDate,
    String? paymentMethod,
    String? transactionId,
  }) async {
    await ticketsCollection.add({
      'userId': userId,
      'busNumber': busNumber,
      'source': source,
      'destination': destination,
      'amount': amount,
      'travelDate': Timestamp.fromDate(travelDate),
      'purchaseDate': Timestamp.now(),
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'isUsed': false,
    });
  }

  Stream<QuerySnapshot> getUserTickets(String userId) {
    return ticketsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('purchaseDate', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getTicketsByDateAndBus({
    required DateTime date,
    String? busNumber,
  }) {
    final String? userId = _authService.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    if (busNumber != null && busNumber.isNotEmpty) {
      return ticketsCollection
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .where('busNumber', isEqualTo: busNumber)
          .snapshots();
    } else {
      return Stream.fromFuture(
              busesCollection.where('userId', isEqualTo: userId).get())
          .asyncExpand((busSnapshot) {
        final userBusNumbers = busSnapshot.docs
            .map((doc) =>
                (doc.data() as Map<String, dynamic>)['busNumber'] as String)
            .toList();

        if (userBusNumbers.isEmpty) {
          return ticketsCollection
              .where('busNumber',
                  isEqualTo: 'NO_BUSES_FAKE_ID_TO_ENSURE_NO_RESULTS')
              .limit(1)
              .snapshots();
        }

        return ticketsCollection
            .where('timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('timestamp',
                isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .where('busNumber', whereIn: userBusNumbers)
            .snapshots();
      });
    }
  }

  Future<List<String>> getAllBusNumbers() async {
    final String? userId = _authService.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final busesSnapshot =
          await busesCollection.where('userId', isEqualTo: userId).get();

      final busNumbers = busesSnapshot.docs
          .map((doc) =>
              (doc.data() as Map<String, dynamic>)['busNumber'] as String)
          .toList()
        ..sort();

      return busNumbers;
    } catch (e) {
      debugPrint('Error getting bus numbers: $e');
      return [];
    }
  }

  Future<void> updateBusStatus(String busId, bool isStarted) async {
    try {
      await busesCollection.doc(busId).update({
        'isStarted': isStarted,
        'lastStatusChange': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating bus status: $e');
      throw Exception('Failed to update bus status: $e');
    }
  }

  Future<DocumentSnapshot?> getBusById(String busId) async {
    try {
      return await busesCollection.doc(busId).get();
    } catch (e) {
      debugPrint('Error getting bus by ID: $e');
      return null;
    }
  }

  Future<List<DocumentSnapshot>> getUserBuses() async {
    final String? userId = _authService.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final busesSnapshot =
          await busesCollection.where('userId', isEqualTo: userId).get();
      return busesSnapshot.docs;
    } catch (e) {
      debugPrint('Error getting user buses: $e');
      return [];
    }
  }

  Future<void> markTicketAsUsed(String ticketId) async {
    await ticketsCollection.doc(ticketId).update({
      'isUsed': true,
      'usedDate': Timestamp.now(),
    });
  }

  Future<String> uploadImage(
      String path, List<int> imageBytes, String fileName) async {
    final Reference reference = _storage.ref().child(path).child(fileName);
    final UploadTask uploadTask =
        reference.putData(Uint8List.fromList(imageBytes));
    final TaskSnapshot taskSnapshot = await uploadTask;
    return await taskSnapshot.ref.getDownloadURL();
  }

  Future<String> uploadProfileImage(String userId, List<int> imageBytes) async {
    return uploadImage('profile_images', imageBytes, '$userId.jpg');
  }
}
