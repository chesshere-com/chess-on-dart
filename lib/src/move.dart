import 'square.dart';
import 'piece.dart';

extension type const Move(int value) {
  static const int moveToBit = 6;
  static const int moveEnPassantBit = 12;
  static const int moveCastlingBit = 13;
  static const int movePromotionBit = 14;
  static const int moveCaptureBit = 17;

  static const int moveToFromMask = 0x3F;
  static const int movePromotionMask = 0x07;
  static const int moveCaptureMask = 0x0F;

  // Primary factory/constructor
  static Move make(
    Square from,
    Square to, {
    int capturedKind = typeEmpty,
    bool enPassant = false,
    bool castling = false,
    int promotion = typeEmpty,
  }) {
    return Move(
      from.value |
          (to.value << moveToBit) |
          (enPassant ? (1 << moveEnPassantBit) : 0) |
          (castling ? (1 << moveCastlingBit) : 0) |
          (promotion << movePromotionBit) |
          (capturedKind << moveCaptureBit),
    );
  }

  Square from() => Square(value & moveToFromMask);
  Square to() => Square((value >> moveToBit) & moveToFromMask);
  bool isEnPassant() => (value & (1 << moveEnPassantBit)) != 0;
  bool isCastling() => (value & (1 << moveCastlingBit)) != 0;
  int promotionTo() => (value >> movePromotionBit) & movePromotionMask;
  bool isPromotion() => promotionTo() != typeEmpty;
  int capturedPieceKind() => (value >> moveCaptureBit) & moveCaptureMask;

  String uci() {
    final fromCoords = from().coords();
    final toCoords = to().coords();
    if (isPromotion()) {
      final promRune = Piece(promotionTo() | whiteColor).toRune().toLowerCase();
      return '$fromCoords$toCoords$promRune';
    }
    return '$fromCoords$toCoords';
  }

  static Move parseUCI(String uci) {
    if (uci.length < 4 || uci.length > 5) return const Move(0);
    final fromSq = Square.parse(uci.substring(0, 2));
    final toSq = Square.parse(uci.substring(2, 4));
    if (!fromSq.isValid || !toSq.isValid) return const Move(0);

    var promKind = typeEmpty;
    if (uci.length == 5) {
      final char = uci[4];
      switch (char) {
        case 'q':
          promKind = typeQueen;
          break;
        case 'r':
          promKind = typeRook;
          break;
        case 'b':
          promKind = typeBishop;
          break;
        case 'n':
          promKind = typeKnight;
          break;
        default:
          return const Move(0);
      }
    }
    return Move.make(fromSq, toSq, promotion: promKind);
  }
}
