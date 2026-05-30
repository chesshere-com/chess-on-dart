// Piece types and colors

const int whiteColor = 8;
const int blackColor = 16;
const int noColor = 0;

const int typeEmpty = 0;
const int typePawn = 1;
const int typeKnight = 2;
const int typeBishop = 3;
const int typeRook = 4;
const int typeQueen = 5;
const int typeKing = 6;

extension type const Piece(int value) {
  static const Piece empty = Piece(0);

  int color() => value & 0x18;
  int kind() => value & 0x07;

  bool get isWhite => color() == whiteColor;
  bool get isBlack => color() == blackColor;

  String toRune() {
    final k = kind();
    if (k == typeEmpty) return ' ';
    final isW = isWhite;
    switch (k) {
      case typePawn:
        return isW ? 'P' : 'p';
      case typeKnight:
        return isW ? 'N' : 'n';
      case typeBishop:
        return isW ? 'B' : 'b';
      case typeRook:
        return isW ? 'R' : 'r';
      case typeQueen:
        return isW ? 'Q' : 'q';
      case typeKing:
        return isW ? 'K' : 'k';
      default:
        return ' ';
    }
  }

  static Piece fromRune(String rune) {
    if (rune.length != 1) return empty;
    final char = rune[0];
    switch (char) {
      case 'P':
        return const Piece(whiteColor | typePawn);
      case 'N':
        return const Piece(whiteColor | typeKnight);
      case 'B':
        return const Piece(whiteColor | typeBishop);
      case 'R':
        return const Piece(whiteColor | typeRook);
      case 'Q':
        return const Piece(whiteColor | typeQueen);
      case 'K':
        return const Piece(whiteColor | typeKing);
      case 'p':
        return const Piece(blackColor | typePawn);
      case 'n':
        return const Piece(blackColor | typeKnight);
      case 'b':
        return const Piece(blackColor | typeBishop);
      case 'r':
        return const Piece(blackColor | typeRook);
      case 'q':
        return const Piece(blackColor | typeQueen);
      case 'k':
        return const Piece(blackColor | typeKing);
      default:
        return empty;
    }
  }
}

// Named piece constants for convenience
const Piece wPawn = Piece(whiteColor | typePawn);
const Piece wKnight = Piece(whiteColor | typeKnight);
const Piece wBishop = Piece(whiteColor | typeBishop);
const Piece wRook = Piece(whiteColor | typeRook);
const Piece wQueen = Piece(whiteColor | typeQueen);
const Piece wKing = Piece(whiteColor | typeKing);

const Piece bPawn = Piece(blackColor | typePawn);
const Piece bKnight = Piece(blackColor | typeKnight);
const Piece bBishop = Piece(blackColor | typeBishop);
const Piece bRook = Piece(blackColor | typeRook);
const Piece bQueen = Piece(blackColor | typeQueen);
const Piece bKing = Piece(blackColor | typeKing);
