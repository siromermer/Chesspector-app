import 'package:flutter/material.dart' hide Color;
import 'package:flutter/material.dart' as material show Color;
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:stockfish/stockfish.dart';
import 'main.dart';
import 'pgn_parser.dart';
import 'sound_service.dart';

class GameViewerPage extends StatefulWidget {
  final MasterGame game;

  const GameViewerPage({super.key, required this.game});

  @override
  State<GameViewerPage> createState() => _GameViewerPageState();
}

class _GameViewerPageState extends State<GameViewerPage> {
  late ChessBoardController _controller;
  int _currentMoveIndex = 0;

  // Engine state
  Stockfish? _stockfish;
  bool _engineReady = false;
  bool _engineEnabled = false;
  int _analysisDepth = 15;
  String _positionScore = '0.00';
  bool? _mateForWhite;
  String? _currentAnalysisFen;
  String? _pendingAnalysisFen; // the FEN we're currently waiting results for

  // Cache: FEN (position only, no move counters) → {score, mateForWhite}
  final Map<String, _CachedScore> _scoreCache = {};

  @override
  void initState() {
    super.initState();
    _controller = ChessBoardController();
    _controller.loadFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
  }

  // ── Stockfish lifecycle ──────────────────────────────────────────────

  void _startEngine() {
    if (_stockfish != null) return;
    try {
      _stockfish = Stockfish();
      _stockfish!.stdout.listen((line) {
        if (!mounted) return;
        bool needsRebuild = false;

        if (line.contains('info') && line.contains('depth') && line.contains('score')) {
          // Discard results if they're for a position we're no longer viewing
          final activeFen = _controller.game.fen;
          if (_pendingAnalysisFen != null && _pendingAnalysisFen != activeFen) return;

          try {
            final parts = line.split(' ');
            bool isWhiteTurnInAnalysis = true;
            if (_currentAnalysisFen != null) {
              final fenParts = _currentAnalysisFen!.split(' ');
              if (fenParts.length >= 2) isWhiteTurnInAnalysis = fenParts[1] == 'w';
            }

            String newScore = _positionScore;
            bool? newMate = _mateForWhite;

            final mateIndex = parts.indexOf('mate');
            if (mateIndex != -1 && mateIndex + 1 < parts.length) {
              final mateIn = int.parse(parts[mateIndex + 1]);
              newMate = mateIn > 0 ? isWhiteTurnInAnalysis : !isWhiteTurnInAnalysis;
              newScore = '#${mateIn.abs()}';
            } else {
              final cpIndex = parts.indexOf('cp');
              if (cpIndex != -1 && cpIndex + 1 < parts.length) {
                int cp = int.parse(parts[cpIndex + 1]);
                final whiteCp = isWhiteTurnInAnalysis ? cp : -cp;
                final score = (whiteCp.abs() / 100.0).toStringAsFixed(2);
                newScore = whiteCp >= 0 ? '+$score' : '-$score';
                newMate = null;
              }
            }

            if (newScore != _positionScore || newMate != _mateForWhite) {
              _positionScore = newScore;
              _mateForWhite = newMate;
              // Cache the result for this position
              final cacheKey = _fenPositionKey(activeFen);
              _scoreCache[cacheKey] = _CachedScore(newScore, newMate);
              needsRebuild = true;
            }
          } catch (_) {}
        }

        if (line == 'readyok') {
          _engineReady = true;
          needsRebuild = true;
          _analyzeCurrentPosition();
        }

        if (needsRebuild) setState(() {});
      });

      _stockfish!.state.addListener(() {
        if (_stockfish != null && _stockfish!.state.value.name == 'ready') {
          _stockfish!.stdin = 'uci';
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_stockfish != null) _stockfish!.stdin = 'isready';
          });
        }
      });
    } catch (e) {
      debugPrint('Error starting Stockfish: $e');
    }
  }

  /// Strip move counters from FEN so transpositions share the same cache entry.
  String _fenPositionKey(String fen) {
    final parts = fen.split(' ');
    if (parts.length >= 4) return parts.sublist(0, 4).join(' ');
    return fen;
  }

  void _stopEngine() {
    try {
      _stockfish?.dispose();
    } catch (_) {}
    _stockfish = null;
    _engineReady = false;
    _positionScore = '0.00';
    _mateForWhite = null;
    _currentAnalysisFen = null;
    _pendingAnalysisFen = null;
  }

  void _analyzeCurrentPosition() {
    if (!_engineReady || _stockfish == null || !_engineEnabled) return;

    final fen = _controller.game.fen;
    _currentAnalysisFen = fen;

    // Use cached score immediately if available
    final cacheKey = _fenPositionKey(fen);
    final cached = _scoreCache[cacheKey];
    if (cached != null) {
      setState(() {
        _positionScore = cached.score;
        _mateForWhite = cached.mateForWhite;
      });
    }

    // Always run fresh analysis (may refine cached result at higher depth)
    _stockfish!.stdin = 'stop';
    _pendingAnalysisFen = fen;
    _stockfish!.stdin = 'position fen $fen';
    _stockfish!.stdin = 'go depth $_analysisDepth';
  }

  void _toggleEngine() {
    setState(() {
      _engineEnabled = !_engineEnabled;
      if (_engineEnabled) {
        _startEngine();
        if (_engineReady) _analyzeCurrentPosition();
      } else {
        _stopEngine();
      }
    });
  }

  // ── Move navigation ──────────────────────────────────────────────────

  void _nextMove() {
    if (_currentMoveIndex >= widget.game.sanMoves.length) return;
    final san = widget.game.sanMoves[_currentMoveIndex];
    final ok = _controller.game.move(san);
    if (ok) {
      setState(() => _currentMoveIndex++);
      _analyzeCurrentPosition();
      // Determine if this move is check/castle/promotion
      // We only have SAN here; simple heuristic: check for '+' (check), 'O-O' (castle), '=' (promotion)
      final sanStr = san;
      if (sanStr.contains('O-O')) {
        SoundService().playCastle();
      } else if (sanStr.contains('+')) {
        SoundService().playCheck();
      } else if (sanStr.contains('=')) {
        SoundService().playPromote();
      } else {
        SoundService().playNormal();
      }
    }
  }

  void _prevMove() {
    if (_currentMoveIndex <= 0) return;
    _controller.game.undo_move();
    setState(() => _currentMoveIndex--);
    _analyzeCurrentPosition();
  }

  void _goToStart() {
    while (_currentMoveIndex > 0) {
      _controller.game.undo_move();
      _currentMoveIndex--;
    }
    setState(() {});
    _analyzeCurrentPosition();
  }

  void _goToEnd() {
    while (_currentMoveIndex < widget.game.sanMoves.length) {
      final san = widget.game.sanMoves[_currentMoveIndex];
      if (_controller.game.move(san)) {
        _currentMoveIndex++;
        // Determine sound by SAN heuristics
        final sanStr = san;
        if (sanStr.contains('O-O')) {
          SoundService().playCastle();
        } else if (sanStr.contains('+')) {
          SoundService().playCheck();
        } else if (sanStr.contains('=')) {
          SoundService().playPromote();
        } else {
          SoundService().playNormal();
        }
      } else {
        break;
      }
    }
    setState(() {});
    _analyzeCurrentPosition();
  }

  // ── Depth settings modal ─────────────────────────────────────────────

  void _showDepthSettings() {
    int tempDepth = _analysisDepth;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(children: [
                    Icon(Icons.tune, color: Colors.white.withOpacity(0.7)),
                    const SizedBox(width: 10),
                    const Text('Engine Settings',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ]),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Analysis Depth',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15, fontWeight: FontWeight.w600)),
                        Text('Higher = slower but more accurate',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: kGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tempDepth <= 10 ? 'Fast ($tempDepth)' : tempDepth <= 15 ? 'Balanced ($tempDepth)' : 'Deep ($tempDepth)',
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
                      value: tempDepth.toDouble(), min: 5, max: 25, divisions: 20,
                      onChanged: (v) => setSheetState(() => tempDepth = v.toInt()),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('5', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3))),
                    Text('25', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3))),
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _analysisDepth = tempDepth);
                        if (_engineEnabled && _engineReady) _analyzeCurrentPosition();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen, foregroundColor: Colors.white,
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

  // ── Helpers ──────────────────────────────────────────────────────────

  String _formatDate(String date) {
    if (date.isEmpty || date == '????.??.??') return '';
    final parts = date.split('.');
    if (parts.length >= 1 && parts[0].length == 4) return parts[0];
    return date;
  }

  bool get _isGameFinished => _currentMoveIndex >= widget.game.sanMoves.length;

  String? get _resultText {
    if (!_isGameFinished) return null;
    final r = widget.game.result;
    if (r == '1-0') return 'White wins';
    if (r == '0-1') return 'Black wins';
    if (r == '1/2-1/2') return 'Draw';
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    try {
      _stockfish?.dispose();
    } catch (_) {}
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final hasPrev = _currentMoveIndex > 0;
    final hasNext = _currentMoveIndex < game.sanMoves.length;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final boardSize = screenWidth - 24;

    final whiteElo = (game.whiteElo != null && game.whiteElo!.isNotEmpty) ? game.whiteElo! : null;
    final blackElo = (game.blackElo != null && game.blackElo!.isNotEmpty) ? game.blackElo! : null;

    final dateStr = _formatDate(game.date);
    final eventStr = game.event.isNotEmpty ? game.event : null;

    // Result banner
    material.Color? resultBg;
    material.Color? resultFg;
    String? resultLabel = _resultText;
    if (resultLabel != null) {
      if (game.result == '1-0') { resultBg = kGreen; resultFg = Colors.white; }
      else if (game.result == '0-1') { resultBg = kRed; resultFg = Colors.white; }
      else { resultBg = kGrey; resultFg = Colors.white; }
    }

    // Score display
    String displayScore = _positionScore;
    String advantageText = 'Equal';
    bool isWhiteAdvantage = true;
    bool isEqual = false;

    if (_positionScore.startsWith('#')) {
      if (_mateForWhite == true) {
        displayScore = '+99.00'; advantageText = 'White'; isWhiteAdvantage = true;
      } else {
        displayScore = '-99.00'; advantageText = 'Black'; isWhiteAdvantage = false;
      }
    } else if (_positionScore.startsWith('+')) {
      advantageText = 'White'; isWhiteAdvantage = true;
    } else if (_positionScore.startsWith('-')) {
      advantageText = 'Black'; isWhiteAdvantage = false;
    } else {
      isEqual = true;
    }

    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        title: Text(
          eventStr != null
              ? (dateStr.isNotEmpty ? '$eventStr, $dateStr' : eventStr)
              : (dateStr.isNotEmpty ? dateStr : 'Game'),
          style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: 0.3, color: Colors.white,
          ),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true, elevation: 0,
        backgroundColor: const material.Color(0xFF1A1916),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        actions: [
          if (_engineEnabled)
            IconButton(
              icon: const Icon(Icons.tune_rounded, size: 22),
              onPressed: _showDepthSettings,
              tooltip: 'Engine Settings',
            ),
          if (_engineEnabled)
            IconButton(
              icon: const Icon(Icons.psychology_rounded, size: 24, color: kGreen),
              onPressed: _toggleEngine,
              tooltip: 'Disable Engine',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Eval bar (only when engine is on)
              if (_engineEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Container(
                    width: boardSize,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isEqual
                          ? kGrey
                          : isWhiteAdvantage ? kGreen : kRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_engineReady)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),
                        Text(
                          _engineReady ? displayScore : '...',
                          style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _engineReady ? advantageText : 'Loading',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Black player bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _PlayerBar(
                  name: game.black, elo: blackElo, isWhite: false,
                  result: game.result, isGameFinished: _isGameFinished,
                ),
              ),

              const SizedBox(height: 6),

              // Board
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: boardSize, height: boardSize,
                      child: ChessBoard(
                        controller: _controller,
                        boardColor: BoardColor.brown,
                        boardOrientation: PlayerColor.white,
                        enableUserMoves: false,
                        size: boardSize,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // White player bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _PlayerBar(
                  name: game.white, elo: whiteElo, isWhite: true,
                  result: game.result, isGameFinished: _isGameFinished,
                ),
              ),

              const SizedBox(height: 10),

              // Result banner
              if (resultLabel != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    decoration: BoxDecoration(
                      color: resultBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          game.result == '1/2-1/2' ? Icons.handshake_rounded : Icons.emoji_events_rounded,
                          color: resultFg, size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(resultLabel,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: resultFg)),
                        const SizedBox(width: 6),
                        Text('(${game.result})',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: resultFg!.withOpacity(0.7))),
                      ],
                    ),
                  ),
                ),

              if (resultLabel != null) const SizedBox(height: 6),

              // Move counter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _currentMoveIndex == 0
                      ? 'Starting position'
                      : 'Move $_currentMoveIndex / ${game.sanMoves.length}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.5)),
                ),
              ),

              const SizedBox(height: 10),

              // Nav controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _NavButton(icon: Icons.skip_previous_rounded, onPressed: hasPrev ? _goToStart : null),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: hasPrev ? _prevMove : null,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Prev'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: hasPrev ? kGreen.withOpacity(0.6) : Colors.white.withOpacity(0.15)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasNext ? _nextMove : null,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('Next'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _NavButton(icon: Icons.skip_next_rounded, onPressed: hasNext ? _goToEnd : null),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Engine activation prompt when engine is off
              if (!_engineEnabled)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: _toggleEngine,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: kGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kGreen.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.psychology_rounded, size: 20, color: kGreen),
                          const SizedBox(width: 10),
                          Text(
                            'Enable Engine Analysis',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Player bar ─────────────────────────────────────────────────────────

class _PlayerBar extends StatelessWidget {
  final String name;
  final String? elo;
  final bool isWhite;
  final String result;
  final bool isGameFinished;

  const _PlayerBar({
    required this.name, required this.elo, required this.isWhite,
    required this.result, required this.isGameFinished,
  });

  bool get _isWinner {
    if (!isGameFinished) return false;
    return (isWhite && result == '1-0') || (!isWhite && result == '0-1');
  }

  bool get _isLoser {
    if (!isGameFinished) return false;
    return (isWhite && result == '0-1') || (!isWhite && result == '1-0');
  }

  String _displayName(String full) {
    final parts = full.split(RegExp(r',\s*'));
    if (parts.length >= 2) return '${parts[1]} ${parts[0]}';
    return full;
  }

  @override
  Widget build(BuildContext context) {
    final material.Color accentColor =
        _isWinner ? kGreen : _isLoser ? kRed : Colors.white.withOpacity(0.6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const material.Color(0xFF302E2B),
        borderRadius: BorderRadius.circular(8),
        border: _isWinner ? Border.all(color: kGreen.withOpacity(0.5), width: 1.5) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: isWhite ? Colors.white : const material.Color(0xFF1A1916),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(children: [
              Flexible(
                child: Text(_displayName(name),
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: (accentColor == kGreen || accentColor == kRed) ? Colors.white : Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              if (elo != null) ...[
                const SizedBox(width: 8),
                Text('($elo)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.45))),
              ],
            ]),
          ),
          if (isGameFinished && (_isWinner || _isLoser))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: accentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
              child: Text(_isWinner ? '1' : '0',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: accentColor)),
            ),
          if (isGameFinished && result == '1/2-1/2')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: kGrey.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
              child: Text('\u00BD', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kGrey)),
            ),
        ],
      ),
    );
  }
}

// ── Nav button ─────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _NavButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48, height: 48,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        color: Colors.white,
        disabledColor: Colors.white.withOpacity(0.2),
        style: IconButton.styleFrom(
          backgroundColor: onPressed != null ? Colors.white.withOpacity(0.08) : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class _CachedScore {
  final String score;
  final bool? mateForWhite;
  const _CachedScore(this.score, this.mateForWhite);
}
