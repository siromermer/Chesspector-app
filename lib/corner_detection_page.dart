import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'corner_adjustment_widget.dart';
import 'board_editor_page.dart';
import 'aws_auth_service.dart';
import 'api_config.dart';

class CornerDetectionPage extends StatefulWidget {
  const CornerDetectionPage({super.key});

  @override
  State<CornerDetectionPage> createState() => _CornerDetectionPageState();
}

class _CornerDetectionPageState extends State<CornerDetectionPage> {
  static const String staticApiUrl = ApiConfig.staticApiUrl;
  static const String dynamicApiUrl = ApiConfig.dynamicApiUrl;
  static const String pieceDetectionApiUrl = ApiConfig.pieceDetectionApiUrl;

  final _awsAuth = AwsAuthService();

  File? _selectedImage;
  Uint8List? _imageBytes;
  Map<String, dynamic>? _corners;
  Map<String, List<int>>? _adjustedCorners;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Actual image dimensions
  int? _imageWidth;
  int? _imageHeight;

  // UI State
  bool _isAdjusting = false;
  bool _showGrid = false;
  bool _cornersApproved = false;  // New: tracks if user approved corners/grid

  // Piece Detection State
  bool _isDetectingPieces = false;
  List<Map<String, dynamic>>? _detectedPieces;
  String _detectionStatusMessage = '';  // Status message during detection

  // White side orientation — which edge of the image has white pieces
  // 'bottom' (default), 'top', 'left', 'right'
  String _whiteSide = 'bottom';
  bool _selectingWhiteSide = false;  // true when user is picking white side on image

  // Manual corner placement state
  bool _isManualCornerMode = false;
  int _manualCornerStep = 0; // 0=TL, 1=TR, 2=BR, 3=BL
  List<Offset?> _manualCornerPoints = [null, null, null, null]; // TL, TR, BR, BL (image coords)
  static const List<String> _cornerLabels = ['Top-Left', 'Top-Right', 'Bottom-Right', 'Bottom-Left'];
  static const List<Color> _cornerColors = [Colors.red, Colors.blue, Colors.orange, Colors.green];

  final ImagePicker _picker = ImagePicker();
  
  // Chess quotes
  String _currentQuote = '';
  String _currentAuthor = '';
  final Random _random = Random();
  
  static const List<Map<String, String>> _chessQuotes = [
    {'quote': 'Chess is the struggle against the error.', 'author': 'Johannes Zukertort'},
    {'quote': 'Every chess master was once a beginner.', 'author': 'Irving Chernev'},
    {'quote': 'Avoid the crowd. Do your own thinking independently. Be the chess player, not the chess piece.', 'author': 'Ralph Charell'},
    {'quote': 'Chess makes men wiser and clear-sighted.', 'author': 'Vladimir Putin'},
    {'quote': 'Chess holds its master in its own bonds, shackling the mind and brain so that the inner freedom of the very strongest must suffer.', 'author': 'Albert Einstein'},
    {'quote': 'Chess is a war over the board. The object is to crush the opponent\'s mind.', 'author': 'Bobby Fischer'},
    {'quote': 'Chess is the gymnasium of the mind.', 'author': 'Blaise Pascal'},
    {'quote': 'Even the laziest King flees wildly in the face of a double check!', 'author': 'Aaron Nimzowitsch'},
    {'quote': 'We cannot resist the fascination of sacrifice, since a passion for sacrifices is part of a Chess player\'s nature.', 'author': 'Rudolf Spielman'},
    {'quote': 'Nothing excites jaded Grandmasters more than a theoretical novelty.', 'author': 'Dominic Lawson'},
    {'quote': 'A win by an unsound combination, however showy, fills me with artistic horror.', 'author': 'Wilhelm Steinitz'},
    {'quote': 'Only the player with the initiative has the right to attack.', 'author': 'Wilhelm Steinitz'},
    {'quote': 'Chess is rarely a game of ideal moves. Almost always, a player faces a series of difficult consequences whichever move he makes.', 'author': 'David Shenk'},
    {'quote': 'When you see a good move, look for a better one.', 'author': 'Emanuel Lasker'},
    {'quote': 'Half the variations which are calculated in a tournament game turn out to be completely superfluous. Unfortunately, no one knows in advance which half.', 'author': 'Jan Timman'},
    {'quote': 'Even a poor plan is better than no plan at all.', 'author': 'Mikhail Chigorin'},
    {'quote': 'Tactics is knowing what to do when there is something to do; strategy is knowing what to do when there is nothing to do.', 'author': 'Savielly Tartakower'},
    {'quote': 'In life, as in chess, forethought wins.', 'author': 'Charles Buxton'},
    {'quote': 'You may learn much more from a game you lose than from a game you win. You will have to lose hundreds of games before becoming a good player.', 'author': 'José Raúl Capablanca'},
    {'quote': 'I don\'t believe in psychology. I believe in good moves.', 'author': 'Bobby Fischer'},
    {'quote': 'Play the opening like a book, the middlegame like a magician, and the endgame like a machine.', 'author': 'Rudolph Spielmann'},
    {'quote': 'I used to attack because it was the only thing I knew. Now I attack because I know it works best.', 'author': 'Garry Kasparov'},
    {'quote': 'It\'s always better to sacrifice your opponent\'s men.', 'author': 'Savielly Tartakower'},
    {'quote': 'One doesn\'t have to play well, it\'s enough to play better than your opponent.', 'author': 'Siegbert Tarrasch'},
    {'quote': 'Up to this point, White has been following well-known analysis. But now he makes a fatal error: he begins to use his own head.', 'author': 'Siegbert Tarrasch'},
    {'quote': 'Of chess, it has been said that life is not long enough for it, but that is the fault of life, not chess.', 'author': 'William Napier'},
    {'quote': 'Chess is beautiful enough to waste your life for.', 'author': 'Hans Ree'},
    {'quote': 'A chess game in progress is… a cosmos unto itself, fully insulated from an infant\'s cry, an erotic invitation, or war.', 'author': 'David Shenk'},
    {'quote': 'The pin is mightier than the sword.', 'author': 'Fred Reinfeld'},
    {'quote': 'The only thing chess players have in common is chess.', 'author': 'Lodewijk Prins'},
    {'quote': 'Those who say they understand chess, understand nothing.', 'author': 'Robert Hübner'},
    {'quote': 'One bad move nullifies forty good ones.', 'author': 'Bernhard Horwitz'},
    {'quote': 'If your opponent offers you a draw, try to work out why he thinks he\'s worse off.', 'author': 'Nigel Short'},
    {'quote': 'Your body has to be in top condition. Your chess deteriorates as your body does. You can\'t separate body and mind.', 'author': 'Bobby Fischer'},
    {'quote': 'A good player is always lucky.', 'author': 'Jose Raul Capablanca'},
    {'quote': 'The hardest game to win is a won game.', 'author': 'Emanuel Lasker'},
    {'quote': 'Chess is not for timid souls.', 'author': 'Wilhelm Steinitz'},
    {'quote': 'Chess is a curse upon a man.', 'author': 'H. G. Wells'},
    {'quote': 'Chess is so inspiring that I do not believe a good player is capable of having an evil thought during the game.', 'author': 'Wilhelm Steinitz'},
    {'quote': 'Chess is as much a mystery as women.', 'author': 'Purdy'},
    {'quote': 'He who fears an isolated Queen\'s Pawn should give up Chess.', 'author': 'Siegbert Tarrasch'},
    {'quote': 'It doesn\'t matter how strong a player you are, if you fail to register some development in the opening, then you are asking for trouble.', 'author': 'John Emms'},
    {'quote': 'When having an edge, Karpov often marked time and still gained the advantage! I don\'t know anyone else who could do that, it\'s incredible.', 'author': 'Vladimir Kramnik'},
    {'quote': 'Chess is a forcing house where the fruits of character can ripen more fully than in life.', 'author': 'Edward Morgan Forster'},
    {'quote': 'A king may be the most important piece on the chessboard; however, the queen is the most powerful.', 'author': 'Karim R. Ellis'},
    {'quote': 'To venture an opinion is like moving a piece at chess: it may be taken, but it forms the beginning of a game that is won.', 'author': 'Johann Wolfgang von Goethe'},
    {'quote': 'It is no easy matter to reply correctly to Lasker\'s bad moves.', 'author': 'W.H.K. Pollock'},
    {'quote': 'For in the idea of chess and the development of the chess mind we have a picture of the intellectual struggle of mankind.', 'author': 'Richard Réti'},
    {'quote': 'Chess, like love, is infectious at any age.', 'author': 'Salo Flohr'},
    {'quote': 'Chess is played with the mind and not with the hands!', 'author': 'Renaud and Kahn'},
    {'quote': 'In Chess, just as in life, today\'s bliss may be tomorrow\'s poison.', 'author': 'Assaic'},
    {'quote': 'Chess is a fairy tale of 1001 blunders.', 'author': 'Savielly Tartakower'},
    {'quote': 'I started by just sitting by the chessboard exploring things. I didn\'t even have books at first, and I just played by myself. I learnt a lot from that, and I feel that it is a big reason why I now have a good intuitive understanding of chess.', 'author': 'Magnus Carlsen'},
    {'quote': 'I don\'t know whether computers are improving the style of play, I know they are changing it. Chess has become a different game, one could say that computers have changed the world of chess. That is pretty clear.', 'author': 'Vladimir Kramnik'},
    {'quote': 'When asked, "How is that you pick better moves than your opponents?", I responded: I\'m very glad you asked me that, because, as it happens, there is a very simple answer. I think up my own moves, and I make my opponent think up his.', 'author': 'Alexander Alekhine'},
    {'quote': 'Help your pieces so they can help you.', 'author': 'Paul Morphy'},
    {'quote': 'The shortcoming of hanging pawns is that they present a convenient target for attack. As the exchange of men proceeds, their potential strength lessens and during the endgame they turn out, as a rule, to be weak.', 'author': 'Boris Spassky'},
    {'quote': 'Chess is a very logical game and it is the man who can reason most logically and profoundly in it that ought to win.', 'author': 'Jose Raul Capablanca'},
    {'quote': 'After a bad opening, there is hope for the middle game. After a bad middle game, there is hope for the endgame. But once you are in the endgame, the moment of truth has arrived.', 'author': 'Edmar Mednis'},
    {'quote': 'Chess is the art of analysis.', 'author': 'Mikhail Botvinnik'},
  ];
  
  @override
  void initState() {
    super.initState();
    _loadRandomQuote();
    _awsAuth.warmUp();
  }
  
  void _loadRandomQuote() {
    final quoteData = _chessQuotes[_random.nextInt(_chessQuotes.length)];
    setState(() {
      _currentQuote = quoteData['quote']!;
      _currentAuthor = quoteData['author']!;
    });
  }

  Future<void> _pickImage({required ImageSource source}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        
        // Decode image to get actual dimensions
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        final int width = frameInfo.image.width;
        final int height = frameInfo.image.height;
        frameInfo.image.dispose();
        
        setState(() {
          _selectedImage = File(image.path);
          _imageBytes = bytes;
          _imageWidth = width;
          _imageHeight = height;
          _corners = null;
          _adjustedCorners = null;
          _errorMessage = null;
          _isAdjusting = false;
          _detectedPieces = null;
          _showGrid = false;
          _cornersApproved = false;
          _whiteSide = 'bottom'; // reset orientation for new image
          _selectingWhiteSide = false;
        });
        
        _loadRandomQuote(); // Load new quote when image is picked
        
        // Image loaded successfully
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
    }
  }

  void _enterManualCornerMode() {
    setState(() {
      _isManualCornerMode = true;
      _manualCornerStep = 0;
      _manualCornerPoints = [null, null, null, null];
      _corners = null;
      _adjustedCorners = null;
      _showGrid = false;
      _cornersApproved = false;
      _errorMessage = null;
    });
  }

  void _handleManualCornerTap(TapDownDetails details, double containerW, double containerH) {
    if (_imageWidth == null || _imageHeight == null) return;
    if (_manualCornerStep >= 4) return;

    // Convert screen tap to image coordinates
    final double imageAR = _imageWidth! / _imageHeight!;
    final double containerAR = containerW / containerH;
    double dw, dh, ox, oy;
    if (imageAR > containerAR) {
      dw = containerW; dh = containerW / imageAR; ox = 0; oy = (containerH - dh) / 2;
    } else {
      dh = containerH; dw = containerH * imageAR; ox = (containerW - dw) / 2; oy = 0;
    }

    final tapX = details.localPosition.dx;
    final tapY = details.localPosition.dy;

    // Check tap is within image bounds
    if (tapX < ox || tapX > ox + dw || tapY < oy || tapY > oy + dh) return;

    final double imgX = ((tapX - ox) / dw) * _imageWidth!;
    final double imgY = ((tapY - oy) / dh) * _imageHeight!;

    setState(() {
      _manualCornerPoints[_manualCornerStep] = Offset(imgX, imgY);
      _manualCornerStep++;
    });
  }

  void _undoLastCorner() {
    if (_manualCornerStep <= 0) return;
    setState(() {
      _manualCornerStep--;
      _manualCornerPoints[_manualCornerStep] = null;
    });
  }

  void _applyManualCorners() {
    final tl = _manualCornerPoints[0]!;
    final tr = _manualCornerPoints[1]!;
    final br = _manualCornerPoints[2]!;
    final bl = _manualCornerPoints[3]!;

    setState(() {
      _corners = {
        'top_left': [tl.dx.round(), tl.dy.round()],
        'top_right': [tr.dx.round(), tr.dy.round()],
        'bottom_left': [bl.dx.round(), bl.dy.round()],
        'bottom_right': [br.dx.round(), br.dy.round()],
      };
      _isManualCornerMode = false;
      _showGrid = true;
    });

    _loadRandomQuote();
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF302E2B),
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
            const Text(
              'Select Image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(source: ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(source: ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: const Color(0xFF69946B)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _detectCorners({required bool useDynamic}) async {
    if (_imageBytes == null) {
      setState(() {
        _errorMessage = 'Please select an image first';
      });
      return;
    }

    final String apiUrl = useDynamic ? dynamicApiUrl : staticApiUrl;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _corners = null;
      _adjustedCorners = null;
      _isAdjusting = false;
      _detectedPieces = null;
      _cornersApproved = false;
      _showGrid = false;
    });

    try {
      final base64Image = base64Encode(_imageBytes!);

      final body = jsonEncode({
        'image': base64Image,
        if (useDynamic) 'debug': true,
      });
      final response = await _awsAuth.signedPost(apiUrl, body);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        setState(() {
          _corners = responseData['corners'];
          _isLoading = false;
          _showGrid = true;
        });
        _loadRandomQuote();
      } else {
        // Check if it's a corner detection failure (400, 422, or success=false)
        final String errorMsg = (response.statusCode == 400 || 
                response.statusCode == 422 || 
                (response.statusCode == 200 && responseData['success'] == false))
            ? 'Cannot extract 4 corner points. Please manually choose corner points.'
            : _friendlyApiError(response.statusCode);
        setState(() {
          _errorMessage = errorMsg;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = _friendlyNetworkError(e);
        _isLoading = false;
      });
    }
  }

  void _startAdjusting() {
    if (_corners == null) return;
    
    _loadRandomQuote(); // Load new quote when starting adjustment
    
    setState(() {
      _isAdjusting = true;
      // Use adjusted corners if they exist (re-adjust case), otherwise use API corners
      if (_adjustedCorners == null) {
        _adjustedCorners = {
          'top_left': List<int>.from(_corners!['top_left']),
          'top_right': List<int>.from(_corners!['top_right']),
          'bottom_left': List<int>.from(_corners!['bottom_left']),
          'bottom_right': List<int>.from(_corners!['bottom_right']),
        };
      }
      // If _adjustedCorners already exists, keep it as-is (user's latest positions)
    });
  }

  /// Resize image bytes so the longest edge = [maxEdge], preserving aspect ratio.
  /// Returns the resized bytes as JPEG and the scale factor used.
  Future<({Uint8List bytes, double scale})> _resizeForDetection(Uint8List original, int maxEdge) async {
    final codec = await ui.instantiateImageCodec(original);
    final frame = await codec.getNextFrame();
    final src = frame.image;
    final int origW = src.width;
    final int origH = src.height;

    final double scale = maxEdge / max(origW, origH);
    if (scale >= 1.0) {
      src.dispose();
      return (bytes: original, scale: 1.0);
    }

    final int newW = (origW * scale).round();
    final int newH = (origH * scale).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, newW.toDouble(), newH.toDouble()));
    canvas.drawImageRect(
      src,
      Rect.fromLTWH(0, 0, origW.toDouble(), origH.toDouble()),
      Rect.fromLTWH(0, 0, newW.toDouble(), newH.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    final resized = await picture.toImage(newW, newH);
    src.dispose();

    final byteData = await resized.toByteData(format: ui.ImageByteFormat.png);
    resized.dispose();
    if (byteData == null) return (bytes: original, scale: 1.0);

    return (bytes: byteData.buffer.asUint8List(), scale: scale);
  }

  Future<void> _detectPieces() async {
    if (_imageBytes == null) {
      setState(() {
        _errorMessage = 'Please select an image first';
      });
      return;
    }

    setState(() {
      _isDetectingPieces = true;
      _errorMessage = null;
      _detectionStatusMessage = 'Analyzing board image...';
    });

    try {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_isDetectingPieces && mounted) {
          setState(() {
            _detectionStatusMessage = 'Detecting chess pieces...';
          });
        }
      });

      Future.delayed(const Duration(milliseconds: 2500), () {
        if (_isDetectingPieces && mounted) {
          setState(() {
            _detectionStatusMessage = 'Identifying piece positions...';
          });
        }
      });

      // Resize image to 640px longest edge before sending — the model
      // internally uses 640x640 so larger images just waste bandwidth.
      final resized = await _resizeForDetection(_imageBytes!, 640);
      final double scaleBack = 1.0 / resized.scale; // to map bboxes back to original coords

      final base64Image = base64Encode(resized.bytes);

      final body = jsonEncode({'image': base64Image});
      final response = await _awsAuth.signedPost(pieceDetectionApiUrl, body);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final rawPieces = List<Map<String, dynamic>>.from(
          responseData['detections']['pieces'],
        );

        // Scale bounding boxes back to original image coordinates
        final pieces = rawPieces.map((p) {
          final bbox = Map<String, dynamic>.from(p['bbox'] as Map);
          bbox['x1'] = (bbox['x1'] as num) * scaleBack;
          bbox['y1'] = (bbox['y1'] as num) * scaleBack;
          bbox['x2'] = (bbox['x2'] as num) * scaleBack;
          bbox['y2'] = (bbox['y2'] as num) * scaleBack;
          return {...p, 'bbox': bbox};
        }).toList();

        setState(() {
          _detectedPieces = pieces;
          _detectionStatusMessage = 'Generating board notation...';
        });
        
        // Generate FEN after pieces are detected
        final fen = _generateFenFromDetection();
        final pieceCounts = _getPieceCounts();
        
        // Directly navigate to Board Editor for user verification
        // Keep loading overlay visible during navigation
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BoardEditorPage(
                initialFen: fen,
                detectedPieceCounts: pieceCounts,
              ),
            ),
          ).then((_) {
            // Only reset state after returning from Board Editor
            if (mounted) {
              setState(() {
                _isDetectingPieces = false;
                _detectionStatusMessage = '';
                _cornersApproved = false;
                _detectedPieces = null;
              });
            }
          });
        }
      } else {
        setState(() {
          _errorMessage = _friendlyApiError(response.statusCode);
          _isDetectingPieces = false;
          _detectionStatusMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = _friendlyNetworkError(e);
        _isDetectingPieces = false;
        _detectionStatusMessage = '';
      });
    }
  }

  void _onCornersConfirmed(Map<String, List<int>> newCorners) {
    setState(() {
      _adjustedCorners = newCorners;
      _isAdjusting = false;
    });
    
    _loadRandomQuote(); // Load new quote when corners confirmed
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Corners adjusted successfully!'),
          ],
        ),
        backgroundColor: const Color(0xFF69946B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Map<String, dynamic> get _displayCorners {
    if (_adjustedCorners != null) {
      return _adjustedCorners!;
    }
    return _corners ?? {};
  }

  /// Generate FEN notation from detected pieces and grid mapping
  String? _generateFenFromDetection() {
    if (_detectedPieces == null || _detectedPieces!.isEmpty) {
      return null;
    }
    
    final corners = _displayCorners;
    if (corners.isEmpty) return null;

    // Get corner coordinates
    final tl = _pointFromCorner(corners['top_left']);
    final tr = _pointFromCorner(corners['top_right']);
    final bl = _pointFromCorner(corners['bottom_left']);
    final br = _pointFromCorner(corners['bottom_right']);

    // Compute inverse perspective matrix (image coords → unit square)
    final invMatrix = _computeInversePerspectiveMatrix(
      tl.dx, tl.dy, tr.dx, tr.dy, bl.dx, bl.dy, br.dx, br.dy,
    );

    // Initialize 8x8 board (null = empty square)
    final List<List<String?>> board = List.generate(8, (_) => List.filled(8, null));
    final List<List<double>> boardConf = List.generate(8, (_) => List.filled(8, 0.0));

    // Track pieces per side for post-processing correction rules
    final List<_PieceInfo> whiteQueens = [];
    final List<_PieceInfo> blackQueens = [];
    final List<_PieceInfo> whiteKings = [];
    final List<_PieceInfo> blackKings = [];
    final List<_PieceInfo> whiteBishops = [];
    final List<_PieceInfo> blackBishops = [];

    // Map each detected piece to a grid cell
    for (final piece in _detectedPieces!) {
      final label = piece['label'] as String;
      final bbox = piece['bbox'] as Map<String, dynamic>;
      
      final double x1 = (bbox['x1'] as num).toDouble();
      final double y1 = (bbox['y1'] as num).toDouble();
      final double x2 = (bbox['x2'] as num).toDouble();
      final double y2 = (bbox['y2'] as num).toDouble();
      final double bboxHeight = y2 - y1;
      
      final double cx = (x1 + x2) / 2;
      final String pieceType = label.toLowerCase().split('-').last;
      final bool isTall = pieceType == 'king' || pieceType == 'queen' || pieceType == 'bishop';
      final double cy = isTall
          ? y2 - bboxHeight * 0.10
          : y2 - bboxHeight * 0.25;
      
      // Transform to unit square [0,1] x [0,1]
      final unitPos = _applyInversePerspective(cx, cy, invMatrix);
      
      // Convert to grid cell (0-7, 0-7) based on white side orientation
      // Unit square: u (dx) = 0→left, 1→right; v (dy) = 0→top, 1→bottom
      final int uIdx = (unitPos.dx * 8).floor().clamp(0, 7);
      final int vIdx = (unitPos.dy * 8).floor().clamp(0, 7);

      // Rotate grid mapping based on which image edge has white pieces
      // FEN row 0 = rank 8 (black home), row 7 = rank 1 (white home)
      // FEN col 0 = file a, col 7 = file h
      int row, col;
      switch (_whiteSide) {
        case 'top':    // white at top of image → 180° rotation
          row = 7 - vIdx; col = 7 - uIdx; break;
        case 'left':   // white at left → 90° CW rotation
          row = 7 - uIdx; col = vIdx; break;
        case 'right':  // white at right → 90° CCW rotation
          row = uIdx; col = 7 - vIdx; break;
        case 'bottom': // default — white at bottom of image
        default:
          row = vIdx; col = uIdx; break;
      }
      
      // Convert label to FEN piece character
      final fenChar = _labelToFenChar(label);
      final double conf = (piece['confidence'] as num?)?.toDouble() ?? 1.0;
      
      if (fenChar != null) {
        // Only place piece if square is empty OR this piece has higher confidence
        if (board[row][col] == null || conf > boardConf[row][col]) {
          board[row][col] = fenChar;
          boardConf[row][col] = conf;
          
          if (fenChar == 'Q') whiteQueens.add(_PieceInfo(row, col, conf));
          if (fenChar == 'q') blackQueens.add(_PieceInfo(row, col, conf));
          if (fenChar == 'K') whiteKings.add(_PieceInfo(row, col, conf));
          if (fenChar == 'k') blackKings.add(_PieceInfo(row, col, conf));
          if (fenChar == 'B') whiteBishops.add(_PieceInfo(row, col, conf));
          if (fenChar == 'b') blackBishops.add(_PieceInfo(row, col, conf));
        }
      }
    }

    // Each side MUST have exactly one king.
    _ensureOneKing(whiteKings, whiteQueens, whiteBishops, board, isWhite: true);
    _ensureOneKing(blackKings, blackQueens, blackBishops, board, isWhite: false);

    // Build FEN string from board
    final StringBuffer fen = StringBuffer();
    for (int row = 0; row < 8; row++) {
      int emptyCount = 0;
      for (int col = 0; col < 8; col++) {
        final piece = board[row][col];
        if (piece == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            fen.write(emptyCount);
            emptyCount = 0;
          }
          fen.write(piece);
        }
      }
      if (emptyCount > 0) {
        fen.write(emptyCount);
      }
      if (row < 7) fen.write('/');
    }

    // Add default game state (white to move, no castling since we don't know game history, no en passant)
    fen.write(' w - - 0 1');
    
    return fen.toString();
  }

  Offset _pointFromCorner(dynamic corner) {
    final List<dynamic> p = corner is List ? corner : [0, 0];
    return Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
  }

  /// Produce a user-friendly message for HTTP error codes.
  String _friendlyApiError(int statusCode) {
    if (statusCode == 422) return 'Cannot extract 4 corner points. Please manually choose corner points.';
    if (statusCode == 403) return 'Access denied. Please update the app.';
    if (statusCode == 429) return 'Too many requests. Please wait a moment and try again.';
    if (statusCode >= 500) return 'Our servers are temporarily unavailable. Please try again shortly.';
    if (statusCode == 408) return 'The request timed out. Please try again.';
    return 'Something went wrong. Please try again. (Code: $statusCode)';
  }

  /// Produce a user-friendly message for network/connection errors.
  String _friendlyNetworkError(dynamic error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('socketexception') || msg.contains('failed host lookup') || msg.contains('no address associated')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'The request timed out. Please check your connection and try again.';
    }
    if (msg.contains('connection refused') || msg.contains('connection reset')) {
      return 'Could not reach the server. Please try again later.';
    }
    if (msg.contains('cognito') || msg.contains('credential')) {
      return 'Authentication failed. Please restart the app and try again.';
    }
    return 'A connection error occurred. Please check your internet and try again.';
  }

  /// Guarantee exactly one king per side.
  ///   0 kings → promote lowest-conf queen to king; if no queen, promote lowest-conf bishop.
  ///   2+ kings → keep highest-conf as king; demote extras to queen (if none) else bishop.
  void _ensureOneKing(
    List<_PieceInfo> kings,
    List<_PieceInfo> queens,
    List<_PieceInfo> bishops,
    List<List<String?>> board,
    {required bool isWhite}
  ) {
    final String k = isWhite ? 'K' : 'k';
    final String q = isWhite ? 'Q' : 'q';
    final String b = isWhite ? 'B' : 'b';

    if (kings.isEmpty) {
      if (queens.isNotEmpty) {
        queens.sort((a, c) => a.conf.compareTo(c.conf));
        final p = queens.removeAt(0);
        board[p.row][p.col] = k;
      } else if (bishops.isNotEmpty) {
        bishops.sort((a, c) => a.conf.compareTo(c.conf));
        final p = bishops.removeAt(0);
        board[p.row][p.col] = k;
      }
    } else if (kings.length >= 2) {
      kings.sort((a, c) => c.conf.compareTo(a.conf));
      final bool hasQueen = queens.isNotEmpty;
      for (int i = 1; i < kings.length; i++) {
        final extra = kings[i];
        if (!hasQueen && i == 1) {
          board[extra.row][extra.col] = q;
        } else {
          board[extra.row][extra.col] = b;
        }
      }
    }
  }

  /// Convert piece label to FEN character
  String? _labelToFenChar(String label) {
    // Expected format: "white-king", "black-pawn", etc.
    final parts = label.toLowerCase().split('-');
    if (parts.length != 2) return null;
    
    final color = parts[0];
    final piece = parts[1];
    
    String? char;
    switch (piece) {
      case 'king': char = 'k'; break;
      case 'queen': char = 'q'; break;
      case 'rook': char = 'r'; break;
      case 'bishop': char = 'b'; break;
      case 'knight': char = 'n'; break;
      case 'pawn': char = 'p'; break;
      default: return null;
    }
    
    return color == 'white' ? char.toUpperCase() : char;
  }

  /// Compute inverse perspective matrix
  /// Maps from quadrilateral to unit square [0,1]x[0,1]
  List<double> _computeInversePerspectiveMatrix(
    double x0, double y0,  // top-left → (0, 0)
    double x1, double y1,  // top-right → (1, 0)
    double x2, double y2,  // bottom-left → (0, 1)
    double x3, double y3,  // bottom-right → (1, 1)
  ) {
    // First compute forward matrix (unit square → quad)
    final double dx1 = x1 - x3;
    final double dx2 = x2 - x3;
    final double dx3 = x0 - x1 + x3 - x2;
    
    final double dy1 = y1 - y3;
    final double dy2 = y2 - y3;
    final double dy3 = y0 - y1 + y3 - y2;
    
    final double denom = dx1 * dy2 - dx2 * dy1;
    
    if (denom.abs() < 1e-10) {
      // Fallback to simple affine inverse
      return [1, 0, 0, 0, 1, 0, 0, 0, 1];
    }
    
    final double g = (dx3 * dy2 - dx2 * dy3) / denom;
    final double h = (dx1 * dy3 - dx3 * dy1) / denom;
    
    final double a = x1 - x0 + g * x1;
    final double b = x2 - x0 + h * x2;
    final double c = x0;
    
    final double d = y1 - y0 + g * y1;
    final double e = y2 - y0 + h * y2;
    final double f = y0;
    
    // Forward matrix: [a, b, c, d, e, f, g, h, 1]
    // Now compute its inverse using adjugate method
    final double A = e - f * h;
    final double B = c * h - b;
    final double C = b * f - c * e;
    final double D = f * g - d;
    final double E = a - c * g;
    final double F = c * d - a * f;
    final double G = d * h - e * g;
    final double H = b * g - a * h;
    final double I = a * e - b * d;
    
    // Determinant
    final double det = a * A + b * D + c * G;
    if (det.abs() < 1e-10) {
      return [1, 0, 0, 0, 1, 0, 0, 0, 1];
    }
    
    // Return inverse matrix (normalized)
    return [
      A / det, B / det, C / det,
      D / det, E / det, F / det,
      G / det, H / det, I / det,
    ];
  }

  /// Apply inverse perspective transform to get unit square coordinates
  Offset _applyInversePerspective(double x, double y, List<double> m) {
    final double w = m[6] * x + m[7] * y + m[8];
    if (w.abs() < 1e-10) return const Offset(0.5, 0.5);
    
    final double u = (m[0] * x + m[1] * y + m[2]) / w;
    final double v = (m[3] * x + m[4] * y + m[5]) / w;
    
    return Offset(u.clamp(0.0, 1.0), v.clamp(0.0, 1.0));
  }

  /// Get piece counts for display in board editor
  Map<String, int> _getPieceCounts() {
    if (_detectedPieces == null) return {};
    
    final Map<String, int> counts = {};
    for (final piece in _detectedPieces!) {
      final label = piece['label'] as String;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts;
  }

  /// Determine which board edge was tapped using angle from board center
  void _handleWhiteSideTap(TapDownDetails details, double containerW, double containerH) {
    if (_displayCorners.isEmpty || _imageWidth == null || _imageHeight == null) return;

    final corners = _displayCorners;
    final double imageAR = _imageWidth! / _imageHeight!;
    final double containerAR = containerW / containerH;
    double dw, dh, ox, oy;
    if (imageAR > containerAR) {
      dw = containerW; dh = containerW / imageAR; ox = 0; oy = (containerH - dh) / 2;
    } else {
      dh = containerH; dw = containerH * imageAR; ox = (containerW - dw) / 2; oy = 0;
    }
    final double sx = dw / _imageWidth!;
    final double sy = dh / _imageHeight!;

    Offset tp(dynamic p) {
      final l = p is List ? p : [0, 0];
      return Offset(ox + (l[0] as num).toDouble() * sx, oy + (l[1] as num).toDouble() * sy);
    }

    final tl = tp(corners['top_left']);
    final tr = tp(corners['top_right']);
    final bl = tp(corners['bottom_left']);
    final br = tp(corners['bottom_right']);

    // Board center
    final cx = (tl.dx + tr.dx + bl.dx + br.dx) / 4;
    final cy = (tl.dy + tr.dy + bl.dy + br.dy) / 4;

    final tap = details.localPosition;
    final angle = atan2(tap.dy - cy, tap.dx - cx);

    String side;
    if (angle >= -pi / 4 && angle < pi / 4) {
      side = 'right';
    } else if (angle >= pi / 4 && angle < 3 * pi / 4) {
      side = 'bottom';
    } else if (angle >= -3 * pi / 4 && angle < -pi / 4) {
      side = 'top';
    } else {
      side = 'left';
    }
    setState(() => _whiteSide = side);
  }

  /// Show a full-screen photo guide with tips and example images
  void _showPhotoGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF302E2B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.tips_and_updates_rounded, color: Color(0xFF69946B), size: 26),
                        const SizedBox(width: 10),
                        const Text(
                          'Photo Tips',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close, color: Colors.white.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Follow these tips for the most accurate board detection',
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.4)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Scrollable content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      children: [
                        // ── Tips section ──
                        _buildTipItem(
                          icon: Icons.camera_rounded,
                          title: 'Shoot from above at an angle',
                          description: 'Hold your phone above the board at roughly a 45° angle. A slight tilt is fine — you don\'t need a perfectly top-down shot.',
                        ),
                        _buildTipItem(
                          icon: Icons.stay_current_portrait_rounded,
                          title: 'Hold phone vertically',
                          description: 'Take the photo in portrait mode (vertical). Landscape photos may crop the board edges.',
                        ),
                        _buildTipItem(
                          icon: Icons.light_mode_rounded,
                          title: 'Good, even lighting',
                          description: 'Avoid harsh shadows on the board. Natural daylight or a well-lit room works best.',
                        ),
                        _buildTipItem(
                          icon: Icons.texture_rounded,
                          title: 'Plain background',
                          description: 'Use a simple, solid-color surface under the board. Patterned tablecloths or busy backgrounds can confuse the detector.',
                        ),
                        _buildTipItem(
                          icon: Icons.crop_free_rounded,
                          title: 'Full board visible',
                          description: 'Make sure all 4 corners of the board are clearly visible in the frame. Leave a small margin around the board.',
                        ),

                        const SizedBox(height: 24),

                        // ── Good examples ──
                        Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: const Color(0xFF69946B), size: 22),
                            const SizedBox(width: 8),
                            const Text(
                              'Good Examples',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF69946B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildExampleImage(
                                'assets/photo_guide/good_image.jpg',
                                'Clear lighting, plain background',
                                true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildExampleImage(
                                'assets/photo_guide/good_image2.jpeg',
                                'Good angle, all corners visible',
                                true,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── Bad examples ──
                        Row(
                          children: [
                            Icon(Icons.cancel_rounded, color: const Color(0xFFC37B76), size: 22),
                            const SizedBox(width: 8),
                            const Text(
                              'Avoid These',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFC37B76),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildExampleImage(
                                'assets/photo_guide/bad_background.jpg',
                                'Patterned/busy background',
                                false,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildExampleImage(
                                'assets/photo_guide/bad_lighting.jpg',
                                'Poor lighting',
                                false,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── Quick summary card ──
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF69946B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF69946B).withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quick Checklist',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF69946B),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildChecklistItem('Phone held vertically (portrait)'),
                              _buildChecklistItem('All 4 board corners visible'),
                              _buildChecklistItem('Good, even lighting'),
                              _buildChecklistItem('Plain background surface'),
                              _buildChecklistItem('Shot from above at an angle'),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildTipItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF69946B), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleImage(String assetPath, String caption, bool isGood) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isGood
                  ? const Color(0xFF69946B).withOpacity(0.5)
                  : const Color(0xFFC37B76).withOpacity(0.5),
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isGood ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isGood ? const Color(0xFF69946B) : const Color(0xFFC37B76),
              size: 14,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                caption,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.check_rounded, color: const Color(0xFF69946B), size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFF262522),
        appBar: AppBar(
          title: Text(
            _isAdjusting
                ? 'Adjust Corners'
                : _isManualCornerMode
                    ? 'Set Corners Manually'
                    : _selectingWhiteSide
                        ? 'Select White Side'
                        : 'Board Scanner',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: const Color(0xFF1A1916),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: _isAdjusting
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() { _isAdjusting = false; });
                  },
                )
              : _isManualCornerMode
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _isManualCornerMode = false;
                          _manualCornerStep = 0;
                          _manualCornerPoints = [null, null, null, null];
                        });
                      },
                    )
                  : _selectingWhiteSide
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () {
                            setState(() { _selectingWhiteSide = false; _cornersApproved = false; });
                          },
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Back',
                        ),
          actions: [
            // Show photo guide help button only on the main scanner view
            if (!_isAdjusting && !_isManualCornerMode && !_selectingWhiteSide)
              IconButton(
                icon: const Icon(Icons.help_outline_rounded, size: 24),
                onPressed: _showPhotoGuide,
                tooltip: 'Photo Tips',
              ),
          ],
        ),
        body: _isAdjusting
            ? _buildAdjustmentView()
            : _isManualCornerMode
                ? _buildManualCornerView()
                : _selectingWhiteSide
                    ? _buildWhiteSideSelectionView()
                    : _buildDetectionView(),
    );
  }

  Widget _buildAdjustmentView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: CornerAdjustmentWidget(
        imageFile: _selectedImage!,
        imageWidth: _imageWidth!,
        imageHeight: _imageHeight!,
        initialCorners: _adjustedCorners!,
        onCornersConfirmed: _onCornersConfirmed,
      ),
    );
  }

  Widget _buildManualCornerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instruction banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF69946B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF69946B).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(
                  _manualCornerStep < 4 ? Icons.touch_app_rounded : Icons.check_circle_rounded,
                  color: const Color(0xFF69946B),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _manualCornerStep < 4
                        ? 'Tap the ${_cornerLabels[_manualCornerStep]} corner of the chessboard'
                        : 'All corners placed. Review and confirm.',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final bool isPlaced = _manualCornerPoints[i] != null;
              final bool isCurrent = i == _manualCornerStep && _manualCornerStep < 4;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPlaced
                            ? _cornerColors[i]
                            : isCurrent
                                ? _cornerColors[i].withOpacity(0.4)
                                : Colors.white.withOpacity(0.1),
                        border: Border.all(
                          color: isCurrent ? _cornerColors[i] : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: isPlaced
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? Colors.white : Colors.white.withOpacity(0.4),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _cornerLabels[i].split('-').map((w) => w[0]).join(''),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isPlaced
                            ? _cornerColors[i]
                            : isCurrent
                                ? Colors.white
                                : Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // Image with tap-to-place overlay
          LayoutBuilder(
            builder: (context, outerConstraints) {
              final double availableWidth = outerConstraints.maxWidth;
              double containerHeight = 220.0;
              if (_imageWidth != null && _imageHeight != null) {
                final aspectRatio = _imageWidth! / _imageHeight!;
                containerHeight = (availableWidth / aspectRatio).clamp(200.0, 520.0);
              }
              return Container(
                height: containerHeight,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onTapDown: _manualCornerStep < 4
                            ? (details) => _handleManualCornerTap(
                                  details, constraints.maxWidth, constraints.maxHeight)
                            : null,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(_selectedImage!, fit: BoxFit.contain),
                            // Paint placed corners and connecting lines
                            CustomPaint(
                              size: Size(constraints.maxWidth, constraints.maxHeight),
                              painter: ManualCornerPainter(
                                points: _manualCornerPoints,
                                currentStep: _manualCornerStep,
                                imageWidth: _imageWidth!,
                                imageHeight: _imageHeight!,
                                containerWidth: constraints.maxWidth,
                                containerHeight: constraints.maxHeight,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Undo button
          if (_manualCornerStep > 0 && _manualCornerStep < 4)
            OutlinedButton.icon(
              onPressed: _undoLastCorner,
              icon: const Icon(Icons.undo_rounded, size: 20),
              label: const Text(
                'Undo Last Point',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: Colors.white.withOpacity(0.8),
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

          // Reset + Confirm row when all 4 corners placed
          if (_manualCornerStep >= 4) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _manualCornerStep = 0;
                        _manualCornerPoints = [null, null, null, null];
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text(
                      'Reset',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: const Color(0xFFC37B76),
                      side: const BorderSide(color: Color(0xFFC37B76)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _applyManualCorners,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text(
                      'Confirm Corners',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF69946B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── White side selection view: tap a region on the image to choose white's side ──
  Widget _buildWhiteSideSelectionView() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instruction
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_rounded, color: Colors.green[700], size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tap the side of the board where White pieces are',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green[800]!.withOpacity(0.85)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Image with edge-region overlay
              LayoutBuilder(
                builder: (context, outerConstraints) {
                  final double availableWidth = outerConstraints.maxWidth;
                  double containerHeight = 220.0;
                  if (_selectedImage != null && _imageWidth != null && _imageHeight != null) {
                    final aspectRatio = _imageWidth! / _imageHeight!;
                    containerHeight = (availableWidth / aspectRatio).clamp(200.0, 520.0);
                  }
                  return Container(
                    height: containerHeight,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onTapDown: (details) => _handleWhiteSideTap(
                              details, constraints.maxWidth, constraints.maxHeight,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(_selectedImage!, fit: BoxFit.contain),
                                // Grid overlay
                                if (_displayCorners.isNotEmpty && _imageWidth != null && _imageHeight != null)
                                  CustomPaint(
                                    size: Size(constraints.maxWidth, constraints.maxHeight),
                                    painter: GridPainter(
                                      corners: _displayCorners,
                                      imageWidth: _imageWidth!,
                                      imageHeight: _imageHeight!,
                                      containerWidth: constraints.maxWidth,
                                      containerHeight: constraints.maxHeight,
                                    ),
                                  ),
                                // Edge selection overlay
                                if (_displayCorners.isNotEmpty && _imageWidth != null && _imageHeight != null)
                                  CustomPaint(
                                    size: Size(constraints.maxWidth, constraints.maxHeight),
                                    painter: WhiteSideSelectionPainter(
                                      corners: _displayCorners,
                                      imageWidth: _imageWidth!,
                                      imageHeight: _imageHeight!,
                                      containerWidth: constraints.maxWidth,
                                      containerHeight: constraints.maxHeight,
                                      selectedSide: _whiteSide,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Currently selected side badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF69946B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('♔', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        'White is on ${_whiteSide[0].toUpperCase()}${_whiteSide.substring(1)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Detect Pieces button
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectingWhiteSide = false;
                    _isDetectingPieces = true;
                    _detectionStatusMessage = 'Analyzing board image...';
                  });
                  _detectPieces();
                },
                icon: const Icon(Icons.search_rounded),
                label: const Text(
                  'Detect Pieces',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF69946B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),

        // Detection loading overlay (same as detection view)
        if (_isDetectingPieces)
          Container(
            color: Colors.black.withOpacity(0.6),
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(40),
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF302E2B),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 48, height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF69946B)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _detectionStatusMessage,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text('Please wait...', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetectionView() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          // Chess Quote Display - only show when no corners detected yet
          if (_displayCorners.isEmpty)
            GestureDetector(
              onTap: _loadRandomQuote,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote, color: const Color(0xFF69946B), size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentQuote,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withOpacity(0.85),
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '— $_currentAuthor',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF69946B),
                          ),
                        ),
                        Icon(Icons.refresh, color: Colors.white.withOpacity(0.4), size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          
          // Image display area — adapts to image aspect ratio
          LayoutBuilder(
            builder: (context, outerConstraints) {
              final double availableWidth = outerConstraints.maxWidth;
              // Calculate height from actual image aspect ratio (no extra white bars)
              double containerHeight;
              if (_selectedImage != null && _imageWidth != null && _imageHeight != null) {
                final aspectRatio = _imageWidth! / _imageHeight!;
                containerHeight = (availableWidth / aspectRatio).clamp(200.0, 520.0);
              } else {
                containerHeight = 220; // compact placeholder when no image
              }
              return Container(
                height: containerHeight,
                decoration: BoxDecoration(
                  color: _selectedImage != null ? Colors.black : const Color(0xFF302E2B),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _selectedImage != null
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                // Image — BoxFit.cover fills the container, no white bars
                                Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.contain,
                                ),
                                // Corner overlay
                                if (_displayCorners.isNotEmpty && _imageWidth != null && _imageHeight != null)
                                  CustomPaint(
                                    size: Size(constraints.maxWidth, constraints.maxHeight),
                                    painter: CornerPainter(
                                      corners: _displayCorners,
                                      imageWidth: _imageWidth!,
                                      imageHeight: _imageHeight!,
                                      containerWidth: constraints.maxWidth,
                                      containerHeight: constraints.maxHeight,
                                      isAdjusted: _adjustedCorners != null,
                                    ),
                                  ),
                                // Grid overlay (8x8 squares)
                                if (_showGrid && _displayCorners.isNotEmpty && _imageWidth != null && _imageHeight != null)
                                  CustomPaint(
                                    size: Size(constraints.maxWidth, constraints.maxHeight),
                                    painter: GridPainter(
                                      corners: _displayCorners,
                                      imageWidth: _imageWidth!,
                                      imageHeight: _imageHeight!,
                                      containerWidth: constraints.maxWidth,
                                      containerHeight: constraints.maxHeight,
                                    ),
                                  ),
                                // Small refresh/change image button in top-right
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: IconButton(
                                      onPressed: _isLoading ? null : _showImageSourcePicker,
                                      icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
                                      iconSize: 22,
                                      tooltip: 'Change Image',
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 64,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No image selected',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Pick Image Buttons - Camera + Gallery side by side
          if (_selectedImage == null) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _pickImage(source: ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text(
                      'Take Photo',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF69946B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _pickImage(source: ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text(
                      'Gallery',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF557B57),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Start to Analyze Button - only show when corners not yet detected
          if (_displayCorners.isEmpty && _selectedImage != null) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: !_isLoading
                    ? () => _detectCorners(useDynamic: true)
                    : null,
                icon: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 26),
                label: Text(
                  _isLoading ? 'Detecting board...' : 'Auto-Detect Board',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF69946B),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 3,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Manual corner placement option
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _enterManualCornerMode,
              icon: const Icon(Icons.touch_app_rounded, size: 20),
              label: const Text(
                'Or Mark Corners Manually',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: Colors.white.withOpacity(0.7),
                side: BorderSide(color: Colors.white.withOpacity(0.25)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Error message
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFC37B76).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC37B76).withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFC37B76)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFC37B76)),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedImage != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _enterManualCornerMode,
                        icon: const Icon(Icons.touch_app_rounded, size: 20),
                        label: const Text(
                          'Mark Corners Manually Instead',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFFC37B76),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // STEP 2: Corner adjustment (only when corners detected, not yet approved)
          if (_displayCorners.isNotEmpty && !_cornersApproved && !_isDetectingPieces) ...[
            // Adjust Corners Button
            OutlinedButton.icon(
              onPressed: _startAdjusting,
              icon: const Icon(Icons.touch_app_rounded, size: 20),
              label: Text(
                _adjustedCorners != null ? 'Re-adjust Corners' : 'Adjust Corners',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: const Color(0xFF69946B),
                side: const BorderSide(color: Color(0xFF69946B)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // STEP 3: Approve Corners → go to white side selection step
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _cornersApproved = true;
                  _selectingWhiteSide = true;
                  _whiteSide = 'bottom'; // default
                });
              },
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text(
                'Approve Corners',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF69946B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
          ],

          const SizedBox(height: 16),
            ],
          ),
        ),
        
        // Centered Loading Overlay
        if (_isDetectingPieces)
          Container(
            color: Colors.black.withOpacity(0.6),
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(40),
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF302E2B),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF69946B)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _detectionStatusMessage,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please wait...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

}

class CornerPainter extends CustomPainter {
  final Map<String, dynamic> corners;
  final int imageWidth;
  final int imageHeight;
  final double containerWidth;
  final double containerHeight;
  final bool isAdjusted;

  CornerPainter({
    required this.corners,
    required this.imageWidth,
    required this.imageHeight,
    required this.containerWidth,
    required this.containerHeight,
    this.isAdjusted = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate how BoxFit.contain displays the image
    final double imageAspectRatio = imageWidth / imageHeight;
    final double containerAspectRatio = containerWidth / containerHeight;
    
    double displayWidth, displayHeight;
    double offsetX, offsetY;
    
    if (imageAspectRatio > containerAspectRatio) {
      displayWidth = containerWidth;
      displayHeight = containerWidth / imageAspectRatio;
      offsetX = 0;
      offsetY = (containerHeight - displayHeight) / 2;
    } else {
      displayHeight = containerHeight;
      displayWidth = containerHeight * imageAspectRatio;
      offsetX = (containerWidth - displayWidth) / 2;
      offsetY = 0;
    }
    
    final double scaleX = displayWidth / imageWidth;
    final double scaleY = displayHeight / imageHeight;
    
    Offset transformPoint(dynamic point) {
      final List<dynamic> p = point is List ? point : [0, 0];
      final double x = offsetX + (p[0] as num).toDouble() * scaleX;
      final double y = offsetY + (p[1] as num).toDouble() * scaleY;
      return Offset(x, y);
    }

    final tl = transformPoint(corners['top_left']);
    final tr = transformPoint(corners['top_right']);
    final bl = transformPoint(corners['bottom_left']);
    final br = transformPoint(corners['bottom_right']);

    // Draw semi-transparent fill
    final fillPaint = Paint()
      ..color = (isAdjusted ? Colors.orange : Colors.blue).withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    canvas.drawPath(path, fillPaint);

    // Draw connecting lines
    final linePaint = Paint()
      ..color = isAdjusted ? Colors.orange : Colors.yellow
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);

    // Draw corner points
    _drawCorner(canvas, tl, Colors.red, 'TL');
    _drawCorner(canvas, tr, Colors.blue, 'TR');
    _drawCorner(canvas, bl, Colors.green, 'BL');
    _drawCorner(canvas, br, Colors.orange, 'BR');
  }

  void _drawCorner(Canvas canvas, Offset point, Color color, String label) {
    // Outer circle (white border)
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, 14, borderPaint);

    // Inner circle (colored)
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, 10, fillPaint);

    // Label
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(point.dx - textPainter.width / 2, point.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CornerPainter oldDelegate) {
    return oldDelegate.corners != corners ||
           oldDelegate.imageWidth != imageWidth ||
           oldDelegate.imageHeight != imageHeight ||
           oldDelegate.containerWidth != containerWidth ||
           oldDelegate.containerHeight != containerHeight ||
           oldDelegate.isAdjusted != isAdjusted;
  }
}

class GridPainter extends CustomPainter {
  final Map<String, dynamic> corners;
  final int imageWidth;
  final int imageHeight;
  final double containerWidth;
  final double containerHeight;

  GridPainter({
    required this.corners,
    required this.imageWidth,
    required this.imageHeight,
    required this.containerWidth,
    required this.containerHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate how BoxFit.contain displays the image
    final double imageAspectRatio = imageWidth / imageHeight;
    final double containerAspectRatio = containerWidth / containerHeight;
    
    double displayWidth, displayHeight;
    double offsetX, offsetY;
    
    if (imageAspectRatio > containerAspectRatio) {
      displayWidth = containerWidth;
      displayHeight = containerWidth / imageAspectRatio;
      offsetX = 0;
      offsetY = (containerHeight - displayHeight) / 2;
    } else {
      displayHeight = containerHeight;
      displayWidth = containerHeight * imageAspectRatio;
      offsetX = (containerWidth - displayWidth) / 2;
      offsetY = 0;
    }
    
    final double scaleX = displayWidth / imageWidth;
    final double scaleY = displayHeight / imageHeight;
    
    Offset transformPoint(dynamic point) {
      final List<dynamic> p = point is List ? point : [0, 0];
      final double x = offsetX + (p[0] as num).toDouble() * scaleX;
      final double y = offsetY + (p[1] as num).toDouble() * scaleY;
      return Offset(x, y);
    }

    // Get the four corners in display coordinates
    final tl = transformPoint(corners['top_left']);
    final tr = transformPoint(corners['top_right']);
    final bl = transformPoint(corners['bottom_left']);
    final br = transformPoint(corners['bottom_right']);

    // Paint for grid lines
    final gridPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Use perspective transformation (like in the Python notebook)
    // We need to compute the inverse perspective transform to map
    // regular grid points to the distorted quadrilateral
    
    // Compute the 3x3 perspective transformation matrix
    // This maps from a unit square [0,1]x[0,1] to the quadrilateral
    final matrix = _computePerspectiveMatrix(
      tl.dx, tl.dy,  // top-left -> (0, 0)
      tr.dx, tr.dy,  // top-right -> (1, 0)
      bl.dx, bl.dy,  // bottom-left -> (0, 1)
      br.dx, br.dy,  // bottom-right -> (1, 1)
    );
    
    // Transform a point from unit square to quadrilateral using perspective matrix
    Offset perspectiveTransform(double u, double v) {
      final double w = matrix[6] * u + matrix[7] * v + matrix[8];
      final double x = (matrix[0] * u + matrix[1] * v + matrix[2]) / w;
      final double y = (matrix[3] * u + matrix[4] * v + matrix[5]) / w;
      return Offset(x, y);
    }

    // Draw 8x8 grid using perspective transformation
    // This correctly handles the perspective distortion
    for (int i = 0; i <= 8; i++) {
      final double t = i / 8.0;
      
      // Horizontal lines: connect points along each row
      for (int j = 0; j < 8; j++) {
        final double u1 = j / 8.0;
        final double u2 = (j + 1) / 8.0;
        final p1 = perspectiveTransform(u1, t);
        final p2 = perspectiveTransform(u2, t);
        canvas.drawLine(p1, p2, gridPaint);
      }
      
      // Vertical lines: connect points along each column
      for (int j = 0; j < 8; j++) {
        final double v1 = j / 8.0;
        final double v2 = (j + 1) / 8.0;
        final p1 = perspectiveTransform(t, v1);
        final p2 = perspectiveTransform(t, v2);
        canvas.drawLine(p1, p2, gridPaint);
      }
    }
  }
  
  /// Compute 3x3 perspective transformation matrix
  /// Maps unit square corners to the given quadrilateral corners:
  /// (0,0) -> (x0,y0), (1,0) -> (x1,y1), (0,1) -> (x2,y2), (1,1) -> (x3,y3)
  List<double> _computePerspectiveMatrix(
    double x0, double y0,  // top-left
    double x1, double y1,  // top-right
    double x2, double y2,  // bottom-left
    double x3, double y3,  // bottom-right
  ) {
    // Using the standard perspective transform equations
    // Solving for the 8 unknowns (9th is normalized to 1)
    
    final double dx1 = x1 - x3;
    final double dx2 = x2 - x3;
    final double dx3 = x0 - x1 + x3 - x2;
    
    final double dy1 = y1 - y3;
    final double dy2 = y2 - y3;
    final double dy3 = y0 - y1 + y3 - y2;
    
    final double denom = dx1 * dy2 - dx2 * dy1;
    
    if (denom.abs() < 1e-10) {
      // Fallback to affine transform if perspective is degenerate
      return [
        x1 - x0, x2 - x0, x0,
        y1 - y0, y2 - y0, y0,
        0, 0, 1
      ];
    }
    
    final double g = (dx3 * dy2 - dx2 * dy3) / denom;
    final double h = (dx1 * dy3 - dx3 * dy1) / denom;
    
    final double a = x1 - x0 + g * x1;
    final double b = x2 - x0 + h * x2;
    final double c = x0;
    
    final double d = y1 - y0 + g * y1;
    final double e = y2 - y0 + h * y2;
    final double f = y0;
    
    return [a, b, c, d, e, f, g, h, 1.0];
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.corners != corners ||
           oldDelegate.imageWidth != imageWidth ||
           oldDelegate.imageHeight != imageHeight ||
           oldDelegate.containerWidth != containerWidth ||
           oldDelegate.containerHeight != containerHeight;
  }
}

/// Draws 4 semi-transparent edge regions on the image for white-side selection.
/// The selected side is highlighted in green; others are dark/dim.
class WhiteSideSelectionPainter extends CustomPainter {
  final Map<String, dynamic> corners;
  final int imageWidth;
  final int imageHeight;
  final double containerWidth;
  final double containerHeight;
  final String selectedSide;

  WhiteSideSelectionPainter({
    required this.corners,
    required this.imageWidth,
    required this.imageHeight,
    required this.containerWidth,
    required this.containerHeight,
    required this.selectedSide,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Compute display transform
    final double imageAR = imageWidth / imageHeight;
    final double containerAR = containerWidth / containerHeight;
    double dw, dh, ox, oy;
    if (imageAR > containerAR) {
      dw = containerWidth; dh = containerWidth / imageAR; ox = 0; oy = (containerHeight - dh) / 2;
    } else {
      dh = containerHeight; dw = containerHeight * imageAR; ox = (containerWidth - dw) / 2; oy = 0;
    }
    final double sx = dw / imageWidth;
    final double sy = dh / imageHeight;

    Offset tp(dynamic p) {
      final l = p is List ? p : [0, 0];
      return Offset(ox + (l[0] as num).toDouble() * sx, oy + (l[1] as num).toDouble() * sy);
    }

    final tl = tp(corners['top_left']);
    final tr = tp(corners['top_right']);
    final bl = tp(corners['bottom_left']);
    final br = tp(corners['bottom_right']);

    // Image display bounds
    final imgTL = Offset(ox, oy);
    final imgTR = Offset(ox + dw, oy);
    final imgBL = Offset(ox, oy + dh);
    final imgBR = Offset(ox + dw, oy + dh);

    // 4 regions: space between board edge and image edge
    _drawRegion(canvas, [imgTL, imgTR, tr, tl], 'top');
    _drawRegion(canvas, [bl, br, imgBR, imgBL], 'bottom');
    _drawRegion(canvas, [imgTL, tl, bl, imgBL], 'left');
    _drawRegion(canvas, [tr, imgTR, imgBR, br], 'right');
  }

  void _drawRegion(Canvas canvas, List<Offset> pts, String side) {
    final isSelected = selectedSide == side;

    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..lineTo(pts[3].dx, pts[3].dy)
      ..close();

    // Fill
    canvas.drawPath(
      path,
      Paint()
        ..color = isSelected
            ? const Color(0xFF059669).withOpacity(0.50)
            : Colors.black.withOpacity(0.35)
        ..style = PaintingStyle.fill,
    );

    // Border for selected
    if (isSelected) {
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF059669)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // Label at region center
    final cx = pts.fold<double>(0, (s, p) => s + p.dx) / pts.length;
    final cy = pts.fold<double>(0, (s, p) => s + p.dy) / pts.length;

    final label = isSelected ? '♔ White' : '♔';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white.withOpacity(isSelected ? 1.0 : 0.7),
          fontSize: isSelected ? 14 : 18,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant WhiteSideSelectionPainter old) {
    return old.selectedSide != selectedSide ||
        old.corners != corners ||
        old.containerWidth != containerWidth ||
        old.containerHeight != containerHeight;
  }
}

/// Paints manually placed corner points and connecting lines during manual corner placement.
class ManualCornerPainter extends CustomPainter {
  final List<Offset?> points; // TL, TR, BR, BL (image coords)
  final int currentStep;
  final int imageWidth;
  final int imageHeight;
  final double containerWidth;
  final double containerHeight;

  // Corner colors matching _cornerColors in the state: TL=red, TR=blue, BR=orange, BL=green
  static const List<Color> _colors = [Colors.red, Colors.blue, Colors.orange, Colors.green];
  static const List<String> _labels = ['TL', 'TR', 'BR', 'BL'];

  ManualCornerPainter({
    required this.points,
    required this.currentStep,
    required this.imageWidth,
    required this.imageHeight,
    required this.containerWidth,
    required this.containerHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double imageAR = imageWidth / imageHeight;
    final double containerAR = containerWidth / containerHeight;
    double dw, dh, ox, oy;
    if (imageAR > containerAR) {
      dw = containerWidth; dh = containerWidth / imageAR; ox = 0; oy = (containerHeight - dh) / 2;
    } else {
      dh = containerHeight; dw = containerHeight * imageAR; ox = (containerWidth - dw) / 2; oy = 0;
    }

    // Convert image coords to screen coords
    Offset toScreen(Offset imgPt) {
      return Offset(
        ox + (imgPt.dx / imageWidth) * dw,
        oy + (imgPt.dy / imageHeight) * dh,
      );
    }

    // Collect placed screen points
    final List<Offset> screenPts = [];
    for (int i = 0; i < 4; i++) {
      if (points[i] != null) {
        screenPts.add(toScreen(points[i]!));
      }
    }

    // Draw connecting lines between placed points
    if (screenPts.length >= 2) {
      final linePaint = Paint()
        ..color = Colors.yellow.withOpacity(0.7)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(screenPts[0].dx, screenPts[0].dy);
      for (int i = 1; i < screenPts.length; i++) {
        path.lineTo(screenPts[i].dx, screenPts[i].dy);
      }
      // Close polygon if all 4 are placed
      if (screenPts.length == 4) {
        path.close();

        // Draw semi-transparent fill
        final fillPaint = Paint()
          ..color = Colors.yellow.withOpacity(0.08)
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, fillPaint);
      }
      canvas.drawPath(path, linePaint);
    }

    // Draw each placed corner point
    for (int i = 0; i < 4; i++) {
      if (points[i] == null) continue;
      final sp = toScreen(points[i]!);

      // White border
      canvas.drawCircle(sp, 14, Paint()..color = Colors.white..style = PaintingStyle.fill);
      // Colored fill
      canvas.drawCircle(sp, 10, Paint()..color = _colors[i]..style = PaintingStyle.fill);
      // Label text
      final tp = TextPainter(
        text: TextSpan(
          text: _labels[i],
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(sp.dx - tp.width / 2, sp.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant ManualCornerPainter old) {
    return old.currentStep != currentStep ||
        old.containerWidth != containerWidth ||
        old.containerHeight != containerHeight;
  }
}

class _PieceInfo {
  final int row;
  final int col;
  final double conf;
  _PieceInfo(this.row, this.col, this.conf);
}
