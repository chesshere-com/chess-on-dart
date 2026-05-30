import 'package:chess_on_dart/chess_on_dart.dart';

int perft(Game g, int depth) {
  if (depth == 0) return 1;
  final moves = List<Move>.from(g.legalMoves);
  if (depth == 1) return moves.length;
  int nodes = 0;
  for (var i = 0; i < moves.length; i++) {
    final m = moves[i];
    g.makeMoveFast(m);
    nodes += perft(g, depth - 1);
    g.undoMoveFast(m);
  }
  return nodes;
}

void main() {
  print('========================================');
  print('    Chess on Dart - Perft Benchmark     ');
  print('========================================\n');

  final game = Game();

  print('Benchmarking standard starting position FEN...');

  for (int depth = 1; depth <= 5; depth++) {
    game.loadFEN(Game.startingPositionFen);

    final stopwatch = Stopwatch()..start();
    final nodes = perft(game, depth);
    stopwatch.stop();

    final timeMs = stopwatch.elapsedMilliseconds;
    final nodesPerSec =
        timeMs > 0 ? (nodes / (timeMs / 1000.0)).round() : nodes;

    print('Depth $depth:');
    print('  - Nodes searched: $nodes');
    print('  - Time elapsed  : ${timeMs}ms');
    print('  - Speed         : $nodesPerSec nodes/second\n');
  }
  print('========================================');
}
