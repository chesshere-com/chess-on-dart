import 'dart:convert';
import 'dart:io';

import 'package:chess_on_dart/chess_on_dart.dart';

int perft(Game game, int depth) {
  if (depth == 0) return 1;
  if (depth == 1) return game.legalMoves.length;
  final moves = List<Move>.of(game.legalMoves);
  var nodes = 0;
  for (final move in moves) {
    game.makeMoveFast(move);
    nodes += perft(game, depth - 1);
    game.undoMoveFast(move);
  }
  return nodes;
}

// Fixed workloads and node counts make before/after measurements comparable.
const positions = [
  ('Starting position', Game.startingPositionFen, 5, 4865609),
  (
    'Kiwipete',
    'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
    4,
    4085603,
  ),
  ('Rook endgame', '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1', 5, 674624),
];

void main(List<String> args) {
  final results = <Map<String, Object>>[];
  for (final (name, fen, depth, expected) in positions) {
    final game = Game()..loadFEN(fen);
    // Warm up JIT compilation, attack tables, and reusable search buffers.
    for (var i = 0; i < 2; i++) {
      if (perft(game, depth) != expected) {
        throw StateError('Incorrect node count for $name');
      }
    }
    final samples = <int>[];
    for (var i = 0; i < 5; i++) {
      final timer = Stopwatch()..start();
      final nodes = perft(game, depth);
      timer.stop();
      if (nodes != expected || game.toFEN() != fen || game.history.isNotEmpty) {
        throw StateError('Incorrect search or undo for $name');
      }
      samples.add(timer.elapsedMicroseconds);
    }
    samples.sort();
    final median = samples[samples.length ~/ 2];
    results.add({
      'position': name,
      'depth': depth,
      'nodes': expected,
      'median_us': median,
      'nodes_per_second': (expected * 1000000 / median).round(),
      'samples_us': samples,
    });
  }
  if (args.contains('--json')) {
    print(jsonEncode({'dart': Platform.version, 'results': results}));
  } else {
    print('Dart ${Platform.version.split(' ').first}; 2 warmups, 5 samples');
    for (final result in results) {
      print('${result['position']} depth ${result['depth']}: '
          '${result['nodes']} nodes, '
          '${(result['median_us'] as int) / 1000} ms median, '
          '${result['nodes_per_second']} nodes/s');
    }
  }
}
