import 'bitboard.dart';
import 'square.dart';
import 'piece.dart';
import 'move.dart';
import 'masks.dart';
import 'sliding_attacks.dart';
import 'zobrist.dart';
import 'game_state.dart';
import 'variant.dart';

// Castling permissions
const int castleWks = 1; // White king side castling  0001
const int castleWqs = 2; // White queen side castling 0010
const int castleBks = 4; // Black king side castling  0100
const int castleBqs = 8; // Black queen side castling 1000

// Castling initial/final squares
const int wKingInitSquare = 60; // e1
const int bKingInitSquare = 4; // e8
const int wksKingToSquare = 62; // g1
const int wqsKingToSquare = 58; // c1
const int bksKingToSquare = 6; // g8
const int bqsKingToSquare = 2; // c8
const int wksRookOriginalSquare = 63; // h1
const int wqsRookOriginalSquare = 56; // a1
const int bksRookOriginalSquare = 7; // h8
const int bqsRookOriginalSquare = 0; // a8

class CastlingSpec {
  final int color;
  final int right;
  final Square kingFrom;
  final Square kingTo;
  final Square rookFrom;
  final Square rookTo;
  final Piece kingPiece;
  final Piece rookPiece;
  final Bitboard emptyMask;
  final Bitboard safeSquares;

  const CastlingSpec({
    required this.color,
    required this.right,
    required this.kingFrom,
    required this.kingTo,
    required this.rookFrom,
    required this.rookTo,
    required this.kingPiece,
    required this.rookPiece,
    required this.emptyMask,
    required this.safeSquares,
  });
}

class LegalMoveInfo {
  Square king = Square.noSquare;
  Bitboard checkers = Bitboard.zero;
  int checkerCount = 0;
  Bitboard checkMask = const Bitboard(0xFFFFFFFFFFFFFFFF);
  final List<Square> pinSquares = List.filled(8, Square.noSquare);
  final List<Bitboard> pinMasks = List.filled(8, Bitboard.zero);
  int pinCount = 0;
  Bitboard pinned = Bitboard.zero;

  Bitboard pinMaskFor(Square square) {
    for (var i = 0; i < pinCount; i++) {
      if (pinSquares[i].value == square.value) {
        return pinMasks[i];
      }
    }
    return Bitboard.zero;
  }
}

class Game {
  Bitboard whitePieces = Bitboard.zero;
  Bitboard blackPieces = Bitboard.zero;

  final List<Bitboard> whites = List.filled(7, Bitboard.zero);
  final List<Bitboard> blacks = List.filled(7, Bitboard.zero);
  Bitboard occupied = Bitboard.zero;

  final List<Piece> squares = List.filled(64, Piece.empty);
  Square enPassant = Square.noSquare;
  int castling = 0;
  int halfMoves = 0;
  int fullMoves = 1;
  int turn = whiteColor;
  Variant variant = Variant.standard;
  VariantState variantState = VariantState(checksGiven: [0, 0]);

  final List<Square> castlingRookFrom = List.filled(16, Square.noSquare);
  List<Move> legalMoves = [];

  final Map<int, int> positionHistory = {};
  int zobristHash = 0;

  bool isCheck = false;
  bool isCheckmate = false;
  bool isStalemate = false;
  bool isMaterialDraw = false;
  bool isThreefoldRepetition = false;
  bool isFiftyMoveRule = false;
  bool isSeventyFiveMoveRule = false;
  bool isFinished = false;
  int winner = noColor;
  GameStatus status = GameStatus.ongoing;

  List<GameState> history = [];

  // PGN state
  Map<String, String>? pgnTags;
  List<String> pgnMoves = [];
  String pgnResult = '*';
  int pgnStartTurn = whiteColor;
  int pgnStartFullMove = 1;
  String pgnStartFEN = '';

  Game() {
    initMasks();
    initSlidingAttacks();
    initZobrist();
    loadFEN(startingPositionFen);
  }

  static const String startingPositionFen =
      "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

  void reset() {
    whitePieces = Bitboard.zero;
    blackPieces = Bitboard.zero;
    for (var i = 0; i < 7; i++) {
      whites[i] = Bitboard.zero;
      blacks[i] = Bitboard.zero;
    }
    occupied = Bitboard.zero;
    squares.fillRange(0, 64, Piece.empty);
    enPassant = Square.noSquare;
    castling = 0;
    halfMoves = 0;
    fullMoves = 1;
    turn = whiteColor;
    variant = Variant.standard;
    variantState = VariantState(checksGiven: [0, 0]);
    castlingRookFrom.fillRange(0, 16, Square.noSquare);
    legalMoves.clear();
    positionHistory.clear();
    zobristHash = 0;
    isCheck = false;
    isCheckmate = false;
    isStalemate = false;
    isMaterialDraw = false;
    isThreefoldRepetition = false;
    isFiftyMoveRule = false;
    isSeventyFiveMoveRule = false;
    isFinished = false;
    winner = noColor;
    status = GameStatus.ongoing;
    history.clear();
    pgnTags = null;
    pgnMoves.clear();
    pgnResult = '*';
    pgnStartTurn = whiteColor;
    pgnStartFullMove = 1;
    pgnStartFEN = '';
  }

  void addPiece(Piece piece, Square square) {
    squares[square.value] = piece;
    if (piece == Piece.empty) return;
    final bit = Bitboard(1 << square.value);
    final kind = piece.kind();
    if (piece.isWhite) {
      whites[kind] |= bit;
      whitePieces |= bit;
    } else {
      blacks[kind] |= bit;
      blackPieces |= bit;
    }
    occupied |= bit;
  }

  void capturePiece(Square square, Piece captured) {
    if (captured == Piece.empty) return;
    final bitNeg = ~Bitboard(1 << square.value);
    final kind = captured.kind();
    if (captured.isWhite) {
      whites[kind] &= bitNeg;
      whitePieces &= bitNeg;
    } else {
      blacks[kind] &= bitNeg;
      blackPieces &= bitNeg;
    }
  }

  void clearSquare(Square square) {
    if (!square.isValid) return;
    final piece = squares[square.value];
    if (piece == Piece.empty) return;
    capturePiece(square, piece);
    occupied &= ~Bitboard(1 << square.value);
    squares[square.value] = Piece.empty;
  }

  // Zobrist calculation
  int computeZobrist() {
    var h = 0;
    for (var sq = 0; sq < 64; sq++) {
      final piece = squares[sq];
      final idx = zobristPieceIndex(piece);
      if (idx >= 0) {
        h ^= zobristPiece[idx][sq];
      }
    }

    h ^= zobristCastling[castling & 0x0F];

    if (variant != Variant.standard && variant.index < zobristVariant.length) {
      h ^= zobristVariant[variant.index];
    }
    final extraHook = rulesForVariant(variant).hashExtra;
    if (extraHook != null) {
      h ^= zobristVariantState[extraHook(this) & 0xFF];
    }
    if (variant != Variant.standard) {
      for (final right in [castleWks, castleWqs, castleBks, castleBqs]) {
        if ((castling & right) == 0) continue;
        final rookFrom = castlingRookFrom[right];
        if (rookFrom.isValid) {
          h ^= zobristCastlingRook[right][rookFrom.value];
        }
      }
    }

    if (enPassant != Square.noSquare && hasAdjacentPawnForEnPassant()) {
      h ^= zobristEnPassant[enPassant.file()];
    }

    if (turn == blackColor) {
      h ^= zobristTurnToMove;
    }

    return h & 0xFFFFFFFFFFFFFFFF;
  }

  bool hasAdjacentPawnForEnPassant() {
    if (enPassant == Square.noSquare) return false;
    final ep = enPassant;
    if (turn == whiteColor) {
      if (ep.rank() != 2 ||
          ep.value + 8 > 63 ||
          squares[ep.value + 8] != bPawn) {
        return false;
      }
      if (ep.file() > 0 &&
          ep.value + 7 <= 63 &&
          squares[ep.value + 7] == wPawn) {
        return true;
      }
      if (ep.file() < 7 &&
          ep.value + 9 <= 63 &&
          squares[ep.value + 9] == wPawn) {
        return true;
      }
      return false;
    } else {
      if (ep.rank() != 5 || ep.value < 8 || squares[ep.value - 8] != wPawn) {
        return false;
      }
      if (ep.file() < 7 && ep.value >= 7 && squares[ep.value - 7] == bPawn) {
        return true;
      }
      if (ep.file() > 0 && ep.value >= 9 && squares[ep.value - 9] == bPawn) {
        return true;
      }
      return false;
    }
  }

  void recordPosition() {
    zobristHash = computeZobrist();
    positionHistory[zobristHash] = (positionHistory[zobristHash] ?? 0) + 1;
  }

  bool checkThreefoldRepetition() {
    return (positionHistory[zobristHash] ?? 0) >= 3;
  }

  bool checkFivefoldRepetition() {
    return (positionHistory[zobristHash] ?? 0) >= 5;
  }

  bool checkFiftyMoveRule() {
    return halfMoves >= 100;
  }

  bool checkSeventyFiveMoveRule() {
    return halfMoves >= 150;
  }

  void seedPositionHistory(List<int> keys) {
    if (keys.isEmpty) return;
    for (final k in keys) {
      positionHistory[k] = (positionHistory[k] ?? 0) + 1;
    }
    refreshStatus();
  }

  // FEN loading and exporting
  void loadFEN(String fen, [Variant v = Variant.standard]) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length < 6) {
      throw FormatException('Invalid FEN: expected 6 fields');
    }

    reset();
    variant = v;
    _fillDefaultCastlingRookFrom();

    // Pieces placement
    final piecePart = parts[0];
    final ranks = piecePart.split('/');
    if (ranks.length != 8) {
      throw FormatException('Invalid FEN piece placement');
    }

    var whiteKings = 0;
    var blackKings = 0;

    for (var r = 0; r < 8; r++) {
      final rankText = ranks[r];
      var f = 0;
      for (var i = 0; i < rankText.length; i++) {
        final code = rankText.codeUnitAt(i);
        if (code >= 49 && code <= 56) {
          // '1' - '8'
          f += (code - 48);
        } else {
          final char = rankText[i];
          final piece = Piece.fromRune(char);
          if (piece == Piece.empty || f >= 8) {
            throw FormatException('Invalid piece $char in FEN');
          }
          final sq = Square(r * 8 + f);
          addPiece(piece, sq);
          if (piece == wKing) whiteKings++;
          if (piece == bKing) blackKings++;
          f++;
        }
      }
      if (f != 8) {
        throw FormatException(
            'Rank ${r + 1} does not contain 8 files (got $f)');
      }
    }

    if (whiteKings != 1 || blackKings != 1) {
      throw FormatException('FEN must contain exactly 1 king per side');
    }

    // Active color
    turn = parts[1] == 'w' ? whiteColor : blackColor;

    // Castling
    _parseFENOrShredderCastling(parts[2]);

    // En passant
    final epPart = parts[3];
    if (epPart == '-') {
      enPassant = Square.noSquare;
    } else {
      enPassant = Square.parse(epPart);
      if (!enPassant.isValid) {
        throw FormatException('Invalid en-passant square $epPart');
      }
    }

    // Halfmove clock
    halfMoves = int.parse(parts[4]);

    // Fullmove number
    fullMoves = int.parse(parts[5]);

    // Variant extra state
    if (variant == Variant.threeCheck && parts.length >= 7) {
      final statePart = parts[6];
      final counts = _parseThreeCheckCounters(statePart);
      variantState = VariantState(checksGiven: counts);
    }

    if (sideNotToMoveInCheck()) {
      throw FormatException('Invalid FEN: side not to move is in check');
    }

    recordPosition();
    generateLegalMoves();
    refreshStatus();
  }

  String toFEN() {
    final buffer = StringBuffer();
    for (var r = 0; r < 8; r++) {
      var emptyCount = 0;
      for (var f = 0; f < 8; f++) {
        final piece = squares[r * 8 + f];
        if (piece == Piece.empty) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            buffer.write(emptyCount);
            emptyCount = 0;
          }
          buffer.write(piece.toRune());
        }
      }
      if (emptyCount > 0) {
        buffer.write(emptyCount);
      }
      if (r < 7) {
        buffer.write('/');
      }
    }

    buffer.write(turn == whiteColor ? ' w ' : ' b ');
    buffer.write(_fenCastlingField());
    buffer.write(
        enPassant == Square.noSquare ? ' - ' : ' ${enPassant.coords()} ');
    buffer.write('$halfMoves $fullMoves');

    if (variant == Variant.threeCheck) {
      buffer.write(
          ' +${variantState.checksGiven[0]}+${variantState.checksGiven[1]}');
    }

    return buffer.toString();
  }

  void _fillDefaultCastlingRookFrom() {
    castlingRookFrom.fillRange(0, 16, Square.noSquare);
    castlingRookFrom[castleWks] = const Square(wksRookOriginalSquare);
    castlingRookFrom[castleWqs] = const Square(wqsRookOriginalSquare);
    castlingRookFrom[castleBks] = const Square(bksRookOriginalSquare);
    castlingRookFrom[castleBqs] = const Square(bqsRookOriginalSquare);
  }

  void _parseFENOrShredderCastling(String field) {
    castling = 0;
    if (field == '-') return;

    final seenChars = List.filled(256, false);
    for (var i = 0; i < field.length; i++) {
      final char = field[i];
      final code = field.codeUnitAt(i);
      if (seenChars[code]) {
        throw FormatException('Duplicate castling rights');
      }
      seenChars[code] = true;

      final (right, rookFrom) = _parseFENCastlingRight(char);
      castling |= right;
      castlingRookFrom[right] = rookFrom;
    }
  }

  (int, Square) _parseFENCastlingRight(String char) {
    final code = char.codeUnitAt(0);
    switch (char) {
      case 'K':
        if (variant == Variant.chess960) {
          return _parseChess960KQCastlingRight(char);
        }
        return (castleWks, const Square(wksRookOriginalSquare));
      case 'Q':
        if (variant == Variant.chess960) {
          return _parseChess960KQCastlingRight(char);
        }
        return (castleWqs, const Square(wqsRookOriginalSquare));
      case 'k':
        if (variant == Variant.chess960) {
          return _parseChess960KQCastlingRight(char);
        }
        return (castleBks, const Square(bksRookOriginalSquare));
      case 'q':
        if (variant == Variant.chess960) {
          return _parseChess960KQCastlingRight(char);
        }
        return (castleBqs, const Square(bqsRookOriginalSquare));
    }

    if (variant != Variant.chess960) {
      throw FormatException('Invalid castling right: $char');
    }

    // Shredder DFR (Double Fischer Random) letter A-H or a-h
    if (code >= 65 && code <= 72) {
      // 'A' - 'H'
      return _parseChess960FileCastlingRight(whiteColor, code - 65);
    }
    if (code >= 97 && code <= 104) {
      // 'a' - 'h'
      return _parseChess960FileCastlingRight(blackColor, code - 97);
    }

    throw FormatException('Invalid castling right: $char');
  }

  (int, Square) _parseChess960FileCastlingRight(int color, int file) {
    final king = kingSquare(color);
    if (!king.isValid) {
      throw FormatException('Castling king not found');
    }
    final rookFrom = squareOnBackRank(color, file);
    final rookPiece = color == whiteColor ? wRook : bRook;
    if (squares[rookFrom.value] != rookPiece) {
      throw FormatException('No rook at selected file on back rank');
    }
    if (file == king.file()) {
      throw FormatException('Rook and king cannot be on the same file');
    }
    return (castlingRightFor(color, file > king.file()), rookFrom);
  }

  (int, Square) _parseChess960KQCastlingRight(String char) {
    final color = (char == 'K' || char == 'Q') ? whiteColor : blackColor;
    final kingside = (char == 'K' || char == 'k');
    final king = kingSquare(color);
    if (!king.isValid) {
      throw FormatException('King not found');
    }
    final rookFrom =
        unambiguousChess960RookForSide(color, king.file(), kingside);
    if (!rookFrom.isValid) {
      throw FormatException('Ambiguous or missing rook for castling side');
    }
    return (castlingRightFor(color, kingside), rookFrom);
  }

  Square unambiguousChess960RookForSide(
      int color, int kingFile, bool kingside) {
    final rookPiece = color == whiteColor ? wRook : bRook;
    Square found = Square.noSquare;
    for (var f = 0; f < 8; f++) {
      if (kingside && f <= kingFile) continue;
      if (!kingside && f >= kingFile) continue;
      final sq = squareOnBackRank(color, f);
      if (squares[sq.value] == rookPiece) {
        if (found != Square.noSquare) {
          return Square.noSquare; // ambiguous
        }
        found = sq;
      }
    }
    return found;
  }

  Square kingSquare(int color) {
    final kingPiece = color == whiteColor ? wKing : bKing;
    final rank = backRankFor(color);
    for (var f = 0; f < 8; f++) {
      final sq = squareOnBackRank(color, f);
      if (squares[sq.value] == kingPiece && sq.rank() == rank) {
        return sq;
      }
    }
    return Square.noSquare;
  }

  String _fenCastlingField() {
    if (castling == 0) return '-';
    if (variant != Variant.chess960) {
      final out = StringBuffer();
      if ((castling & castleWks) > 0) out.write('K');
      if ((castling & castleWqs) > 0) out.write('Q');
      if ((castling & castleBks) > 0) out.write('k');
      if ((castling & castleBqs) > 0) out.write('q');
      return out.toString();
    }

    final out = <String>[];
    for (final right in [castleWks, castleWqs, castleBks, castleBqs]) {
      if ((castling & right) == 0) continue;
      final rookFrom = castlingRookFrom[right];
      if (!rookFrom.isValid) continue;
      var code = 65 + rookFrom.file(); // 'A' + file
      if (castlingRightColor(right) == blackColor) {
        code += 32; // lower case
      }
      out.add(String.fromCharCode(code));
    }
    if (out.isEmpty) return '-';
    return out.join('');
  }

  List<int> _parseThreeCheckCounters(String field) {
    if (field.length != 4 || field[0] != '+' || field[2] != '+') {
      throw FormatException('Invalid three-check counter');
    }
    final wCount = int.parse(field[1]);
    final bCount = int.parse(field[3]);
    if (wCount < 0 || wCount > 3 || bCount < 0 || bCount > 3) {
      throw FormatException('Three-check counter out of bounds');
    }
    return [wCount, bCount];
  }

  bool sideNotToMoveInCheck() {
    if (turn == whiteColor) {
      final king = blacks[typeKing];
      return king.isNotEmpty &&
          isSquareAttackedByWithOccupied(
              Square(king.lsbIndex()), whiteColor, occupied);
    } else {
      final king = whites[typeKing];
      return king.isNotEmpty &&
          isSquareAttackedByWithOccupied(
              Square(king.lsbIndex()), blackColor, occupied);
    }
  }

  // Legal Move generation
  void generateLegalMoves() {
    isCheck = computeIsCheck();
    final info = buildLegalMoveInfo();

    // Reset legalMoves array
    legalMoves.clear();

    final ours = turn == whiteColor ? whites : blacks;
    final oursAll = turn == whiteColor ? whitePieces : blackPieces;
    final theirsAll = turn == whiteColor ? blackPieces : whitePieces;

    legalMoves = _appendLegalKingMoves(
        legalMoves, ours[typeKing], oursAll, theirsAll, info);
    if (info.checkerCount > 1) {
      return; // Double check: only king evasions are legal
    }

    if (info.checkerCount == 0 && info.pinned.isEmpty) {
      // Fast path: no check, no pins
      legalMoves = _appendPawnMovesNoFilter(legalMoves, ours[typePawn]);
      legalMoves = _appendJumpMovesNoFilter(
          legalMoves, ours[typeKnight], oursAll, theirsAll, knightAttacksFrom);
      legalMoves = _appendBishopMovesNoFilter(
          legalMoves, ours[typeBishop] | ours[typeQueen], oursAll, theirsAll);
      legalMoves = _appendRookMovesNoFilter(
          legalMoves, ours[typeRook] | ours[typeQueen], oursAll, theirsAll);
      legalMoves = _appendLegalCastlingMoves(legalMoves, info);
      return;
    }

    // Filtered path: single check or pinned pieces exist
    legalMoves = _appendLegalPawnMoves(legalMoves, ours[typePawn], info);
    legalMoves = _appendLegalJumpMoves(legalMoves, ours[typeKnight], oursAll,
        theirsAll, knightAttacksFrom, info);
    legalMoves = _appendLegalBishopMoves(legalMoves,
        ours[typeBishop] | ours[typeQueen], oursAll, theirsAll, info);
    legalMoves = _appendLegalRookMoves(
        legalMoves, ours[typeRook] | ours[typeQueen], oursAll, theirsAll, info);
    if (info.checkerCount == 0) {
      legalMoves = _appendLegalCastlingMoves(legalMoves, info);
    }
  }

  LegalMoveInfo buildLegalMoveInfo() {
    final info = LegalMoveInfo();
    Bitboard kingBB = turn == whiteColor ? whites[typeKing] : blacks[typeKing];
    final opponent = turn == whiteColor ? blackColor : whiteColor;
    if (kingBB.isEmpty) return info;

    info.king = Square(kingBB.lsbIndex());
    info.checkers = attackersTo(info.king, opponent);
    info.checkerCount = info.checkers.countOnes();
    if (info.checkerCount == 1) {
      final checker = Square(info.checkers.lsbIndex());
      info.checkMask = Bitboard(1 << checker.value) |
          betweenLineMasks[info.king.value][checker.value];
    }
    if (info.checkerCount < 2) {
      fillAbsolutePinInfo(info, turn, opponent);
    }
    return info;
  }

  void fillAbsolutePinInfo(LegalMoveInfo info, int us, int opponent) {
    final ours = us == whiteColor ? whitePieces : blackPieces;
    var rookPinners = Bitboard.zero;
    var bishopPinners = Bitboard.zero;
    if (opponent == whiteColor) {
      rookPinners = whites[typeRook] | whites[typeQueen];
      bishopPinners = whites[typeBishop] | whites[typeQueen];
    } else {
      rookPinners = blacks[typeRook] | blacks[typeQueen];
      bishopPinners = blacks[typeBishop] | blacks[typeQueen];
    }

    for (final direction in allDirections) {
      final orthogonal = isOrthogonalDirection(direction);
      final ray = rayMasks[direction][info.king.value];
      if (orthogonal) {
        if ((ray & rookPinners).isEmpty) continue;
      } else {
        if ((ray & bishopPinners).isEmpty) continue;
      }

      final res1 = nearestRayBlocker(info.king, direction, occupied);
      if (!res1.$2) continue;
      final pinned = res1.$1;
      final pinnedBB = Bitboard(1 << pinned.value);
      if ((pinnedBB & ours).isEmpty) continue;

      final res2 = nearestRayBlocker(pinned, direction, occupied);
      if (!res2.$2) continue;
      final pinner = res2.$1;
      final pinnerBB = Bitboard(1 << pinner.value);

      if ((orthogonal && (pinnerBB & rookPinners).isNotEmpty) ||
          (!orthogonal && (pinnerBB & bishopPinners).isNotEmpty)) {
        info.pinSquares[info.pinCount] = pinned;
        info.pinMasks[info.pinCount] = pinnedBB |
            pinnerBB |
            squaresBetweenAlong(info.king, pinner, direction);
        info.pinCount++;
        info.pinned |= pinnedBB;
      }
    }
  }

  (Square, bool) nearestRayBlocker(
      Square square, int direction, Bitboard occupied) {
    final blockers = rayMasks[direction][square.value] & occupied;
    if (blockers.isEmpty) {
      return (Square.noSquare, false);
    }
    if (directionLsbMsp[direction] == lsb) {
      return (Square(blockers.lsbIndex()), true);
    } else {
      return (Square(blockers.msbIndex()), true);
    }
  }

  bool isOrthogonalDirection(int direction) {
    return direction == dirN ||
        direction == dirS ||
        direction == dirE ||
        direction == dirW;
  }

  Bitboard squaresBetweenAlong(Square from, Square to, int direction) {
    return rayMasks[direction][from.value] &
        ~rayMasks[direction][to.value] &
        ~Bitboard(1 << to.value);
  }

  List<Move> _appendLegalKingMoves(List<Move> dst, Bitboard pieces,
      Bitboard ours, Bitboard theirs, LegalMoveInfo info) {
    var p = pieces;
    while (p.isNotEmpty) {
      final from = Square(p.lsbIndex());
      p = Bitboard(p.value & (p.value - 1));

      // Quiet moves
      var targets = kingAttacksFrom[from.value] & ~occupied;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        final move = Move.make(from, to, capturedKind: typeEmpty);
        if (canKingMoveWithInfo(move, info)) {
          dst.add(move);
        }
      }
      // Captures
      targets = kingAttacksFrom[from.value] & theirs;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        final move =
            Move.make(from, to, capturedKind: squares[to.value].kind());
        if (canKingMoveWithInfo(move, info)) {
          dst.add(move);
        }
      }
    }
    return dst;
  }

  bool canKingMoveWithInfo(Move m, LegalMoveInfo info) {
    final opponent = oppositeColor(turn);
    if (m.isCastling()) {
      if (info.checkerCount > 0) return false;
      final spec = castlingSpecForMove(m);
      if (spec == null) return false;
      return castlingKingPathIsSafe(spec, opponent);
    }

    final fromBBNeg = ~Bitboard(1 << m.from().value);
    final toBB = Bitboard(1 << m.to().value);
    final occupiedAfter = (occupied & fromBBNeg) | toBB;
    return !isSquareAttackedByWithOccupied(m.to(), opponent, occupiedAfter);
  }

  List<Move> _appendPawnMovesNoFilter(List<Move> dst, Bitboard pawns) {
    if (turn == whiteColor) {
      // White pawn single step
      final oneStep = (pawns >> 8) & ~occupied;
      var targets = oneStep;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        final from = Square(to.value + 8);
        if (isPromotionTarget(whiteColor, to)) {
          dst = _appendPromotions(dst, from, to, typeEmpty);
        } else {
          dst.add(Move.make(from, to));
        }
      }
      // White pawn double step
      final twoStep = ((oneStep & rank3Mask) >> 8) & ~occupied;
      targets = twoStep;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        dst.add(Move.make(Square(to.value + 16), to));
      }
      // Captures left
      final leftCaptures = ((pawns & ~fileHMask) >> 7) & blackPieces;
      targets = leftCaptures;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        final from = Square(to.value + 7);
        dst =
            _appendPawnCaptureNoFilter(dst, from, to, squares[to.value].kind());
      }
      // Captures right
      final rightCaptures = ((pawns & ~fileAMask) >> 9) & blackPieces;
      targets = rightCaptures;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        final from = Square(to.value + 9);
        dst =
            _appendPawnCaptureNoFilter(dst, from, to, squares[to.value].kind());
      }
      return _appendLegalEnPassantMoves(dst, pawns);
    } else {
      // Black pawn single step
      final oneStep = (pawns << 8) & ~occupied;
      var targets = oneStep;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        final from = Square(to.value - 8);
        if (isPromotionTarget(blackColor, to)) {
          dst = _appendPromotions(dst, from, to, typeEmpty);
        } else {
          dst.add(Move.make(from, to));
        }
      }
      // Black pawn double step
      final twoStep = ((oneStep & rank6Mask) << 8) & ~occupied;
      targets = twoStep;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        dst.add(Move.make(Square(to.value - 16), to));
      }
      // Captures left
      final leftCaptures = ((pawns & ~fileAMask) << 7) & whitePieces;
      targets = leftCaptures;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        final from = Square(to.value - 7);
        dst =
            _appendPawnCaptureNoFilter(dst, from, to, squares[to.value].kind());
      }
      // Captures right
      final rightCaptures = ((pawns & ~fileHMask) << 9) & whitePieces;
      targets = rightCaptures;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        final from = Square(to.value - 9);
        dst =
            _appendPawnCaptureNoFilter(dst, from, to, squares[to.value].kind());
      }
      return _appendLegalEnPassantMoves(dst, pawns);
    }
  }

  List<Move> _appendPawnCaptureNoFilter(
      List<Move> dst, Square from, Square to, int capturedKind) {
    if (isPromotionTarget(turn, to)) {
      return _appendPromotions(dst, from, to, capturedKind);
    }
    dst.add(Move.make(from, to, capturedKind: capturedKind));
    return dst;
  }

  List<Move> _appendPromotions(
      List<Move> dst, Square from, Square to, int capturedKind) {
    dst.add(
        Move.make(from, to, capturedKind: capturedKind, promotion: typeQueen));
    dst.add(
        Move.make(from, to, capturedKind: capturedKind, promotion: typeRook));
    dst.add(
        Move.make(from, to, capturedKind: capturedKind, promotion: typeBishop));
    dst.add(
        Move.make(from, to, capturedKind: capturedKind, promotion: typeKnight));
    return dst;
  }

  List<Move> _appendJumpMovesNoFilter(List<Move> dst, Bitboard pieces,
      Bitboard ours, Bitboard theirs, List<Bitboard> attackFrom) {
    var p = pieces;
    while (p.isNotEmpty) {
      final from = Square(p.lsbIndex());
      p = Bitboard(p.value & (p.value - 1));
      // Quiets
      var targets = attackFrom[from.value] & ~occupied;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        dst.add(Move.make(from, to));
      }
      // Captures
      targets = attackFrom[from.value] & theirs;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        dst.add(Move.make(from, to, capturedKind: squares[to.value].kind()));
      }
    }
    return dst;
  }

  List<Move> _appendBishopMovesNoFilter(
      List<Move> dst, Bitboard pieces, Bitboard ours, Bitboard theirs) {
    var p = pieces;
    while (p.isNotEmpty) {
      final from = Square(p.lsbIndex());
      p = Bitboard(p.value & (p.value - 1));
      final attacks = bishopAttacks(from, occupied);
      // Quiets
      var targets = attacks & ~occupied;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        dst.add(Move.make(from, to));
      }
      // Captures
      targets = attacks & theirs;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        dst.add(Move.make(from, to, capturedKind: squares[to.value].kind()));
      }
    }
    return dst;
  }

  List<Move> _appendRookMovesNoFilter(
      List<Move> dst, Bitboard pieces, Bitboard ours, Bitboard theirs) {
    var p = pieces;
    while (p.isNotEmpty) {
      final from = Square(p.lsbIndex());
      p = Bitboard(p.value & (p.value - 1));
      final attacks = rookAttacks(from, occupied);
      // Quiets
      var targets = attacks & ~occupied;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        dst.add(Move.make(from, to));
      }
      // Captures
      targets = attacks & theirs;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        dst.add(Move.make(from, to, capturedKind: squares[to.value].kind()));
      }
    }
    return dst;
  }

  List<Move> _appendLegalPawnMoves(
      List<Move> dst, Bitboard pawns, LegalMoveInfo info) {
    if (turn == whiteColor) {
      // White pawn single step
      final oneStep = (pawns >> 8) & ~occupied;
      var targets = oneStep;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        final from = Square(to.value + 8);
        dst = _appendLegalPawnQuiet(dst, from, to, info);
      }
      // White pawn double step
      final rank3 = oneStep & rank3Mask;
      final twoStep = (rank3 >> 8) & ~occupied;
      targets = twoStep;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        final from = Square(to.value + 16);
        if (canNonKingMoveTo(from, to, info)) {
          dst.add(Move.make(from, to));
        }
      }
      // Captures left
      final leftCaptures = ((pawns & ~fileHMask) >> 7) & blackPieces;
      targets = leftCaptures;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        final from = Square(to.value + 7);
        dst = _appendLegalPawnCapture(
            dst, from, to, squares[to.value].kind(), info);
      }
      // Captures right
      final rightCaptures = ((pawns & ~fileAMask) >> 9) & blackPieces;
      targets = rightCaptures;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        final from = Square(to.value + 9);
        dst = _appendLegalPawnCapture(
            dst, from, to, squares[to.value].kind(), info);
      }
      return _appendLegalEnPassantMoves(dst, pawns);
    } else {
      // Black pawn single step
      final oneStep = (pawns << 8) & ~occupied;
      var targets = oneStep;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        final from = Square(to.value - 8);
        dst = _appendLegalPawnQuiet(dst, from, to, info);
      }
      // Black pawn double step
      final rank6 = oneStep & rank6Mask;
      final twoStep = (rank6 << 8) & ~occupied;
      targets = twoStep;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        final from = Square(to.value - 16);
        if (canNonKingMoveTo(from, to, info)) {
          dst.add(Move.make(from, to));
        }
      }
      // Captures left
      final leftCaptures = ((pawns & ~fileAMask) << 7) & whitePieces;
      targets = leftCaptures;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        final from = Square(to.value - 7);
        dst = _appendLegalPawnCapture(
            dst, from, to, squares[to.value].kind(), info);
      }
      // Captures right
      final rightCaptures = ((pawns & ~fileHMask) << 9) & whitePieces;
      targets = rightCaptures;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        final from = Square(to.value - 9);
        dst = _appendLegalPawnCapture(
            dst, from, to, squares[to.value].kind(), info);
      }
      return _appendLegalEnPassantMoves(dst, pawns);
    }
  }

  List<Move> _appendLegalPawnQuiet(
      List<Move> dst, Square from, Square to, LegalMoveInfo info) {
    if (!canNonKingMoveTo(from, to, info)) return dst;
    if (isPromotionTarget(turn, to)) {
      return _appendPromotions(dst, from, to, typeEmpty);
    }
    dst.add(Move.make(from, to));
    return dst;
  }

  List<Move> _appendLegalPawnCapture(List<Move> dst, Square from, Square to,
      int capturedKind, LegalMoveInfo info) {
    if (!canNonKingMoveTo(from, to, info)) return dst;
    if (isPromotionTarget(turn, to)) {
      return _appendPromotions(dst, from, to, capturedKind);
    }
    dst.add(Move.make(from, to, capturedKind: capturedKind));
    return dst;
  }

  List<Move> _appendLegalEnPassantMoves(List<Move> dst, Bitboard pawns) {
    if (enPassant == Square.noSquare) return dst;
    final to = enPassant;
    if (turn == whiteColor) {
      if (to.file() > 0) {
        dst = _appendLegalEnPassantFrom(
            dst, pawns, Square(to.value + 7), to, Square(to.value + 8));
      }
      if (to.file() < 7) {
        dst = _appendLegalEnPassantFrom(
            dst, pawns, Square(to.value + 9), to, Square(to.value + 8));
      }
      return dst;
    } else {
      if (to.file() < 7) {
        dst = _appendLegalEnPassantFrom(
            dst, pawns, Square(to.value - 7), to, Square(to.value - 8));
      }
      if (to.file() > 0) {
        dst = _appendLegalEnPassantFrom(
            dst, pawns, Square(to.value - 9), to, Square(to.value - 8));
      }
      return dst;
    }
  }

  List<Move> _appendLegalEnPassantFrom(
      List<Move> dst, Bitboard pawns, Square from, Square to, Square captured) {
    if (from.value > 63 ||
        captured.value > 63 ||
        (pawns.value & (1 << from.value)) == 0) {
      return dst;
    }
    final capturedPiece = squares[captured.value];
    if (capturedPiece == Piece.empty) return dst;
    if (canEnPassantMove(from, to, captured)) {
      dst.add(Move.make(from, to,
          capturedKind: capturedPiece.kind(), enPassant: true));
    }
    return dst;
  }

  bool canEnPassantMove(Square from, Square to, Square captured) {
    final kingBB = turn == whiteColor ? whites[typeKing] : blacks[typeKing];
    final opponent = oppositeColor(turn);
    if (kingBB.isEmpty) return false;

    final fromBBNeg = ~Bitboard(1 << from.value);
    final toBB = Bitboard(1 << to.value);
    final capturedBBNeg = ~Bitboard(1 << captured.value);
    final occupiedAfter = (occupied & fromBBNeg & capturedBBNeg) | toBB;

    final List<Bitboard> pieces =
        List.from(opponent == whiteColor ? whites : blacks);
    pieces[typePawn] &= capturedBBNeg;

    return !isSquareAttackedByPieces(
        Square(kingBB.lsbIndex()), opponent, occupiedAfter, pieces);
  }

  List<Move> _appendLegalJumpMoves(
      List<Move> dst,
      Bitboard pieces,
      Bitboard ours,
      Bitboard theirs,
      List<Bitboard> attackFrom,
      LegalMoveInfo info) {
    var p = pieces;
    while (p.isNotEmpty) {
      final from = Square(p.lsbIndex());
      p = Bitboard(p.value & (p.value - 1));
      // Quiets
      var targets = attackFrom[from.value] & ~occupied;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        if (!canNonKingMoveTo(from, to, info)) continue;
        dst.add(Move.make(from, to));
      }
      // Captures
      targets = attackFrom[from.value] & theirs;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        if (!canNonKingMoveTo(from, to, info)) continue;
        dst.add(Move.make(from, to, capturedKind: squares[to.value].kind()));
      }
    }
    return dst;
  }

  List<Move> _appendLegalBishopMoves(List<Move> dst, Bitboard pieces,
      Bitboard ours, Bitboard theirs, LegalMoveInfo info) {
    var p = pieces;
    while (p.isNotEmpty) {
      final from = Square(p.lsbIndex());
      p = Bitboard(p.value & (p.value - 1));
      final attacks = bishopAttacks(from, occupied);
      // Quiets
      var targets = attacks & ~occupied;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        if (!canNonKingMoveTo(from, to, info)) continue;
        dst.add(Move.make(from, to));
      }
      // Captures
      targets = attacks & theirs;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        if (!canNonKingMoveTo(from, to, info)) continue;
        dst.add(Move.make(from, to, capturedKind: squares[to.value].kind()));
      }
    }
    return dst;
  }

  List<Move> _appendLegalRookMoves(List<Move> dst, Bitboard pieces,
      Bitboard ours, Bitboard theirs, LegalMoveInfo info) {
    var p = pieces;
    while (p.isNotEmpty) {
      final from = Square(p.lsbIndex());
      p = Bitboard(p.value & (p.value - 1));
      final attacks = rookAttacks(from, occupied);
      // Quiets
      var targets = attacks & ~occupied;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        if (!canNonKingMoveTo(from, to, info)) continue;
        dst.add(Move.make(from, to));
      }
      // Captures
      targets = attacks & theirs;
      while (targets.isNotEmpty) {
        final to = Square(targets.lsbIndex());
        targets = Bitboard(targets.value & (targets.value - 1));
        if (!canNonKingMoveTo(from, to, info)) continue;
        dst.add(Move.make(from, to, capturedKind: squares[to.value].kind()));
      }
    }
    return dst;
  }

  List<Move> _appendLegalCastlingMoves(List<Move> dst, LegalMoveInfo info) {
    if (castling == 0) return dst;
    for (final right in [castleWks, castleWqs, castleBks, castleBqs]) {
      final spec = castlingSpec(right);
      if (spec == null) continue;
      if (spec.color != turn || (castling & spec.right) == 0) continue;
      if (squares[spec.kingFrom.value] != spec.kingPiece ||
          squares[spec.rookFrom.value] != spec.rookPiece) {
        continue;
      }
      if ((occupied & spec.emptyMask).isNotEmpty) {
        continue;
      }
      // Create the move representing castling: from = king's start, to = king's end
      final castlingMove =
          Move.make(spec.kingFrom, spec.kingTo, castling: true);
      if (canKingMoveWithInfo(castlingMove, info)) {
        dst.add(castlingMove);
      }
    }
    return dst;
  }

  bool canNonKingMoveTo(Square from, Square to, LegalMoveInfo info) {
    if (info.checkerCount == 0 && info.pinned.isEmpty) {
      return true;
    }
    if ((info.pinned & Bitboard(1 << from.value)).isNotEmpty &&
        (info.pinMaskFor(from) & Bitboard(1 << to.value)).isEmpty) {
      return false;
    }
    return info.checkerCount == 0 ||
        (info.checkMask & Bitboard(1 << to.value)).isNotEmpty;
  }

  // Attack checkers
  Bitboard attackersTo(Square square, int attacker) {
    return attackersToWithOccupied(square, attacker, occupied);
  }

  Bitboard attackersToWithOccupied(
      Square square, int attacker, Bitboard occupied) {
    final pieces = attacker == whiteColor ? whites : blacks;

    var attackers = (knightAttacksFrom[square.value] & pieces[typeKnight]) |
        (kingAttacksFrom[square.value] & pieces[typeKing]);
    attackers |= pawnAttackersTo(square, attacker, pieces[typePawn]);
    attackers |=
        rookAttacks(square, occupied) & (pieces[typeRook] | pieces[typeQueen]);
    attackers |= bishopAttacks(square, occupied) &
        (pieces[typeBishop] | pieces[typeQueen]);

    return attackers;
  }

  bool isSquareAttackedByWithOccupied(
      Square square, int attacker, Bitboard occupied) {
    final pieces = attacker == whiteColor ? whites : blacks;
    return isSquareAttackedByPieces(square, attacker, occupied, pieces);
  }

  bool isSquareAttackedByPieces(
      Square square, int attacker, Bitboard occupied, List<Bitboard> pieces) {
    if ((knightAttacksFrom[square.value] & pieces[typeKnight]).isNotEmpty) {
      return true;
    }
    if ((kingAttacksFrom[square.value] & pieces[typeKing]).isNotEmpty) {
      return true;
    }
    if (pawnAttackersTo(square, attacker, pieces[typePawn]).isNotEmpty) {
      return true;
    }
    if ((rookAttacks(square, occupied) & (pieces[typeRook] | pieces[typeQueen]))
        .isNotEmpty) {
      return true;
    }
    if ((bishopAttacks(square, occupied) &
            (pieces[typeBishop] | pieces[typeQueen]))
        .isNotEmpty) {
      return true;
    }
    return false;
  }

  Bitboard pawnAttackersTo(Square square, int attacker, Bitboard pawns) {
    if (attacker == whiteColor) {
      return whitePawnAttackersTo[square.value] & pawns;
    }
    return blackPawnAttackersTo[square.value] & pawns;
  }

  bool computeIsCheck() {
    final kingBB = turn == whiteColor ? whites[typeKing] : blacks[typeKing];
    if (kingBB.isEmpty) return false;
    final kingIdx = kingBB.lsbIndex();
    return isSquareAttackedByWithOccupied(
        Square(kingIdx), oppositeColor(turn), occupied);
  }

  // Castling specifications
  CastlingSpec? castlingSpec(int right) {
    final color = castlingRightColor(right);
    if (color == noColor) return null;

    final kingside = castlingRightIsKingside(right);
    final finalSquares = castlingFinalSquares(color, kingside);
    final kingTo = finalSquares.$1;
    final rookTo = finalSquares.$2;

    var kingFrom = const Square(wKingInitSquare);
    var rookFrom = const Square(wksRookOriginalSquare);

    switch (right) {
      case castleWqs:
        rookFrom = const Square(wqsRookOriginalSquare);
        break;
      case castleBks:
        kingFrom = const Square(bKingInitSquare);
        rookFrom = const Square(bksRookOriginalSquare);
        break;
      case castleBqs:
        kingFrom = const Square(bKingInitSquare);
        rookFrom = const Square(bqsRookOriginalSquare);
        break;
    }

    if (variant == Variant.chess960) {
      kingFrom = kingSquare(color);
      rookFrom = castlingRookFrom[right];
      if (!kingFrom.isValid || !rookFrom.isValid) return null;
    }

    final spec = CastlingSpec(
      color: color,
      right: right,
      kingFrom: kingFrom,
      kingTo: kingTo,
      rookFrom: rookFrom,
      rookTo: rookTo,
      kingPiece: color == whiteColor ? wKing : bKing,
      rookPiece: color == whiteColor ? wRook : bRook,
      emptyMask: Bitboard.zero, // filled below
      safeSquares: castlingKingPathMask(kingFrom, kingTo),
    );

    return CastlingSpec(
      color: spec.color,
      right: spec.right,
      kingFrom: spec.kingFrom,
      kingTo: spec.kingTo,
      rookFrom: spec.rookFrom,
      rookTo: spec.rookTo,
      kingPiece: spec.kingPiece,
      rookPiece: spec.rookPiece,
      emptyMask: castlingEmptyMask(spec),
      safeSquares: spec.safeSquares,
    );
  }

  Bitboard castlingEmptyMask(CastlingSpec spec) {
    final occupiedByCastlingPieces =
        Bitboard((1 << spec.kingFrom.value) | (1 << spec.rookFrom.value));
    return (castlingBetweenInclusiveMask(spec.kingFrom, spec.kingTo) |
            castlingBetweenInclusiveMask(spec.rookFrom, spec.rookTo)) &
        ~occupiedByCastlingPieces;
  }

  Bitboard castlingKingPathMask(Square from, Square to) {
    return castlingBetweenInclusiveMask(from, to);
  }

  Bitboard castlingBetweenInclusiveMask(Square from, Square to) {
    if (!from.isValid || !to.isValid) return Bitboard.zero;
    var mask = 1 << from.value;
    if (from == to) return Bitboard(mask);

    final rankDelta = to.rank() - from.rank();
    final fileDelta = to.file() - from.file();
    final rankStep = rankDelta.sign;
    final fileStep = fileDelta.sign;

    if (rankDelta != 0 &&
        fileDelta != 0 &&
        rankDelta.abs() != fileDelta.abs()) {
      return Bitboard.zero;
    }

    var r = from.rank();
    var f = from.file();
    while (r != to.rank() || f != to.file()) {
      r += rankStep;
      f += fileStep;
      mask |= (1 << (r * 8 + f));
    }
    return Bitboard(mask);
  }

  CastlingSpec? castlingSpecForMove(Move m) {
    if (!m.isCastling()) return null;
    for (final right in [castleWks, castleWqs, castleBks, castleBqs]) {
      final spec = castlingSpec(right);
      if (spec == null) continue;
      if (spec.kingFrom == m.from() && spec.kingTo == m.to()) {
        return spec;
      }
    }
    return null;
  }

  CastlingSpec? castlingSpecForUndoMove(Move m, int color) {
    if (!m.isCastling()) return null;
    final right = castlingRightForMoveDestination(color, m.to());
    if (right == 0) return null;
    final kingside = castlingRightIsKingside(right);
    final finalSquares = castlingFinalSquares(color, kingside);
    final kingTo = finalSquares.$1;
    final rookTo = finalSquares.$2;

    var rookFrom = castlingRookFrom[right];
    if (variant != Variant.chess960) {
      switch (right) {
        case castleWks:
          rookFrom = const Square(wksRookOriginalSquare);
          break;
        case castleWqs:
          rookFrom = const Square(wqsRookOriginalSquare);
          break;
        case castleBks:
          rookFrom = const Square(bksRookOriginalSquare);
          break;
        case castleBqs:
          rookFrom = const Square(bqsRookOriginalSquare);
          break;
      }
    }
    if (!m.from().isValid || !rookFrom.isValid) return null;
    return CastlingSpec(
      color: color,
      right: right,
      kingFrom: m.from(),
      kingTo: kingTo,
      rookFrom: rookFrom,
      rookTo: rookTo,
      kingPiece: color == whiteColor ? wKing : bKing,
      rookPiece: color == whiteColor ? wRook : bRook,
      emptyMask: Bitboard.zero,
      safeSquares: Bitboard.zero,
    );
  }

  int castlingRightForMoveDestination(int color, Square to) {
    final kingsideKingTo = castlingFinalSquares(color, true).$1;
    if (to == kingsideKingTo) {
      return castlingRightFor(color, true);
    }
    final queensideKingTo = castlingFinalSquares(color, false).$1;
    if (to == queensideKingTo) {
      return castlingRightFor(color, false);
    }
    return 0;
  }

  bool castlingKingPathIsSafe(CastlingSpec spec, int opponent) {
    var squares = spec.safeSquares;
    while (squares.isNotEmpty) {
      final square = Square(squares.lsbIndex());
      squares = Bitboard(squares.value & (squares.value - 1));
      var occupiedAfter = occupied;
      occupiedAfter &= ~Bitboard(1 << spec.kingFrom.value);
      occupiedAfter &= ~Bitboard(1 << spec.rookFrom.value);
      occupiedAfter |= Bitboard(1 << square.value);
      occupiedAfter |= Bitboard(1 << spec.rookTo.value);
      if (isSquareAttackedByWithOccupied(square, opponent, occupiedAfter)) {
        return false;
      }
    }
    return true;
  }

  void clearCastlingRightsForRookSquare(Square square) {
    for (final right in [castleWks, castleWqs, castleBks, castleBqs]) {
      if (castlingRookFrom[right] == square) {
        castling &= ~right;
      }
    }
  }

  // Move making
  void tryMove(Move m) {
    generateLegalMoves();
    for (final legal in legalMoves) {
      if (_moveMatchesRequest(legal, m)) {
        makeMove(legal);
        return;
      }
    }
    throw FormatException('Illegal move: ${m.uci()}');
  }

  bool _moveMatchesRequest(Move legal, Move requested) {
    if (legal.from() != requested.from() || legal.to() != requested.to()) {
      return false;
    }
    if (legal.isPromotion() || requested.isPromotion()) {
      return legal.promotionTo() == requested.promotionTo();
    }
    return true;
  }

  void makeMove(Move m) {
    _recordPGNMove(m);
    _makeMoveInternal(m, true, true);
  }

  void makeMoveFast(Move m) {
    _makeMoveInternal(m, false, true);
  }

  void _makeMoveInternal(
      Move m, bool updatePositionHistory, bool generateLegal) {
    // Capture state for UndoMove
    var captured = squares[m.to().value];
    if (m.isEnPassant()) {
      if (turn == whiteColor) {
        captured = squares[m.to().value + 8];
      } else {
        captured = squares[m.to().value - 8];
      }
    }

    history.add(GameState(
      capturedPiece: captured,
      castling: castling,
      castlingRookFrom: List.from(castlingRookFrom),
      variantState: variantState.clone(),
      enPassant: enPassant,
      halfMoves: halfMoves,
      fullMoves: fullMoves,
      zobristHash: zobristHash,
    ));

    if (captured != Piece.empty || squares[m.from().value].kind() == typePawn) {
      halfMoves = 0;
    } else {
      halfMoves++;
    }

    if (squares[m.from().value].color() == blackColor) {
      fullMoves++;
    }

    justMove(m);

    final kind = squares[m.to().value].kind();
    if (kind == typeKing) {
      if (turn == whiteColor) {
        castling &= ~(castleWks | castleWqs);
      } else {
        castling &= ~(castleBks | castleBqs);
      }
    }
    if (kind == typeRook) {
      clearCastlingRightsForRookSquare(m.from());
    }

    clearCastlingRightsForRookSquare(m.to());

    // enPassant square
    enPassant = Square.noSquare;
    if (kind == typePawn && turn == whiteColor) {
      if (m.from().rank() == 6 && m.to().rank() == 4) {
        enPassant = Square(m.from().value - 8);
      }
    }
    if (kind == typePawn && turn == blackColor) {
      if (m.from().rank() == 1 && m.to().rank() == 3) {
        enPassant = Square(m.from().value + 8);
      }
    }

    // Switch turn
    turn = oppositeColor(turn);

    // Call variant hook
    final afterMoveHook = rulesForVariant(variant).afterMove;
    if (afterMoveHook != null) {
      afterMoveHook(this, m, history.last);
    }

    if (updatePositionHistory) {
      recordPosition();
    }

    if (generateLegal) {
      generateLegalMoves();
      if (updatePositionHistory) {
        refreshStatus();
      }
    }
  }

  void justMove(Move m) {
    if (m.isCastling()) {
      justCastle(m);
      return;
    }

    final from = m.from();
    final to = m.to();
    final capturedPiece = squares[to.value];

    final fromBBNeg = ~Bitboard(1 << from.value);
    final toBB = Bitboard(1 << to.value);
    final movingPiece = squares[from.value];
    final movingPieceKind = movingPiece.kind();

    if (movingPiece.isWhite) {
      whites[movingPieceKind] &= fromBBNeg;
      whites[movingPieceKind] |= toBB;
      whitePieces &= fromBBNeg;
      whitePieces |= toBB;
    } else {
      blacks[movingPieceKind] &= fromBBNeg;
      blacks[movingPieceKind] |= toBB;
      blackPieces &= fromBBNeg;
      blackPieces |= toBB;
    }

    occupied &= fromBBNeg;
    occupied |= toBB;

    squares[to.value] = squares[from.value];
    squares[from.value] = Piece.empty;

    if (m.isEnPassant()) {
      final capSq =
          turn == whiteColor ? Square(to.value + 8) : Square(to.value - 8);
      final capPiece = squares[capSq.value];
      capturePiece(capSq, capPiece);
      occupied &= ~Bitboard(1 << capSq.value);
      squares[capSq.value] = Piece.empty;
    } else if (capturedPiece != Piece.empty) {
      capturePiece(to, capturedPiece);
    }

    final promoteTo = m.promotionTo();
    if (promoteTo != typeEmpty) {
      if (squares[to.value].isWhite) {
        whites[typePawn] &= ~toBB;
        whites[promoteTo] |= toBB;
        whitePieces |= toBB;
      } else {
        blacks[typePawn] &= ~toBB;
        blacks[promoteTo] |= toBB;
        blackPieces |= toBB;
      }
      squares[to.value] = Piece(promoteTo | turn);
    }
  }

  void justCastle(Move m) {
    final spec = castlingSpecForMove(m);
    if (spec == null) return;
    clearSquare(spec.kingFrom);
    clearSquare(spec.rookFrom);
    addPiece(spec.kingPiece, spec.kingTo);
    addPiece(spec.rookPiece, spec.rookTo);
  }

  void undoMove(Move m) {
    if (pgnMoves.isNotEmpty) {
      pgnMoves.removeLast();
    }
    _undoMoveInternal(m, true, true);
  }

  void undoMoveFast(Move m) {
    _undoMoveInternal(m, false, true);
  }

  void _undoMoveInternal(
      Move m, bool updatePositionHistory, bool generateLegal) {
    if (history.isEmpty) return;

    if (updatePositionHistory) {
      positionHistory[zobristHash] = (positionHistory[zobristHash] ?? 0) - 1;
      if ((positionHistory[zobristHash] ?? 0) <= 0) {
        positionHistory.remove(zobristHash);
      }
    }

    final state = history.removeLast();
    castling = state.castling;
    castlingRookFrom.setAll(0, state.castlingRookFrom);
    variantState = state.variantState;
    enPassant = state.enPassant;
    halfMoves = state.halfMoves;
    fullMoves = state.fullMoves;
    zobristHash = state.zobristHash;

    turn = oppositeColor(turn);

    unmakeMove(m, state.capturedPiece);

    if (generateLegal) {
      generateLegalMoves();
      if (updatePositionHistory) {
        refreshStatus();
      }
    }
  }

  void unmakeMove(Move m, Piece captured) {
    final from = m.from();
    final to = m.to();

    if (m.isCastling()) {
      unmakeCastle(m);
      return;
    }

    final movingPieceKind = squares[to.value].kind();

    if (m.isPromotion()) {
      final promotedKind = m.promotionTo();
      final toBB = Bitboard(1 << to.value);
      final fromBB = Bitboard(1 << from.value);

      if (turn == whiteColor) {
        whites[promotedKind] &= ~toBB;
        whitePieces &= ~toBB;
        whites[typePawn] |= fromBB;
        whitePieces |= fromBB;
      } else {
        blacks[promotedKind] &= ~toBB;
        blackPieces &= ~toBB;
        blacks[typePawn] |= fromBB;
        blackPieces |= fromBB;
      }
      squares[to.value] = Piece.empty;
      squares[from.value] = Piece(typePawn | turn);
      occupied &= ~toBB;
      occupied |= fromBB;
    } else {
      final toBB = Bitboard(1 << to.value);
      final fromBB = Bitboard(1 << from.value);

      if (turn == whiteColor) {
        whites[movingPieceKind] &= ~toBB;
        whites[movingPieceKind] |= fromBB;
        whitePieces &= ~toBB;
        whitePieces |= fromBB;
      } else {
        blacks[movingPieceKind] &= ~toBB;
        blacks[movingPieceKind] |= fromBB;
        blackPieces &= ~toBB;
        blackPieces |= fromBB;
      }
      occupied &= ~toBB;
      occupied |= fromBB;

      squares[from.value] = squares[to.value];
      squares[to.value] = Piece.empty;
    }

    if (captured != Piece.empty) {
      if (m.isEnPassant()) {
        final capSq =
            turn == whiteColor ? Square(to.value + 8) : Square(to.value - 8);
        addPiece(captured, capSq);
      } else {
        addPiece(captured, to);
      }
    }
  }

  void unmakeCastle(Move m) {
    final spec = castlingSpecForUndoMove(m, turn);
    if (spec == null) return;
    clearSquare(spec.kingTo);
    clearSquare(spec.rookTo);
    addPiece(spec.kingPiece, spec.kingFrom);
    addPiece(spec.rookPiece, spec.rookFrom);
  }

  // Insufficient Material
  bool hasInsufficientMaterial() {
    if (whites[typeQueen].isNotEmpty ||
        whites[typeRook].isNotEmpty ||
        whites[typePawn].isNotEmpty) {
      return false;
    }
    if (blacks[typeQueen].isNotEmpty ||
        blacks[typeRook].isNotEmpty ||
        blacks[typePawn].isNotEmpty) {
      return false;
    }
    if (whites[typeKnight].isNotEmpty && whites[typeBishop].isNotEmpty) {
      return false;
    }
    if (blacks[typeKnight].isNotEmpty && blacks[typeBishop].isNotEmpty) {
      return false;
    }

    if ((whites[typeBishop] | blacks[typeBishop]).isNotEmpty &&
        (whites[typeKnight] | blacks[typeKnight]).isNotEmpty) {
      return false;
    }

    if ((whites[typeBishop] | blacks[typeBishop]).isNotEmpty) {
      return _allBishopsOnSameColor(whites[typeBishop] | blacks[typeBishop]);
    }

    if (whites[typeKnight].countOnes() > 1) {
      return false;
    }
    if (blacks[typeKnight].countOnes() > 1) {
      return false;
    }

    return true;
  }

  bool _allBishopsOnSameColor(Bitboard bishops) {
    const light = Bitboard(0xAA55AA55AA55AA55);
    const dark = Bitboard(~0xAA55AA55AA55AA55);
    return (bishops & light).isEmpty || (bishops & dark).isEmpty;
  }

  void refreshStatus() {
    final comp = ComputedStatus();
    comp.isCheckmate = isCheck && legalMoves.isEmpty;
    comp.isMaterialDraw = hasInsufficientMaterial();
    comp.isThreefoldRepetition = checkThreefoldRepetition();
    comp.isFiftyMoveRule = checkFiftyMoveRule();
    comp.isSeventyFiveMoveRule = checkSeventyFiveMoveRule();
    comp.winner = noColor;
    comp.status = GameStatus.ongoing;
    comp.isStalemate = !comp.isCheckmate && legalMoves.isEmpty;

    if (comp.isCheckmate) {
      comp.status = GameStatus.checkmate;
      comp.winner = oppositeColor(turn);
    } else if (comp.isStalemate) {
      comp.status = GameStatus.stalemate;
    } else if (comp.isMaterialDraw) {
      comp.status = GameStatus.drawInsufficientMaterial;
    } else if (checkFivefoldRepetition()) {
      comp.status = GameStatus.drawFivefoldRepetition;
    } else if (comp.isSeventyFiveMoveRule) {
      comp.status = GameStatus.drawSeventyFiveMoveRule;
    } else if (isCheck) {
      comp.status = GameStatus.check;
    }

    comp.isFinished = comp.isCheckmate ||
        comp.isStalemate ||
        comp.isMaterialDraw ||
        checkFivefoldRepetition() ||
        comp.isSeventyFiveMoveRule;

    final overrideHook = rulesForVariant(variant).overrideStatus;
    if (overrideHook != null) {
      overrideHook(this, comp);
    }

    isCheckmate = comp.isCheckmate;
    isStalemate = comp.isStalemate;
    isMaterialDraw = comp.isMaterialDraw;
    isThreefoldRepetition = comp.isThreefoldRepetition;
    isFiftyMoveRule = comp.isFiftyMoveRule;
    isSeventyFiveMoveRule = comp.isSeventyFiveMoveRule;
    isFinished = comp.isFinished;
    winner = comp.winner;
    status = comp.status;
  }

  // PGN hooks
  void _recordPGNMove(Move m) {
    if (pgnMoves.isEmpty) {
      pgnStartTurn = turn;
      pgnStartFullMove = fullMoves;
      pgnStartFEN = toFEN();
      final tag = rulesForVariant(variant).pgnVariantTag;
      if (tag.isNotEmpty) {
        pgnTags ??= {};
        pgnTags!['Variant'] = tag;
        pgnTags!['SetUp'] = '1';
        pgnTags!['FEN'] = pgnStartFEN;
      }
    }
    pgnMoves.add(getMoveSAN(m));
    pgnResult = '*';
    pgnTags?.remove('Result');
  }

  String getMoveSAN(Move m) {
    final base = getMoveSanWithoutSuffix(m);
    final clone = cloneGame(this);
    clone.makeMoveFast(m);
    final isMate = clone.isCheck && clone.legalMoves.isEmpty;
    if (isMate) {
      return '$base#';
    } else if (clone.isCheck) {
      return '$base+';
    }
    return base;
  }

  String getMoveSanWithoutSuffix(Move m) {
    if (m.isCastling()) {
      if (m.to() == const Square(wksKingToSquare) ||
          m.to() == const Square(bksKingToSquare)) {
        return 'O-O';
      }
      if (m.to() == const Square(wqsKingToSquare) ||
          m.to() == const Square(bqsKingToSquare)) {
        return 'O-O-O';
      }
    }

    final from = m.from();
    final to = m.to();
    final movingKind = squares[from.value].kind();

    final buffer = StringBuffer();
    if (movingKind != typePawn) {
      buffer.write(Piece(movingKind | whiteColor).toRune().toUpperCase());
    }

    // Disambiguation
    final dis = _getDisambiguationCounts(m);
    final others = dis.others;
    if (others > 0 && movingKind != typePawn) {
      if (dis.sameFile == 0) {
        buffer.write(from.fileLetter());
      } else if (dis.sameRank == 0) {
        buffer.write(from.rankDigit());
      } else {
        buffer.write(from.coords());
      }
    }

    final isCap = m.capturedPieceKind() != typeEmpty;
    if (isCap && movingKind == typePawn) {
      buffer.write(from.fileLetter());
    }
    if (isCap) {
      buffer.write('x');
    }

    buffer.write(to.coords());

    if (m.isPromotion()) {
      buffer.write('=');
      buffer.write(Piece(m.promotionTo() | whiteColor).toRune().toUpperCase());
    }

    return buffer.toString();
  }

  _DisambiguationCounts _getDisambiguationCounts(Move m) {
    final kind = squares[m.from().value].kind();
    final from = m.from();
    final to = m.to();
    var others = 0;
    var sameFile = 0;
    var sameRank = 0;

    for (final legal in legalMoves) {
      if (legal.value == m.value) {
        continue;
      }
      if (legal.to() != to || squares[legal.from().value].kind() != kind) {
        continue;
      }
      others++;
      if (legal.from().file() == from.file()) {
        sameFile++;
      }
      if (legal.from().rank() == from.rank()) {
        sameRank++;
      }
    }

    return _DisambiguationCounts(others, sameFile, sameRank);
  }
}

class _DisambiguationCounts {
  final int others;
  final int sameFile;
  final int sameRank;
  _DisambiguationCounts(this.others, this.sameFile, this.sameRank);
}

// Helpers
int oppositeColor(int color) => color == whiteColor ? blackColor : whiteColor;

int castlingRightFor(int color, bool kingside) {
  if (color == whiteColor) {
    return kingside ? castleWks : castleWqs;
  }
  return kingside ? castleBks : castleBqs;
}

int backRankFor(int color) => color == whiteColor ? 7 : 0;

Square squareOnBackRank(int color, int file) =>
    Square(backRankFor(color) * 8 + file);

int castlingRightColor(int right) {
  switch (right) {
    case castleWks:
    case castleWqs:
      return whiteColor;
    case castleBks:
    case castleBqs:
      return blackColor;
    default:
      return noColor;
  }
}

bool castlingRightIsKingside(int right) {
  return right == castleWks || right == castleBks;
}

(Square, Square) castlingFinalSquares(int color, bool kingside) {
  if (kingside) {
    return (squareOnBackRank(color, 6), squareOnBackRank(color, 5));
  }
  return (squareOnBackRank(color, 2), squareOnBackRank(color, 3));
}

Game cloneGame(Game g) {
  final clone = Game();
  clone.whitePieces = g.whitePieces;
  clone.blackPieces = g.blackPieces;
  clone.occupied = g.occupied;
  clone.enPassant = g.enPassant;
  clone.castling = g.castling;
  clone.halfMoves = g.halfMoves;
  clone.fullMoves = g.fullMoves;
  clone.turn = g.turn;
  clone.variant = g.variant;
  clone.variantState = g.variantState.clone();
  clone.zobristHash = g.zobristHash;
  clone.isCheck = g.isCheck;
  clone.isCheckmate = g.isCheckmate;
  clone.isStalemate = g.isStalemate;
  clone.isMaterialDraw = g.isMaterialDraw;
  clone.isThreefoldRepetition = g.isThreefoldRepetition;
  clone.isFiftyMoveRule = g.isFiftyMoveRule;
  clone.isSeventyFiveMoveRule = g.isSeventyFiveMoveRule;
  clone.isFinished = g.isFinished;
  clone.winner = g.winner;
  clone.status = g.status;
  clone.history = List.from(g.history);
  clone.pgnMoves = List.from(g.pgnMoves);
  clone.pgnResult = g.pgnResult;
  clone.pgnStartTurn = g.pgnStartTurn;
  clone.pgnStartFullMove = g.pgnStartFullMove;
  clone.pgnStartFEN = g.pgnStartFEN;
  clone.pgnTags = g.pgnTags != null ? Map.from(g.pgnTags!) : null;

  clone.whites.setAll(0, g.whites);
  clone.blacks.setAll(0, g.blacks);
  clone.squares.setAll(0, g.squares);
  clone.castlingRookFrom.setAll(0, g.castlingRookFrom);
  clone.positionHistory.addAll(g.positionHistory);
  clone.legalMoves = List.from(g.legalMoves);

  return clone;
}

int sign(int v) => v < 0 ? -1 : (v > 0 ? 1 : 0);

bool isPromotionTarget(int color, Square to) {
  if (color == whiteColor) {
    return to.value < 8; // rank 8 (indices 0..7)
  }
  return to.value >= 56; // rank 1 (indices 56..63)
}
