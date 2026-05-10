import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Color;
import 'package:flutter/material.dart' as material;
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:stockfish/stockfish.dart';
import 'board_editor_page.dart';
import 'game_storage.dart';
import 'main_menu_page.dart';
import 'sound_service.dart';

// Global constants for theming
const material.Color kDarkBg = material.Color(0xFF262522);
const material.Color kLightBg = material.Color(0xFFF5F5F5);
const material.Color kPageBg = material.Color(0xFFF8F9FA);
const material.Color kGreen = material.Color(0xFF69946B); // Softer green
const material.Color kRed = material.Color(0xFFC37B76);   // Softer red
const material.Color kGrey = material.Color(0xFF757575);
const material.Color kArrowGreen = material.Color(0xFF66BB6A);
const material.Color kArrowBorder = material.Color(0xFF2E7D32);

void main() {
  // Register Stockfish GPL-3.0 license notice
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['Stockfish'],
      'Stockfish, a UCI chess engine\n'
      'Copyright (C) 2004-2024 The Stockfish developers\n\n'
      'Licensed under the GNU General Public License v3.0\n'
      'https://github.com/official-stockfish/Stockfish',
    );
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chesspector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kDarkBg,
        scaffoldBackgroundColor: kPageBg,
      ),
      home: const MainMenuPage(),
    );
  }
}

class ChessGame extends StatefulWidget {
  final String? initialFen;
  final String? initialScore; // Optional: if provided, skip initial analysis and use this score
  
  const ChessGame({super.key, this.initialFen, this.initialScore});

  @override
  State<ChessGame> createState() => _ChessGameState();
}

class _ChessGameState extends State<ChessGame> {
  late ChessBoardController controller;
  Stockfish? stockfish;
  String engineOutput = 'Engine not initialized';
  String bestMove = 'None';
  bool isEngineReady = false;
  bool isInitializing = true;
  bool isCalculating = false;
  int searchDepth = 15; // Default depth for engine move calculation
  int analysisDepth = 15; // Default depth for position score analysis
  int currentDepth = 0; // Current analysis depth during calculation
  String? selectedSquare; // Track selected square for tap-to-move
  String? lastMoveFrom; // Track last move for highlighting
  String? lastMoveTo;
  String positionScore = '0.00'; // Position evaluation score (always from White's perspective)
  bool? mateForWhite; // Track who wins in mate scenarios (true=White wins, false=Black wins, null=no mate)
  String? _currentAnalysisFen; // Track which FEN is being analyzed for proper score attribution
  bool _isExplicitMoveRequest = false; // True only when user clicks "Get Engine Move" button
  String? _bestMoveFen; // Track which FEN the bestMove was calculated for
  String? _gameOverMessage; // Shown when position is already terminal
  double _boardSize = 0; // Cached board size; avoids recomputation on keyboard show/hide

  @override
  void initState() {
    super.initState();
    controller = ChessBoardController();
    
    // Use initial score if provided (from saved game); skip auto-analysis
    if (widget.initialScore != null) {
      positionScore = widget.initialScore!;
      // Parse mate info from score string if it starts with '#'
      if (positionScore.startsWith('#')) {
        // Determine winner from sign (no sign means current player wins)
        final numericPart = positionScore.substring(1);
        final isPositive = !numericPart.startsWith('-');
        mateForWhite = isPositive;
      }
    }
    
    // Load initial FEN if provided (from image detection or saved game)
    if (widget.initialFen != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          controller.loadFen(widget.initialFen!);
        } catch (e) {
          debugPrint('Error loading FEN: $e');
        }
        _checkGameOver();
        setState(() {});
      });
    }
    
    _initializeStockfish();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Compute board size from screen width only; cache it so keyboard
    // show/hide (which changes viewInsets but not screen width) does
    // not force an expensive layout recomputation.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final newSize = screenWidth - 24; // 12px padding each side
    if (newSize != _boardSize) {
      _boardSize = newSize;
    }
  }

  /// Detect if the loaded position is already terminal and set a user-facing message
  void _checkGameOver() {
    if (controller.game.game_over) {
      if (controller.game.in_checkmate) {
        // The side whose turn it is has been checkmated → the other side wins
        final loser = controller.game.turn.name == 'WHITE' ? 'White' : 'Black';
        final winner = loser == 'White' ? 'Black' : 'White';
        _gameOverMessage = '$winner wins by checkmate';
        positionScore = winner == 'White' ? '+99.00' : '-99.00';
        mateForWhite = winner == 'White';
      } else if (controller.game.in_stalemate) {
        _gameOverMessage = 'Stalemate — Draw';
        positionScore = '0.00';
      } else if (controller.game.in_draw) {
        _gameOverMessage = 'Draw';
        positionScore = '0.00';
      } else {
        _gameOverMessage = 'Game Over';
      }
    } else {
      _gameOverMessage = null;
    }
  }

  // Custom tap handler for click-to-move functionality
  void onSquareTapped(String square) {
    if (controller.game.game_over) return; // no moves on terminated games
    // Get the piece at the tapped square
    final piece = controller.game.get(square);
    
    // If no square is selected yet
    if (selectedSquare == null) {
      // Only allow selecting pieces that match the current turn
      if (piece != null && piece.color == controller.game.turn) {
        setState(() {
          selectedSquare = square;
        });
      }
      return;
    }
    
    // If a square is already selected
    if (selectedSquare != null) {
      // If tapping the same square, deselect it
      if (selectedSquare == square) {
        setState(() {
          selectedSquare = null;
        });
        return;
      }
      
      // If tapping a piece of the same color, switch selection
      if (piece != null && piece.color == controller.game.turn) {
        setState(() {
          selectedSquare = square;
        });
        return;
      }
      
      // Check if this is a pawn promotion move
      // Library returns type as single char ("p") and color as "Color.WHITE"/"Color.BLACK"
      final movingPiece = controller.game.get(selectedSquare!);
      
      final isPromotion = movingPiece != null &&
          movingPiece.type.toString() == 'p' &&
          ((movingPiece.color.toString() == 'Color.WHITE' && square[1] == '8') ||
           (movingPiece.color.toString() == 'Color.BLACK' && square[1] == '1'));
      
      if (isPromotion) {
        _showPromotionDialog(selectedSquare!, square);
      } else {
        // Try to make a normal move
        final move = controller.game.move({'from': selectedSquare, 'to': square});
        
        if (move) {
          setState(() {
            lastMoveFrom = selectedSquare;
            lastMoveTo = square;
            selectedSquare = null;
            bestMove = 'None';
            _bestMoveFen = null;
            _checkGameOver();
            analyzePosition();
          });
          // Determine special move types
          final isCastle = (selectedSquare == 'e1' && square == 'g1') ||
              (selectedSquare == 'e1' && square == 'c1') ||
              (selectedSquare == 'e8' && square == 'g8') ||
              (selectedSquare == 'e8' && square == 'c8');
          if (isPromotion) {
            SoundService().playPromote();
          } else if (isCastle) {
            SoundService().playCastle();
          } else {
            final givesCheck = controller.game.in_check;
            if (givesCheck) {
              SoundService().playCheck();
            } else {
              SoundService().playNormal();
            }
          }
        } else {
          // Invalid move, just deselect
          setState(() {
            selectedSquare = null;
          });
        }
      }
    }
  }

  void _showPromotionDialog(String from, String to) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const material.Color(0xFF302E2B),
          title: const Text('Promote Pawn', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose a piece:', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPromotionOption('Queen', 'q', from, to),
                  _buildPromotionOption('Rook', 'r', from, to),
                  _buildPromotionOption('Bishop', 'b', from, to),
                  _buildPromotionOption('Knight', 'n', from, to),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromotionOption(String label, String piece, String from, String to) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _makePromotionMove(from, to, piece);
      },
      child: Container(
        width: 60,
        height: 70,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _getPieceSymbol(piece),
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }

  String _getPieceSymbol(String piece) {
    final isWhite = controller.game.turn.toString() == 'Color.WHITE';
    switch (piece) {
      case 'q':
        return isWhite ? '♕' : '♛';
      case 'r':
        return isWhite ? '♖' : '♜';
      case 'b':
        return isWhite ? '♗' : '♝';
      case 'n':
        return isWhite ? '♘' : '♞';
      default:
        return '';
    }
  }

  void _makePromotionMove(String from, String to, String promotion) {
    final move = controller.game.move({
      'from': from,
      'to': to,
      'promotion': promotion,
    });
    
    if (move) {
      setState(() {
        lastMoveFrom = from;
        lastMoveTo = to;
        selectedSquare = null;
        bestMove = 'None';
        _bestMoveFen = null;
        _checkGameOver();
        analyzePosition();
      });
    } else {
      setState(() {
        selectedSquare = null;
      });
    }
  }

  Future<void> _initializeStockfish() async {
    try {
      stockfish = Stockfish();
      
      // Set up stdout listener FIRST before any initialization
      stockfish!.stdout.listen((line) {
        if (!mounted) return;

        // Track whether any UI-visible state actually changed
        bool needsRebuild = false;
          
          // Parse best move - ONLY store if user explicitly requested via "Get Engine Move"
          // This matches chess.com behavior: score updates automatically, but best move
          // is only shown when user asks for it
          if (line.startsWith('bestmove')) {
            List<String> parts = line.split(' ');
            if (parts.length > 1) {
              // Only update bestMove if this was an explicit user request
              final wasExplicitRequest = _isExplicitMoveRequest;
              if (_isExplicitMoveRequest) {
                bestMove = parts[1];
                _bestMoveFen = _currentAnalysisFen;
              } else {
                // Background analysis — don't store move
              }
              isCalculating = false;
              currentDepth = 0;
              _isExplicitMoveRequest = false; // Reset the flag
              needsRebuild = true;

              // After an explicit move search finishes, refresh position score
              if (wasExplicitRequest) {
                Future.microtask(() => analyzePosition());
              }
            }
          }
          
          // Parse evaluation score and depth from info lines
          // Example: "info depth 20 score cp 145" means +1.45 for side to move
          // "info depth 20 score cp -230" means -2.30 for side to move
          // "info depth 20 score mate 3" means side to move can checkmate in 3
          // "info depth 20 score mate -3" means side to move gets checkmated in 3
          if (line.contains('info') && line.contains('depth') && line.contains('score')) {
            try {
              final parts = line.split(' ');
              
              // Extract current depth
              int parsedDepth = 0;
              final depthIndex = parts.indexOf('depth');
              if (depthIndex != -1 && depthIndex + 1 < parts.length) {
                parsedDepth = int.parse(parts[depthIndex + 1]);
              }

              // Update depth counter during explicit move calculation
              if (isCalculating) {
                currentDepth = parsedDepth;
              }

              // Save previous score to detect if it actually changed
              final prevScore = positionScore;
              final prevMate = mateForWhite;
              
              // CRITICAL: Determine whose turn it was for the position being analyzed
              // We MUST use the stored FEN, not the current game state (which may have changed)
              bool isWhiteTurnInAnalysis = true; // default
              if (_currentAnalysisFen != null) {
                final fenParts = _currentAnalysisFen!.split(' ');
                if (fenParts.length >= 2) {
                  isWhiteTurnInAnalysis = fenParts[1] == 'w';
                }
              }
              
              // Check for mate score first (higher priority than centipawns)
              final mateIndex = parts.indexOf('mate');
              if (mateIndex != -1 && mateIndex + 1 < parts.length) {
                final mateIn = int.parse(parts[mateIndex + 1]);
                if (mateIn > 0) {
                  mateForWhite = isWhiteTurnInAnalysis;
                  positionScore = '#$mateIn';
                } else {
                  mateForWhite = !isWhiteTurnInAnalysis;
                  positionScore = '#${mateIn.abs()}';
                }
              } else {
                // Extract centipawn score
                final cpIndex = parts.indexOf('cp');
                if (cpIndex != -1 && cpIndex + 1 < parts.length) {
                  int centipawns = int.parse(parts[cpIndex + 1]);
                  final whitePercentpawns = isWhiteTurnInAnalysis ? centipawns : -centipawns;
                  final score = (whitePercentpawns.abs() / 100.0).toStringAsFixed(2);
                  positionScore = whitePercentpawns >= 0 ? '+$score' : '-$score';
                  mateForWhite = null;
                }
              }

              // Only rebuild UI when score visibly changed, or during active calculation
              if (positionScore != prevScore || mateForWhite != prevMate || isCalculating) {
                needsRebuild = true;
              }
            } catch (e) {
              debugPrint('Error parsing score: $e');
            }
          }
          
                          // Check if engine is ready
                          if (line == 'readyok') {
                            isEngineReady = true;
                            engineOutput = 'Engine ready! Analyzing position...';
                            needsRebuild = true;
                            // Auto-analyze position only if no initial score was provided
                            // (i.e., not loading a saved game with pre-calculated score)
                            if (widget.initialScore == null) {
                              analyzePosition();
                            }
                          }

        // Only rebuild the widget tree when UI-visible state changed
        if (needsRebuild) {
          setState(() {});
        }
      });

      // Listen to state changes
      stockfish!.state.addListener(() {
        if (stockfish!.state.value.name == 'ready') {
          _sendUCICommands();
        }
      });
      
      setState(() {
        isInitializing = false;
      });
    } catch (e) {
      debugPrint('Error initializing Stockfish: $e');
      setState(() {
        engineOutput = 'Error: $e';
        isInitializing = false;
        isEngineReady = false;
      });
    }
  }

  void _sendUCICommands() {
    if (stockfish == null) return;
    
    stockfish!.stdin = 'uci';
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (stockfish != null) {
        stockfish!.stdin = 'isready';
      }
    });
  }

  void resetGame() {
    // Stop any ongoing analysis
    if (stockfish != null) {
      stockfish!.stdin = 'stop';
    }
    
    setState(() {
      controller.dispose();
      controller = ChessBoardController();
      bestMove = 'None';
      _bestMoveFen = null; // Clear the best move's position reference
      engineOutput = 'Game reset!';
      selectedSquare = null;
      lastMoveFrom = null;
      lastMoveTo = null;
      positionScore = '0.00';
      mateForWhite = null;
      _currentAnalysisFen = null;
      _isExplicitMoveRequest = false;
      _gameOverMessage = null;
      currentDepth = 0;
      isCalculating = false;
    });
    
    // Analyze starting position after state is reset (for score only)
    analyzePosition();
  }

  void stopCalculation() {
    if (stockfish != null && isCalculating) {
      stockfish!.stdin = 'stop';
      setState(() {
        isCalculating = false;
        currentDepth = 0;
        _isExplicitMoveRequest = false; // Reset flag when stopped
        engineOutput = 'Calculation stopped';
      });
    }
  }

  // Analyze current position (for score display)
  void analyzePosition() {
    if (!isEngineReady || stockfish == null || controller.game.game_over) {
      return;
    }

    // Never interrupt an explicit move search; score will refresh after it completes
    if (isCalculating) return;

    // Stop any previous background analysis to avoid conflicts
    stockfish!.stdin = 'stop';
    
    // Get current position in FEN and store it for score attribution
    // FEN format: "pieces turn castling en_passant halfmove fullmove"
    final fen = controller.game.fen;
    _currentAnalysisFen = fen;
    
    // Send position and start analysis
    stockfish!.stdin = 'position fen $fen';
    stockfish!.stdin = 'go depth $analysisDepth';
  }

  void getEngineMove() {
    if (!isEngineReady || stockfish == null) {
      setState(() {
        engineOutput = 'Engine not ready yet!';
      });
      return;
    }

    // Check if game is over
    if (controller.game.game_over) {
      setState(() {
        engineOutput = controller.game.in_checkmate 
            ? 'Game Over - Checkmate!' 
            : controller.game.in_stalemate
                ? 'Game Over - Stalemate!'
                : controller.game.in_draw
                    ? 'Game Over - Draw!'
                    : 'Game Over!';
      });
      return;
    }

    // Stop any previous analysis
    stockfish!.stdin = 'stop';
    
    // IMPORTANT: Mark this as an explicit user request for best move
    // This ensures the bestmove will be stored and displayed
    _isExplicitMoveRequest = true;
    
    // Clear previous best move since we're calculating a new one
    bestMove = 'None';
    
    // Get current position in FEN and store for score attribution
    final fen = controller.game.fen;
    _currentAnalysisFen = fen;
    
    // Send position to Stockfish
    stockfish!.stdin = 'position fen $fen';
    stockfish!.stdin = 'go depth $searchDepth';
    
    setState(() {
      isCalculating = true;
      currentDepth = 0;
      engineOutput = 'Analyzing position...';
    });
  }

  void makeEngineMove() {
    if (bestMove != 'None' && bestMove.isNotEmpty) {
      try {
        // Parse UCI move format (e.g., "e2e4")
        String from = bestMove.substring(0, 2);
        String to = bestMove.substring(2, 4);
        
        controller.makeMove(from: from, to: to);
        setState(() {
          engineOutput = 'Engine played: $bestMove';
          lastMoveFrom = from;
          lastMoveTo = to;
          selectedSquare = null;
          bestMove = 'None'; // Clear the old move so user must calculate again
          _bestMoveFen = null; // Invalidate for the new position
          // Analyze the new position (for score display only)
          analyzePosition();
        });
          // Play move sound
          SoundService().playNormal();
      } catch (e) {
        setState(() {
          engineOutput = 'Error making move: $e';
        });
      }
    }
  }

  // Check if we have a valid best move for the current position
  bool get hasBestMoveForCurrentPosition {
    return bestMove != 'None' && 
           bestMove.isNotEmpty && 
           _bestMoveFen != null && 
           _bestMoveFen == controller.game.fen;
  }

  @override
  void dispose() {
    controller.dispose();
    try {
      stockfish?.dispose();
    } catch (_) {}
    super.dispose();
  }

  /// Show a dialog for saving the current game position.
  void _showSaveGameDialog() {
    final titleController = TextEditingController();
    final fen = controller.game.fen;

    // Derive a default title from the turn and piece count
    final board = fen.split(' ').first;
    int totalPieces = 0;
    for (final c in board.runes) {
      final ch = String.fromCharCode(c);
      if ('PNBRQKpnbrqk'.contains(ch)) totalPieces++;
    }
    final turnLabel = controller.game.turn.name == 'WHITE' ? 'White' : 'Black';
    titleController.text = '$turnLabel to move • $totalPieces pieces';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const material.Color(0xFF302E2B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Save Game', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Give this position a name:',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                autofocus: true,
                maxLength: 40,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kGreen),
                  ),
                  counterStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  hintText: 'e.g. Sicilian Defence',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                await GameStorage.save(
                  fen: fen,
                  title: title,
                  score: positionScore,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Game saved', style: TextStyle(color: Colors.white)),
                    backgroundColor: kGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showDepthSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        int tempSearchDepth = searchDepth;
        int tempAnalysisDepth = analysisDepth;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: const BoxDecoration(
                color: material.Color(0xFF302E2B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.tune, color: Colors.white.withOpacity(0.7)),
                      const SizedBox(width: 10),
                      const Text(
                        'Engine Settings',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Move Search Depth Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Move Search Depth', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15, fontWeight: FontWeight.w600)),
                          Text('For best move calculation', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tempSearchDepth <= 10 ? 'Fast ($tempSearchDepth)' : tempSearchDepth <= 15 ? 'Balanced ($tempSearchDepth)' : 'Strong ($tempSearchDepth)',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.7), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: kGreen,
                      inactiveTrackColor: Colors.white.withOpacity(0.1),
                      trackHeight: 4.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18.0),
                    ),
                    child: Slider(
                      value: tempSearchDepth.toDouble(),
                      min: 5,
                      max: 25,
                      divisions: 20,
                      onChanged: (value) {
                        setSheetState(() {
                          tempSearchDepth = value.toInt();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('5', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3))),
                      Text('25', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3))),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Position Analysis Depth Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Analysis Depth', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15, fontWeight: FontWeight.w600)),
                          Text('For position score evaluation', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: kGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tempAnalysisDepth <= 10 ? 'Fast ($tempAnalysisDepth)' : tempAnalysisDepth <= 15 ? 'Balanced ($tempAnalysisDepth)' : 'Deep ($tempAnalysisDepth)',
                          style: TextStyle(fontWeight: FontWeight.w600, color: kGreen, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: kGreen,
                      inactiveTrackColor: Colors.white.withOpacity(0.1),
                      trackHeight: 4.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18.0),
                    ),
                    child: Slider(
                      value: tempAnalysisDepth.toDouble(),
                      min: 5,
                      max: 25,
                      divisions: 20,
                      onChanged: (value) {
                        setSheetState(() {
                          tempAnalysisDepth = value.toInt();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('5', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3))),
                      Text('25', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3))),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          searchDepth = tempSearchDepth;
                          analysisDepth = tempAnalysisDepth;
                        });
                        // Re-analyze position with new depth if game is active
                        if (!controller.game.game_over && isEngineReady) {
                          analyzePosition();
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                      ),
                      child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Parse best move into from/to square positions for arrow drawing
  Map<String, String>? get _parsedBestMove {
    if (!hasBestMoveForCurrentPosition || bestMove.length < 4) return null;
    return {
      'from': bestMove.substring(0, 2),
      'to': bestMove.substring(2, 4),
    };
  }

  @override
  Widget build(BuildContext context) {
    final boardSize = _boardSize; // Use cached value; immune to keyboard inset changes

    // Compute score display values
    String displayScore;
    String advantageText;
    bool isWhiteAdvantage;
    bool isEqual = false;

    if (positionScore.startsWith('#')) {
      if (mateForWhite == true) {
        displayScore = '+99.00';
        advantageText = 'White Advantage';
        isWhiteAdvantage = true;
      } else {
        displayScore = '-99.00';
        advantageText = 'Black Advantage';
        isWhiteAdvantage = false;
      }
    } else if (positionScore.startsWith('+')) {
      displayScore = positionScore;
      advantageText = 'White Advantage';
      isWhiteAdvantage = true;
    } else if (positionScore.startsWith('-')) {
      displayScore = positionScore;
      advantageText = 'Black Advantage';
      isWhiteAdvantage = false;
    } else {
      displayScore = positionScore;
      advantageText = 'Equal Position';
      isWhiteAdvantage = true;
      isEqual = true;
    }

    return Scaffold(
      backgroundColor: kDarkBg,
      resizeToAvoidBottomInset: false, // Prevent keyboard from forcing layout recomputation
      appBar: AppBar(
        title: const Text(
          'Analysis',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: 0.3),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const material.Color(0xFF1A1916),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            // Navigate back to board editor with current FEN position
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BoardEditorPage(
                  initialFen: controller.game.fen,
                  detectedPieceCounts: const {},
                ),
              ),
            );
          },
          tooltip: 'Edit Position',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded, size: 22),
            onPressed: _showSaveGameDialog,
            tooltip: 'Save Game',
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 22),
            onPressed: isCalculating ? null : _showDepthSettings,
            tooltip: 'Engine Settings',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: resetGame,
            tooltip: 'Reset Position',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
          children: [
            const SizedBox(height: 12),
            
            // Show game-over banner instead of eval bar when game is over
            if (_gameOverMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  width: boardSize,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: _gameOverMessage!.contains('Draw') || _gameOverMessage!.contains('Stalemate')
                        ? kGrey
                        : kGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _gameOverMessage!.contains('Draw') || _gameOverMessage!.contains('Stalemate')
                            ? Icons.handshake_rounded
                            : Icons.emoji_events_rounded,
                        color: Colors.white, size: 22,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _gameOverMessage!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  width: boardSize,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    color: isEqual
                        ? const material.Color(0xFF757575)
                        : isWhiteAdvantage
                            ? const material.Color(0xFF69946B)
                            : const material.Color(0xFFC37B76),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    if (!isEngineReady)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                    Text(
                      displayScore,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        advantageText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
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
                          controller: controller,
                          boardColor: BoardColor.brown,
                          boardOrientation: PlayerColor.white,
                          onMove: () {
                            setState(() {
                              bestMove = 'None';
                              _bestMoveFen = null;
                              _checkGameOver();
                            });
                            analyzePosition();
                          },
                        ),
                        // Tap overlay for move highlighting and selection
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
                            
                            final isLastMoveSquare = square == lastMoveFrom || square == lastMoveTo;
                            final isSelected = square == selectedSquare;
                            
                            final legalMoves = selectedSquare != null
                                ? controller.game.moves({'square': selectedSquare, 'verbose': true})
                                : [];
                            final isLegalMove = legalMoves.any((move) => move['to'] == square);
                            
                            return GestureDetector(
                              onTap: () => onSquareTapped(square),
                              child: Container(
                                decoration: BoxDecoration(
                                  // Radial gradient: transparent center → green edges
                                  // Keeps the piece clearly visible while framing the square
                                  gradient: isLastMoveSquare
                                      ? RadialGradient(
                                          colors: [
                                            Colors.green.withOpacity(0.0),
                                            Colors.green.withOpacity(0.08),
                                            Colors.green.withOpacity(0.45),
                                          ],
                                          stops: const [0.3, 0.55, 1.0],
                                        )
                                      : null,
                                  border: isSelected
                                      ? Border.all(color: Colors.amber, width: 3)
                                      : isLastMoveSquare
                                          ? Border.all(color: Colors.green.withOpacity(0.6), width: 2.5)
                                          : null,
                                ),
                                child: isLegalMove
                                    ? Center(
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.55),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                        // Best move arrow overlay (IgnorePointer so it doesn't block taps)
                        if (_parsedBestMove != null)
                          IgnorePointer(
                            child: CustomPaint(
                              size: Size(boardSize, boardSize),
                              painter: MoveArrowPainter(
                                fromSquare: _parsedBestMove!['from']!,
                                toSquare: _parsedBestMove!['to']!,
                                boardSize: boardSize,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Turn indicator + best move text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Turn indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: controller.game.turn.name == 'WHITE' ? Colors.white.withOpacity(0.1) : kDarkBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: controller.game.turn.name == 'WHITE' ? Colors.white : Colors.black,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          controller.game.turn.name == 'WHITE' ? 'White' : 'Black',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Best move display
                  if (hasBestMoveForCurrentPosition)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: kGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kGreen.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_forward_rounded, size: 16, color: kGreen),
                          const SizedBox(width: 4),
                          Text(
                            'Best: ${bestMove.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kGreen,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (isCalculating)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: kGreen,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Depth $currentDepth/$searchDepth',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Bottom action button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: (!isEngineReady || isCalculating) ? null : getEngineMove,
                        icon: isCalculating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Icon(Icons.psychology_rounded, size: 22),
                        label: Text(
                          isCalculating ? 'Thinking...' : 'Get Engine Move',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          disabledBackgroundColor: const material.Color(0xFF302E2B),
                        ),
                      ),
                    ),
                  ),
                  if (isCalculating) ...[
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      width: 52,
                      child: ElevatedButton(
                        onPressed: stopCalculation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kRed.withOpacity(0.2),
                          foregroundColor: kRed,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(Icons.stop_rounded, size: 26),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

/// Draws a green semi-transparent arrow on the board from one square to another
class MoveArrowPainter extends CustomPainter {
  final String fromSquare;
  final String toSquare;
  final double boardSize;

  MoveArrowPainter({
    required this.fromSquare,
    required this.toSquare,
    required this.boardSize,
  });

  Offset _squareToCenter(String square) {
    final col = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final row = int.parse(square[1]) - 1;
    final squareSize = boardSize / 8;
    // Board oriented white at bottom: rank 8 at top, rank 1 at bottom
    final x = (col + 0.5) * squareSize;
    final y = (7 - row + 0.5) * squareSize;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final from = _squareToCenter(fromSquare);
    final to = _squareToCenter(toSquare);

    final squareSize = boardSize / 8;
    final arrowWidth = squareSize * 0.28;
    final headLength = squareSize * 0.55;
    final headWidth = squareSize * 0.5;

    // Calculate direction
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final length = (Offset(dx, dy)).distance;
    if (length < 1) return;

    final ux = dx / length;
    final uy = dy / length;
    // Perpendicular
    final px = -uy;
    final py = ux;

    // Shorten start & end slightly so it doesn't overlap piece edges
    final shortenBy = squareSize * 0.15;
    final startX = from.dx + ux * shortenBy;
    final startY = from.dy + uy * shortenBy;
    final endX = to.dx - ux * shortenBy;
    final endY = to.dy - uy * shortenBy;

    // Arrow shaft end (where the head begins)
    final shaftEndX = endX - ux * headLength;
    final shaftEndY = endY - uy * headLength;

    final paint = Paint()
      ..color = kArrowGreen.withOpacity(0.75)
      ..style = PaintingStyle.fill;

    // Build arrow path
    final path = Path()
      // Shaft left side
      ..moveTo(startX + px * arrowWidth / 2, startY + py * arrowWidth / 2)
      ..lineTo(shaftEndX + px * arrowWidth / 2, shaftEndY + py * arrowWidth / 2)
      // Head left side
      ..lineTo(shaftEndX + px * headWidth / 2, shaftEndY + py * headWidth / 2)
      // Arrow tip
      ..lineTo(endX, endY)
      // Head right side
      ..lineTo(shaftEndX - px * headWidth / 2, shaftEndY - py * headWidth / 2)
      // Shaft right side
      ..lineTo(shaftEndX - px * arrowWidth / 2, shaftEndY - py * arrowWidth / 2)
      ..lineTo(startX - px * arrowWidth / 2, startY - py * arrowWidth / 2)
      ..close();

    // Draw shadow
    canvas.drawPath(
      path.shift(const Offset(1, 1)),
      Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..style = PaintingStyle.fill,
    );

    // Draw arrow
    canvas.drawPath(path, paint);

    // Thin border
    canvas.drawPath(
      path,
      Paint()
        ..color = kArrowBorder.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant MoveArrowPainter oldDelegate) {
    return oldDelegate.fromSquare != fromSquare ||
        oldDelegate.toSquare != toSquare ||
        oldDelegate.boardSize != boardSize;
  }
}
