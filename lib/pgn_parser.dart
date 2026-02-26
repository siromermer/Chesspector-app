/// PGN parsing using only package:chess. No external PGN library.
/// Parses [Key "value"] headers and move text into game headers + list of SAN moves.

class MasterGame {
  final String event;
  final String site;
  final String date;
  final String white;
  final String black;
  final String result;
  final String? whiteElo;
  final String? blackElo;
  final String? eco;
  final String? round;
  final List<String> sanMoves;

  MasterGame({
    required this.event,
    required this.site,
    required this.date,
    required this.white,
    required this.black,
    required this.result,
    this.whiteElo,
    this.blackElo,
    this.eco,
    this.round,
    required this.sanMoves,
  });

  String get displayTitle {
    final w = _shortName(white);
    final b = _shortName(black);
    return '$w vs $b';
  }

  static String _shortName(String full) {
    final parts = full.split(RegExp(r'[,\s]+'));
    if (parts.isEmpty) return full;
    return parts.first;
  }
}

/// Parse a single PGN game block (headers + move text) into [MasterGame].
MasterGame? parseOneGame(String block) {
  final lines = block.split('\n');
  final headers = <String, String>{};
  final moveLines = <String>[];

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final headerMatch = RegExp(r'^\[(\w+)\s+"([^"]*)"\]').firstMatch(trimmed);
    if (headerMatch != null) {
      headers[headerMatch.group(1)!] = headerMatch.group(2)!;
    } else {
      moveLines.add(trimmed);
    }
  }

  final event = headers['Event'] ?? '';
  final white = headers['White'] ?? '';
  final black = headers['Black'] ?? '';
  if (white.isEmpty && black.isEmpty) return null;

  final moveText = moveLines.join(' ');
  final sanMoves = _tokenizeMoves(moveText);
  if (sanMoves.isEmpty) return null;

  return MasterGame(
    event: event,
    site: headers['Site'] ?? '',
    date: headers['Date'] ?? '',
    white: white,
    black: black,
    result: headers['Result'] ?? '*',
    whiteElo: headers['WhiteElo'],
    blackElo: headers['BlackElo'],
    eco: headers['ECO'],
    round: headers['Round'],
    sanMoves: sanMoves,
  );
}

/// Split PGN file content into game blocks.
/// A new game starts when a header line (e.g. [Event "..."]) appears after
/// a blank line or after move text — consecutive header lines belong together.
List<String> splitPgnGames(String content) {
  final games = <String>[];
  final lines = content.split('\n');
  final block = StringBuffer();
  final headerRe = RegExp(r'^\[');
  bool lastWasHeader = false;

  for (final line in lines) {
    final trimmed = line.trim();
    final isHeader = headerRe.hasMatch(trimmed);

    if (isHeader && !lastWasHeader && block.isNotEmpty) {
      // Header after blank/move line → flush previous game
      final game = block.toString().trim();
      if (game.isNotEmpty) games.add(game);
      block.clear();
    }

    if (trimmed.isEmpty) {
      lastWasHeader = false;
      if (block.isNotEmpty) block.writeln();
      continue;
    }

    if (block.isNotEmpty) block.writeln();
    block.write(line);
    lastWasHeader = isHeader;
  }

  if (block.isNotEmpty) {
    final game = block.toString().trim();
    if (game.isNotEmpty) games.add(game);
  }

  return games;
}

/// Extract SAN moves from move text. Removes move numbers and results.
List<String> _tokenizeMoves(String moveText) {
  final sanMoves = <String>[];
  final tokens = moveText.split(RegExp(r'\s+'));

  for (final token in tokens) {
    final t = token.trim();
    if (t.isEmpty) continue;
    if (RegExp(r'^(1\-0|0\-1|1/2\-1/2|\*)$').hasMatch(t)) break;
    if (RegExp(r'^\d+\.+$').hasMatch(t)) continue;

    // Strip move number prefix: "1.e4", "2.Nf3", "1...e5" -> "e4", "Nf3", "e5"
    String san = t.replaceFirst(RegExp(r'^\d+\.+\s*'), '').trim();
    if (san.isEmpty) continue;

    final commentStart = san.indexOf('{');
    if (commentStart >= 0) san = san.substring(0, commentStart).trim();
    final lineComment = san.indexOf(';');
    if (lineComment >= 0) san = san.substring(0, lineComment).trim();
    if (san.isEmpty) continue;

    sanMoves.add(san);
  }

  return sanMoves;
}

/// Master name from filename: "Anand_selected.pgn" -> "Viswanathan Anand"
String masterNameFromFilename(String filename) {
  final base = filename.replaceAll(RegExp(r'\.(pgn|PGN)$'), '');
  final shortName = base.replaceAll(RegExp(r'_selected$'), '');
  
  // Map short names to full grandmaster names
  const nameMapping = {
    'Nakamura': 'Hikaru Nakamura',
    'Alekhine': 'Alexander Alekhine',
    'Anand': 'Viswanathan Anand',
    'Capablanca': 'José Raúl Capablanca',
    'Carlsen': 'Magnus Carlsen',
    'Caruana': 'Fabiano Caruana',
    'Ding': 'Ding Liren',
    'Fischer': 'Bobby Fischer',
    'Giri': 'Anish Giri',
    'Karjakin': 'Sergey Karjakin',
    'Karpov': 'Anatoly Karpov',
    'Kasparov': 'Garry Kasparov',
    'Kramnik': 'Vladimir Kramnik',
    'Lasker': 'Emanuel Lasker',
    'Nepomniachtchi': 'Ian Nepomniachtchi',
    'Petrosian': 'Tigran Petrosian',
    'So': 'Wesley So',
    'Spassky': 'Boris Spassky',
    'Steinitz': 'Wilhelm Steinitz',
    'Tal': 'Mikhail Tal',
  };
  
  return nameMapping[shortName] ?? shortName;
}
