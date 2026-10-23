import 'piece.dart';

// Zobrist tables
final List<int> zobristPieceIndexTable = List.filled(24, -1);
final List<List<int>> zobristPiece =
    List.generate(12, (_) => List.filled(64, 0));
final List<int> zobristCastling = List.filled(16, 0);
final List<int> zobristVariant = List.filled(8, 0);
final List<int> zobristVariantState = List.filled(256, 0);
final List<List<int>> zobristCastlingRook =
    List.generate(16, (_) => List.filled(64, 0));
final List<int> zobristEnPassant = List.filled(8, 0);
late final int zobristTurnToMove;

class _XorShift64 {
  int state;
  _XorShift64(this.state) {
    if (state == 0) state = 1;
  }

  int next64() {
    state ^= (state << 13) & 0xFFFFFFFFFFFFFFFF;
    state ^= state >>> 7;
    state ^= (state << 17) & 0xFFFFFFFFFFFFFFFF;
    return state;
  }
}

bool _zobristInitialized = false;

void initZobrist() {
  if (_zobristInitialized) return;
  _zobristInitialized = true;

  // Initialize piece index table
  zobristPieceIndexTable[wPawn.value] = 0;
  zobristPieceIndexTable[wKnight.value] = 1;
  zobristPieceIndexTable[wBishop.value] = 2;
  zobristPieceIndexTable[wRook.value] = 3;
  zobristPieceIndexTable[wQueen.value] = 4;
  zobristPieceIndexTable[wKing.value] = 5;
  zobristPieceIndexTable[bPawn.value] = 6;
  zobristPieceIndexTable[bKnight.value] = 7;
  zobristPieceIndexTable[bBishop.value] = 8;
  zobristPieceIndexTable[bRook.value] = 9;
  zobristPieceIndexTable[bQueen.value] = 10;
  zobristPieceIndexTable[bKing.value] = 11;

  final rng = _XorShift64(1);

  for (var i = 0; i < 12; i++) {
    for (var j = 0; j < 64; j++) {
      zobristPiece[i][j] = rng.next64();
    }
  }

  for (var i = 0; i < 16; i++) {
    zobristCastling[i] = rng.next64();
  }

  for (var i = 0; i < 8; i++) {
    zobristEnPassant[i] = rng.next64();
  }

  zobristTurnToMove = rng.next64();

  for (var i = 0; i < 8; i++) {
    zobristVariant[i] = rng.next64();
  }

  for (var i = 0; i < 256; i++) {
    zobristVariantState[i] = rng.next64();
  }

  for (var i = 0; i < 16; i++) {
    for (var j = 0; j < 64; j++) {
      zobristCastlingRook[i][j] = rng.next64();
    }
  }
}

int zobristPieceIndex(Piece p) {
  if (p.value < 0 || p.value >= 24) return -1;
  return zobristPieceIndexTable[p.value];
}
