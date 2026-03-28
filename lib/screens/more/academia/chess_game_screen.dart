import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../constants/app_constants.dart';
import '../../../services/chess_service.dart';
import '../../../models/chess_game_model.dart';

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
  
  // Board representation
  List<List<String>> _board = [];
  String? _selectedSquare;
  List<String> _validMoves = [];
  bool _isMyTurn = false;
  String _playerColor = '';
  Timer? _timer;
  int _timeLeft = 420; // 7 minutes in seconds
  bool _showPromotionDialog = false;
  String? _promotionMoveFrom;
  String? _promotionMoveTo;
  String? _currentFen;

  // Initial board setup (standard chess)
  final List<List<String>> _initialBoard = [
    ['br', 'bn', 'bb', 'bq', 'bk', 'bb', 'bn', 'br'],
    ['bp', 'bp', 'bp', 'bp', 'bp', 'bp', 'bp', 'bp'],
    ['', '', '', '', '', '', '', ''],
    ['', '', '', '', '', '', '', ''],
    ['', '', '', '', '', '', '', ''],
    ['', '', '', '', '', '', '', ''],
    ['wp', 'wp', 'wp', 'wp', 'wp', 'wp', 'wp', 'wp'],
    ['wr', 'wn', 'wb', 'wq', 'wk', 'wb', 'wn', 'wr'],
  ];

  @override
  void initState() {
    super.initState();
    _board = _initialBoard.map((row) => List<String>.from(row)).toList();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isMyTurn && mounted) {
        setState(() {
          _timeLeft--;
        });
        
        if (_timeLeft <= 0) {
          _timer?.cancel();
          _handleTimeout();
        }
      }
    });
  }

  Future<void> _handleTimeout() async {
    try {
      await _chessService.resignGame(widget.gameId, widget.userId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Time expired! You lost the game.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print('Error handling timeout: $e');
    }
  }

  // Get all valid moves for a piece
  List<String> _getValidMoves(int row, int col) {
    List<String> moves = [];
    String piece = _board[row][col];
    
    if (piece.isEmpty) return moves;
    
    // Check if it's the player's piece
    String pieceColor = piece[0];
    if ((_playerColor == 'white' && pieceColor != 'w') ||
        (_playerColor == 'black' && pieceColor != 'b')) {
      return moves;
    }

    String pieceType = piece[1];

    switch (pieceType) {
      case 'p': // Pawn
        moves.addAll(_getPawnMoves(row, col, pieceColor));
        break;
      case 'r': // Rook
        moves.addAll(_getRookMoves(row, col, pieceColor));
        break;
      case 'n': // Knight
        moves.addAll(_getKnightMoves(row, col, pieceColor));
        break;
      case 'b': // Bishop
        moves.addAll(_getBishopMoves(row, col, pieceColor));
        break;
      case 'q': // Queen
        moves.addAll(_getQueenMoves(row, col, pieceColor));
        break;
      case 'k': // King
        moves.addAll(_getKingMoves(row, col, pieceColor));
        break;
    }
    
    return moves;
  }

  List<String> _getPawnMoves(int row, int col, String color) {
    List<String> moves = [];
    int direction = color == 'w' ? -1 : 1;
    int startRow = color == 'w' ? 6 : 1;

    // Move forward one
    if (row + direction >= 0 && row + direction < 8) {
      if (_board[row + direction][col].isEmpty) {
        moves.add('${String.fromCharCode(97 + col)}${8 - (row + direction)}');
        
        // Move forward two from start
        if (row == startRow && _board[row + 2 * direction][col].isEmpty) {
          moves.add('${String.fromCharCode(97 + col)}${8 - (row + 2 * direction)}');
        }
      }
      
      // Captures
      if (col > 0) {
        String leftCapture = _board[row + direction][col - 1];
        if (leftCapture.isNotEmpty && leftCapture[0] != color) {
          moves.add('${String.fromCharCode(97 + col - 1)}${8 - (row + direction)}');
        }
      }
      if (col < 7) {
        String rightCapture = _board[row + direction][col + 1];
        if (rightCapture.isNotEmpty && rightCapture[0] != color) {
          moves.add('${String.fromCharCode(97 + col + 1)}${8 - (row + direction)}');
        }
      }
    }
    return moves;
  }

  List<String> _getRookMoves(int row, int col, String color) {
    List<String> moves = [];
    List<List<int>> directions = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    
    for (var dir in directions) {
      int r = row + dir[0];
      int c = col + dir[1];
      
      while (r >= 0 && r < 8 && c >= 0 && c < 8) {
        if (_board[r][c].isEmpty) {
          moves.add('${String.fromCharCode(97 + c)}${8 - r}');
        } else {
          if (_board[r][c][0] != color) {
            moves.add('${String.fromCharCode(97 + c)}${8 - r}');
          }
          break;
        }
        r += dir[0];
        c += dir[1];
      }
    }
    return moves;
  }

  List<String> _getBishopMoves(int row, int col, String color) {
    List<String> moves = [];
    List<List<int>> directions = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
    
    for (var dir in directions) {
      int r = row + dir[0];
      int c = col + dir[1];
      
      while (r >= 0 && r < 8 && c >= 0 && c < 8) {
        if (_board[r][c].isEmpty) {
          moves.add('${String.fromCharCode(97 + c)}${8 - r}');
        } else {
          if (_board[r][c][0] != color) {
            moves.add('${String.fromCharCode(97 + c)}${8 - r}');
          }
          break;
        }
        r += dir[0];
        c += dir[1];
      }
    }
    return moves;
  }

  List<String> _getQueenMoves(int row, int col, String color) {
    return _getRookMoves(row, col, color) + _getBishopMoves(row, col, color);
  }

  List<String> _getKnightMoves(int row, int col, String color) {
    List<String> moves = [];
    List<List<int>> jumps = [
      [-2, -1], [-2, 1], [-1, -2], [-1, 2],
      [1, -2], [1, 2], [2, -1], [2, 1]
    ];
    
    for (var jump in jumps) {
      int r = row + jump[0];
      int c = col + jump[1];
      
      if (r >= 0 && r < 8 && c >= 0 && c < 8) {
        if (_board[r][c].isEmpty || _board[r][c][0] != color) {
          moves.add('${String.fromCharCode(97 + c)}${8 - r}');
        }
      }
    }
    return moves;
  }

  List<String> _getKingMoves(int row, int col, String color) {
    List<String> moves = [];
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        int r = row + dr;
        int c = col + dc;
        
        if (r >= 0 && r < 8 && c >= 0 && c < 8) {
          if (_board[r][c].isEmpty || _board[r][c][0] != color) {
            moves.add('${String.fromCharCode(97 + c)}${8 - r}');
          }
        }
      }
    }
    return moves;
  }

  void _onSquareTap(int row, int col, ChessGameModel game) {
    if (!_isMyTurn || game.status != ChessGameStatus.active) return;
    if (_showPromotionDialog) return;

    String square = '${String.fromCharCode(97 + col)}${8 - row}';

    if (_selectedSquare != null) {
      if (_selectedSquare == square) {
        setState(() {
          _selectedSquare = null;
          _validMoves = [];
        });
        return;
      }

      if (_validMoves.contains(square)) {
        String piece = _board[row][col];
        
        // Check for pawn promotion
        String selectedPiece = _board[_selectedRow][_selectedCol];
        if (selectedPiece == 'wp' && row == 0) {
          setState(() {
            _showPromotionDialog = true;
            _promotionMoveFrom = _selectedSquare;
            _promotionMoveTo = square;
          });
          return;
        }
        if (selectedPiece == 'bp' && row == 7) {
          setState(() {
            _showPromotionDialog = true;
            _promotionMoveFrom = _selectedSquare;
            _promotionMoveTo = square;
          });
          return;
        }

        _makeMove(_selectedSquare!, square);
        return;
      }

      // Select new piece
      if (_board[row][col].isNotEmpty) {
        String pieceColor = _board[row][col][0];
        if ((_playerColor == 'white' && pieceColor == 'w') ||
            (_playerColor == 'black' && pieceColor == 'b')) {
          setState(() {
            _selectedSquare = square;
            _validMoves = _getValidMoves(row, col);
          });
        }
      }
    } else {
      // Select piece
      if (_board[row][col].isNotEmpty) {
        String pieceColor = _board[row][col][0];
        if ((_playerColor == 'white' && pieceColor == 'w') ||
            (_playerColor == 'black' && pieceColor == 'b')) {
          setState(() {
            _selectedSquare = square;
            _validMoves = _getValidMoves(row, col);
          });
        }
      }
    }
  }

  int get _selectedRow {
    if (_selectedSquare == null) return -1;
    int col = _selectedSquare!.codeUnitAt(0) - 97;
    int row = 8 - int.parse(_selectedSquare![1]);
    return row;
  }

  int get _selectedCol {
    if (_selectedSquare == null) return -1;
    return _selectedSquare!.codeUnitAt(0) - 97;
  }

  Future<void> _makeMove(String from, String to, {String? promotion}) async {
    int fromRow = 8 - int.parse(from[1]);
    int fromCol = from.codeUnitAt(0) - 97;
    int toRow = 8 - int.parse(to[1]);
    int toCol = to.codeUnitAt(0) - 97;

    String piece = _board[fromRow][fromCol];
    String captured = _board[toRow][toCol];

    // Update board locally
    setState(() {
      if (promotion != null) {
        _board[toRow][toCol] = _playerColor[0] + promotion;
      } else {
        _board[toRow][toCol] = piece;
      }
      _board[fromRow][fromCol] = '';
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
      // Revert move on error
      setState(() {
        _board[fromRow][fromCol] = piece;
        _board[toRow][toCol] = captured;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid move: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPromotionDialog() {
    if (!_showPromotionDialog) return SizedBox();

    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose Promotion',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPromotionPiece('q', 'Queen'),
                    _buildPromotionPiece('r', 'Rook'),
                    _buildPromotionPiece('b', 'Bishop'),
                    _buildPromotionPiece('n', 'Knight'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromotionPiece(String piece, String name) {
    return GestureDetector(
      onTap: () {
        if (_promotionMoveFrom != null && _promotionMoveTo != null) {
          _makeMove(_promotionMoveFrom!, _promotionMoveTo!, promotion: piece);
        }
      },
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryPurple.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Text(
              _getPieceSymbol(_playerColor[0] + piece),
              style: TextStyle(fontSize: 32),
            ),
            SizedBox(height: 4),
            Text(
              name,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPieceSymbol(String piece) {
    switch (piece) {
      case 'wp': return '♙';
      case 'wn': return '♘';
      case 'wb': return '♗';
      case 'wr': return '♖';
      case 'wq': return '♕';
      case 'wk': return '♔';
      case 'bp': return '♟';
      case 'bn': return '♞';
      case 'bb': return '♝';
      case 'br': return '♜';
      case 'bq': return '♛';
      case 'bk': return '♚';
      default: return '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChessGameModel?>(
      stream: _chessService.getGameStream(widget.gameId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            ),
          );
        }

        final game = snapshot.data;
        if (game == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'Game not found',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          );
        }

        _playerColor = game.getPlayerColor(widget.userId);
        _isMyTurn = game.isPlayerTurn(widget.userId);
        _timeLeft = game.getPlayerTimer(widget.userId);

        final opponentId = game.getOpponentId(widget.userId);
        final opponentName = opponentId != null 
            ? (game.playerNames[opponentId] ?? 'Opponent') 
            : 'Opponent';

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Top bar - Opponent info
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
                            backgroundImage: opponentId != null && game.playerAvatars.containsKey(opponentId)
                                ? NetworkImage(game.playerAvatars[opponentId]!)
                                : null,
                            child: opponentId == null || !game.playerAvatars.containsKey(opponentId)
                                ? Text(
                                    (opponentName)[0].toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      color: AppColors.primaryPurple,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opponentName,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _playerColor == 'white' ? 'Black pieces' : 'White pieces',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (opponentId != null)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.timer, size: 16, color: Colors.white70),
                                  SizedBox(width: 4),
                                  Text(
                                    '${(game.getPlayerTimer(opponentId) / 60).floor()}:${(game.getPlayerTimer(opponentId) % 60).toString().padLeft(2, '0')}',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Chess Board
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            margin: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.primaryPurple,
                                width: 2,
                              ),
                            ),
                            child: GridView.builder(
                              physics: NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 8,
                              ),
                              itemCount: 64,
                              itemBuilder: (context, index) {
                                int row = index ~/ 8;
                                int col = index % 8;
                                
                                // Flip board for black's perspective
                                if (_playerColor == 'black') {
                                  row = 7 - row;
                                  col = 7 - col;
                                }
                                
                                bool isLight = (row + col) % 2 == 0;
                                String piece = _board[row][col];
                                String square = '${String.fromCharCode(97 + col)}${8 - row}';
                                bool isSelected = _selectedSquare == square;
                                bool isValidMove = _validMoves.contains(square);

                                return GestureDetector(
                                  onTap: () => _onSquareTap(row, col, game),
                                  child: Container(
                                    color: isValidMove
                                        ? Colors.green.withOpacity(0.3)
                                        : (isLight ? Color(0xFFF0D9B5) : Color(0xFFB58863)),
                                    child: Stack(
                                      children: [
                                        if (piece.isNotEmpty)
                                          Center(
                                            child: Text(
                                              _getPieceSymbol(piece),
                                              style: TextStyle(
                                                fontSize: 32,
                                                color: piece.startsWith('w') ? Colors.white : Colors.black,
                                              ),
                                            ),
                                          ),
                                        if (isSelected)
                                          Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: AppColors.primaryPurple,
                                                width: 3,
                                              ),
                                            ),
                                          ),
                                        if (isValidMove && piece.isEmpty)
                                          Center(
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom bar - Player info
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
                            backgroundImage: game.playerAvatars.containsKey(widget.userId)
                                ? NetworkImage(game.playerAvatars[widget.userId]!)
                                : null,
                            child: !game.playerAvatars.containsKey(widget.userId)
                                ? Text(
                                    game.playerNames[widget.userId]![0].toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      color: AppColors.primaryPurple,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  game.playerNames[widget.userId]!,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _playerColor == 'white' ? 'White pieces' : 'Black pieces',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _timeLeft < 60 ? Colors.red.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: 16,
                                  color: _timeLeft < 60 ? Colors.red : Colors.white70,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${(_timeLeft / 60).floor()}:${(_timeLeft % 60).toString().padLeft(2, '0')}',
                                  style: GoogleFonts.poppins(
                                    color: _timeLeft < 60 ? Colors.red : Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Game Controls
                    if (game.isActive)
                      Container(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildControlButton(
                              icon: Icons.outbond,
                              label: 'Resign',
                              color: Colors.red,
                              onTap: _showResignDialog,
                            ),
                            _buildControlButton(
                              icon: Icons.sports_score,
                              label: game.drawOfferBy != null ? 'Draw Offered' : 'Offer Draw',
                              color: game.drawOfferBy != null ? Colors.orange : Colors.blue,
                              onTap: _handleDrawAction,
                            ),
                          ],
                        ),
                      ),

                    if (game.isCompleted)
                      Container(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              game.winnerId == widget.userId
                                  ? '🎉 You Won! +250 coins'
                                  : game.winnerId == null
                                      ? 'Game Drawn'
                                      : '😞 You Lost',
                              style: GoogleFonts.poppins(
                                color: game.winnerId == widget.userId
                                    ? Colors.green
                                    : game.winnerId == null
                                        ? Colors.orange
                                        : Colors.red,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildControlButton(
                                  icon: Icons.replay,
                                  label: 'Rematch',
                                  color: AppColors.primaryPurple,
                                  onTap: _handleRematchAction,
                                ),
                                _buildControlButton(
                                  icon: Icons.exit_to_app,
                                  label: 'Exit',
                                  color: Colors.grey,
                                  onTap: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                _buildPromotionDialog(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showResignDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A1A1A),
        title: Text(
          'Resign Game?',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to resign? Your opponent will win.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Resign', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _chessService.resignGame(widget.gameId, widget.userId);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDrawAction() async {
    final game = await _chessService.getGameStream(widget.gameId).first;
    if (game == null) return;

    if (game.drawOfferBy != null) {
      if (game.drawOfferBy != widget.userId) {
        // Accept draw
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Color(0xFF1A1A1A),
            title: Text(
              'Accept Draw?',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Your opponent offered a draw. Accept?',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Decline', style: GoogleFonts.poppins(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text('Accept', style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await _chessService.acceptDraw(widget.gameId, widget.userId);
        } else {
          await _chessService.declineDraw(widget.gameId);
        }
      }
    } else {
      // Offer draw
      await _chessService.offerDraw(widget.gameId, widget.userId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Draw offer sent'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _handleRematchAction() async {
    final game = await _chessService.getGameStream(widget.gameId).first;
    if (game == null) return;

    if (game.rematchOfferBy != null) {
      if (game.rematchOfferBy != widget.userId) {
        // Accept rematch
        final newGame = await _chessService.acceptRematch(widget.gameId, widget.userId);
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChessGameScreen(
              gameId: newGame.id,
              userId: widget.userId,
            ),
          ),
        );
      }
    } else {
      // Offer rematch
      await _chessService.offerRematch(widget.gameId, widget.userId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rematch offer sent'),
          backgroundColor: AppColors.primaryPurple,
        ),
      );
    }
  }
}