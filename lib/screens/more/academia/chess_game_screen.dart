import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess/chess.dart' as ch;
import '../../../constants/app_constants.dart';
import '../../../services/chess_service.dart';
import '../../../models/chess_game_model.dart';
import 'chess_lobby_screen.dart';

class ChessGameScreen extends StatefulWidget {
  final String gameId;
  final String userId;

  const ChessGameScreen({
    Key? key,
    required this.gameId,
    required this.userId,
  }) : super(key: key);

  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> {
  final ChessService _chessService = ChessService();

  // ── Selection state ──────────────────────────────────────────────
  String? _selectedSquare;       // e.g. "e2"
  List<String> _validMoves = []; // e.g. ["e4", "e3"]

  // ── Promotion ────────────────────────────────────────────────────
  bool _showPromotionDialog = false;
  String? _promotionFrom;
  String? _promotionTo;

  // ── Local countdown timer (counts down active player's clock) ────
  Timer? _clockTimer;
  // Mirrors the Firestore timers map so we can tick locally without
  // waiting for a round-trip write every second.
  Map<String, int> _localTimers = {};
  String? _lastKnownTurn;   // userId of who was moving last snapshot
  DateTime? _turnStartedAt; // wall-clock moment the current turn began

  // ── Result dialog guard ──────────────────────────────────────────
  bool _resultShown = false;

  // ── Latest game snapshot (avoids passing it through many methods) ─
  ChessGameModel? _lastGame;

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────
  // Timer logic
  // ──────────────────────────────────────────────────────────────────

  /// Called every time a new Firestore snapshot arrives.
  void _syncTimersFromSnapshot(ChessGameModel game) {
    final newTurn = game.currentTurn;

    // Sync base values from server whenever the turn changes
    if (newTurn != _lastKnownTurn) {
      _lastKnownTurn = newTurn;
      _localTimers = Map<String, int>.from(game.timers);
      _turnStartedAt = game.lastMoveTime ?? game.startedAt ?? DateTime.now();
      _restartClock(game);
    }
  }

  void _restartClock(ChessGameModel game) {
    _clockTimer?.cancel();
    if (!game.isActive) return;

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final currentPlayer = _lastGame?.currentTurn;
      if (currentPlayer == null) return;

      final remaining = (_localTimers[currentPlayer] ?? 0) - 1;

      if (remaining <= 0) {
        _clockTimer?.cancel();
        _localTimers[currentPlayer] = 0;
        setState(() {});
        // Tell server this player timed out
        _chessService.resignGame(widget.gameId, currentPlayer);
        return;
      }

      setState(() => _localTimers[currentPlayer] = remaining);
    });
  }

  // ──────────────────────────────────────────────────────────────────
  // Square interaction
  // ──────────────────────────────────────────────────────────────────

  void _onSquareTap(String square, ChessGameModel game) {
    if (_showPromotionDialog) return;
    if (game.currentTurn != widget.userId) return;
    if (!game.isActive) return;

    final chess = ch.Chess.fromFEN(game.fen);
    final myColor = _myColor(game);

    if (_selectedSquare == null) {
      // First tap — select a piece
      final piece = chess.get(square);
      if (piece != null && _colorChar(piece.color) == myColor) {
        setState(() {
          _selectedSquare = square;
          _validMoves = _legalDestinations(chess, square, myColor);
        });
      }
      return;
    }

    // Second tap
    if (_validMoves.contains(square)) {
      // Check for promotion
      if (_isPromotion(chess, _selectedSquare!, square)) {
        setState(() {
          _showPromotionDialog = true;
          _promotionFrom = _selectedSquare;
          _promotionTo = square;
          _selectedSquare = null;
          _validMoves = [];
        });
        return;
      }
      _submitMove(_selectedSquare!, square);
    } else {
      // Re-select a different friendly piece, or deselect
      final piece = chess.get(square);
      if (piece != null && _colorChar(piece.color) == myColor) {
        setState(() {
          _selectedSquare = square;
          _validMoves = _legalDestinations(chess, square, myColor);
        });
      } else {
        setState(() { _selectedSquare = null; _validMoves = []; });
      }
    }
  }

  Future<void> _submitMove(String from, String to, {String? promotion}) async {
    setState(() {
      _selectedSquare = null;
      _validMoves = [];
      _showPromotionDialog = false;
    });

    try {
      await _chessService.makeMove(
        gameId: widget.gameId,
        userId: widget.userId,
        from: from,
        to: to,
        promotion: promotion,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Move failed: $e',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Chess helpers
  // ──────────────────────────────────────────────────────────────────

  String _myColor(ChessGameModel game) =>
      game.players.isNotEmpty && game.players[0] == widget.userId
          ? 'w'
          : 'b';

  String _colorChar(ch.Color c) =>
      c == ch.Color.WHITE ? 'w' : 'b';

  bool _isPromotion(ch.Chess chess, String from, String to) {
    final piece = chess.get(from);
    if (piece == null || piece.type != ch.PieceType.PAWN) return false;
    final toRank = to[1];
    return (piece.color == ch.Color.WHITE && toRank == '8') ||
        (piece.color == ch.Color.BLACK && toRank == '1');
  }

  /// Returns legal destination squares for the piece on [square].
  /// We use chess.dart's move() in a try-each-candidate approach because
  /// generate_moves() internal fields are not part of the public API and
  /// differ across versions. Instead we attempt each square as a move on
  /// a copy and keep those that succeed.
  List<String> _legalDestinations(ch.Chess chess, String square, String myColor) {
    final files = ['a','b','c','d','e','f','g','h'];
    final ranks = ['1','2','3','4','5','6','7','8'];
    final destinations = <String>[];

    for (final f in files) {
      for (final r in ranks) {
        final target = '$f$r';
        if (target == square) continue;
        // Clone the board and try the move
        final copy = ch.Chess.fromFEN(chess.fen);
        final ok = copy.move({'from': square, 'to': target});
        if (ok) destinations.add(target);
      }
    }

    // Also try promotion moves (queen) to catch pawn promotion squares
    // They are already included above since move() auto-promotes to queen
    // when no promotion key is given in some versions — this is fine for
    // highlighting; the actual promotion choice is handled separately.

    return destinations;
  }

  // ──────────────────────────────────────────────────────────────────
  // Board rendering from FEN
  // ──────────────────────────────────────────────────────────────────

  /// Returns a 8×8 list of piece strings (same encoding as before: 'wp', 'bk', etc.)
  /// built fresh from the FEN every build — no stale local state.
  List<List<String>> _boardFromFen(String fen) {
    final board =
        List.generate(8, (_) => List<String>.filled(8, ''));
    final chess = ch.Chess.fromFEN(fen);

    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        // chess.dart uses square indices: rank 8 = row 0 of our grid
        final sq = '${String.fromCharCode(97 + c)}${8 - r}';
        final piece = chess.get(sq);
        if (piece != null) {
          final color = piece.color == ch.Color.WHITE ? 'w' : 'b';
          final type = piece.type.toString().toLowerCase()[0]; // k,q,r,b,n,p
          board[r][c] = '$color$type';
        }
      }
    }
    return board;
  }

  // ──────────────────────────────────────────────────────────────────
  // Game-end dialogs
  // ──────────────────────────────────────────────────────────────────

  void _handleGameEnd(ChessGameModel game) {
    if (_resultShown) return;
    if (!game.isCompleted) return;

    _resultShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showResultDialog(game));
  }

  void _showResultDialog(ChessGameModel game) {
    final won = game.winnerId == widget.userId;
    final isDraw = game.winnerId == null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          isDraw ? '🤝 Draw' : (won ? '🎉 You Won!' : '😞 You Lost'),
          style: GoogleFonts.poppins(
            color: isDraw
                ? Colors.orange
                : (won ? Colors.green : Colors.red),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        content: Text(
          isDraw
              ? 'The game ended in a draw. Your entry fee is refunded.'
              : (won ? 'You earned 500 coins! 🪙' : 'You lost your entry fee.'),
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const ChessLobbyScreen()));
            },
            child:
                Text('Lobby', style: GoogleFonts.poppins(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleRematchAction();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple),
            child: Text('Rematch',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Draw / resign / rematch
  // ──────────────────────────────────────────────────────────────────

  Future<void> _showResignDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Resign Game?',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure? Your opponent will win.',
            style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: Colors.white70))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Resign',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _chessService.resignGame(widget.gameId, widget.userId);
    }
  }

  Future<void> _handleDrawAction(ChessGameModel game) async {
    if (game.drawOfferBy != null && game.drawOfferBy != widget.userId) {
      final accept = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text('Accept Draw?',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text('Opponent offered a draw.',
              style: GoogleFonts.poppins(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Decline',
                    style: GoogleFonts.poppins(color: Colors.white70))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('Accept',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      );
      if (accept == true) {
        await _chessService.acceptDraw(widget.gameId, widget.userId);
      } else {
        await _chessService.declineDraw(widget.gameId);
      }
    } else if (game.drawOfferBy == null) {
      await _chessService.offerDraw(widget.gameId, widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Draw offered'),
          backgroundColor: Colors.blue,
        ));
      }
    }
  }

  Future<void> _handleRematchAction() async {
    final game = await _chessService.getGameStream(widget.gameId).first;
    if (game == null) return;

    if (game.rematchOfferBy != null && game.rematchOfferBy != widget.userId) {
      final newGame =
          await _chessService.acceptRematch(widget.gameId, widget.userId);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChessGameScreen(
                gameId: newGame.id, userId: widget.userId),
          ),
        );
      }
    } else if (game.rematchOfferBy == null) {
      await _chessService.offerRematch(widget.gameId, widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Rematch offered'),
          backgroundColor: Colors.blue,
        ));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChessGameModel?>(
      stream: _chessService.getGameStream(widget.gameId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _lastGame == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
                child: CircularProgressIndicator(
                    color: AppColors.primaryPurple)),
          );
        }

        final game = snapshot.data ?? _lastGame;
        if (game == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
                child: Text('Game not found',
                    style: TextStyle(color: Colors.white))),
          );
        }

        // Cache latest game for timer use
        _lastGame = game;

        // Sync timers on every snapshot (only resets when turn changes)
        _syncTimersFromSnapshot(game);

        // Check game end
        _handleGameEnd(game);

        final board = _boardFromFen(game.fen);
        final myColorChar = _myColor(game);
        final flipped = myColorChar == 'b';
        final isMyTurn = game.currentTurn == widget.userId;

        final opponentId = game.getOpponentId(widget.userId);
        final opponentName = opponentId != null
            ? (game.playerNames[opponentId] ?? 'Opponent')
            : 'Opponent';
        final myName =
            game.playerNames[widget.userId] ?? 'You';

        // Use local timers for smooth countdown
        final myTime = _localTimers[widget.userId] ?? game.getPlayerTimer(widget.userId);
        final oppTime = opponentId != null
            ? (_localTimers[opponentId] ?? game.getPlayerTimer(opponentId))
            : 420;

        // ── Last move squares (yellow highlight) ──────────────────
        String? lastMoveFrom;
        String? lastMoveTo;
        if (game.moveHistory.isNotEmpty) {
          final last = game.moveHistory.last; // stored as 'e2e4'
          if (last.length >= 4) {
            lastMoveFrom = last.substring(0, 2);
            lastMoveTo   = last.substring(2, 4);
          }
        }

        // ── King-in-check square (red highlight) ──────────────────
        String? kingInCheckSq;
        {
          final chess = ch.Chess.fromFEN(game.fen);
          if (chess.in_check) {
            // Find the king of the side to move
            final colorToFind = game.currentTurn == game.players[0]
                ? ch.Color.WHITE
                : ch.Color.BLACK;
            outer:
            for (int r = 0; r < 8; r++) {
              for (int c = 0; c < 8; c++) {
                final sq = '${String.fromCharCode(97 + c)}${8 - r}';
                final p = chess.get(sq);
                if (p != null &&
                    p.type == ch.PieceType.KING &&
                    p.color == colorToFind) {
                  kingInCheckSq = sq;
                  break outer;
                }
              }
            }
          }
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(children: [
              Column(children: [
                _buildPlayerBar(
                  name: opponentName,
                  timeSecs: oppTime,
                  isMyTurn: !isMyTurn,
                  color: myColorChar == 'w' ? 'black' : 'white',
                  avatarUrl: opponentId != null
                      ? game.playerAvatars[opponentId]
                      : null,
                ),

                // Board
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppColors.primaryPurple, width: 2),
                        ),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 8),
                          itemCount: 64,
                          itemBuilder: (context, index) {
                            int row = index ~/ 8;
                            int col = index % 8;
                            if (flipped) {
                              row = 7 - row;
                              col = 7 - col;
                            }
                            final sq =
                                '${String.fromCharCode(97 + col)}${8 - row}';
                            final piece = board[row][col];
                            final isLight = (row + col) % 2 == 0;
                            final isSel      = _selectedSquare == sq;
                            final isValid    = _validMoves.contains(sq);
                            final isLastMove = sq == lastMoveFrom || sq == lastMoveTo;
                            final isKingCheck = sq == kingInCheckSq;

                            // Priority: selected > check > valid > lastMove > normal
                            Color squareColor;
                            if (isSel) {
                              squareColor = Colors.yellow.withOpacity(0.75);
                            } else if (isKingCheck) {
                              squareColor = Colors.red.withOpacity(0.80);
                            } else if (isValid) {
                              squareColor = Colors.green.withOpacity(0.35);
                            } else if (isLastMove) {
                              squareColor = const Color(0xFFF6F669).withOpacity(0.50);
                            } else {
                              squareColor = isLight
                                  ? const Color(0xFFF0D9B5)
                                  : const Color(0xFFB58863);
                            }

                            return GestureDetector(
                              onTap: () => _onSquareTap(sq, game),
                              child: Container(
                                decoration: BoxDecoration(color: squareColor),
                                child: Stack(children: [
                                  if (piece.isNotEmpty)
                                    Center(
                                      child: Text(
                                        _pieceSymbol(piece),
                                        style: TextStyle(
                                          fontSize: 30,
                                          shadows: [
                                            Shadow(
                                              // stronger shadow on red bg so king is readable
                                              color: isKingCheck
                                                  ? Colors.black87
                                                  : Colors.black54,
                                              offset: const Offset(1, 1),
                                              blurRadius: isKingCheck ? 4 : 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (isValid && piece.isEmpty)
                                    Center(
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle),
                                      ),
                                    ),
                                  if (isValid && piece.isNotEmpty)
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.green, width: 3),
                                      ),
                                    ),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                _buildPlayerBar(
                  name: myName,
                  timeSecs: myTime,
                  isMyTurn: isMyTurn,
                  color: myColorChar == 'w' ? 'white' : 'black',
                  avatarUrl: game.playerAvatars[widget.userId],
                  showTurnLabel: true,
                ),

                // Controls
                if (game.isActive) _buildControls(game),
                if (game.isCompleted) _buildRematchRow(game),
              ]),

              // Promotion overlay
              if (_showPromotionDialog) _buildPromotionOverlay(myColorChar),
            ]),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Sub-widgets
  // ──────────────────────────────────────────────────────────────────

  Widget _buildPlayerBar({
    required String name,
    required int timeSecs,
    required bool isMyTurn,
    required String color,
    String? avatarUrl,
    bool showTurnLabel = false,
  }) {
    final mins = timeSecs ~/ 60;
    final secs = timeSecs % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final isLow = timeSecs < 30;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isMyTurn
            ? AppColors.primaryPurple.withOpacity(0.15)
            : const Color(0xFF1A1A1A),
        border: isMyTurn
            ? Border(
                bottom: BorderSide(
                    color: AppColors.primaryPurple.withOpacity(0.5), width: 1))
            : null,
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
          backgroundImage:
              avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(name[0].toUpperCase(),
                  style: GoogleFonts.poppins(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.bold))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Text(name,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color == 'white' ? Colors.white : Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white38),
                    ),
                  ),
                ]),
                if (showTurnLabel && isMyTurn)
                  Text('Your turn',
                      style: GoogleFonts.poppins(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
              ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isLow
                ? Colors.red.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            Icon(Icons.timer,
                size: 16, color: isLow ? Colors.red : Colors.white70),
            const SizedBox(width: 4),
            Text(timeStr,
                style: GoogleFonts.poppins(
                    color: isLow ? Colors.red : Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildControls(ChessGameModel game) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _controlBtn(
          icon: Icons.flag_outlined,
          label: 'Resign',
          color: Colors.red,
          onTap: _showResignDialog,
        ),
        _controlBtn(
          icon: Icons.handshake_outlined,
          label: game.drawOfferBy != null ? 'Draw Offered' : 'Offer Draw',
          color: game.drawOfferBy != null ? Colors.orange : Colors.blue,
          onTap: () => _handleDrawAction(game),
        ),
      ]),
    );
  }

  Widget _buildRematchRow(ChessGameModel game) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _controlBtn(
          icon: Icons.replay,
          label: game.rematchOfferBy != null
              ? (game.rematchOfferBy == widget.userId
                  ? 'Rematch Sent'
                  : 'Accept Rematch')
              : 'Rematch',
          color: AppColors.primaryPurple,
          onTap: _handleRematchAction,
        ),
        _controlBtn(
          icon: Icons.exit_to_app,
          label: 'Leave',
          color: Colors.grey,
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ChessLobbyScreen()),
          ),
        ),
      ]),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildPromotionOverlay(String myColorChar) {
    final pieces = ['q', 'r', 'b', 'n'];
    final labels = ['Queen', 'Rook', 'Bishop', 'Knight'];

    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Choose Promotion',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(4, (i) {
                    final code = myColorChar + pieces[i];
                    return GestureDetector(
                      onTap: () => _submitMove(
                          _promotionFrom!, _promotionTo!,
                          promotion: pieces[i]),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.primaryPurple.withOpacity(0.5)),
                        ),
                        child: Column(children: [
                          Text(_pieceSymbol(code),
                              style: const TextStyle(fontSize: 32)),
                          const SizedBox(height: 4),
                          Text(labels[i],
                              style: GoogleFonts.poppins(
                                  color: Colors.white70, fontSize: 10)),
                        ]),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Piece symbol helper
  // ──────────────────────────────────────────────────────────────────

  String _pieceSymbol(String piece) {
    const map = {
      'wp': '♙', 'wn': '♘', 'wb': '♗', 'wr': '♖', 'wq': '♕', 'wk': '♔',
      'bp': '♟', 'bn': '♞', 'bb': '♝', 'br': '♜', 'bq': '♛', 'bk': '♚',
    };
    return map[piece] ?? '?';
  }
}