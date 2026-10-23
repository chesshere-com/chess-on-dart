import 'package:chess_on_dart/chess_on_dart.dart';

void main() {
  final game = Game();
  // Loading a PGN replaces the game; it does not append moves.
  game.loadPGN('1.e4 e5 2.Nf3 Nc6 3.Bb5 a6');
  print(game.exportPGN());

  final before = game.toFEN();
  try {
    game.loadFEN('not a position');
  } on FormatException {
    print('Invalid FEN left the game unchanged: ${game.toFEN() == before}');
  }

  final copy = cloneGame(game);
  copy.tryMove(Move.parseUCI('b5a4'));
  print('Original unchanged: ${game.toFEN() == before}');
}
