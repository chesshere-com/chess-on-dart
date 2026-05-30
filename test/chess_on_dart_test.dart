import 'package:chess_on_dart/chess_on_dart.dart';
import 'package:test/test.dart';

void main() {
  group('FEN and Board Setup Tests', () {
    test('Standard Starting Position FEN', () {
      final game = Game();
      expect(game.toFEN(),
          equals('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'));
      expect(game.turn, equals(whiteColor));
      expect(game.isFinished, isFalse);
    });

    test('Load Custom FEN and Export', () {
      final game = Game();
      const customFEN =
          'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3';
      game.loadFEN(customFEN);
      expect(game.toFEN(), equals(customFEN));
      expect(game.turn, equals(whiteColor));
      expect(game.halfMoves, equals(2));
      expect(game.fullMoves, equals(3));
    });
  });

  group('PGN and SAN Tests', () {
    test('Load PGN and Move Legality', () {
      final game = Game();
      game.loadPGN('1. e4 e5 2. Nf3 Nc6 3. Bb5 a6');
      expect(
          game.toFEN(),
          equals(
              'r1bqkbnr/1ppp1ppp/p1n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 4'));
      expect(game.pgnMoves.length, equals(6));
      expect(game.pgnMoves, equals(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6']));
    });

    test('Export PGN', () {
      final game = Game();
      game.loadPGN('1. e4 e5 2. Nf3 Nc6');
      final pgn = game.exportPGN();
      expect(pgn, contains('1. e4 e5'));
      expect(pgn, contains('2. Nf3 Nc6'));
    });

    test(
        'Load and Export Evergreen Game (Adolf Anderssen vs Jean Dufresne, 1852)',
        () {
      final game = Game();
      const evergreenPGN =
          '1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. b4 Bxb4 5. c3 Ba5 6. d4 exd4 7. O-O d3 8. Qb3 Qf6 9. e5 Qg6 10. Re1 Nge7 11. Ba3 b5 12. Qxb5 Rb8 13. Qa4 Bb6 14. Nbd2 Bb7 15. Ne4 Qf5 16. Bxd3 Qh5 17. Nf6+ gxf6 18. exf6 Rg8 19. Rad1 Qxf3 20. Rxe7+ Nxe7 21. Qxd7+ Kxd7 22. Bf5+ Ke8 23. Bd7+ Kf8 24. Bxe7#';
      game.loadPGN(evergreenPGN);

      expect(game.toFEN(),
          equals('1r3kr1/pbpBBp1p/1b3P2/8/8/2P2q2/P4PPP/3R2K1 b - - 0 24'));
      expect(game.isFinished, isTrue);
      expect(game.isCheckmate, isTrue);
      expect(game.winner, equals(whiteColor));

      final exported = game.exportPGN();
      expect(exported, contains('24. Bxe7#'));
    });

    test(
        'Load and Export Opera Game (Paul Morphy vs Duke Karl / Count Isouard, 1858)',
        () {
      final game = Game();
      const operaPGN =
          '1. e4 e5 2. Nf3 d6 3. d4 Bg4 4. dxe5 Bxf3 5. Qxf3 dxe5 6. Bc4 Nf6 7. Qb3 Qe7 8. Nc3 c6 9. Bg5 b5 10. Nxb5 cxb5 11. Bxb5+ Nbd7 12. O-O-O Rd8 13. Rxd7 Rxd7 14. Rd1 Qe6 15. Bxd7+ Nxd7 16. Qb8+ Nxb8 17. Rd8#';
      game.loadPGN(operaPGN);

      expect(game.toFEN(),
          equals('1n1Rkb1r/p4ppp/4q3/4p1B1/4P3/8/PPP2PPP/2K5 b k - 1 17'));
      expect(game.isFinished, isTrue);
      expect(game.isCheckmate, isTrue);
      expect(game.winner, equals(whiteColor));

      final exported = game.exportPGN();
      expect(exported, contains('17. Rd8#'));
    });
  });

  group('Variant Rules Tests', () {
    test('King of the Hill - White wins by placing King on center', () {
      final game = Game();
      game.loadFEN('k7/8/8/8/3K4/8/8/8 w - - 0 1', Variant.kingOfTheHill);
      expect(game.isFinished, isTrue);
      expect(game.winner, equals(whiteColor));
    });

    test('Three Check - White wins by checking three times', () {
      final game = Game();
      game.loadFEN('4k3/8/8/8/8/8/8/3Q3K w - - 0 1', Variant.threeCheck);
      game.variantState = VariantState(checksGiven: [2, 0]);
      game.generateLegalMoves();
      game.tryMove(Move.parseUCI('d1e2'));
      expect(game.isFinished, isTrue);
      expect(game.winner, equals(whiteColor));
    });
  });

  group('Game End State Tests', () {
    test("Fool's Mate (Checkmate)", () {
      final game = Game();
      game.tryMove(Move.parseUCI('f2f3')); // 1. f3
      game.tryMove(Move.parseUCI('e7e5')); // 1... e5
      game.tryMove(Move.parseUCI('g2g4')); // 2. g4
      game.tryMove(Move.parseUCI('d8h4')); // 2... Qh4#

      expect(game.isCheck, isTrue);
      expect(game.isCheckmate, isTrue);
      expect(game.isFinished, isTrue);
      expect(game.winner, equals(blackColor));
      expect(game.status, equals(GameStatus.checkmate));
    });

    test('Stalemate detection', () {
      final game = Game();
      // White King on h1, Black Queen on f2, Black King on a8
      // White to move has no moves and is not in check.
      game.loadFEN('k7/8/8/8/8/8/5q2/7K w - - 0 1');

      expect(game.isCheck, isFalse);
      expect(game.isStalemate, isTrue);
      expect(game.isFinished, isTrue);
      expect(game.status, equals(GameStatus.stalemate));
    });

    test('Insufficient Material draws', () {
      final game = Game();

      // King vs King
      game.loadFEN('k7/8/8/8/8/8/8/7K w - - 0 1');
      expect(game.isMaterialDraw, isTrue);
      expect(game.status, equals(GameStatus.drawInsufficientMaterial));

      // King + Bishop vs King
      game.loadFEN('k7/8/8/8/8/8/8/6BK w - - 0 1');
      expect(game.isMaterialDraw, isTrue);

      // King + Knight vs King
      game.loadFEN('k7/8/8/8/8/8/8/6NK w - - 0 1');
      expect(game.isMaterialDraw, isTrue);

      // King + Bishop vs King + Bishop on same color square (both dark-squared)
      // White Bishop on c1, Black Bishop on b8, Kings on h1 and f8
      game.loadFEN('1b3k2/8/8/8/8/8/8/2B4K w - - 0 1');
      expect(game.isMaterialDraw, isTrue);
    });

    test('50-move and 75-move rules', () {
      final game = Game();
      // Add pawns on a2 and a7 so that it's not a King-vs-King draw
      game.loadFEN('k7/p7/8/8/8/8/P7/7K w - - 99 1'); // 99 half moves
      game.tryMove(Move.parseUCI('h1g1')); // Make it 100
      expect(game.isFiftyMoveRule, isTrue);
      expect(game.isFinished, isFalse); // FIDE 50-move rule requires a claim
      expect(game.status, equals(GameStatus.ongoing));

      // Test 75-move rule (which is an automatic terminal draw)
      final game2 = Game();
      game2.loadFEN('k7/p7/8/8/8/8/P7/7K w - - 149 1'); // 149 half moves
      game2.tryMove(Move.parseUCI('h1g1')); // Make it 150
      expect(game2.isSeventyFiveMoveRule, isTrue);
      expect(game2.isFinished, isTrue);
      expect(game2.status, equals(GameStatus.drawSeventyFiveMoveRule));
    });

    test('Threefold and Fivefold Repetitions', () {
      final game = Game();
      // Execute repeating moves:
      // 1. Nf3 Nf6 2. Ng1 Ng8 (1st repeat)
      // 3. Nf3 Nf6 4. Ng1 Ng8 (2nd repeat -> Threefold Repetition)
      game.tryMove(Move.parseUCI('g1f3'));
      game.tryMove(Move.parseUCI('g8f6'));
      game.tryMove(Move.parseUCI('f3g1'));
      game.tryMove(Move.parseUCI('f6g8')); // 1st repetition of initial position

      game.tryMove(Move.parseUCI('g1f3'));
      game.tryMove(Move.parseUCI('g8f6'));
      game.tryMove(Move.parseUCI('f3g1'));
      game.tryMove(Move.parseUCI('f6g8')); // 2nd repetition -> 3fold
      expect(game.isThreefoldRepetition, isTrue);
      expect(game.isFinished, isFalse); // Threefold is claimable, not automatic
      expect(game.status, equals(GameStatus.ongoing));

      game.tryMove(Move.parseUCI('g1f3'));
      game.tryMove(Move.parseUCI('g8f6'));
      game.tryMove(Move.parseUCI('f3g1'));
      game.tryMove(Move.parseUCI('f6g8')); // 3rd repetition

      game.tryMove(Move.parseUCI('g1f3'));
      game.tryMove(Move.parseUCI('g8f6'));
      game.tryMove(Move.parseUCI('f3g1'));
      game.tryMove(Move.parseUCI('f6g8')); // 4th repetition -> 5fold
      expect(game.isFinished, isTrue); // 5fold is automatic draw
      expect(game.status, equals(GameStatus.drawFivefoldRepetition));
    });
  });

  group('Promotion Tests', () {
    test('White Pawn promotes to all pieces', () {
      for (final type in [
        (typeQueen, 'q'),
        (typeRook, 'r'),
        (typeBishop, 'b'),
        (typeKnight, 'n')
      ]) {
        final game = Game();
        game.loadFEN('2k3r1/P7/8/8/8/8/8/7K w - - 0 1');
        game.tryMove(Move.parseUCI('a7a8${type.$2}'));
        final piece = game.squares[Square.parse('a8').value];
        expect(piece.kind(), equals(type.$1));
        expect(piece.isWhite, isTrue);
        expect(game.squares[Square.parse('a7').value], equals(Piece.empty));
      }
    });

    test('Black Pawn promotes to all pieces', () {
      for (final type in [
        (typeQueen, 'q'),
        (typeRook, 'r'),
        (typeBishop, 'b'),
        (typeKnight, 'n')
      ]) {
        final game = Game();
        game.loadFEN('7k/8/8/8/8/8/p7/2K3R1 b - - 0 1');
        game.tryMove(Move.parseUCI('a2a1${type.$2}'));
        final piece = game.squares[Square.parse('a1').value];
        expect(piece.kind(), equals(type.$1));
        expect(piece.isBlack, isTrue);
        expect(game.squares[Square.parse('a2').value], equals(Piece.empty));
      }
    });
  });

  group('Chess960 Castling Tests', () {
    test('Chess960 castling generated from non-standard King square', () {
      final game = Game();
      game.loadFEN('6k1/8/8/8/8/8/8/5RK1 w F - 0 1', Variant.chess960);
      final uciMoves = game.legalMoves.map((m) => m.uci()).toList();
      expect(uciMoves, contains('g1c1'));
    });

    test('Chess960 castling generated when King already on final square', () {
      final game = Game();
      game.loadFEN('6k1/8/8/8/8/8/8/6KR w H - 0 1', Variant.chess960);
      final uciMoves = game.legalMoves.map((m) => m.uci()).toList();
      expect(uciMoves, contains('g1g1'));
    });

    test('Chess960 kingside castle where King does not move', () {
      final game = Game();
      const startFEN = '6k1/8/8/8/8/8/8/6KR w H - 0 1';
      game.loadFEN(startFEN, Variant.chess960);

      // Find the g1g1 castling move
      final castleMove = game.legalMoves.firstWhere((m) => m.uci() == 'g1g1');
      game.makeMove(castleMove);

      expect(game.squares[Square.parse('g1').value], equals(wKing));
      expect(game.squares[Square.parse('f1').value], equals(wRook));
      expect(game.castling & castleWks, equals(0));

      game.undoMove(castleMove);
      expect(game.toFEN(), equals(startFEN));
    });

    test('Chess960 queenside castle interchanges King and Rook', () {
      final game = Game();
      game.loadFEN('4k3/8/8/8/8/8/8/2RK4 w C - 0 1', Variant.chess960);
      game.tryMove(Move.parseUCI('d1c1'));

      expect(game.squares[Square.parse('c1').value], equals(wKing));
      expect(game.squares[Square.parse('d1').value], equals(wRook));
    });

    test('Chess960 moving castling Rook clears only that right', () {
      final game = Game();
      game.loadFEN('6k1/8/8/8/8/8/8/4R1KR w HE - 0 1', Variant.chess960);

      // Move the Queen-side Rook e1e2
      game.tryMove(Move.parseUCI('e1e2'));

      // White queenside castling (right E) is cleared, but kingside (right H) remains
      expect(game.castling & castleWqs, equals(0));
      expect(game.castling & castleWks, isNot(equals(0)));
    });

    test('Chess960 castling blocked by pieces between King and Rook', () {
      final game = Game();
      game.loadFEN('6k1/8/8/8/8/8/8/4BRK1 w F - 0 1', Variant.chess960);
      final uciMoves = game.legalMoves.map((m) => m.uci()).toList();
      expect(uciMoves, isNot(contains('g1c1')));
    });

    test('Chess960 castling requires safe King path', () {
      final game = Game();
      // Enemy Rook on c3 controls f1 (path)
      game.loadFEN('6k1/8/8/8/8/2r5/8/5RK1 w F - 0 1', Variant.chess960);
      final uciMoves = game.legalMoves.map((m) => m.uci()).toList();
      expect(uciMoves, isNot(contains('g1c1')));
    });
  });
}
