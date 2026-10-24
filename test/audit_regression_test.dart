import 'package:chess_on_dart/chess_on_dart.dart';
import 'package:test/test.dart';

List<Object?> snapshot(Game game) => [
      game.toFEN(),
      game.zobristHash,
      Map<int, int>.of(game.positionHistory),
      List<Move>.of(game.legalMoves),
      List<Bitboard>.of(game.whites),
      List<Bitboard>.of(game.blacks),
      game.occupied,
      game.whitePieces,
      game.blackPieces,
      game.history.length,
      List<String>.of(game.pgnMoves),
      game.pgnTags == null ? null : Map<String, String>.of(game.pgnTags!),
      game.pgnResult,
      game.isCheck,
      game.status,
      game.isFinished,
      game.winner,
    ];

void main() {
  group('Input validation is transactional', () {
    final invalidFields = [
      'x KQkq - 0 1',
      'w KQkq - -1 1',
      'w KQkq - 0 0',
      'w KQkq - 0 1 extra',
      'w KQkq e4 0 1',
      'w KQkq e6 0 1',
      'b KQkq a8 0 1',
      'w KQKq - 0 1',
      'w ♔ - 0 1',
    ];
    for (final fields in invalidFields) {
      test('rejects invalid FEN fields: $fields', () {
        final game = Game()..loadPGN('1. e4 e5');
        final before = snapshot(game);
        expect(
            () => game
                .loadFEN('${Game.startingPositionFen.split(' ')[0]} $fields'),
            throwsFormatException);
        expect(snapshot(game), before);
      });
    }
    test('rejects impossible pieces and castling rights', () {
      final game = Game();
      for (final fen in [
        '4k3/8/8/8/8/8/8/P3K3 w - - 0 1',
        '4k3/8/8/8/8/8/8/4K3 w K - 0 1',
        '4k3/8/8/8/8/8/8/8 w - - 0 1',
      ]) {
        final before = snapshot(game);
        expect(() => game.loadFEN(fen), throwsFormatException);
        expect(snapshot(game), before);
      }
      expect(
          () => game.loadFEN(
              '4k3/8/8/8/8/8/8/4KR1R w FH - 0 1', Variant.chess960),
          throwsFormatException);
    });
    test('rejects unknown UCI promotion suffixes', () {
      for (final uci in ['e2e4x', 'e2e4p', 'a7a8k', 'a7a8Q']) {
        expect(Move.parseUCI(uci), const Move(0));
      }
    });
  });

  group('State and chess rules', () {
    test('bitboard right shift does not sign extend', () {
      expect((Bitboard(1 << 63) >> 8).value, 1 << 55);
      expect((const Bitboard(-1) >> 1).countOnes(), 63);
    });
    test('repetition hash ignores illegal pinned en passant', () {
      final game = Game()..loadFEN('k3r3/8/8/3pP3/8/8/8/4K3 w - d6 0 1');
      final withEp = game.zobristHash;
      expect(game.legalMoves.any((move) => move.isEnPassant()), isFalse);
      game.loadFEN('k3r3/8/8/3pP3/8/8/8/4K3 w - - 0 1');
      expect(game.zobristHash, withEp);
      game.loadFEN('k7/8/8/3pP3/8/8/8/4K3 w - d6 0 1');
      final legalEpHash = game.zobristHash;
      game.loadFEN('k7/8/8/3pP3/8/8/8/4K3 w - - 0 1');
      expect(game.zobristHash, isNot(legalEpHash));
    });
    test('material draws respect possible mates and variant wins', () {
      final game = Game()..loadFEN('kn6/8/8/8/8/8/8/6NK w - - 0 1');
      expect(game.isMaterialDraw, isFalse);
      game.loadFEN('k7/8/8/8/8/8/8/7K w - - 0 1', Variant.kingOfTheHill);
      expect(game.isFinished, isFalse);
      game.loadFEN('k7/8/8/8/8/8/8/6BK w - - 0 1', Variant.threeCheck);
      expect(game.isFinished, isFalse);
    });
    test('Chess960 castling is not a capture of our own piece', () {
      final game = Game()
        ..loadFEN('4k3/8/8/8/8/8/8/6KR w H - 17 1', Variant.chess960);
      final before = snapshot(game);
      final castle = game.legalMoves.firstWhere((move) => move.isCastling());
      game.makeMove(castle);
      expect(game.halfMoves, 18);
      game.undoMove(castle);
      // PGN start metadata may be initialized by the first real move.
      expect(game.toFEN(), before.first);
      expect(game.zobristHash, before[1]);
    });
    test('explicit Chess960 castling wins over matching king coordinates', () {
      final game = Game()
        ..loadFEN('4k3/8/8/8/8/8/8/5K1R w H - 0 1', Variant.chess960);
      final castle = game.legalMoves.firstWhere((move) => move.isCastling());
      game.tryMove(castle);
      expect(game.squares[Square.parse('f1').value], wRook);
      expect(game.squares[Square.parse('h1').value], Piece.empty);
      expect(game.pgnMoves, ['O-O']);
    });
    test('fast make and undo maintain hashes and restore parent moves', () {
      final game = Game();
      final before = snapshot(game);
      for (final move in List<Move>.of(game.legalMoves)) {
        game.makeMoveFast(move);
        expect(game.zobristHash, game.computeZobrist());
        game.undoMoveFast(move);
        expect(snapshot(game), before);
      }
    });
    test('SAN accepts coordinate captures without altering the game', () {
      final game = Game()..loadPGN('1. e4 d5');
      final before = snapshot(game);
      expect(game.getMoveSAN(Move.parseUCI('e4d5')), 'exd5');
      expect(snapshot(game), before);
    });
    test('cloning does not seed an extra starting position', () {
      final game = Game()..loadFEN('k7/p7/8/8/8/8/P7/7K w - - 0 1');
      final copy = cloneGame(game);
      expect(snapshot(copy), snapshot(game));
    });
    test('cloned history cannot change three-check state in original', () {
      final game = Game()
        ..loadFEN('4k3/8/8/8/8/8/8/3Q3K w - - 0 1', Variant.threeCheck);
      final move = Move.parseUCI('d1e2');
      game.tryMove(move);
      final before = snapshot(game);
      final copy = cloneGame(game);
      copy.undoMove(move);
      copy.variantState.checksGiven[0] = 2;
      game.undoMove(move);
      expect(game.variantState.checksGiven, [0, 0]);
      expect(before[0], contains('+1+0'));
    });
    test('undoing a coordinate move restores en passant', () {
      final game = Game()..loadFEN('k7/8/8/3pP3/8/8/8/4K3 w - d6 0 1');
      final before = game.toFEN();
      final move = Move.parseUCI('e5d6');
      game.tryMove(move);
      game.undoMove(move);
      expect(game.toFEN(), before);
    });
    test('a finished variant rejects further moves', () {
      final game = Game()
        ..loadFEN('k7/8/8/8/3K4/8/8/8 w - - 0 1', Variant.kingOfTheHill);
      expect(() => game.tryMove(Move.parseUCI('d4d3')), throwsStateError);
    });
  });

  group('PGN round trips', () {
    test('compact move numbers retain the moves', () {
      final game = Game()..loadPGN('1.e4 e5 2.Nf3 Nc6');
      expect(game.pgnMoves, ['e4', 'e5', 'Nf3', 'Nc6']);
    });
    test('comment punctuation does not alter variation nesting', () {
      final game = Game()
        ..loadPGN('1. e4 {ignored ( ; text} e5 (1... c5 {)}) 2. Nf3');
      expect(game.pgnMoves, ['e4', 'e5', 'Nf3']);
    });
    test('tag result survives move recording and tags escape on export', () {
      final game = Game()
        ..loadPGN(
            '[Event "A \\"quote\\" and \\\\ path"]\n[Result "1-0"]\n\n1. e4 e5');
      expect(game.pgnResult, '1-0');
      final exported = game.exportPGN();
      final copy = Game()..loadPGN(exported);
      expect(copy.pgnTags!['Event'], game.pgnTags!['Event']);
      expect(copy.pgnResult, '1-0');
    });
    test('exporting a FEN-only game retains its starting position', () {
      final game = Game()..loadFEN('k7/p7/8/8/8/8/P7/7K b - - 0 12');
      final copy = Game()..loadPGN(game.exportPGN());
      expect(copy.toFEN(), game.toFEN());
    });
    test('malformed comments and trailing moves fail atomically', () {
      final game = Game()..loadPGN('1. d4 d5');
      for (final pgn in [
        '1. e4 {unterminated',
        '1. e4 (1. d4',
        '1. e4 1-0 e5'
      ]) {
        final before = snapshot(game);
        expect(() => game.loadPGN(pgn), throwsFormatException);
        expect(snapshot(game), before);
      }
    });
  });

  group('Game-end enforcement', () {
    const bareKings = 'k7/8/8/8/8/8/8/K7 w - - 0 1';
    const knightShuffle = ['g1f3', 'g8f6', 'f3g1', 'f6g8'];
    final shufflePgn = [
      for (var i = 0; i < 5; i++) '${2 * i + 1}. Nf3 Nf6 ${2 * i + 2}. Ng1 Ng8',
    ].join(' ');

    void shuffle(Game game, int plies) {
      for (var ply = 0; ply < plies; ply++) {
        game.tryMove(Move.parseUCI(knightShuffle[ply % 4]));
      }
    }

    test('finished games reject recorded moves by default', () {
      final game = Game()..loadFEN(bareKings);
      expect(game.status, GameStatus.drawInsufficientMaterial);
      final before = snapshot(game);
      expect(() => game.tryMove(Move.parseUCI('a1a2')), throwsStateError);
      expect(snapshot(game), before);
    });

    test('the opt-out plays on after insufficient material', () {
      final game = Game(enforceGameEnd: false)..loadFEN(bareKings);
      game.tryMove(Move.parseUCI('a1a2'));
      game.makeMove(Move.parseUCI('a8b8'));
      expect(game.pgnMoves, ['Ka2', 'Kb8']);
      expect(game.status, GameStatus.drawInsufficientMaterial);
      expect(game.pgnResult, '1/2-1/2');
      game.undoMove(Move.parseUCI('a8b8'));
      expect(game.toFEN(), 'k7/8/8/8/8/8/K7/8 b - - 1 1');
      expect(game.isFinished, isTrue);
    });

    test('the opt-out reports status for each position after fivefold', () {
      final game = Game(enforceGameEnd: false);
      shuffle(game, 17);
      expect(game.status, GameStatus.drawFivefoldRepetition);
      expect(game.pgnResult, '1/2-1/2');
      game.tryMove(Move.parseUCI('e7e5'));
      expect(game.isFinished, isFalse);
      expect(game.status, GameStatus.ongoing);
      expect(game.pgnResult, '*');
      expect(game.pgnMoves, hasLength(18));
    });

    test('loadPGN follows the setting', () {
      final strict = Game();
      final before = snapshot(strict);
      expect(() => strict.loadPGN(shufflePgn), throwsFormatException);
      expect(snapshot(strict), before);

      final lenient = Game(enforceGameEnd: false)..loadPGN(shufflePgn);
      expect(lenient.pgnMoves, hasLength(20));
      expect(lenient.status, GameStatus.drawFivefoldRepetition);
      expect(lenient.pgnResult, '1/2-1/2');
    });

    test('cloneGame copies the setting; copyFrom and loadFEN keep it', () {
      final lenient = Game(enforceGameEnd: false);
      expect(cloneGame(lenient).enforceGameEnd, isFalse);
      expect(cloneGame(Game()).enforceGameEnd, isTrue);
      lenient
        ..copyFrom(Game())
        ..loadFEN(bareKings)
        ..tryMove(Move.parseUCI('a1a2'));
      expect(lenient.enforceGameEnd, isFalse);
      expect(lenient.pgnMoves, ['Ka2']);
    });

    test('decisive endings leave no legal moves to play', () {
      final game = Game(enforceGameEnd: false)
        ..loadFEN('k7/8/8/8/3K4/8/8/8 w - - 0 1', Variant.kingOfTheHill);
      expect(game.legalMoves, isEmpty);
      expect(() => game.tryMove(Move.parseUCI('d4d3')), throwsFormatException);
    });
  });
}
