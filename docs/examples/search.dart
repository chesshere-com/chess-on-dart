import 'package:chess_on_dart/chess_on_dart.dart';

int perft(Game game, int depth) {
  if (depth == 0) return 1;
  if (depth == 1) return game.legalMoves.length;
  final moves = game.legalMoves;
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

void main() {
  final game = Game();
  print('Depth 3: ${perft(game, 3)} nodes');
  print('Position restored: ${game.toFEN() == Game.startingPositionFen}');
}
