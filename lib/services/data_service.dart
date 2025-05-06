import 'dart:developer';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
    });

    if (result.id.isNotEmpty) {
      log("Bus added with ID: ${result.id}");
      // return success message
      return 'Bus added successfully';
    }

    // log the error
    log(result.toString());
    // return error message
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

  // Get all tickets for a specific date and optionally filtered by bus number
  Stream<QuerySnapshot> getTicketsByDateAndBus({
    required DateTime date,
    String? busNumber,
  }) {
    // Create start and end of the selected day for timestamp comparison
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    // Start with base query filtering by date using timestamp field
    Query query = ticketsCollection
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));

    // Add bus number filter if provided
    if (busNumber != null && busNumber.isNotEmpty) {
      query = query.where('busNumber', isEqualTo: busNumber);
    }

    return query.snapshots();
  }

  // Get all bus numbers for populating the dropdown
  Future<List<String>> getAllBusNumbers() async {
    final Set<String> busNumbersSet = {};

    try {
      // Get bus numbers from Buses collection
      final busesSnapshot = await busesCollection.get();
      for (var doc in busesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final busNumber = data?['busNumber'] as String?;
        if (busNumber != null && busNumber.isNotEmpty) {
          busNumbersSet.add(busNumber);
        }
      }

      // Also get bus numbers from Ticket collection
      final ticketsSnapshot = await ticketsCollection.get();
      for (var doc in ticketsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final busNumber = data?['busNumber'] as String?;
        if (busNumber != null && busNumber.isNotEmpty) {
          busNumbersSet.add(busNumber);
        }
      }
    } catch (e) {
      // Handle any errors
      print('Error getting bus numbers: $e');
    }

    return busNumbersSet.toList()..sort();
  }

  Future<void> markTicketAsUsed(String ticketId) async {
    await ticketsCollection.doc(ticketId).update({
      'isUsed': true,
      'usedDate': Timestamp.now(),
    });
  }

  // Storage operations
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
