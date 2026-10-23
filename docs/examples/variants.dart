import 'package:chess_on_dart/chess_on_dart.dart';

void main() {
  final chess960 = Game()..loadFEN(chess960StartingFEN(0), Variant.chess960);
  print('Chess960 #0: ${chess960.toFEN()}');

  final hill = Game()
    ..loadFEN('k7/8/8/8/8/3K4/8/8 w - - 0 1', Variant.kingOfTheHill);
  hill.tryMove(Move.parseUCI('d3d4'));
  print('King of the Hill: ${hill.status.name}');

  final checks = Game()
    ..loadFEN('4k3/8/8/8/8/8/8/3Q3K w - - 0 1 +2+0', Variant.threeCheck);
  checks.tryMove(Move.parseUCI('d1e2'));
  print('Three-Check: ${checks.variantState.checksGiven[0]} checks, '
      '${checks.status.name}');
}
