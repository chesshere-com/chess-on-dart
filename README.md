# Chess on Dart

[![Pub Version](https://img.shields.io/pub/v/chess_on_dart)](https://pub.dev/packages/chess_on_dart)
[![Dart CI](https://github.com/chesshere-com/chess-on-dart/actions/workflows/dart.yml/badge.svg)](https://github.com/chesshere-com/chess-on-dart/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A ultra-high-performance, zero-allocation **bitboard chess rules engine** written in pure Dart. It supports standard chess, Fischer Random (Chess960), and popular variants like King of the Hill and Three-Check.

Perfect for building chess applications, analysis boards, and bots in Dart or Flutter.

Developed by [ChessHere](https://www.chesshere.com/).

---

## Features

- **⚡ High Performance**: Powered by optimized 64-bit integer Bitboards, precomputed attack masks, and Magic Bitboards for sliding pieces.
- **🚫 Zero Runtime Allocations**: Designed to prevent garbage collection overhead by avoiding object allocations in critical move-generation and evaluation loops.
- **♟️ Standard & Chess960**: Complete validation of legal chess moves, en-passant, promotions, and castling rights (supporting standard castling as well as Chess960 double-move castling).
- **🏆 Chess Variants Supported**:
  - **Standard Chess**
  - **Chess960 (Fischer Random)**
  - **King of the Hill**: Win by placing your king on one of the four center squares (`d4`, `d5`, `e4`, `e5`).
  - **Three-Check**: Win by checking the opponent's king three times.
- **📄 Import & Export**:
  - Full **FEN** (Forsythe-Edwards Notation) import/export.
  - Full **PGN** (Portable Game Notation) tagging, tokenizing, loading, and exporting.
  - Full **SAN** (Standard Algebraic Notation) and **UCI** (Universal Chess Interface) move parsing.
- **🔍 State Detection**: Checkmate, stalemate, draw by insufficient material, threefold repetition, 50-move rule, and 75-move rule.

---

## Installation

Add `chess_on_dart` to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  chess_on_dart: ^0.1.0
```

And run:
```bash
dart pub get
```

---

## Usage

### 1. Standard Chess Quickstart
```dart
import 'package:chess_on_dart/chess_on_dart.dart';

void main() {
  // Initialize standard game state
  final game = Game();
  print('Initial FEN: ${game.toFEN()}');

  // List all legal moves
  print('Legal moves (${game.legalMoves.length}):');
  for (final move in game.legalMoves) {
    print('  - ${move.uci()} (SAN: ${game.getMoveSAN(move)})');
  }

  // Play a move using UCI coordinate notation (e.g. e2e4)
  game.tryMove(Move.parseUCI('e2e4'));
  
  // Play another move using SAN notation (e.g. e5)
  // Or load standard PGN moves:
  game.loadPGN('1. e4 e5 2. Nf3 Nc6');
  print('FEN after moves: ${game.toFEN()}');

  // Game Status checking
  print('Is game finished? ${game.isFinished}');
  print('Status: ${game.status}');
}
```

### 2. Playing Variants (Three-Check & King of the Hill)
```dart
import 'package:chess_on_dart/chess_on_dart.dart';

void main() {
  // --- King of the Hill ---
  final kothGame = Game();
  kothGame.loadFEN('k7/8/8/8/3K4/8/8/8 w - - 0 1', Variant.kingOfTheHill);
  print('KOTH Finished? ${kothGame.isFinished}'); // true
  print('KOTH Winner: ${kothGame.winner == whiteColor ? "White" : "Black"}'); // White

  // --- Three-Check ---
  final tcGame = Game();
  tcGame.loadFEN('4k3/8/8/8/8/8/8/3Q3K w - - 0 1', Variant.threeCheck);
  // Give White 2 checks already
  tcGame.variantState = VariantState(checksGiven: [2, 0]);
  tcGame.generateLegalMoves();

  // Play Qd1-e2+ giving the 3rd check
  tcGame.tryMove(Move.parseUCI('d1e2'));
  print('Three-Check Finished? ${tcGame.isFinished}'); // true
  print('Three-Check Winner: ${tcGame.winner == whiteColor ? "White" : "Black"}'); // White
}
```

### 3. Playing Chess960 (Fischer Random)
```dart
import 'package:chess_on_dart/chess_on_dart.dart';

void main() {
  final game = Game();
  
  // Load a Chess960 position using Fischerandom Variant
  // SP0: bbqnnrkr/pppppppp/8/8/8/8/PPPPPPPP/BBQNNRKR w HFhf - 0 1
  game.loadFEN(
    'bbqnnrkr/pppppppp/8/8/8/8/PPPPPPPP/BBQNNRKR w HFhf - 0 1',
    Variant.chess960,
  );
  
  print('Chess960 Legal moves: ${game.legalMoves.length}');
}
```

### 4. Move Representation
To keep the engine allocation-free, `Move` is implemented as a Dart **extension type** wrapping a 32-bit integer. It encodes:
- Source square (6 bits)
- Target square (6 bits)
- Promotion piece kind (3 bits)
- Captured piece kind (3 bits)
- Special flags: en-passant (1 bit), castling (1 bit), promotion flag (1 bit)

```dart
final move = Move.make(Square.parse('e2'), Square.parse('e4'));
print(move.from().name); // e2
print(move.to().name);   // e4
print(move.isCastling()); // false
```

---

## Development & Verification

If you want to contribute or verify the package's correctness and performance, you can use the following commands:

### 1. Static Analysis
Verify that the codebase complies with Dart formatting and standard guidelines:
```bash
dart analyze
```

### 2. Running Tests
Run the entire test suite (including unit tests, PGN/FEN parsing tests, variant tests, and validation perft tests):
```bash
dart test
```

### 3. Benchmarks
Execute the Perft (Performance Test) move generation benchmark to measure node search performance on the Dart VM:
```bash
dart run benchmark/perft_benchmark.dart
```

---

## License

This package is licensed under the MIT License. See [LICENSE](LICENSE) for details.
