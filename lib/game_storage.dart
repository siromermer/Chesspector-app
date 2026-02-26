import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a single saved chess game with metadata.
class SavedGame {
  final String id;
  final String fen;
  final String title;
  final DateTime savedAt;
  final String? score; // Position evaluation at save time
  final int moveCount; // Number of half-moves played
  final String gameMode; // 'analysis' or 'play-computer'
  final bool? playerSide; // true=white, false=black; only for play-computer mode
  final int? engineDepth; // only for play-computer mode

  SavedGame({
    required this.id,
    required this.fen,
    required this.title,
    required this.savedAt,
    this.score,
    this.moveCount = 0,
    this.gameMode = 'analysis',
    this.playerSide,
    this.engineDepth,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fen': fen,
        'title': title,
        'savedAt': savedAt.toIso8601String(),
        'score': score,
        'moveCount': moveCount,
        'gameMode': gameMode,
        'playerSide': playerSide,
        'engineDepth': engineDepth,
      };

  factory SavedGame.fromJson(Map<String, dynamic> json) => SavedGame(
        id: json['id'] as String,
        fen: json['fen'] as String,
        title: json['title'] as String,
        savedAt: DateTime.parse(json['savedAt'] as String),
        score: json['score'] as String?,
        moveCount: json['moveCount'] as int? ?? 0,
        gameMode: json['gameMode'] as String? ?? 'analysis',
        playerSide: json['playerSide'] as bool?,
        engineDepth: json['engineDepth'] as int?,
      );
}

/// Handles persistence of saved games using SharedPreferences.
///
/// Games are stored as a JSON-encoded list under the key [_storageKey].
/// Each entry contains the FEN, a user-supplied title, evaluation score,
/// and a UTC timestamp.
class GameStorage {
  static const String _storageKey = 'saved_games';

  /// Retrieve all saved games, sorted by most recent first.
  static Future<List<SavedGame>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final List<dynamic> decoded = jsonDecode(raw);
      final games = decoded
          .map((e) => SavedGame.fromJson(e as Map<String, dynamic>))
          .toList();
      games.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return games;
    } catch (e) {
      return [];
    }
  }

  /// Save a new game. Returns the created [SavedGame].
  static Future<SavedGame> save({
    required String fen,
    required String title,
    String? score,
    int moveCount = 0,
    String gameMode = 'analysis',
    bool? playerSide,
    int? engineDepth,
  }) async {
    final games = await loadAll();
    final game = SavedGame(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fen: fen,
      title: title,
      savedAt: DateTime.now().toUtc(),
      score: score,
      moveCount: moveCount,
      gameMode: gameMode,
      playerSide: playerSide,
      engineDepth: engineDepth,
    );
    games.insert(0, game);
    await _persist(games);
    return game;
  }

  /// Delete a saved game by its [id].
  static Future<void> delete(String id) async {
    final games = await loadAll();
    games.removeWhere((g) => g.id == id);
    await _persist(games);
  }

  /// Write the full list to SharedPreferences.
  static Future<void> _persist(List<SavedGame> games) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(games.map((g) => g.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
