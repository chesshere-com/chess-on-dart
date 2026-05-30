import 'bitboard.dart';
import 'square.dart';

// Direction constants
const int dirN = 0;
const int dirS = 1;
const int dirE = 2;
const int dirW = 3;
const int dirNE = 4;
const int dirNW = 5;
const int dirSE = 6;
const int dirSW = 7;

const int lsb = 0;
const int msb = 1;

const List<int> allDirections = [
  dirN,
  dirS,
  dirE,
  dirW,
  dirNE,
  dirNW,
  dirSE,
  dirSW
];
const List<int> rookDirections = [dirN, dirS, dirE, dirW];
const List<int> bishopDirections = [dirNE, dirNW, dirSE, dirSW];

const List<List<int>> directionShift = [
  [1, 0], // N (downwards in rank index)
  [-1, 0], // S (upwards in rank index)
  [0, -1], // E (leftwards in file index)
  [0, 1], // W (rightwards in file index)
  [1, -1], // NE
  [1, 1], // NW
  [-1, -1], // SE
  [-1, 1], // SW
];

const List<int> directionLsbMsp = [
  lsb, // N
  msb, // S
  msb, // E
  lsb, // W
  lsb, // NE
  lsb, // NW
  msb, // SE
  msb, // SW
];

const List<List<int>> kingRankFileShifts = [
  [-1, -1],
  [0, -1],
  [1, -1],
  [-1, 0],
  [1, 0],
  [-1, 1],
  [0, 1],
  [1, 1],
];

const List<List<int>> knightRankFileShifts = [
  [-2, -1],
  [-2, 1],
  [2, -1],
  [2, 1],
  [-1, -2],
  [-1, 2],
  [1, -2],
  [1, 2],
];

// Precomputed tables
final List<Bitboard> knightAttacksFrom = List.filled(64, Bitboard.zero);
final List<Bitboard> kingAttacksFrom = List.filled(64, Bitboard.zero);
final List<Bitboard> attacksTo = List.filled(64, Bitboard.zero);
final List<List<Bitboard>> rayMasks =
    List.generate(8, (_) => List.filled(64, Bitboard.zero));

final List<Bitboard> whitePawnAttackersTo = List.filled(64, Bitboard.zero);
final List<Bitboard> blackPawnAttackersTo = List.filled(64, Bitboard.zero);
final List<List<Bitboard>> betweenLineMasks =
    List.generate(64, (_) => List.filled(64, Bitboard.zero));

// Rank and File masks
const Bitboard rank1Mask = Bitboard(0xFF00000000000000);
const Bitboard rank2Mask = Bitboard(0x00FF000000000000);
const Bitboard rank3Mask = Bitboard(0x0000FF0000000000);
const Bitboard rank4Mask = Bitboard(0x000000FF00000000);
const Bitboard rank5Mask = Bitboard(0x00000000FF000000);
const Bitboard rank6Mask = Bitboard(0x0000000000FF0000);
const Bitboard rank7Mask = Bitboard(0x000000000000FF00);
const Bitboard rank8Mask = Bitboard(0x00000000000000FF);

const Bitboard fileAMask = Bitboard(0x0101010101010101);
const Bitboard fileBMask = Bitboard(0x0202020202020202);
const Bitboard fileCMask = Bitboard(0x0404040404040404);
const Bitboard fileDMask = Bitboard(0x0808080808080808);
const Bitboard fileEMask = Bitboard(0x1010101010101010);
const Bitboard fileFMask = Bitboard(0x2020202020202020);
const Bitboard fileGMask = Bitboard(0x4040404040404040);
const Bitboard fileHMask = Bitboard(0x8080808080808080);

bool _initialized = false;

void initMasks() {
  if (_initialized) return;
  _initialized = true;

  // King & Knight attacks
  for (var sq = 0; sq < 64; sq++) {
    final s = Square(sq);
    final rank = s.rank();
    final file = s.file();

    // King attacks
    var kingMask = 0;
    for (final shift in kingRankFileShifts) {
      final r = rank + shift[0];
      final f = file + shift[1];
      if (r >= 0 && r < 8 && f >= 0 && f < 8) {
        kingMask |= (1 << (r * 8 + f));
      }
    }
    kingAttacksFrom[sq] = Bitboard(kingMask);

    // Knight attacks
    var knightMask = 0;
    for (final shift in knightRankFileShifts) {
      final r = rank + shift[0];
      final f = file + shift[1];
      if (r >= 0 && r < 8 && f >= 0 && f < 8) {
        knightMask |= (1 << (r * 8 + f));
      }
    }
    knightAttacksFrom[sq] = Bitboard(knightMask);
  }

  // Ray masks
  for (final dir in allDirections) {
    final shift = directionShift[dir];
    for (var sq = 0; sq < 64; sq++) {
      final s = Square(sq);
      var r = s.rank() + shift[0];
      var f = s.file() + shift[1];
      var mask = 0;
      while (r >= 0 && r < 8 && f >= 0 && f < 8) {
        mask |= (1 << (r * 8 + f));
        r += shift[0];
        f += shift[1];
      }
      rayMasks[dir][sq] = Bitboard(mask);
    }
  }

  // Attacks to
  for (var sq = 0; sq < 64; sq++) {
    var mask = 0;
    for (final dir in allDirections) {
      mask |= rayMasks[dir][sq].value;
    }
    mask |= kingAttacksFrom[sq].value;
    mask |= knightAttacksFrom[sq].value;
    attacksTo[sq] = Bitboard(mask);
  }

  // Pawn attackers to
  for (var sq = 0; sq < 64; sq++) {
    final s = Square(sq);
    final file = s.file();

    // White pawn attackers (move up, so they attack from down/greater index rank)
    var whiteMask = 0;
    if (file > 0 && sq + 7 <= 63) {
      whiteMask |= (1 << (sq + 7));
    }
    if (file < 7 && sq + 9 <= 63) {
      whiteMask |= (1 << (sq + 9));
    }
    whitePawnAttackersTo[sq] = Bitboard(whiteMask);

    // Black pawn attackers (move down, so they attack from up/lesser index rank)
    var blackMask = 0;
    if (file < 7 && sq >= 7) {
      blackMask |= (1 << (sq - 7));
    }
    if (file > 0 && sq >= 9) {
      blackMask |= (1 << (sq - 9));
    }
    blackPawnAttackersTo[sq] = Bitboard(blackMask);
  }

  // betweenLineMasks
  for (var from = 0; from < 64; from++) {
    for (var to = 0; to < 64; to++) {
      betweenLineMasks[from][to] =
          _computeBetweenLineMask(Square(from), Square(to));
    }
  }
}

Bitboard _computeBetweenLineMask(Square from, Square to) {
  final fromRank = from.rank();
  final fromFile = from.file();
  final toRank = to.rank();
  final toFile = to.file();

  final rankDelta = toRank - fromRank;
  final fileDelta = toFile - fromFile;

  final rankStep = rankDelta.sign;
  final fileStep = fileDelta.sign;

  if (rankDelta != 0 && fileDelta != 0 && rankDelta.abs() != fileDelta.abs()) {
    return Bitboard.zero;
  }
  if (rankDelta == 0 && fileDelta == 0) {
    return Bitboard.zero;
  }

  var r = fromRank + rankStep;
  var f = fromFile + fileStep;
  var mask = 0;
  while (r != toRank || f != toFile) {
    mask |= (1 << (r * 8 + f));
    r += rankStep;
    f += fileStep;
  }
  return Bitboard(mask);
}
