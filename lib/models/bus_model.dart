import 'package:cloud_firestore/cloud_firestore.dart';

class BusModel {
  final String id;
  final String busNumber;
  final String source;
  final String destination;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final double fare;
  final int totalSeats;
  final int availableSeats;
  final String? busType;
  final String? operator;

  BusModel({
    required this.id,
    required this.busNumber,
    required this.source,
    required this.destination,
    required this.departureTime,
    required this.arrivalTime,
    required this.fare,
    required this.totalSeats,
    required this.availableSeats,
    this.busType,
    this.operator,
  });

  // Convert Bus model to JSON for storing in Firestore
  Map<String, dynamic> toJson() {
    return {
      'busNumber': busNumber,
      'source': source,
      'destination': destination,
      'departureTime': Timestamp.fromDate(departureTime),
      'arrivalTime': Timestamp.fromDate(arrivalTime),
      'fare': fare,
      'totalSeats': totalSeats,
      'availableSeats': availableSeats,
      'busType': busType,
      'operator': operator,
    };
  }

  // Create Bus model from Firestore document
  factory BusModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return BusModel(
      id: doc.id,
      busNumber: data['busNumber'] ?? '',
      source: data['source'] ?? '',
      destination: data['destination'] ?? '',
      departureTime: (data['departureTime'] as Timestamp).toDate(),
      arrivalTime: (data['arrivalTime'] as Timestamp).toDate(),
      fare: (data['fare'] as num).toDouble(),
      totalSeats: data['totalSeats'] ?? 0,
      availableSeats: data['availableSeats'] ?? 0,
      busType: data['busType'],
      operator: data['operator'],
    );
  }

  // Create a copy of the bus with updated fields
  BusModel copyWith({
    String? busNumber,
    String? source,
    String? destination,
    DateTime? departureTime,
    DateTime? arrivalTime,
    double? fare,
    int? totalSeats,
    int? availableSeats,
    String? busType,
    String? operator,
  }) {
    return BusModel(
      id: id,
      busNumber: busNumber ?? this.busNumber,
      source: source ?? this.source,
      destination: destination ?? this.destination,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      fare: fare ?? this.fare,
      totalSeats: totalSeats ?? this.totalSeats,
      availableSeats: availableSeats ?? this.availableSeats,
      busType: busType ?? this.busType,
      operator: operator ?? this.operator,
    );
  }
}
