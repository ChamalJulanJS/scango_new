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
      'isStarted': false,
      'lastStatusChange': null,
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

  // Get all tickets for a specific date and optionally filtered by bus number (only for current user's buses)
  Stream<QuerySnapshot> getTicketsByDateAndBus({
    required DateTime date,
    String? busNumber,
  }) {
    final String? userId = _authService.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Create start and end of the selected day for timestamp comparison
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    // If specific bus number is provided, check if it belongs to the user
    if (busNumber != null && busNumber.isNotEmpty) {
      // Return tickets for the specific bus and date
      return ticketsCollection
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .where('busNumber', isEqualTo: busNumber)
          .snapshots();
    } else {
      // For all user's buses, this is more complex
      // We'll need to get the user's buses first, then use the list in a query
      // This is a workaround using two separate queries

      // Return a stream that first fetches the user's buses, then uses that to filter tickets
      return Stream.fromFuture(
              busesCollection.where('userId', isEqualTo: userId).get())
          .asyncExpand((busSnapshot) {
        // Extract bus numbers owned by the current user
        final userBusNumbers = busSnapshot.docs
            .map((doc) =>
                (doc.data() as Map<String, dynamic>)['busNumber'] as String)
            .toList();

        if (userBusNumbers.isEmpty) {
          // If user has no buses, return empty result - use limit(1) and add a filter that will never match
          // instead of limit(0) which causes an assertion error
          return ticketsCollection
              .where('busNumber',
                  isEqualTo: 'NO_BUSES_FAKE_ID_TO_ENSURE_NO_RESULTS')
              .limit(1)
              .snapshots();
        }

        // Otherwise, filter by all of the user's buses
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

  // Get all bus numbers for populating the dropdown (only for current user)
  Future<List<String>> getAllBusNumbers() async {
    final String? userId = _authService.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get bus numbers from Buses collection where user is the owner
      final busesSnapshot =
          await busesCollection.where('userId', isEqualTo: userId).get();

      // Extract and sort bus numbers
      final busNumbers = busesSnapshot.docs
          .map((doc) =>
              (doc.data() as Map<String, dynamic>)['busNumber'] as String)
          .toList()
        ..sort();

      return busNumbers;
    } catch (e) {
      // Handle any errors
      print('Error getting bus numbers: $e');
      return [];
    }
  }
  
  // Update bus status (start/stop)
  Future<void> updateBusStatus(String busId, bool isStarted) async {
    try {
      await busesCollection.doc(busId).update({
        'isStarted': isStarted,
        'lastStatusChange': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating bus status: $e');
      throw Exception('Failed to update bus status: $e');
    }
  }
  
  // Get a specific bus by ID
  Future<DocumentSnapshot?> getBusById(String busId) async {
    try {
      return await busesCollection.doc(busId).get();
    } catch (e) {
      print('Error getting bus by ID: $e');
      return null;
    }
  }
  
  // Get all buses for the current user
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
      print('Error getting user buses: $e');
      return [];
    }
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
