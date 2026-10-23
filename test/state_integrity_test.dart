import 'dart:math';

import 'package:chess_on_dart/chess_on_dart.dart';
import 'package:chess_on_dart/src/zobrist.dart';
import 'package:test/test.dart';

import 'audit_regression_test.dart' show snapshot;
import 'oracle_test.dart' show assertBoardConsistent;

void main() {
  test('recorded random games undo exactly through every ply', () {
    final random = Random(271828);
    for (final variant in Variant.values) {
      final game = Game()..loadFEN(Game.startingPositionFen, variant);
      final states = <List<Object?>>[];
      final played = <Move>[];
      for (var ply = 0; ply < 100 && !game.isFinished; ply++) {
        states.add(snapshot(game));
        final move = game.legalMoves[random.nextInt(game.legalMoves.length)];
        played.add(move);
        game.makeMove(move);
        assertBoardConsistent(game);
      }
      while (played.isNotEmpty) {
        game.undoMove(played.removeLast());
        assertBoardConsistent(game);
        expect(snapshot(game), states.removeLast());
      }
    }
  });

  test('failed undo and mismatched fast/recorded APIs preserve state', () {
    final game = Game();
    final move = game.legalMoves.first;
    game.makeMove(move);
    final before = snapshot(game);
    expect(() => game.undoMove(Move.parseUCI('a1a8')), throwsArgumentError);
    expect(snapshot(game), before);
    expect(() => game.undoMoveFast(move), throwsStateError);
    expect(snapshot(game), before);
    game.undoMove(move);
    game.makeMoveFast(move);
    final fastBefore = snapshot(game);
    expect(() => game.undoMove(move), throwsStateError);
    expect(snapshot(game), fastBefore);
    game.undoMoveFast(move);
  });

  test('Chess960 accepts UCI king-to-rook coordinates', () {
    final game = Game()
      ..loadFEN('4k3/8/8/8/8/8/8/5K1R w H - 0 1', Variant.chess960);
    final before = snapshot(game);
    final request = Move.parseUCI('f1h1');
    expect(game.getMoveSAN(request), 'O-O');
    game.tryMove(request);
    expect(game.squares[Square.parse('g1').value], wKing);
    expect(game.squares[Square.parse('f1').value], wRook);
    game.undoMove(request);
    expect(snapshot(game), before);
  });

  test('terminal variant wins are not labelled stalemate', () {
    final game = Game()
      ..loadFEN('k7/8/8/8/3K4/8/8/8 w - - 0 1', Variant.kingOfTheHill);
    expect(game.legalMoves, isEmpty);
    expect(game.isStalemate, isFalse);
    expect(game.isCheckmate, isFalse);
    expect(game.status, GameStatus.variantWin);
  });

  test('PGN exports are pure and undo restores declared results', () {
    final game = Game()..loadPGN('[Event "Test"] [Result "1-0"]\n1.e4 e5');
    final before = snapshot(game);
    game.exportPGN();
    expect(snapshot(game), before);
    final move = game.legalMoves.first;
    game.makeMove(move);
    game.undoMove(move);
    expect(snapshot(game), before);
    for (final pgn in [
      '[Result "invalid"]\n1.e4',
      '[Result "1-0"]\n1.e4 0-1',
      '[Variant "unknown"]\n1.e4',
      '[Event "broken]',
      '1.e4 ) e5',
      '1.e4 } e5',
    ]) {
      expect(() => game.loadPGN(pgn), throwsFormatException);
      expect(snapshot(game), before);
    }
  });

  test('FEN mutations either load coherently or fail without side effects', () {
    final random = Random(314159);
    final game = Game();
    const chars = 'KQkrnp81/wb -09♔';
    for (var i = 0; i < 1000; i++) {
      game.loadFEN(Game.startingPositionFen);
      final before = snapshot(game);
      final at = random.nextInt(Game.startingPositionFen.length);
      final mutated = Game.startingPositionFen
          .replaceRange(at, at + 1, chars[random.nextInt(chars.length)]);
      try {
        game.loadFEN(mutated);
        assertBoardConsistent(game);
      } on FormatException {
        expect(snapshot(game), before, reason: mutated);
      }
    }
  });

  test('placing a piece replaces all old occupancy bits', () {
    final game = Game();
    final square = Square.parse('a2');
    game.addPiece(bKnight, square);
    expect(game.whites[typePawn].value & (1 << square.value), 0);
    expect(game.whitePieces.value & (1 << square.value), 0);
    expect(game.blacks[typeKnight].value & (1 << square.value), isNot(0));
    game.addPiece(Piece.empty, square);
    expect(game.occupied.value & (1 << square.value), 0);
    expect(() => game.addPiece(wPawn, Square.noSquare), throwsRangeError);
    expect(() => game.addPiece(const Piece(41), square), throwsArgumentError);
    expect(() => game.addPiece(const Piece(-23), square), throwsArgumentError);
    expect(zobristPieceIndex(const Piece(-1)), -1);
  });

  test('invalid variant counters fail at the public boundary', () {
    for (final counts in [
      <int>[],
      [0],
      [4, 0],
      [-1, 0],
      [0, 0, 0]
    ]) {
      expect(() => VariantState(checksGiven: counts), throwsArgumentError);
    }
  });

  test('SAN preserves external references to three-check counters', () {
    final game = Game()
      ..loadFEN('4k3/8/8/8/8/8/8/3Q3K w - - 0 1', Variant.threeCheck);
    final counters = game.variantState;
    expect(game.getMoveSAN(Move.parseUCI('d1e2')), 'Qe2+');
    expect(identical(game.variantState, counters), isTrue);
    expect(counters.checksGiven, [0, 0]);
  });
}
