import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'pgn_parser.dart';
import 'game_viewer_page.dart';

/// Lists games for one master (from one PGN asset). Tap opens game viewer.
class MasterGamesListPage extends StatefulWidget {
  final String masterName;
  final String assetPath;

  const MasterGamesListPage({
    super.key,
    required this.masterName,
    required this.assetPath,
  });

  @override
  State<MasterGamesListPage> createState() => _MasterGamesListPageState();
}

class _MasterGamesListPageState extends State<MasterGamesListPage> {
  List<MasterGame> _games = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    try {
      final content = await rootBundle.loadString(widget.assetPath);
      final blocks = splitPgnGames(content);
      final games = <MasterGame>[];
      for (final block in blocks) {
        final game = parseOneGame(block);
        if (game != null) games.add(game);
      }
      if (!mounted) return;
      setState(() {
        _games = games;
        _loading = false;
        _error = games.isEmpty ? 'No games in this file' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _openGame(MasterGame game) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GameViewerPage(game: game),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        title: Text(
          widget.masterName,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.3,
            color: Colors.white,
          ),
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
      body: _loading
          ? Center(child: CircularProgressIndicator(color: kGreen))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: _games.length,
                  itemBuilder: (context, index) {
                    final game = _games[index];
                    return _GameTile(
                      game: game,
                      onTap: () => _openGame(game),
                    );
                  },
                ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final MasterGame game;
  final VoidCallback onTap;

  const _GameTile({
    required this.game,
    required this.onTap,
  });

  String _formatDate(String date) {
    if (date.isEmpty || date == '????.??.??') return '—';
    final parts = date.split('.');
    if (parts.length >= 1 && parts[0].length == 4) {
      return parts[0];
    }
    return date;
  }

  @override
  Widget build(BuildContext context) {
    final whiteElo = game.whiteElo != null && game.whiteElo!.isNotEmpty
        ? '${game.whiteElo}'
        : null;
    final blackElo = game.blackElo != null && game.blackElo!.isNotEmpty
        ? '${game.blackElo}'
        : null;
    final eloText = (whiteElo != null || blackElo != null)
        ? '${whiteElo ?? '?'} – ${blackElo ?? '?'}'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF302E2B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.displayTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (game.event.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    game.event,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _formatDate(game.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.45),
                      ),
                    ),
                    if (eloText != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        eloText,
                        style: TextStyle(
                          fontSize: 12,
                          color: kGreen.withOpacity(0.9),
                        ),
                      ),
                    ],
                    const Spacer(),
                    _ResultChip(result: game.result),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String result;

  const _ResultChip({required this.result});

  @override
  Widget build(BuildContext context) {
    Color bg;
    String text = result;
    if (result == '1-0') {
      bg = kGreen.withOpacity(0.2);
      text = '1-0';
    } else if (result == '0-1') {
      bg = kRed.withOpacity(0.2);
      text = '0-1';
    } else if (result == '1/2-1/2') {
      bg = kGrey.withOpacity(0.2);
      text = '½-½';
    } else {
      bg = Colors.white.withOpacity(0.08);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.9),
        ),
      ),
    );
  }
}
