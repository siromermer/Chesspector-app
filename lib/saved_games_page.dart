import 'package:flutter/material.dart';
import 'main.dart';
import 'game_storage.dart';
import 'play_computer_page.dart';

/// Displays a list of saved games. Tapping an entry opens the analysis page
/// with the stored FEN position.
class SavedGamesPage extends StatefulWidget {
  const SavedGamesPage({super.key});

  @override
  State<SavedGamesPage> createState() => _SavedGamesPageState();
}

class _SavedGamesPageState extends State<SavedGamesPage> {
  List<SavedGame> _games = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    final games = await GameStorage.loadAll();
    if (!mounted) return;
    setState(() {
      _games = games;
      _isLoading = false;
    });
  }

  Future<void> _deleteGame(SavedGame game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF302E2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Game', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Remove "${game.title}" from saved games?',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: kRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await GameStorage.delete(game.id);
      _loadGames();
    }
  }

  void _openGame(SavedGame game) {
    if (game.gameMode == 'play-computer') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayComputerGamePage(
            initialFen: game.fen,
            playAsWhite: game.playerSide ?? true,
            engineDepth: game.engineDepth ?? 10,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChessGame(
            initialFen: game.fen,
            initialScore: game.score,
          ),
        ),
      );
    }
  }

  /// Extract a compact summary from FEN (piece counts).
  String _pieceSummary(String fen) {
    final board = fen.split(' ').first;
    int white = 0;
    int black = 0;
    for (final c in board.runes) {
      final ch = String.fromCharCode(c);
      if ('PNBRQK'.contains(ch)) white++;
      if ('pnbrqk'.contains(ch)) black++;
    }
    return 'White: $white pieces  •  Black: $black pieces';
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${local.day} ${months[local.month - 1]} ${local.year}, ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        title: const Text(
          'Saved Games',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: 0.3),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1A1916),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: kGreen))
          : _games.isEmpty
              ? _buildEmptyState()
              : _buildGameList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border_rounded, size: 64, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 16),
          Text(
            'No Saved Games',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analyze a position and tap the save icon\nto store it here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.3),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _games.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final game = _games[index];
        return _buildGameCard(game);
      },
    );
  }

  Widget _buildGameCard(SavedGame game) {
    // Determine score color
    Color scoreColor = kGrey;
    if (game.score != null) {
      if (game.score!.startsWith('+') || game.score!.startsWith('#')) {
        scoreColor = kGreen;
      } else if (game.score!.startsWith('-')) {
        scoreColor = kRed;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openGame(game),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF302E2B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              // Left: chess icon with score-colored accent
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.grid_on_rounded, color: scoreColor, size: 24),
              ),
              const SizedBox(width: 14),

              // Middle: title, piece summary, date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _pieceSummary(game.fen),
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(game.savedAt),
                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3)),
                    ),
                  ],
                ),
              ),

              // Right: score badge + delete
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (game.score != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scoreColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        game.score!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scoreColor,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _deleteGame(game),
                    child: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.white.withOpacity(0.25)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
