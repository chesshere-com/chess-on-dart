import 'dart:convert';
import 'dart:io';

import 'package:chess_on_dart/chess_on_dart.dart';
import 'package:chess_on_dart/src/sliding_attacks.dart';
import 'package:test/test.dart';

String moveKey(Move move) =>
    '${move.uci()}${move.isCastling() ? ' castle' : ''}';

void assertBoardConsistent(Game game) {
  var white = 0;
  var black = 0;
  final whites = List<int>.filled(7, 0);
  final blacks = List<int>.filled(7, 0);
  for (var square = 0; square < 64; square++) {
    final piece = game.squares[square];
    if (piece == Piece.empty) continue;
    if (piece.isWhite) {
      white |= 1 << square;
      whites[piece.kind()] |= 1 << square;
    } else {
      black |= 1 << square;
      blacks[piece.kind()] |= 1 << square;
    }
  }
  expect(game.whitePieces.value, white);
  expect(game.blackPieces.value, black);
  expect(game.whites.map((b) => b.value), whites);
  expect(game.blacks.map((b) => b.value), blacks);
  expect(game.occupied.value, white | black);
  expect(game.zobristHash, game.computeZobrist());
}

int walkAttacks(int square, int occupied, List<(int, int)> directions) {
  var result = 0;
  for (final (dr, df) in directions) {
    var rank = square ~/ 8 + dr;
    var file = square % 8 + df;
    while (rank >= 0 && rank < 8 && file >= 0 && file < 8) {
      final bit = 1 << (rank * 8 + file);
      result |= bit;
      if ((occupied & bit) != 0) break;
      rank += dr;
      file += df;
    }
  }
  return result;
}

void main() {
  final data =
      jsonDecode(File('test/fixtures/oracle_positions.json').readAsStringSync())
          as Map<String, dynamic>;
  final positions = data['positions'] as List<dynamic>;
  group('Independent python-chess oracle', () {
    for (var i = 0; i < positions.length; i++) {
      final entry = positions[i] as Map<String, dynamic>;
      test('position $i ${entry['variant']}', () {
        final variant = Variant.values.byName(entry['variant'] as String);
        final game = Game()..loadFEN(entry['fen'] as String, variant);
        expect(game.legalMoves.map(moveKey).toList()..sort(), entry['moves']);
        expect(game.isCheck, entry['check']);
        expect(game.hasInsufficientMaterial(), entry['insufficient']);
        assertBoardConsistent(game);
        final beforeMoves = List<Move>.of(game.legalMoves);
        final hash = game.zobristHash;
        for (final move in beforeMoves) {
          game.makeMoveFast(move);
          assertBoardConsistent(game);
          if (moveKey(move) == entry['selected']) {
            expect(game.toFEN(), entry['after']);
          }
          game.undoMoveFast(move);
          expect(game.toFEN(), entry['fen']);
          expect(game.zobristHash, hash);
          expect(game.legalMoves, beforeMoves);
          assertBoardConsistent(game);
          if (moveKey(move) == entry['selected']) {
            expect(game.getMoveSAN(move), entry['san']);
          }
        }
      });
    }
  });
  test('magic tables match ray walking for every relevant occupancy', () {
    initSlidingAttacks();
    for (final bishop in [false, true]) {
      final directions = bishop
          ? const [(1, 1), (1, -1), (-1, 1), (-1, -1)]
          : const [(1, 0), (-1, 0), (0, 1), (0, -1)];
      for (var square = 0; square < 64; square++) {
        final mask =
            (bishop ? bishopAttackTables : rookAttackTables)[square].mask.value;
        var subset = 0;
        do {
          final actual = bishop
              ? bishopAttacks(Square(square), Bitboard(subset))
              : rookAttacks(Square(square), Bitboard(subset));
          expect(actual.value, walkAttacks(square, subset, directions),
              reason: 'square=$square occupancy=$subset bishop=$bishop');
          subset = (subset - mask) & mask;
        } while (subset != 0);
      }
    }
  });
  test('all 960 starting layouts are unique and round trip', () {
    final layouts = <String>{};
    final game = Game();
    for (var index = 0; index < 960; index++) {
      expect(layouts.add(chess960BackRank(index)), isTrue);
      final fen = chess960StartingFEN(index);
      game.loadFEN(fen, Variant.chess960);
      expect(game.toFEN(), fen);
      assertBoardConsistent(game);
    }
    expect(chess960BackRank(518), 'RNBQKBNR');
  });
}
