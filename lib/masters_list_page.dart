import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'pgn_parser.dart';
import 'master_games_list_page.dart';

/// Lists all masters (from PGN asset filenames). Tapping a master opens their games.
class MastersListPage extends StatefulWidget {
  const MastersListPage({super.key});

  @override
  State<MastersListPage> createState() => _MastersListPageState();
}

class _MastersListPageState extends State<MastersListPage> {
  List<String> _assetPaths = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMasterList();
  }

  Future<void> _loadMasterList() async {
    try {
      const knownMasters = [
        'Carlsen_selected.pgn',
        'Nakamura_selected.pgn',
        'Karpov_selected.pgn',
        'Nepomniachtchi_selected.pgn',
        'Kramnik_selected.pgn',
        'Kasparov_selected.pgn',
        'Alekhine_selected.pgn',
        'Anand_selected.pgn',
        'Capablanca_selected.pgn',
        'Caruana_selected.pgn',
        'Ding_selected.pgn',
        'Fischer_selected.pgn',
        'Giri_selected.pgn',
        'Karjakin_selected.pgn',
        'Lasker_selected.pgn',
        'Petrosian_selected.pgn',
        'So_selected.pgn',
        'Spassky_selected.pgn',
        'Steinitz_selected.pgn',
        'Tal_selected.pgn',
      ];
      final existing = <String>[];
      for (final name in knownMasters) {
        try {
          await rootBundle.load('assets/pgn_masters/$name');
          existing.add('assets/pgn_masters/$name');
        } catch (_) {
          // asset not found, skip
        }
      }
      if (!mounted) return;
      setState(() {
        _assetPaths = existing;
        _loading = false;
        _error = existing.isEmpty ? 'No PGN files found' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        title: const Text(
          'Grandmaster Archive',
          style: TextStyle(
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
                  itemCount: _assetPaths.length,
                  itemBuilder: (context, index) {
                    final path = _assetPaths[index];
                    final name = masterNameFromFilename(path.split('/').last);
                    return _MasterTile(
                      masterName: name,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => MasterGamesListPage(
                              masterName: name,
                              assetPath: path,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class _MasterTile extends StatelessWidget {
  final String masterName;
  final VoidCallback onTap;

  const _MasterTile({
    required this.masterName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF302E2B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: kGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_rounded, color: kGreen, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    masterName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
