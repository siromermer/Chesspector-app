import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'main.dart';

/// Board Editor Page
/// Allows user to verify and edit the detected chess position before analysis
class BoardEditorPage extends StatefulWidget {
  final String? initialFen;
  final Map<String, int> detectedPieceCounts;

  const BoardEditorPage({
    super.key,
    this.initialFen,
    required this.detectedPieceCounts,
  });

  @override
  State<BoardEditorPage> createState() => _BoardEditorPageState();
}

class _BoardEditorPageState extends State<BoardEditorPage> {
  late ChessBoardController _controller;
  String? _selectedPiece;
  bool _isEraseMode = false;
  String _currentTurn = 'w';

  // Piece palette
  static const List<String> whitePieces = ['K', 'Q', 'R', 'B', 'N', 'P'];
  static const List<String> blackPieces = ['k', 'q', 'r', 'b', 'n', 'p'];

  @override
  void initState() {
    super.initState();
    _controller = ChessBoardController();
    
    // Load initial FEN if valid, otherwise start with empty board
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialPosition();
    });
  }

  void _loadInitialPosition() {
    if (widget.initialFen != null && widget.initialFen!.isNotEmpty) {
      try {
        _controller.loadFen(widget.initialFen!);
        setState(() {});
      } catch (e) {
        debugPrint('Invalid FEN, starting with empty board: $e');
        _clearBoard();
      }
    } else {
      _clearBoard();
    }
  }

  void _clearBoard() {
    // Load empty board FEN - need at least both kings for a valid position
    // Start with just the two kings in their standard positions
    _controller.loadFen('4k3/8/8/8/8/8/8/4K3 w - - 0 1');
    setState(() {});
  }

  void _resetToStandard() {
    // Standard starting position - castling available in standard position
    _controller.loadFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    setState(() {});
  }

  void _onSquareTapped(String square) {
    if (_isEraseMode) {
      // Remove piece from square
      _removePiece(square);
    } else if (_selectedPiece != null) {
      // Block placing pawns on rank 1 or rank 8
      final rank = int.parse(square[1]);
      if (_selectedPiece!.toLowerCase() == 'p' && (rank == 1 || rank == 8)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Pawns cannot be placed on the first or last rank')),
              ],
            ),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      // Place selected piece on square
      _placePiece(square, _selectedPiece!);
    }
  }

  void _placePiece(String square, String piece) {
    // Get current FEN, modify it, reload
    final fen = _controller.game.fen;
    final newFen = _modifyFen(fen, square, piece);
    try {
      _controller.loadFen(newFen);
      setState(() {});
    } catch (e) {
      debugPrint('Error placing piece: $e');
    }
  }

  void _removePiece(String square) {
    final fen = _controller.game.fen;
    final newFen = _modifyFen(fen, square, null);
    try {
      _controller.loadFen(newFen);
      setState(() {});
    } catch (e) {
      debugPrint('Error removing piece: $e');
    }
  }

  String _modifyFen(String fen, String square, String? piece) {
    // Parse square (e.g., "e4" -> col=4, row=4)
    final col = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final row = 8 - int.parse(square[1]);

    // Parse FEN board part
    final parts = fen.split(' ');
    final boardPart = parts[0];
    final rows = boardPart.split('/');

    // Expand each row to 8 characters
    List<String> expandedRows = rows.map((r) {
      StringBuffer sb = StringBuffer();
      for (int i = 0; i < r.length; i++) {
        final c = r[i];
        if (c.codeUnitAt(0) >= '1'.codeUnitAt(0) && c.codeUnitAt(0) <= '8'.codeUnitAt(0)) {
          sb.write('.' * int.parse(c));
        } else {
          sb.write(c);
        }
      }
      return sb.toString();
    }).toList();

    // Modify the specific square
    final rowChars = expandedRows[row].split('');
    rowChars[col] = piece ?? '.';
    expandedRows[row] = rowChars.join();

    // Compress back to FEN format
    List<String> compressedRows = expandedRows.map((r) {
      StringBuffer sb = StringBuffer();
      int emptyCount = 0;
      for (int i = 0; i < r.length; i++) {
        if (r[i] == '.') {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            sb.write(emptyCount);
            emptyCount = 0;
          }
          sb.write(r[i]);
        }
      }
      if (emptyCount > 0) {
        sb.write(emptyCount);
      }
      return sb.toString();
    }).toList();

    // Reconstruct FEN with no castling (since we're editing arbitrary positions)
    parts[0] = compressedRows.join('/');
    parts[1] = _currentTurn;
    parts[2] = '-';  // No castling for edited positions
    parts[3] = '-';  // No en passant
    return parts.join(' ');
  }

  /// Check if the board has pawns on rank 1 or rank 8 (illegal — must promote)
  String? _findPawnOnLastRank() {
    final fen = _controller.game.fen;
    final boardPart = fen.split(' ')[0];
    final rows = boardPart.split('/');

    // rows[0] = rank 8, rows[7] = rank 1
    // Rank 8: no white or black pawns allowed
    if (rows[0].contains('P') || rows[0].contains('p')) {
      return 'rank 8';
    }
    // Rank 1: no white or black pawns allowed
    if (rows[7].contains('P') || rows[7].contains('p')) {
      return 'rank 1';
    }
    return null; // valid
  }

  /// Validate king counts on the board
  /// Returns error message if invalid, null if valid
  String? _validateKings() {
    final fen = _controller.game.fen;
    final boardPart = fen.split(' ')[0];
    
    // Count white and black kings
    final whiteKingCount = boardPart.split('K').length - 1;
    final blackKingCount = boardPart.split('k').length - 1;

    if (whiteKingCount == 0 && blackKingCount == 0) {
      return 'Both kings are missing. Please place a White King (♔) and a Black King (♚) on the board.';
    }
    if (whiteKingCount == 0) {
      return 'White King is missing. Please place a White King (♔) on the board.';
    }
    if (blackKingCount == 0) {
      return 'Black King is missing. Please place a Black King (♚) on the board.';
    }
    if (whiteKingCount > 1) {
      return 'Multiple White Kings detected ($whiteKingCount). Each side must have exactly one king.';
    }
    if (blackKingCount > 1) {
      return 'Multiple Black Kings detected ($blackKingCount). Each side must have exactly one king.';
    }

    return null; // valid
  }

  /// Validate that the side that just moved didn't leave their own king in check
  /// Uses _currentTurn (user-selected turn) to determine whose turn it is.
  /// If it's White's turn, Black (who just moved) cannot have left their king in check.
  /// If it's Black's turn, White (who just moved) cannot have left their king in check.
  /// Returns error message if invalid, null if valid
  String? _validateOpponentKingNotInCheck() {
    try {
      final fen = _controller.game.fen;
      final parts = fen.split(' ');
      
      // Use the user-selected turn (_currentTurn), not the FEN's turn field
      final currentTurn = _currentTurn; // 'w' or 'b'
      
      // Switch turn to see if the side that just moved left their own king in check
      final previousPlayerTurn = currentTurn == 'w' ? 'b' : 'w';
      final tempFen = '${parts[0]} $previousPlayerTurn ${parts[2]} ${parts[3]} ${parts[4]} ${parts[5]}';
      
      // Load position with previous player's turn
      final tempController = ChessBoardController();
      tempController.loadFen(tempFen);
      
      // If the previous player is in check on their own turn, they left their king in check
      // This is illegal - you cannot make a move that leaves your own king in check
      if (tempController.game.in_check) {
        final previousPlayerColor = previousPlayerTurn == 'w' ? 'White' : 'Black';
        final currentPlayerColor = currentTurn == 'w' ? 'White' : 'Black';
        tempController.dispose();
        return 'Invalid position: $previousPlayerColor King is in check, but it\'s $currentPlayerColor\'s turn. This means $previousPlayerColor left their own king in check (illegal move).';
      }
      
      tempController.dispose();
      return null; // valid
    } catch (e) {
      return 'Invalid position: ${e.toString()}';
    }
  }

  void _confirmAndAnalyze() {
    // Validate kings (exactly one of each color)
    final kingError = _validateKings();
    if (kingError != null) {
      _showValidationWarning(
        'Invalid King Configuration',
        kingError,
      );
      return;
    }

    // Validate no pawns on rank 1 or rank 8 (they must promote)
    final pawnRank = _findPawnOnLastRank();
    if (pawnRank != null) {
      _showValidationWarning(
        'Pawn on $pawnRank is not allowed',
        'In chess, pawns reaching the last rank must be promoted to another piece (Queen, Rook, Bishop, or Knight). Please replace the pawn.',
      );
      return;
    }

    // Validate opponent's king is not in check
    final opponentCheckError = _validateOpponentKingNotInCheck();
    if (opponentCheckError != null) {
      _showValidationWarning(
        'Illegal Position',
        opponentCheckError,
      );
      return;
    }

    final rawFen = _controller.game.fen;
    final fenParts = rawFen.split(' ');
    fenParts[1] = _currentTurn;
    final fen = fenParts.join(' ');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChessGame(initialFen: fen),
      ),
    );
  }

  void _showValidationWarning(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ui.Color(0xFF302E2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.warning_amber_rounded, color: Colors.orange[400], size: 40),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        content: Text(message, style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Got it', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.orange[400])),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boardSize = MediaQuery.of(context).size.width - 24;
    
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        title: const Text(
          'Edit Position',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: ui.Color(0xFF1A1916),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 22),
            onPressed: _clearBoard,
            tooltip: 'Clear Board',
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, size: 22),
            onPressed: _resetToStandard,
            tooltip: 'Standard Position',
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          if (widget.detectedPieceCounts.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: kGreen.withOpacity(0.15),
              child: Row(
                children: [
                  Icon(Icons.auto_fix_high_rounded, color: kGreen, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.detectedPieceCounts.values.fold(0, (a, b) => a + b)} pieces detected. Tap squares to edit.',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          // Chess board
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: boardSize,
                  height: boardSize,
                  child: Stack(
                    children: [
                      ChessBoard(
                        controller: _controller,
                        boardColor: BoardColor.brown,
                        boardOrientation: PlayerColor.white,
                        enableUserMoves: false,
                      ),
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                        ),
                        itemCount: 64,
                        itemBuilder: (context, index) {
                          final row = 7 - (index ~/ 8);
                          final col = index % 8;
                          final file = String.fromCharCode(97 + col);
                          final rank = (row + 1).toString();
                          final square = '$file$rank';
                          return GestureDetector(
                            onTap: () => _onSquareTapped(square),
                            child: Container(color: Colors.transparent),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Turn selector - compact row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Turn', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.6), fontSize: 14)),
                const SizedBox(width: 12),
                _buildTurnChip('White', 'w', Colors.white, Colors.grey[800]!),
                const SizedBox(width: 8),
                _buildTurnChip('Black', 'b', kDarkBg, Colors.white),
                const Spacer(),
                // Erase toggle
                Material(
                  color: _isEraseMode ? kRed.withOpacity(0.15) : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() {
                        _isEraseMode = !_isEraseMode;
                        if (_isEraseMode) _selectedPiece = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isEraseMode ? kRed.withOpacity(0.5) : Colors.white.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.backspace_rounded,
                            size: 16,
                            color: _isEraseMode ? kRed : Colors.white.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Erase',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isEraseMode ? kRed : Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Piece palette
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  // White pieces row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: whitePieces.map((p) => _buildPieceButton(p, true)).toList(),
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 8),
                  // Black pieces row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: blackPieces.map((p) => _buildPieceButton(p, false)).toList(),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Confirm button at bottom
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirmAndAnalyze,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text(
                  'Confirm & Analyze',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: kGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnChip(String label, String value, ui.Color bgColor, ui.Color textColor) {
    final isSelected = _currentTurn == value;
    return GestureDetector(
      onTap: () => setState(() => _currentTurn = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2)),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? textColor : Colors.white.withOpacity(0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildPieceButton(String piece, bool isWhite) {
    final isSelected = _selectedPiece == piece && !_isEraseMode;
    final pieceSymbol = _getPieceSymbol(piece);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPiece = piece;
          _isEraseMode = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: isSelected ? kGreen.withOpacity(0.2) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? kGreen : Colors.white.withOpacity(0.12),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: kGreen.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2)),
          ] : null,
        ),
        child: Center(
          child: Text(
            pieceSymbol,
            style: TextStyle(
              fontSize: 26,
              color: isWhite ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  String _getPieceSymbol(String piece) {
    switch (piece.toLowerCase()) {
      case 'k': return piece == 'K' ? '♔' : '♚';
      case 'q': return piece == 'Q' ? '♕' : '♛';
      case 'r': return piece == 'R' ? '♖' : '♜';
      case 'b': return piece == 'B' ? '♗' : '♝';
      case 'n': return piece == 'N' ? '♘' : '♞';
      case 'p': return piece == 'P' ? '♙' : '♙';
      default: return '?';
    }
  }
}
