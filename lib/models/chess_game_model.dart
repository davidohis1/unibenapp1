import 'package:cloud_firestore/cloud_firestore.dart';

enum ChessGameStatus { waiting, active, completed, abandoned }

class ChessGameModel {
  final String id;
  final List<String> players; // [whiteId, blackId] or just [creatorId] when waiting
  final Map<String, String> playerNames; // userId -> username
  final Map<String, String> playerAvatars; // userId -> avatarUrl
  final ChessGameStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? winnerId;
  final String? currentTurn; // userId of player whose turn it is
  final String fen; // Forsyth-Edwards Notation for board state
  final List<String> moveHistory; // List of moves in algebraic notation
  final Map<String, int> timers; // userId -> seconds left (420 seconds = 7 minutes)
  final DateTime? lastMoveTime;
  final String? drawOfferBy; // userId if draw offered
  final String? rematchOfferBy; // userId if rematch offered

  ChessGameModel({
    required this.id,
    required this.players,
    required this.playerNames,
    this.playerAvatars = const {},
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.winnerId,
    this.currentTurn,
    this.fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', // Starting position
    this.moveHistory = const [],
    this.timers = const {},
    this.lastMoveTime,
    this.drawOfferBy,
    this.rematchOfferBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'players': players,
      'playerNames': playerNames,
      'playerAvatars': playerAvatars,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'winnerId': winnerId,
      'currentTurn': currentTurn,
      'fen': fen,
      'moveHistory': moveHistory,
      'timers': timers,
      'lastMoveTime': lastMoveTime != null ? Timestamp.fromDate(lastMoveTime!) : null,
      'drawOfferBy': drawOfferBy,
      'rematchOfferBy': rematchOfferBy,
    };
  }

  factory ChessGameModel.fromMap(Map<String, dynamic> map) {
    return ChessGameModel(
      id: map['id'] ?? '',
      players: List<String>.from(map['players'] ?? []),
      playerNames: Map<String, String>.from(map['playerNames'] ?? {}),
      playerAvatars: Map<String, String>.from(map['playerAvatars'] ?? {}),
      status: _parseStatus(map['status']),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (map['startedAt'] as Timestamp?)?.toDate(),
      endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
      winnerId: map['winnerId'],
      currentTurn: map['currentTurn'],
      fen: map['fen'] ?? 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      moveHistory: List<String>.from(map['moveHistory'] ?? []),
      timers: Map<String, int>.from(map['timers'] ?? {}),
      lastMoveTime: (map['lastMoveTime'] as Timestamp?)?.toDate(),
      drawOfferBy: map['drawOfferBy'],
      rematchOfferBy: map['rematchOfferBy'],
    );
  }

  static ChessGameStatus _parseStatus(String? status) {
    switch (status) {
      case 'active':
        return ChessGameStatus.active;
      case 'completed':
        return ChessGameStatus.completed;
      case 'abandoned':
        return ChessGameStatus.abandoned;
      default:
        return ChessGameStatus.waiting;
    }
  }

  bool get isWaiting => status == ChessGameStatus.waiting;
  bool get isActive => status == ChessGameStatus.active;
  bool get isCompleted => status == ChessGameStatus.completed;
  
  String? get whitePlayer => players.isNotEmpty ? players[0] : null;
  String? get blackPlayer => players.length > 1 ? players[1] : null;
  
  bool isPlayerInGame(String userId) => players.contains(userId);
  
  String? getOpponentId(String userId) {
    if (players.length < 2) return null;
    return players.first == userId ? players[1] : players[0];
  }
  
  String getPlayerColor(String userId) {
    if (players.isEmpty) return '';
    if (players[0] == userId) return 'white';
    if (players.length > 1 && players[1] == userId) return 'black';
    return '';
  }
  
  bool isPlayerTurn(String userId) => currentTurn == userId;
  
  int getPlayerTimer(String userId) => timers[userId] ?? 420; // Default 7 minutes
}

class ChessMove {
  final String from;
  final String to;
  final String? promotion; // 'q', 'r', 'b', 'n' for queen, rook, bishop, knight
  final bool isCapture;
  final bool isCheck;
  final bool isCheckmate;
  final bool isCastling;
  final bool isEnPassant;
  final String san; // Standard Algebraic Notation

  ChessMove({
    required this.from,
    required this.to,
    this.promotion,
    this.isCapture = false,
    this.isCheck = false,
    this.isCheckmate = false,
    this.isCastling = false,
    this.isEnPassant = false,
    required this.san,
  });

  Map<String, dynamic> toMap() {
    return {
      'from': from,
      'to': to,
      'promotion': promotion,
      'isCapture': isCapture,
      'isCheck': isCheck,
      'isCheckmate': isCheckmate,
      'isCastling': isCastling,
      'isEnPassant': isEnPassant,
      'san': san,
    };
  }

  factory ChessMove.fromMap(Map<String, dynamic> map) {
    return ChessMove(
      from: map['from'] ?? '',
      to: map['to'] ?? '',
      promotion: map['promotion'],
      isCapture: map['isCapture'] ?? false,
      isCheck: map['isCheck'] ?? false,
      isCheckmate: map['isCheckmate'] ?? false,
      isCastling: map['isCastling'] ?? false,
      isEnPassant: map['isEnPassant'] ?? false,
      san: map['san'] ?? '',
    );
  }
}