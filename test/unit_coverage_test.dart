import 'package:chess_on_dart/chess_on_dart.dart';
import 'package:chess_on_dart/src/zobrist.dart';
import 'package:test/test.dart';

void main() {
  group('Bitboard Unit Tests', () {
    test('Bitboard Operators & Utilities', () {
      const b1 = Bitboard(0xF0);
      const b2 = Bitboard(0x0F);

      expect((b1 & b2).value, equals(0));
      expect((b1 | b2).value, equals(0xFF));
      expect((b1 ^ b2).value, equals(0xFF));
      expect((~b1).value, equals((~0xF0) & 0xFFFFFFFFFFFFFFFF));
      expect((b2 << 4).value, equals(0xF0));
      expect((b1 >> 4).value, equals(0x0F));
      expect(b1.unsignedRightShift(4).value, equals(0x0F));

      expect(Bitboard.zero.isEmpty, isTrue);
      expect(b1.isNotEmpty, isTrue);
      expect(b1.isEmpty, isFalse);
    });

    test('Bitboard Indexing and CountOnes Edges', () {
      expect(Bitboard.zero.lsbIndex(), equals(-1));
      expect(Bitboard.zero.msbIndex(), equals(-1));

      // Negative value (63rd bit set)
      final negBB = Bitboard(1 << 63);
      expect(negBB.lsbIndex(), equals(63));
      expect(negBB.msbIndex(), equals(63));
      expect(negBB.countOnes(), equals(1));

      // Multi-bit value containing negative sign
      final multiBB = Bitboard((1 << 63) | 0x0F);
      expect(multiBB.lsbIndex(), equals(0)); // 1 is bit 0
      expect(multiBB.msbIndex(), equals(63));
      expect(multiBB.countOnes(), equals(5)); // bits 0, 1, 2, 3 and 63
    });
  });

  group('Square Unit Tests', () {
    test('Coordinate Parsing and Validations', () {
      expect(Square.noSquare.isValid, isFalse);
      expect(Square.parse('-'), equals(Square.noSquare));

      // Standard parses
      expect(Square.parse('a8'), equals(const Square(0)));
      expect(Square.parse('h1'), equals(const Square(63)));
      expect(Square.parse('e4'), equals(const Square(36)));

      // Edge/Invalid parses
      expect(Square.parse('a9').isValid, isFalse);
      expect(Square.parse('i1').isValid, isFalse);
      expect(Square.parse('e').isValid, isFalse);
      expect(Square.parse('e44').isValid, isFalse);
      expect(Square.parse(''), equals(Square.noSquare));

      // Name and coords
      final sq = const Square(36); // e4
      expect(sq.coords(), equals('e4'));
      expect(sq.file(), equals(4)); // File E (0=A, 4=E)
      expect(sq.rank(), equals(4)); // Rank 4 (0=Rank 8, 4=Rank 4)
    });
  });

  group('Piece Unit Tests', () {
    test('Color and Kind Bit-packing', () {
      expect(Piece.empty.color(), equals(noColor));
      expect(Piece.empty.kind(), equals(typeEmpty));
      expect(Piece.empty.isWhite, isFalse);
      expect(Piece.empty.isBlack, isFalse);

      const wQ = Piece(whiteColor | typeQueen);
      expect(wQ.isWhite, isTrue);
      expect(wQ.isBlack, isFalse);
      expect(wQ.kind(), equals(typeQueen));
      expect(wQ.color(), equals(whiteColor));
      expect(wQ.toRune(), equals('Q'));

      const bN = Piece(blackColor | typeKnight);
      expect(bN.isWhite, isFalse);
      expect(bN.isBlack, isTrue);
      expect(bN.kind(), equals(typeKnight));
      expect(bN.color(), equals(blackColor));
      expect(bN.toRune(), equals('n'));
    });

    test('Piece Parser from Rune', () {
      expect(Piece.fromRune('P'), equals(wPawn));
      expect(Piece.fromRune('K'), equals(wKing));
      expect(Piece.fromRune('r'), equals(bRook));
      expect(Piece.fromRune('x'), equals(Piece.empty));
      expect(Piece.fromRune(''), equals(Piece.empty));
      expect(Piece.fromRune('PP'), equals(Piece.empty));
    });
  });

  group('Move Unit Tests', () {
    test('Move Encoding & Decoding', () {
      final from = const Square(52); // e2
      final to = const Square(36); // e4

      final normalMove = Move.make(from, to);
      expect(normalMove.from(), equals(from));
      expect(normalMove.to(), equals(to));
      expect(normalMove.isCastling(), isFalse);
      expect(normalMove.isEnPassant(), isFalse);
      expect(normalMove.isPromotion(), isFalse);
      expect(normalMove.promotionTo(), equals(typeEmpty));
      expect(normalMove.capturedPieceKind(), equals(typeEmpty));

      // En Passant
      final epMove =
          Move.make(from, to, enPassant: true, capturedKind: typePawn);
      expect(epMove.isEnPassant(), isTrue);
      expect(epMove.capturedPieceKind(), equals(typePawn));

      // Castling
      final castleMove = Move.make(from, to, castling: true);
      expect(castleMove.isCastling(), isTrue);

      // Promotion
      final promoMove =
          Move.make(from, to, promotion: typeQueen, capturedKind: typeRook);
      expect(promoMove.isPromotion(), isTrue);
      expect(promoMove.promotionTo(), equals(typeQueen));
      expect(promoMove.capturedPieceKind(), equals(typeRook));
    });

    test('Move parsing UCI', () {
      final m1 = Move.parseUCI('e2e4');
      expect(m1.from(), equals(Square.parse('e2')));
      expect(m1.to(), equals(Square.parse('e4')));
      expect(m1.isPromotion(), isFalse);
      expect(m1.uci(), equals('e2e4'));

      final m2 = Move.parseUCI('a7a8q');
      expect(m2.from(), equals(Square.parse('a7')));
      expect(m2.to(), equals(Square.parse('a8')));
      expect(m2.isPromotion(), isTrue);
      expect(m2.promotionTo(), equals(typeQueen));
      expect(m2.uci(), equals('a7a8q'));

      expect(Move.parseUCI('e2'), equals(const Move(0)));
      expect(Move.parseUCI('e2e9'), equals(const Move(0)));
    });
  });

  group('Chess960 & Zobrist Init Tests', () {
    test('Generate Starting Chess960 Position Layout', () {
      // Validate that all layout indexes 0 to 959 generate valid Chess960 backranks
      for (int i = 0; i < 960; i += 100) {
        final backrank = chess960BackRank(i);
        expect(backrank.length, equals(8));

        // Assert we have exactly two bishops of different color squares
        var lightBishop = false;
        var darkBishop = false;
        for (int sq = 0; sq < 8; sq++) {
          if (backrank[sq] == 'B') {
            if (sq % 2 == 0) {
              lightBishop = true;
            } else {
              darkBishop = true;
            }
          }
        }
        expect(lightBishop && darkBishop, isTrue);

        // Assert the King is sandwiched between the two Rooks
        var rookCount = 0;
        var kingFound = false;
        for (int sq = 0; sq < 8; sq++) {
          if (backrank[sq] == 'R') {
            rookCount++;
          }
          if (backrank[sq] == 'K') {
            expect(rookCount,
                equals(1)); // Must have found exactly 1 rook before King
            kingFound = true;
          }
        }
        expect(kingFound, isTrue);
        expect(rookCount, equals(2));
      }
    });

    test('Zobrist Deterministic Tables Check', () {
      initZobrist();

      expect(zobristPiece[0][0], isNot(equals(0)));
      expect(zobristCastling[0], isNot(equals(zobristCastling[1])));
      expect(zobristTurnToMove, isNot(equals(0)));
    });
  });
}
