import 'package:cloud_firestore/cloud_firestore.dart';

class TicketModel {
  final String id;
  final String userId;
  final String busNumber;
  final String source;
  final String destination;
  final double amount;
  final DateTime travelDate;
  final DateTime purchaseDate;
  final String? paymentMethod;
  final String? transactionId;
  final bool isUsed;
  final DateTime? usedDate;

  TicketModel({
    required this.id,
    required this.userId,
    required this.busNumber,
    required this.source,
    required this.destination,
    required this.amount,
    required this.travelDate,
    required this.purchaseDate,
    this.paymentMethod,
    this.transactionId,
    required this.isUsed,
    this.usedDate,
  });

  // Convert Ticket model to JSON for storing in Firestore
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'busNumber': busNumber,
      'source': source,
      'destination': destination,
      'amount': amount,
      'travelDate': Timestamp.fromDate(travelDate),
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'isUsed': isUsed,
      'usedDate': usedDate != null ? Timestamp.fromDate(usedDate!) : null,
    };
  }

  // Create Ticket model from Firestore document
  factory TicketModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return TicketModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      busNumber: data['busNumber'] ?? '',
      source: data['source'] ?? '',
      destination: data['destination'] ?? '',
      amount: (data['amount'] as num).toDouble(),
      travelDate: (data['travelDate'] as Timestamp).toDate(),
      purchaseDate: (data['purchaseDate'] as Timestamp).toDate(),
      paymentMethod: data['paymentMethod'],
      transactionId: data['transactionId'],
      isUsed: data['isUsed'] ?? false,
      usedDate: data['usedDate'] != null
          ? (data['usedDate'] as Timestamp).toDate()
          : null,
    );
  }

  // Create a copy of the ticket with updated fields
  TicketModel copyWith({
    String? busNumber,
    String? source,
    String? destination,
    double? amount,
    DateTime? travelDate,
    String? paymentMethod,
    String? transactionId,
    bool? isUsed,
    DateTime? usedDate,
  }) {
    return TicketModel(
      id: id,
      userId: userId,
      busNumber: busNumber ?? this.busNumber,
      source: source ?? this.source,
      destination: destination ?? this.destination,
      amount: amount ?? this.amount,
      travelDate: travelDate ?? this.travelDate,
      purchaseDate: purchaseDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionId: transactionId ?? this.transactionId,
      isUsed: isUsed ?? this.isUsed,
      usedDate: usedDate ?? this.usedDate,
    );
  }
}
