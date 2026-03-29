import 'package:cloud_firestore/cloud_firestore.dart';

enum ChessGameStatus { waiting, active, completed, abandoned }

class ChessGameModel {
  final String id;
  final List<String> players;         // [whiteId, blackId] or [creatorId] when waiting
  final Map<String, String> playerNames;
  final Map<String, String> playerAvatars;
  final ChessGameStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? winnerId;
  final String? currentTurn;          // userId whose turn it is
  final String fen;
  final List<String> moveHistory;
  final Map<String, int> timers;      // userId -> seconds remaining
  final DateTime? lastMoveTime;       // when the current turn started
  final String? drawOfferBy;
  final String? rematchOfferBy;

  const ChessGameModel({
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
    this.fen =
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    this.moveHistory = const [],
    this.timers = const {},
    this.lastMoveTime,
    this.drawOfferBy,
    this.rematchOfferBy,
  });

  // ── Derived getters ──────────────────────────────────────────────

  bool get isWaiting   => status == ChessGameStatus.waiting;
  bool get isActive    => status == ChessGameStatus.active;
  bool get isCompleted => status == ChessGameStatus.completed;

  String? get whitePlayer => players.isNotEmpty ? players[0] : null;
  String? get blackPlayer => players.length > 1  ? players[1] : null;

  bool isPlayerInGame(String userId) => players.contains(userId);

  String? getOpponentId(String userId) {
    if (players.length < 2) return null;
    return players[0] == userId ? players[1] : players[0];
  }

  /// Returns 'white' or 'black' for this userId.
  String getPlayerColor(String userId) {
    if (players.isEmpty) return '';
    if (players[0] == userId) return 'white';
    if (players.length > 1 && players[1] == userId) return 'black';
    return '';
  }

  bool isPlayerTurn(String userId) => currentTurn == userId;

  /// Seconds remaining for this player (default 7 minutes).
  int getPlayerTimer(String userId) => timers[userId] ?? 420;

  // ── Serialisation ────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'id':             id,
    'players':        players,
    'playerNames':    playerNames,
    'playerAvatars':  playerAvatars,
    'status':         _statusToString(status),
    'createdAt':      Timestamp.fromDate(createdAt),
    'startedAt':      startedAt  != null ? Timestamp.fromDate(startedAt!)  : null,
    'endedAt':        endedAt    != null ? Timestamp.fromDate(endedAt!)    : null,
    'winnerId':       winnerId,
    'currentTurn':    currentTurn,
    'fen':            fen,
    'moveHistory':    moveHistory,
    'timers':         timers,
    'lastMoveTime':   lastMoveTime != null
        ? Timestamp.fromDate(lastMoveTime!) : null,
    'drawOfferBy':    drawOfferBy,
    'rematchOfferBy': rematchOfferBy,
  };

  factory ChessGameModel.fromMap(Map<String, dynamic> m) => ChessGameModel(
    id:             m['id'] as String? ?? '',
    players:        List<String>.from(m['players'] as List? ?? []),
    playerNames:    Map<String, String>.from(m['playerNames'] as Map? ?? {}),
    playerAvatars:  Map<String, String>.from(m['playerAvatars'] as Map? ?? {}),
    status:         _parseStatus(m['status'] as String?),
    createdAt:      _toDateTime(m['createdAt']) ?? DateTime.now(),
    startedAt:      _toDateTime(m['startedAt']),
    endedAt:        _toDateTime(m['endedAt']),
    winnerId:       m['winnerId']    as String?,
    currentTurn:    m['currentTurn'] as String?,
    fen:            m['fen'] as String? ??
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    moveHistory:    List<String>.from(m['moveHistory'] as List? ?? []),
    timers:         _parseTimers(m['timers']),
    lastMoveTime:   _toDateTime(m['lastMoveTime']),
    drawOfferBy:    m['drawOfferBy']    as String?,
    rematchOfferBy: m['rematchOfferBy'] as String?,
  );

  // ── Private helpers ──────────────────────────────────────────────

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static Map<String, int> _parseTimers(dynamic raw) {
    if (raw == null) return {};
    final m = Map<String, dynamic>.from(raw as Map);
    return m.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  static String _statusToString(ChessGameStatus s) {
    switch (s) {
      case ChessGameStatus.active:    return 'active';
      case ChessGameStatus.completed: return 'completed';
      case ChessGameStatus.abandoned: return 'abandoned';
      default:                         return 'waiting';
    }
  }

  static ChessGameStatus _parseStatus(String? s) {
    switch (s) {
      case 'active':    return ChessGameStatus.active;
      case 'completed': return ChessGameStatus.completed;
      case 'abandoned': return ChessGameStatus.abandoned;
      default:          return ChessGameStatus.waiting;
    }
  }
}