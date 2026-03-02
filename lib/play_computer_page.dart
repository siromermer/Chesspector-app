import 'package:flutter/material.dart' hide Color;
import 'package:flutter/material.dart' as material;
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:stockfish/stockfish.dart';
import 'main.dart';
import 'game_storage.dart';
import 'sound_service.dart';

/// Setup screen where the user picks a side and engine depth, then
/// navigates to the actual game screen.
class PlayComputerSetupPage extends StatefulWidget {
  const PlayComputerSetupPage({super.key});

  @override
  State<PlayComputerSetupPage> createState() => _PlayComputerSetupPageState();
}

class _PlayComputerSetupPageState extends State<PlayComputerSetupPage> {
  bool _playAsWhite = true;
  int _depth = 10;

  String get _levelLabel {
    if (_depth <= 5) return 'Beginner';
    if (_depth <= 10) return 'Intermediate';
    if (_depth <= 15) return 'Advanced';
    if (_depth <= 20) return 'Expert';
    return 'Master';
  }

  String get _thinkingHint {
    if (_depth <= 5) return 'Instant moves';
    if (_depth <= 10) return '~1-2 seconds per move';
    if (_depth <= 15) return '~3-5 seconds per move';
    if (_depth <= 20) return '~10-20 seconds per move';
    return '~30+ seconds per move';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        title: const Text(
          'Play vs Stockfish',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: 0.3),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const material.Color(0xFF1A1916),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Side selection
              Text(
                'Choose Your Side',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSideOption(
                    label: 'White',
                    icon: '♔',
                    isSelected: _playAsWhite,
                    onTap: () => setState(() => _playAsWhite = true),
                  ),
                  const SizedBox(width: 20),
                  _buildSideOption(
                    label: 'Black',
                    icon: '♚',
                    isSelected: !_playAsWhite,
                    onTap: () => setState(() => _playAsWhite = false),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // Depth / difficulty selection
              Text(
                'Stockfish Strength',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Higher depth = stronger play but longer thinking time',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 24),

              // Level badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: kGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGreen.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      _levelLabel,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: kGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Depth $_depth  •  $_thinkingHint',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: kGreen,
                  inactiveTrackColor: Colors.white.withOpacity(0.1),
                  trackHeight: 4.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 18.0),
                ),
                child: Slider(
                  value: _depth.toDouble(),
                  min: 1,
                  max: 25,
                  divisions: 24,
                  onChanged: (v) => setState(() => _depth = v.toInt()),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3))),
                  Text('25', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3))),
                ],
              ),

              const Spacer(flex: 3),

              // Start button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayComputerGamePage(
                          playAsWhite: _playAsWhite,
                          engineDepth: _depth,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 26),
                  label: const Text(
                    'Start Game',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideOption({
    required String label,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isWhite = label == 'White';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 110,
        height: 120,
        decoration: BoxDecoration(
          color: isSelected ? kGreen.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? kGreen : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: TextStyle(
                fontSize: 42,
                color: isWhite ? Colors.white : Colors.grey[900],
                shadows: isWhite
                  ? [
                      Shadow(
                        offset: const Offset(0, 0),
                        blurRadius: 2.0,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ]
                  : [
                      Shadow(
                        offset: const Offset(0, 0),
                        blurRadius: 3.0,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? kGreen : Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The actual game screen: user plays against Stockfish.
class PlayComputerGamePage extends StatefulWidget {
  final bool playAsWhite;
  final int engineDepth;
  final String? initialFen;

  const PlayComputerGamePage({
    super.key,
    required this.playAsWhite,
    required this.engineDepth,
    this.initialFen,
  });

  @override
  State<PlayComputerGamePage> createState() => _PlayComputerGamePageState();
}

class _PlayComputerGamePageState extends State<PlayComputerGamePage> {
  late ChessBoardController controller;
  Stockfish? stockfish;
  bool isEngineReady = false;
  bool isEngineThinking = false;
  String? selectedSquare;
  String? lastMoveFrom;
  String? lastMoveTo;
  String positionScore = '0.00';
  bool? mateForWhite;
  String? _gameOverMessage;
  double _boardSize = 0;
  String? _currentAnalysisFen;
  String? _pendingMoveFen; // The FEN for which we are waiting for a bestmove

  // True when it is the computer's turn
  bool get isComputerTurn {
    final isWhiteTurn = controller.game.turn.name == 'WHITE';
    return widget.playAsWhite ? !isWhiteTurn : isWhiteTurn;
  }

  PlayerColor get boardOrientation =>
      widget.playAsWhite ? PlayerColor.white : PlayerColor.black;

  @override
  void initState() {
    super.initState();
    controller = ChessBoardController();
    if (widget.initialFen != null) {
      controller.loadFen(widget.initialFen!);
    }
    _initializeStockfish();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final newSize = screenWidth - 24;
    if (newSize != _boardSize) {
      _boardSize = newSize;
    }
  }

  void _checkGameOver() {
    if (controller.game.game_over) {
      if (controller.game.in_checkmate) {
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

  Future<void> _initializeStockfish() async {
    try {
      stockfish = Stockfish();

      stockfish!.stdout.listen((line) {
        if (!mounted) return;

        bool needsRebuild = false;

        if (line.startsWith('bestmove')) {
          final parts = line.split(' ');
          if (parts.length > 1 && isEngineThinking) {
            // Verify the bestmove is for the position we actually requested
            final currentFen = controller.game.fen;
            if (_pendingMoveFen != null && _pendingMoveFen != currentFen) {
              return;
            }
            final move = parts[1];
            _applyEngineMove(move);
          }
          return;
        }

        // Parse score from info lines
        if (line.contains('info') && line.contains('depth') && line.contains('score')) {
          try {
            final parts = line.split(' ');
            final prevScore = positionScore;
            final prevMate = mateForWhite;

            bool isWhiteTurnInAnalysis = true;
            if (_currentAnalysisFen != null) {
              final fenParts = _currentAnalysisFen!.split(' ');
              if (fenParts.length >= 2) {
                isWhiteTurnInAnalysis = fenParts[1] == 'w';
              }
            }

            final mateIndex = parts.indexOf('mate');
            if (mateIndex != -1 && mateIndex + 1 < parts.length) {
              final mateIn = int.parse(parts[mateIndex + 1]);
              mateForWhite = mateIn > 0 ? isWhiteTurnInAnalysis : !isWhiteTurnInAnalysis;
              positionScore = '#${mateIn.abs()}';
            } else {
              final cpIndex = parts.indexOf('cp');
              if (cpIndex != -1 && cpIndex + 1 < parts.length) {
                int centipawns = int.parse(parts[cpIndex + 1]);
                final wp = isWhiteTurnInAnalysis ? centipawns : -centipawns;
                final score = (wp.abs() / 100.0).toStringAsFixed(2);
                positionScore = wp >= 0 ? '+$score' : '-$score';
                mateForWhite = null;
              }
            }

            if (positionScore != prevScore || mateForWhite != prevMate) {
              needsRebuild = true;
            }
          } catch (_) {}
        }

        if (line == 'readyok') {
          isEngineReady = true;
          needsRebuild = true;
          // If computer plays first (user chose black), trigger engine move
          if (isComputerTurn && !controller.game.game_over) {
            Future.microtask(() => _requestEngineMove());
          }
        }

        if (needsRebuild) {
          setState(() {});
        }
      });

      stockfish!.state.addListener(() {
        if (stockfish!.state.value.name == 'ready') {
          stockfish!.stdin = 'uci';
          Future.delayed(const Duration(milliseconds: 500), () {
            stockfish?.stdin = 'isready';
          });
        }
      });

      setState(() {});
    } catch (e) {
      debugPrint('Error initializing Stockfish: $e');
    }
  }

  void _requestEngineMove() {
    if (!isEngineReady || stockfish == null || controller.game.game_over) return;

    stockfish!.stdin = 'stop';
    final fen = controller.game.fen;
    _currentAnalysisFen = fen;
    _pendingMoveFen = fen; // Track which position this move request is for

    stockfish!.stdin = 'position fen $fen';
    stockfish!.stdin = 'go depth ${widget.engineDepth}';

    setState(() {
      isEngineThinking = true;
    });
  }

  void _applyEngineMove(String uciMove) {
    if (!mounted) return;

    final from = uciMove.substring(0, 2);
    final to = uciMove.substring(2, 4);
    final promotion = uciMove.length > 4 ? uciMove.substring(4, 5) : null;

    final moveArgs = <String, dynamic>{'from': from, 'to': to};
    if (promotion != null) moveArgs['promotion'] = promotion;

    final success = controller.game.move(moveArgs);
    if (success) {
      setState(() {
        lastMoveFrom = from;
        lastMoveTo = to;
        selectedSquare = null;
        isEngineThinking = false;
        _pendingMoveFen = null;
        _checkGameOver();
      });
      // Determine special move types: castle, promotion, check
      final isCastle = (from == 'e1' && to == 'g1') ||
          (from == 'e1' && to == 'c1') ||
          (from == 'e8' && to == 'g8') ||
          (from == 'e8' && to == 'c8');
      if (promotion != null) {
        SoundService().playPromote();
      } else if (isCastle) {
        SoundService().playCastle();
      } else {
        // Normal move — check whether this move gives check
        final givesCheck = controller.game.in_check;
        if (givesCheck) {
          SoundService().playCheck();
        } else {
          SoundService().playNormal();
        }
      }
    } else {
      // Move was invalid (should not happen); reset thinking state and retry
      debugPrint('Engine move failed: $uciMove — requesting new move');
      setState(() {
        isEngineThinking = false;
        _pendingMoveFen = null;
      });
      if (!controller.game.game_over && isComputerTurn) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _requestEngineMove();
        });
      }
    }
  }

  // Human tap-to-move handler
  void onSquareTapped(String square) {
    if (controller.game.game_over) return;
    if (isComputerTurn) return; // Block taps during computer's turn
    if (isEngineThinking) return;

    final piece = controller.game.get(square);

    if (selectedSquare == null) {
      if (piece != null && piece.color == controller.game.turn) {
        setState(() => selectedSquare = square);
      }
      return;
    }

    // Deselect
    if (selectedSquare == square) {
      setState(() => selectedSquare = null);
      return;
    }

    // Switch selection to another own piece
    if (piece != null && piece.color == controller.game.turn) {
      setState(() => selectedSquare = square);
      return;
    }

    // Check promotion
    final movingPiece = controller.game.get(selectedSquare!);
    final isPromotion = movingPiece != null &&
        movingPiece.type.toString() == 'p' &&
        ((movingPiece.color.toString() == 'Color.WHITE' && square[1] == '8') ||
         (movingPiece.color.toString() == 'Color.BLACK' && square[1] == '1'));

    if (isPromotion) {
      _showPromotionDialog(selectedSquare!, square);
    } else {
      _tryHumanMove(selectedSquare!, square);
    }
  }

  void _tryHumanMove(String from, String to, {String? promotion}) {
    final moveArgs = <String, dynamic>{'from': from, 'to': to};
    if (promotion != null) moveArgs['promotion'] = promotion;

    final success = controller.game.move(moveArgs);
    if (success) {
      setState(() {
        lastMoveFrom = from;
        lastMoveTo = to;
        selectedSquare = null;
        _checkGameOver();
      });
      // Determine if this was a castle, promotion or check
      final isCastle = (from == 'e1' && to == 'g1') ||
          (from == 'e1' && to == 'c1') ||
          (from == 'e8' && to == 'g8') ||
          (from == 'e8' && to == 'c8');
      if (promotion != null) {
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
      // Trigger computer's reply
      if (!controller.game.game_over) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _requestEngineMove();
        });
      }
    } else {
      setState(() => selectedSquare = null);
    }
  }

  void _showPromotionDialog(String from, String to) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
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
    final isWhite = controller.game.turn.toString() == 'Color.WHITE';
    String symbol;
    switch (piece) {
      case 'q': symbol = isWhite ? '♕' : '♛'; break;
      case 'r': symbol = isWhite ? '♖' : '♜'; break;
      case 'b': symbol = isWhite ? '♗' : '♝'; break;
      case 'n': symbol = isWhite ? '♘' : '♞'; break;
      default: symbol = '';
    }
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _tryHumanMove(from, to, promotion: piece);
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
            Text(symbol, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }

  void _showGameOverDialog() {
    if (_gameOverMessage == null) return;

    // Determine if user won, lost, or drew
    String title;
    IconData icon;
    material.Color iconColor;

    if (_gameOverMessage!.contains('Draw') || _gameOverMessage!.contains('Stalemate')) {
      title = 'Draw!';
      icon = Icons.handshake_rounded;
      iconColor = kGrey;
    } else {
      final whiteWon = _gameOverMessage!.startsWith('White');
      final userWon = widget.playAsWhite ? whiteWon : !whiteWon;
      title = userWon ? 'You Win!' : 'You Lose!';
      icon = userWon ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded;
      iconColor = userWon ? kGreen : kRed;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const material.Color(0xFF302E2B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            _gameOverMessage!,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: Text('Review Board', style: TextStyle(color: Colors.white.withOpacity(0.5))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _resetGame();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('New Game', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _resetGame() {
    if (stockfish != null) stockfish!.stdin = 'stop';

    setState(() {
      controller.dispose();
      controller = ChessBoardController();
      selectedSquare = null;
      lastMoveFrom = null;
      lastMoveTo = null;
      positionScore = '0.00';
      mateForWhite = null;
      _gameOverMessage = null;
      isEngineThinking = false;
      _currentAnalysisFen = null;
      _pendingMoveFen = null;
    });

    // If computer plays first, trigger its move
    if (isComputerTurn && isEngineReady) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _requestEngineMove();
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    try {
      stockfish?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boardSize = _boardSize;

    // Score display
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

    // Show game-over dialog once after state settles
    if (_gameOverMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _gameOverMessage != null) {
          _showGameOverDialog();
        }
      });
    }

  void _showSaveGameDialog() {
    final titleController = TextEditingController();
    final fen = controller.game.fen;

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
          title: const Text('Save Game',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              child: Text('Cancel',
                  style: TextStyle(color: Colors.white.withOpacity(0.5))),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                await GameStorage.save(
                  fen: fen,
                  title: title,
                  score: positionScore,
                  moveCount: controller.game.history.length,
                  gameMode: 'play-computer',
                  playerSide: widget.playAsWhite,
                  engineDepth: widget.engineDepth,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Game saved',
                        style: TextStyle(color: Colors.white)),
                    backgroundColor: kGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

    return Scaffold(
      backgroundColor: kDarkBg,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_rounded, size: 20),
            const SizedBox(width: 8),
            const Text(
              'vs Stockfish',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: 0.3),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Depth ${widget.engineDepth}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const material.Color(0xFF1A1916),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add_rounded, size: 22),
            onPressed: _showSaveGameDialog,
            tooltip: 'Save Game',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _resetGame,
            tooltip: 'New Game',
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
                          ? kGrey
                          : isWhiteAdvantage
                              ? kGreen
                              : kRed,
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
                            boardOrientation: boardOrientation,
                            onMove: () {
                              // Drag-and-drop moves from the library itself
                              setState(() {
                                _checkGameOver();
                              });
                              if (!controller.game.game_over && isComputerTurn) {
                                Future.delayed(const Duration(milliseconds: 200), () {
                                  if (mounted) _requestEngineMove();
                                });
                              }
                            },
                          ),
                          // Tap overlay
                          GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 8,
                            ),
                            itemCount: 64,
                            itemBuilder: (context, index) {
                              // Map index to square depending on board orientation
                              int row, col;
                              if (widget.playAsWhite) {
                                row = 7 - (index ~/ 8);
                                col = index % 8;
                              } else {
                                row = index ~/ 8;
                                col = 7 - (index % 8);
                              }
                              final file = String.fromCharCode(97 + col);
                              final rank = (row + 1).toString();
                              final square = '$file$rank';

                              final isLastMoveSquare = square == lastMoveFrom || square == lastMoveTo;
                              final isSelected = square == selectedSquare;

                              final legalMoves = selectedSquare != null
                                  ? controller.game.moves({'square': selectedSquare, 'verbose': true})
                                  : [];
                              final isLegalMove = legalMoves.any((m) => m['to'] == square);

                              return GestureDetector(
                                onTap: () => onSquareTapped(square),
                                child: Container(
                                  decoration: BoxDecoration(
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Status bar: turn indicator + thinking indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Turn indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: controller.game.turn.name == 'WHITE'
                            ? Colors.white.withOpacity(0.1)
                            : kDarkBg,
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
                    if (isEngineThinking)
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: kGreen),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Thinking...',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ),
                    if (!isEngineThinking && _gameOverMessage == null && isEngineReady)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: kGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isComputerTurn ? 'Stockfish\'s turn' : 'Your turn',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kGreen),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // New Game button at bottom
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Go back to setup page
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const PlayComputerSetupPage()),
                      );
                    },
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    label: const Text(
                      'Change Settings',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const material.Color(0xFF302E2B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
