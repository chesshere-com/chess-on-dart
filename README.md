# Chess on Dart

[![Pub Version](https://img.shields.io/pub/v/chess_on_dart)](https://pub.dev/packages/chess_on_dart)
[![Dart CI](https://github.com/chesshere-com/chess-on-dart/actions/workflows/dart.yml/badge.svg)](https://github.com/chesshere-com/chess-on-dart/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A high-performance **bitboard chess rules engine** written in pure Dart for native Dart and Flutter applications. It supports standard chess, Fischer Random (Chess960), and popular variants like King of the Hill and Three-Check.

Build chess applications, analysis boards, and bots on the Dart VM or native AOT runtime.

The engine relies on native 64-bit integer arithmetic. JavaScript compilation and Flutter web are not supported; WebAssembly has not been validated.

Developed by [ChessHere](https://www.chesshere.com/).

Visit the **[documentation website](https://chesshere-com.github.io/chess-on-dart/)** for runnable examples, an API guide, recorded move replays, and analysis of the native benchmark results. See the [documentation source and build instructions](https://github.com/chesshere-com/chess-on-dart/blob/main/docs/README.md) to run it locally.

---

## Features

- **⚡ High Performance**: Powered by optimized 64-bit integer Bitboards, precomputed attack masks, and Magic Bitboards for sliding pieces.
- **Reusable Search Buffers**: Legal-move and pin-analysis buffers are reused, castling geometry is cached, and undo restores parent moves without regenerating them. Move values are packed integers; undo records and public import/export APIs still allocate.
- **♟️ Standard & Chess960**: Complete validation of legal chess moves, en-passant, promotions, and castling rights (supporting standard castling as well as Chess960 double-move castling).
- **🏆 Chess Variants Supported**:
  - **Standard Chess**
  - **Chess960 (Fischer Random)**
  - **King of the Hill**: Win by placing your king on one of the four center squares (`d4`, `d5`, `e4`, `e5`).
  - **Three-Check**: Win by checking the opponent's king three times.
- **📄 Import & Export**:
  - Full **FEN** (Forsythe-Edwards Notation) import/export.
  - **PGN** main-line import/export with escaped tags, compact move numbers, comments, NAGs, and skipped variations.
  - Full **SAN** (Standard Algebraic Notation) and **UCI** (Universal Chess Interface) move parsing.
- **🔍 State Detection**: Checkmate, stalemate, draw by insufficient material, threefold repetition, 50-move rule, and 75-move rule.

---

## Installation

Install the [pub.dev package](https://pub.dev/packages/chess_on_dart):

```bash
dart pub add chess_on_dart
```

Or add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  chess_on_dart: ^0.2.0
```

And run:
```bash
dart pub get
```

Version `0.2.0` includes the correctness fixes and native performance improvements described in the [changelog](CHANGELOG.md).

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
  // The final field records checks already given by White and Black.
  tcGame.loadFEN('4k3/8/8/8/8/8/8/3Q3K w - - 0 1 +2+0', Variant.threeCheck);

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
To avoid allocating a separate object for every move, `Move` is a Dart **extension type** wrapping a packed integer. It encodes:
- Source square (6 bits)
- Target square (6 bits)
- Promotion piece kind (3 bits; zero means no promotion)
- Captured piece kind (4 bits)
- Special flags: en-passant (1 bit), castling (1 bit)

```dart
final move = Move.make(Square.parse('e2'), Square.parse('e4'));
print(move.from().coords()); // e2
print(move.to().coords());   // e4
print(move.isCastling()); // false
```

### 5. Validated game moves and search

Use `tryMove` or `makeMove` for recorded game moves. Both resolve coordinate requests to legal moves and reject moves after a terminal board status. Construct `Game(enforceGameEnd: false)` when an application decides game end itself, such as an analysis board or a replay of moves a server accepted: recorded moves and `loadPGN` then continue past automatic draws (insufficient material, fivefold repetition, the 75-move rule) while `isFinished` and `status` still describe each position. Invalid FEN/PGN imports throw `FormatException` and leave the game unchanged. FEN validation checks structure, counters, king counts, pawn ranks, castling pieces, en-passant geometry, and the non-moving king's safety; it does not prove that a position is historically reachable.

`makeMoveFast` requires a move from the current `legalMoves`. It updates the board, Zobrist hash, check flag, and child moves while skipping PGN, repetition counts, and terminal-status refresh. Pair it with `undoMoveFast`, and pair recorded moves with `undoMove`. Undo verifies that the requested move matches the most recent move.

```dart
int perft(Game game, int depth) {
  if (depth == 0) return 1;
  if (depth == 1) return game.legalMoves.length;
  final moves = game.legalMoves; // Preserved while visiting child positions.
  var nodes = 0;
  for (final move in moves) {
    game.makeMoveFast(move);
    try {
      nodes += perft(game, depth - 1);
    } finally {
      game.undoMoveFast(move);
    }
  }
  return nodes;
}
```

Treat board arrays and `legalMoves` as read-only during play/search. Move buffers are reused at each depth; copy a list when retaining it beyond a make/undo traversal. Prefer `loadFEN` to editing board fields, since direct edits do not automatically synchronize hashes, history, and status.

Chess960 generated castling moves retain the king-to-destination encoding. Pass the generated move (including its castling flag) to distinguish it from an ordinary king move with the same coordinates. Coordinate requests also accept UCI_Chess960 king-to-rook notation.

---

## Development & Verification

If you want to contribute or verify the package's correctness and performance, you can use the following commands:

### 1. Static Analysis
Verify that the codebase complies with Dart formatting and standard guidelines:
```bash
dart analyze
```

### 2. Running Tests
Run the full suite, including canonical perft counts, transactional import regressions, random make/undo invariants, 332 independent oracle positions, all 960 initial layouts, and exhaustive sliding-attack table checks:
```bash
dart test
```

### 3. Benchmarks
The benchmark verifies node counts, warms each workload twice, and reports the median of five runs. It covers the starting position, Kiwipete, and a rook endgame. Run it on the VM or compile it for native AOT:
```bash
dart run benchmark/perft_benchmark.dart
dart compile exe benchmark/perft_benchmark.dart -o /tmp/chess-perft
/tmp/chess-perft --json
```

The audit comparison uses the same benchmark harness for both revisions, including the same move-list snapshots. On macOS ARM64 with Dart 3.13.4, three alternating AOT runs used about **60% less user CPU time** after the changes (about **2.5×** the throughput per CPU second). This measures these fixed workloads on one machine, not a guarantee for every application. Raw results and methodology are in `benchmark/results/native_audit.json`.

Oracle fixtures were generated with python-chess 1.11.2 (the `python-chess==1.999` distribution). Normal Dart tests require no Python dependency. To regenerate them:

```bash
python3 -m pip install python-chess==1.999
python3 tool/generate_oracle.py
```

---

## License

This package is licensed under the MIT License. See [LICENSE](LICENSE) for details.
