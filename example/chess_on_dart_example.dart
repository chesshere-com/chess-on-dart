import 'package:chess_on_dart/chess_on_dart.dart';

void main() {
  print('========================================');
  print('     Chess on Dart - Example Code       ');
  print('========================================\n');

  // 1. Standard Chess Gameplay
  print('--- 1. Standard Chess Gameplay ---');
  final game = Game();
  print('Starting Position FEN: ${game.toFEN()}');

  // Print all legal moves from starting position
  print('Legal Moves count: ${game.legalMoves.length}');
  print('First few legal moves:');
  game.legalMoves.take(5).forEach((move) {
    print('  - UCI: ${move.uci()} | SAN: ${game.getMoveSAN(move)}');
  });

  // Play a move in coordinate format (UCI)
  print('\nPlaying e2e4...');
  game.tryMove(Move.parseUCI('e2e4'));
  print('FEN: ${game.toFEN()}');

  // Play a move in SAN format (via PGN string loader)
  print('Playing e7e5 (via PGN)...');
  game.loadPGN('1. e4 e5');
  print('FEN after e5: ${game.toFEN()}');
  print('Is check? ${game.isCheck}');
  print('Is finished? ${game.isFinished}\n');

  // 2. Playing Variants: King of the Hill
  print('--- 2. King of the Hill Variant ---');
  print(
      'Description: The game is won if the king reaches one of the four center squares (d4, d5, e4, e5).');
  final kothGame = Game();

  // Set up a custom position where White's King is on d4 (center) and Black's King is on a8
  kothGame.loadFEN('k7/8/8/8/3K4/8/8/8 w - - 0 1', Variant.kingOfTheHill);
  print('KOTH Finished? ${kothGame.isFinished}');
  print('KOTH Winner: ${kothGame.winner == whiteColor ? "White" : "Black"}');
  print('KOTH Game Status: ${kothGame.status}\n');

  // 3. Playing Variants: Three-Check
  print('--- 3. Three-Check Variant ---');
  print('Description: Checking the opponent king 3 times wins the game.');
  final threeCheckGame = Game();

  // Set up a custom position where White is about to check Black for the 3rd time
  threeCheckGame.loadFEN('4k3/8/8/8/8/8/8/3Q3K w - - 0 1', Variant.threeCheck);
  // Inject 2 checks already given by White
  threeCheckGame.variantState = VariantState(checksGiven: [2, 0]);
  threeCheckGame.generateLegalMoves();

  print('Checks given by White: ${threeCheckGame.variantState.checksGiven[0]}');
  print('Playing Qd1-e2+ (Checking black King)...');
  threeCheckGame.tryMove(Move.parseUCI('d1e2'));

  print(
      'Checks given by White now: ${threeCheckGame.variantState.checksGiven[0]}');
  print('Three-Check Finished? ${threeCheckGame.isFinished}');
  print('Winner: ${threeCheckGame.winner == whiteColor ? "White" : "Black"}\n');

  // 4. Fischer Random (Chess960)
  print('--- 4. Chess960 (Fischer Random) ---');
  final chess960Game = Game();

  // Load Chess960 SP 0 (BBQNNRKR) FEN
  const chess960FEN =
      'bbqnnrkr/pppppppp/8/8/8/8/PPPPPPPP/BBQNNRKR w HFhf - 0 1';
  chess960Game.loadFEN(chess960FEN, Variant.chess960);
  print('Chess960 FEN: ${chess960Game.toFEN()}');
  print(
      'Legal Moves in Chess960 Starting Position: ${chess960Game.legalMoves.length}');
  print('First few legal moves:');
  chess960Game.legalMoves.take(5).forEach((move) {
    print('  - ${move.uci()}');
  });
  print('\n========================================');
}
