import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { deposit, withdrawal, gameEntry, gameWinning }

class WalletTransaction {
  final String id;
  final String userId;
  final double amount;
  final TransactionType type;
  final String description;
  final DateTime createdAt;
  final String? gameId;

  WalletTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.description,
    required this.createdAt,
    this.gameId,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      type: _typeFromString(map['type'] ?? 'deposit'),
      description: map['description'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      gameId: map['gameId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'type': _typeToString(type),
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'gameId': gameId,
    };
  }

  static TransactionType _typeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'deposit': return TransactionType.deposit;
      case 'withdrawal': return TransactionType.withdrawal;
      case 'gameentry': return TransactionType.gameEntry;
      case 'gamewinning': return TransactionType.gameWinning;
      default: return TransactionType.deposit;
    }
  }

  static String _typeToString(TransactionType type) {
    switch (type) {
      case TransactionType.deposit: return 'deposit';
      case TransactionType.withdrawal: return 'withdrawal';
      case TransactionType.gameEntry: return 'gameentry';
      case TransactionType.gameWinning: return 'gamewinning';
    }
  }
}

class WalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user wallet balance
  Stream<double> getUserBalance(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return 0.0;
      return (doc.data()?['walletBalance'] ?? 0).toDouble();
    });
  }

  // Get transaction history
  Stream<List<WalletTransaction>> getTransactionHistory(String userId) {
    return _firestore
        .collection('wallet_transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WalletTransaction.fromMap(doc.data()))
            .toList());
  }

  // Add deposit transaction (after external deposit)
  Future<void> addDeposit(String userId, double amount, String description) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(userId);
        final transactionRef = _firestore.collection('wallet_transactions').doc();

        final walletTransaction = WalletTransaction(
          id: transactionRef.id,
          userId: userId,
          amount: amount,
          type: TransactionType.deposit,
          description: description,
          createdAt: DateTime.now(),
        );

        transaction.update(userRef, {
          'walletBalance': FieldValue.increment(amount),
        });

        transaction.set(transactionRef, walletTransaction.toMap());
      });
    } catch (e) {
      print('Error adding deposit: $e');
      rethrow;
    }
  }

  // Record game entry transaction
  Future<void> recordGameEntry(String userId, String gameId, double amount) async {
    try {
      final transactionRef = _firestore.collection('wallet_transactions').doc();

      final walletTransaction = WalletTransaction(
        id: transactionRef.id,
        userId: userId,
        amount: amount,
        type: TransactionType.gameEntry,
        description: 'Entry fee for quiz game',
        createdAt: DateTime.now(),
        gameId: gameId,
      );

      await transactionRef.set(walletTransaction.toMap());
    } catch (e) {
      print('Error recording game entry: $e');
    }
  }

  // Record game winning transaction
  Future<void> recordGameWinning(String userId, String gameId, double amount, int rank) async {
    try {
      final transactionRef = _firestore.collection('wallet_transactions').doc();

      final walletTransaction = WalletTransaction(
        id: transactionRef.id,
        userId: userId,
        amount: amount,
        type: TransactionType.gameWinning,
        description: 'Prize for rank #$rank',
        createdAt: DateTime.now(),
        gameId: gameId,
      );

      await transactionRef.set(walletTransaction.toMap());
    } catch (e) {
      print('Error recording game winning: $e');
    }
  }

  // Get deposit URL (opens external deposit site)
  String getDepositUrl(String userId) {
    // Replace with your actual deposit website URL
    return 'https://yourschool.com/deposit?userId=$userId';
  }
}