import 'game.dart';
import 'variant.dart';
import 'piece.dart';

// Extension on Game to load and export PGN
extension GamePGN on Game {
  void loadPGN(String pgn) {
    final tags = parsePGNTags(pgn);
    final variantName = tags['Variant'] ?? '';
    final variant = _pgnVariant(variantName);

    var startFEN = Game.startingPositionFen;
    if (tags['FEN'] != null) {
      startFEN = tags['FEN']!.trim();
    } else if (variant == Variant.threeCheck) {
      startFEN = '${Game.startingPositionFen} +0+0';
    }

    final loaded = Game();
    loaded.loadFEN(startFEN, variant);
    loaded.pgnTags = tags;
    loaded.pgnStartFEN = startFEN;
    loaded.pgnStartTurn = loaded.turn;
    loaded.pgnStartFullMove = loaded.fullMoves;

    final fastPath = !pgn.contains('[') &&
        !pgn.contains('{') &&
        !pgn.contains('(') &&
        !pgn.contains(';');

    final List<String> tokens =
        fastPath ? _fastTokenizeMoves(pgn) : _tokenizePGNMoves(pgn);

    var movetextResult = '';
    for (var tok in tokens) {
      tok = tok.trim();
      if (tok.isEmpty) continue;
      if (_isPGNResult(tok)) {
        movetextResult = tok;
        continue;
      }
      // Skip move numbers and NAGs
      if (tok.contains('..') || tok.contains('.') || tok.startsWith('\$')) {
        continue;
      }

      final normalizedTok = _trimSANAnnotations(tok);
      if (normalizedTok.isEmpty) continue;

      final targetSq = _getTargetSquare(normalizedTok);

      var matched = false;
      for (final mv in loaded.legalMoves) {
        if (targetSq != -1 && mv.to().value != targetSq) {
          continue;
        }

        final san = _trimSANAnnotations(loaded.getMoveSanWithoutSuffix(mv));
        if (san == normalizedTok) {
          loaded.makeMove(mv);
          matched = true;
          break;
        }
      }
      if (!matched) {
        throw FormatException('PGN move not found: $tok');
      }
    }

    final resolvedResult =
        _resolvePGNResult(tags['Result'] ?? '', movetextResult, loaded);
    loaded.pgnResult = resolvedResult;
    loaded.pgnTags ??= {};
    loaded.pgnTags!['Result'] = resolvedResult;

    // Apply loaded state to this game
    whitePieces = loaded.whitePieces;
    blackPieces = loaded.blackPieces;
    occupied = loaded.occupied;
    enPassant = loaded.enPassant;
    castling = loaded.castling;
    halfMoves = loaded.halfMoves;
    fullMoves = loaded.fullMoves;
    turn = loaded.turn;
    this.variant = loaded.variant;
    variantState = loaded.variantState;
    zobristHash = loaded.zobristHash;
    isCheck = loaded.isCheck;
    isCheckmate = loaded.isCheckmate;
    isStalemate = loaded.isStalemate;
    isMaterialDraw = loaded.isMaterialDraw;
    isThreefoldRepetition = loaded.isThreefoldRepetition;
    isFiftyMoveRule = loaded.isFiftyMoveRule;
    isSeventyFiveMoveRule = loaded.isSeventyFiveMoveRule;
    isFinished = loaded.isFinished;
    winner = loaded.winner;
    status = loaded.status;
    history = List.from(loaded.history);
    pgnMoves = List.from(loaded.pgnMoves);
    pgnResult = loaded.pgnResult;
    pgnStartTurn = loaded.pgnStartTurn;
    pgnStartFullMove = loaded.pgnStartFullMove;
    pgnStartFEN = loaded.pgnStartFEN;
    pgnTags = loaded.pgnTags;

    whites.setAll(0, loaded.whites);
    blacks.setAll(0, loaded.blacks);
    squares.setAll(0, loaded.squares);
    castlingRookFrom.setAll(0, loaded.castlingRookFrom);
    positionHistory.clear();
    positionHistory.addAll(loaded.positionHistory);
    legalMoves = List.from(loaded.legalMoves);
  }

  String exportPGN() {
    final tags = pgnTags ?? {};
    final result = pgnResult;

    // Fill standard tags if missing
    final seven = [
      'Event',
      'Site',
      'Date',
      'Round',
      'White',
      'Black',
      'Result'
    ];
    final defaults = {
      'Event': '?',
      'Site': '?',
      'Date': '????.??.??',
      'Round': '?',
      'White': '?',
      'Black': '?',
      'Result': result,
    };
    for (final key in seven) {
      tags[key] ??= defaults[key]!;
    }
    tags['Result'] = result;

    final buffer = StringBuffer();
    // Export tag headers
    for (final key in tags.keys) {
      buffer.write('[$key "${tags[key]}"]\n');
    }
    buffer.write('\n');

    // Movetext formatting
    final moveTextBuffer = StringBuffer();
    var currentFullmove = pgnStartFullMove;
    var currentTurn = pgnStartTurn;

    for (var i = 0; i < pgnMoves.length; i++) {
      if (currentTurn == whiteColor) {
        moveTextBuffer.write('$currentFullmove. ${pgnMoves[i]} ');
      } else {
        if (i == 0) {
          moveTextBuffer.write('$currentFullmove... ${pgnMoves[i]} ');
        } else {
          moveTextBuffer.write('${pgnMoves[i]} ');
        }
        currentFullmove++;
      }
      currentTurn = oppositeColor(currentTurn);
    }
    moveTextBuffer.write(result);

    // Line wrapping at 80 chars
    buffer.write(_wrapText(moveTextBuffer.toString(), 80));
    return '${buffer.toString().trim()}\n';
  }
}

// Global PGN helper functions
Map<String, String> parsePGNTags(String pgn) {
  final tags = <String, String>{};
  final lines = pgn.split('\n');
  for (var line in lines) {
    line = line.trim();
    if (line.startsWith('[') && line.endsWith(']')) {
      final body = line.substring(1, line.length - 1).trim();
      final spaceIdx = body.indexOf(RegExp(r'\s'));
      if (spaceIdx > 0) {
        final key = body.substring(0, spaceIdx);
        var rest = body.substring(spaceIdx).trim();
        if (rest.startsWith('"') && rest.endsWith('"')) {
          final val = rest
              .substring(1, rest.length - 1)
              .replaceAll('\\"', '"')
              .replaceAll('\\\\', '\\');
          tags[key] = val;
        }
      }
    }
  }
  return tags;
}

List<String> _tokenizePGNMoves(String pgn) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  var braceDepth = 0;
  var parenDepth = 0;
  var inTag = false;
  var inLineComment = false;
  var lineStart = true;

  void flush() {
    if (buffer.length > 0) {
      tokens.add(buffer.toString());
      buffer.clear();
    }
  }

  for (var i = 0; i < pgn.length; i++) {
    final c = pgn[i];
    if (inLineComment) {
      if (c == '\n') {
        inLineComment = false;
        lineStart = true;
      }
      continue;
    }
    if (c == '\n') {
      lineStart = true;
      inTag = false;
      flush();
      continue;
    }
    if (lineStart) {
      if (c == ' ' || c == '\t' || c == '\r') {
        continue;
      }
      inTag = c == '[';
      lineStart = false;
    }

    if (inTag) continue;

    switch (c) {
      case ';':
        inLineComment = true;
        flush();
        continue;
      case '{':
        braceDepth++;
        flush();
        continue;
      case '}':
        if (braceDepth > 0) braceDepth--;
        flush();
        continue;
      case '(':
        parenDepth++;
        flush();
        continue;
      case ')':
        if (parenDepth > 0) parenDepth--;
        flush();
        continue;
    }

    if (braceDepth > 0 || parenDepth > 0) continue;

    if (c == ' ' || c == '\t' || c == '\r') {
      flush();
      continue;
    }

    buffer.write(c);
  }
  flush();
  return tokens;
}

List<String> _fastTokenizeMoves(String pgn) {
  final tokens = <String>[];
  var start = -1;
  for (var i = 0; i <= pgn.length; i++) {
    final charCode = i < pgn.length ? pgn.codeUnitAt(i) : 32;
    if (i == pgn.length ||
        charCode == 32 ||
        charCode == 9 ||
        charCode == 10 ||
        charCode == 13) {
      if (start >= 0) {
        tokens.add(pgn.substring(start, i));
        start = -1;
      }
      continue;
    }
    if (start == -1) {
      start = i;
    }
  }
  return tokens;
}

bool _isPGNResult(String tok) {
  return tok == '1-0' || tok == '0-1' || tok == '1/2-1/2' || tok == '*';
}

String _trimSANAnnotations(String san) {
  final dollarIdx = san.indexOf('\$');
  var s = dollarIdx >= 0 ? san.substring(0, dollarIdx) : san;

  // Trim trailing check/mate +!?
  s = s.trim();
  while (s.isNotEmpty &&
      (s.endsWith('+') ||
          s.endsWith('#') ||
          s.endsWith('!') ||
          s.endsWith('?'))) {
    s = s.substring(0, s.length - 1);
  }

  // Remove leading numbers (e.g. "12.Nf3" => "Nf3")
  var startIdx = 0;
  while (startIdx < s.length) {
    final charCode = s.codeUnitAt(startIdx);
    if ((charCode >= 48 && charCode <= 57) || charCode == 46) {
      // digit or dot
      startIdx++;
    } else {
      break;
    }
  }
  return s.substring(startIdx);
}

int _getTargetSquare(String san) {
  for (var i = san.length - 1; i >= 0; i--) {
    final code = san.codeUnitAt(i);
    if (code >= 49 && code <= 56) {
      // '1' - '8'
      if (i > 0) {
        final fCode = san.codeUnitAt(i - 1);
        if (fCode >= 97 && fCode <= 104) {
          // 'a' - 'h'
          final file = fCode - 97;
          final rank = 56 - code; // '8' is 0, '1' is 7
          return rank * 8 + file;
        }
      }
    }
  }
  return -1;
}

Variant _pgnVariant(String tag) {
  final norm = tag.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  for (final v in Variant.values) {
    final rules = rulesForVariant(v);
    for (final name in rules.pgnNames) {
      final nameNorm = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (nameNorm == norm) return v;
    }
  }
  return Variant.standard;
}

String _resolvePGNResult(String tagRes, String movetextRes, Game g) {
  final tag = tagRes.trim();
  final move = movetextRes.trim();
  final inferred = _inferPGNResult(g);

  if (tag.isNotEmpty && tag != '*') return tag;
  if (move.isNotEmpty && move != '*') return move;
  return inferred;
}

String _inferPGNResult(Game g) {
  if (!g.isFinished) return '*';
  if (g.winner == whiteColor) return '1-0';
  if (g.winner == blackColor) return '0-1';
  return '1/2-1/2';
}

String _wrapText(String text, int width) {
  final buffer = StringBuffer();
  final words = text.split(RegExp(r'\s+'));
  var lineLength = 0;
  for (final word in words) {
    if (word.isEmpty) continue;
    if (lineLength + word.length + (lineLength > 0 ? 1 : 0) > width) {
      buffer.write('\n');
      lineLength = 0;
    }
    if (lineLength > 0) {
      buffer.write(' ');
      lineLength++;
    }
    buffer.write(word);
    lineLength += word.length;
  }
  return buffer.toString();
}
