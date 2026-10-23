import 'piece.dart';
import 'square.dart';
import 'move.dart';

class VariantState {
  final List<int> checksGiven;

  VariantState({required List<int> checksGiven})
      : checksGiven = List<int>.of(checksGiven, growable: false) {
    if (checksGiven.length != 2 ||
        checksGiven.any((count) => count < 0 || count > 3)) {
      throw ArgumentError.value(checksGiven, 'checksGiven',
          'Expected two check counts between 0 and 3');
    }
  }

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
  final Move? move;
  final List<Move>? legalMoves;
  final bool isCheck;
  final bool recordsPosition;
  final PgnState? pgnState;

  const GameState({
    required this.capturedPiece,
    required this.castling,
    required this.castlingRookFrom,
    required this.variantState,
    required this.enPassant,
    required this.halfMoves,
    required this.fullMoves,
    required this.zobristHash,
    this.move,
    this.legalMoves,
    this.isCheck = false,
    this.recordsPosition = true,
    this.pgnState,
  });
}

/// PGN metadata saved only for recorded game moves, never for search moves.
class PgnState {
  final Map<String, String>? tags;
  final String result;
  final int startTurn;
  final int startFullMove;
  final String startFEN;

  PgnState({
    required Map<String, String>? tags,
    required this.result,
    required this.startTurn,
    required this.startFullMove,
    required this.startFEN,
  }) : tags = tags == null ? null : Map<String, String>.of(tags);

  PgnState clone() => PgnState(
        tags: tags,
        result: result,
        startTurn: startTurn,
        startFullMove: startFullMove,
        startFEN: startFEN,
      );
}
