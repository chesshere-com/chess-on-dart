import 'piece.dart';
import 'square.dart';

class VariantState {
  final List<int> checksGiven;

  VariantState({required List<int> checksGiven})
      : checksGiven = List.from(checksGiven);

  VariantState clone() {
    return VariantState(checksGiven: checksGiven);
  }
}

class GameState {
  final Piece capturedPiece;
  final int castling;
  final List<Square> castlingRookFrom;
  final VariantState variantState;
  final Square enPassant;
  final int halfMoves;
  final int fullMoves;
  final int zobristHash;

  const GameState({
    required this.capturedPiece,
    required this.castling,
    required this.castlingRookFrom,
    required this.variantState,
    required this.enPassant,
    required this.halfMoves,
    required this.fullMoves,
    required this.zobristHash,
  });
}
