# Chesspector

**Chesspector** is an open-source Flutter mobile app that lets you photograph a real chessboard, detect pieces with AI, and analyze positions with the Stockfish chess engine.

## Features

- **Board Scanning** — Take a photo of any physical chessboard. The app detects board corners (automatically or manually) and identifies every piece using a YOLOv8 model running on AWS Lambda.
- **Stockfish Analysis** — Once a position is recognized, analyze it move-by-move with Stockfish. See evaluation scores, best move arrows, and step through engine lines.
- **Board Editor** — Manually adjust any detected position before analysis.
- **Play vs Stockfish** — Play a full game against Stockfish at adjustable depth (1-25). Save and resume games at any time.
- **Grandmaster Archive** — Browse 5,000 games from 20 legendary grandmasters (Alekhine, Anand, Capablanca, Carlsen, Fischer, Kasparov, Tal, and more). Replay any game move-by-move with Stockfish evaluation.
- **Game Saving** — Save positions from analysis or from games against Stockfish. Reopen them later and continue exactly where you left off.
- **Move Sounds** — Distinct audio feedback for normal moves, captures, castling, checks, and promotions.

## Screenshots

*Coming soon*

## Getting Started

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install) 3.x or higher
- Android Studio or Xcode (for running on a device/emulator)
- An AWS account (for the image-processing backend — see [Backend Setup](#backend-setup))

### Installation

```bash
git clone https://github.com/siromermer/Chesspector-app.git
cd Chesspector-app

flutter pub get
flutter run
```

### Configuration

The app communicates with AWS Lambda endpoints for corner detection and piece detection. These credentials are stored in `lib/api_config.dart`, which is **git-ignored** to prevent leaking secrets.

1. Copy the template:
   ```bash
   cp lib/api_config.example.dart lib/api_config.dart
   ```
2. Fill in your own values in `lib/api_config.dart`:
   - AWS region
   - Cognito Identity Pool ID (for anonymous authentication)
   - API Gateway endpoints for corner detection and piece detection

See `lib/api_config.example.dart` for the exact format.

### Backend Setup

Chesspector's image processing runs on three AWS Lambda functions behind API Gateway:

| Endpoint | Purpose |
|---|---|
| **Static Corner Detection** | Detects chessboard corners using OpenCV |
| **Dynamic Corner Detection** | Alternative corner detection for different perspectives |
| **Piece Detection** | Identifies chess pieces using a YOLOv8 model |

Authentication is handled via **AWS Cognito Identity Pool** (unauthenticated access) with **SigV4-signed** requests. You will need to deploy your own Lambda functions and configure the endpoints in `api_config.dart`.

## Project Structure

```
lib/
├── main.dart                    # App entry point & analysis game screen
├── main_menu_page.dart          # Home screen with feature navigation
├── corner_detection_page.dart   # Board scanning, corner & piece detection
├── corner_adjustment_widget.dart# Manual corner adjustment UI
├── board_editor_page.dart       # Manual board position editor
├── game_viewer_page.dart        # Master archive game replay with Stockfish
├── play_computer_page.dart      # Play vs Stockfish (setup + game)
├── masters_list_page.dart       # Grandmaster archive list
├── master_games_list_page.dart  # Individual grandmaster's game list
├── pgn_parser.dart              # PGN parsing utilities
├── saved_games_page.dart        # Saved games list
├── game_storage.dart            # Game persistence (SharedPreferences)
├── sound_service.dart           # Audio feedback for moves
├── aws_auth_service.dart        # AWS Cognito auth & SigV4 signed requests
├── api_config.dart              # API endpoints & credentials (git-ignored)
└── api_config.example.dart      # Template for api_config.dart
```

## Building for Release

### Android

```bash
# Create a keystore (one-time)
keytool -genkey -v -keystore android/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Create android/key.properties with your keystore details:
# storePassword=<your-password>
# keyPassword=<your-password>
# keyAlias=upload
# storeFile=../upload-keystore.jks

# Build release AAB
flutter build appbundle --release
```

The signing configuration in `android/app/build.gradle.kts` automatically reads from `key.properties`.

## License

This project is licensed under the **GNU General Public License v3.0** — see the [LICENSE](LICENSE) file for details.

Chesspector uses the [Stockfish](https://stockfishchess.org/) chess engine, which is licensed under GPL-3.0. This means the entire application must also be distributed under GPL-3.0.

## Acknowledgments

- **[Stockfish](https://github.com/official-stockfish/Stockfish)** — Free, powerful open-source chess engine (GPL-3.0)
- **[stockfish](https://pub.dev/packages/stockfish)** — Flutter/Dart package providing Stockfish bindings (GPL-3.0)
- **[flutter_chess_board](https://pub.dev/packages/flutter_chess_board)** — Chessboard widget for Flutter
- **[chess](https://pub.dev/packages/chess)** — Chess logic library for Dart
- **[OpenCV](https://github.com/opencv/opencv)** — Computer vision library used in backend corner detection (Apache 2.0)
- **[YOLOv8](https://github.com/ultralytics/ultralytics)** — Object detection model used for piece recognition (AGPL-3.0)

## Author

**Omer Gunaydin**
- GitHub: [@siromermer](https://github.com/siromermer)
- Email: siromermer@gmail.com

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
