import 'package:chess_on_dart/chess_on_dart.dart';

void main() {
  final game = Game();
  print('Legal moves: ${game.legalMoves.length}');

  final move = Move.parseUCI('e2e4');
  print('SAN: ${game.getMoveSAN(move)}');
  game.tryMove(move);
  print(game.toFEN());

  game.undoMove(move);
  print('Back at start: ${game.toFEN() == Game.startingPositionFen}');
}
