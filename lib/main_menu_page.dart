import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'corner_detection_page.dart';
import 'saved_games_page.dart';
import 'play_computer_page.dart';
import 'masters_list_page.dart';

/// Displays a random chess quote and provides navigation to the main app sections.
class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  late String _quote;
  late String _author;

  static const List<Map<String, String>> _quotes = [
    {'quote': 'Chess is the struggle against the error.', 'author': 'Johannes Zukertort'},
    {'quote': 'Every chess master was once a beginner.', 'author': 'Irving Chernev'},
    {'quote': 'Chess makes men wiser and clear-sighted.', 'author': 'Vladimir Putin'},
    {'quote': 'Chess is the gymnasium of the mind.', 'author': 'Blaise Pascal'},
    {'quote': 'When you see a good move, look for a better one.', 'author': 'Emanuel Lasker'},
    {'quote': 'Chess is a war over the board. The object is to crush the opponent\'s mind.', 'author': 'Bobby Fischer'},
    {'quote': 'Play the opening like a book, the middlegame like a magician, and the endgame like a machine.', 'author': 'Rudolph Spielmann'},
    {'quote': 'I used to attack because it was the only thing I knew. Now I attack because I know it works best.', 'author': 'Garry Kasparov'},
    {'quote': 'In life, as in chess, forethought wins.', 'author': 'Charles Buxton'},
    {'quote': 'Tactics is knowing what to do when there is something to do; strategy is knowing what to do when there is nothing to do.', 'author': 'Savielly Tartakower'},
    {'quote': 'I don\'t believe in psychology. I believe in good moves.', 'author': 'Bobby Fischer'},
    {'quote': 'Chess is beautiful enough to waste your life for.', 'author': 'Hans Ree'},
    {'quote': 'The pin is mightier than the sword.', 'author': 'Fred Reinfeld'},
    {'quote': 'One bad move nullifies forty good ones.', 'author': 'Bernhard Horwitz'},
    {'quote': 'A good player is always lucky.', 'author': 'Jose Raul Capablanca'},
    {'quote': 'The hardest game to win is a won game.', 'author': 'Emanuel Lasker'},
    {'quote': 'Chess is not for timid souls.', 'author': 'Wilhelm Steinitz'},
    {'quote': 'Help your pieces so they can help you.', 'author': 'Paul Morphy'},
    {'quote': 'Chess is the art of analysis.', 'author': 'Mikhail Botvinnik'},
    {'quote': 'Chess, like love, is infectious at any age.', 'author': 'Salo Flohr'},
  ];

  @override
  void initState() {
    super.initState();
    _pickRandomQuote();
  }

  void _pickRandomQuote() {
    final entry = _quotes[Random().nextInt(_quotes.length)];
    _quote = entry['quote']!;
    _author = entry['author']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // App title
              const Text(
                'Chesspector',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: kGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const Spacer(flex: 2),

              // Quote section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      color: kGreen.withOpacity(0.7),
                      size: 28,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '"$_quote"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.85),
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '— $_author',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kGreen.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Menu buttons
              _MenuButton(
                icon: Icons.camera_alt_rounded,
                label: 'Analyze Position',
                subtitle: 'Scan a chess board from photo',
                color: kGreen,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CornerDetectionPage()),
                  ).then((_) => setState(() => _pickRandomQuote()));
                },
              ),
              const SizedBox(height: 14),
              _MenuButton(
                icon: Icons.emoji_events_rounded,
                label: 'Grandmaster Archive',
                subtitle: 'Study classic games by legends',
                color: kGreen,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MastersListPage()),
                  ).then((_) => setState(() => _pickRandomQuote()));
                },
              ),
              const SizedBox(height: 14),
              _MenuButton(
                icon: Icons.smart_toy_rounded,
                label: 'Play Against Stockfish',
                subtitle: 'Choose difficulty and side',
                color: kGreen,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlayComputerSetupPage()),
                  ).then((_) => setState(() => _pickRandomQuote()));
                },
              ),
              const SizedBox(height: 14),
              _MenuButton(
                icon: Icons.bookmark_rounded,
                label: 'Saved Games',
                subtitle: 'Review your saved positions',
                color: kGreen,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SavedGamesPage()),
                  ).then((_) => setState(() => _pickRandomQuote()));
                },
              ),

              const Spacer(flex: 2),

              // Licenses link
              GestureDetector(
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'Chesspector',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2026 Ömer  Günaydın',
                  );
                },
                child: Text(
                  'Licenses',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.25),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable menu button widget for the main menu.
class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
