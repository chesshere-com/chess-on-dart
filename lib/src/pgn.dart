import 'game.dart';
import 'variant.dart';
import 'piece.dart';

extension GamePGN on Game {
  /// Loads one PGN main line atomically, skipping comments, NAGs and variations.
  void loadPGN(String pgn) {
    final (tags, tokens) = _scanPGN(pgn);
    final variant = _pgnVariant(tags['Variant'] ?? '');
    final startFEN = tags['FEN']?.trim() ?? Game.startingPositionFen;
    final loaded = Game()..loadFEN(startFEN, variant);
    // Recording moves may update Result; preserve the parsed headers separately.
    loaded.pgnTags = Map<String, String>.of(tags);
    var movetextResult = '';
    for (final token in tokens) {
      var tok = token.replaceFirst(_moveNumber, '');
      if (tok.isEmpty || tok.startsWith(r'$')) continue;
      if (_isPGNResult(tok)) {
        if (movetextResult.isNotEmpty) {
          throw FormatException('Multiple PGN results');
        }
        movetextResult = tok;
        continue;
      }
      if (movetextResult.isNotEmpty) {
        throw FormatException('Moves after PGN result');
      }
      tok = _trimSANAnnotations(tok);
      if (tok.isEmpty) continue;
      final targetSq = _getTargetSquare(tok);
      var matched = false;
      for (final move in loaded.legalMoves) {
        if (targetSq != -1 && move.to().value != targetSq) continue;
        if (loaded.getMoveSanWithoutSuffix(move) == tok) {
          if (loaded.isFinished) {
            throw FormatException('Move after game ended: $token');
          }
          loaded.makeMove(move);
          matched = true;
          break;
        }
      }
      if (!matched) throw FormatException('PGN move not found: $token');
    }
    loaded.pgnResult =
        _resolvePGNResult(tags['Result'] ?? '', movetextResult, loaded);
    loaded.pgnTags ??= {};
    loaded.pgnTags!['Result'] = loaded.pgnResult;
    copyFrom(loaded);
  }

  String exportPGN() {
    final tags = Map<String, String>.of(pgnTags ?? {});
    final result = pgnResult;
    final startFEN = pgnStartFEN.isEmpty ? toFEN() : pgnStartFEN;
    if (variant != Variant.standard) {
      tags['Variant'] = rulesForVariant(variant).pgnVariantTag;
    }
    if (startFEN != Game.startingPositionFen || variant != Variant.standard) {
      tags['SetUp'] = '1';
      tags['FEN'] = startFEN;
    }
    const defaults = {
      'Event': '?',
      'Site': '?',
      'Date': '????.??.??',
      'Round': '?',
      'White': '?',
      'Black': '?',
    };
    for (final entry in defaults.entries) {
      tags[entry.key] ??= entry.value;
    }
    tags['Result'] = result;
    final buffer = StringBuffer();
    for (final entry in tags.entries) {
      final value = entry.value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      buffer.writeln('[${entry.key} "$value"]');
    }
    buffer.writeln();
    final moves = StringBuffer();
    var fullmove = pgnStartFullMove;
    var color = pgnStartTurn;
    for (var i = 0; i < pgnMoves.length; i++) {
      if (color == whiteColor) {
        moves.write('$fullmove. ${pgnMoves[i]} ');
      } else {
        moves
            .write(i == 0 ? '$fullmove... ${pgnMoves[i]} ' : '${pgnMoves[i]} ');
        fullmove++;
      }
      color = oppositeColor(color);
    }
    moves.write(result);
    buffer.write(_wrapText(moves.toString(), 80));
    return '${buffer.toString().trim()}\n';
  }
}

final _moveNumber = RegExp(r'^\d+\.+');
final _tagName = RegExp(r'^[A-Za-z0-9_]+$');

Map<String, String> parsePGNTags(String pgn) => _scanPGN(pgn).$1;

// A single linear scan keeps comment punctuation out of variation nesting and
// handles escaped tag strings independently of their contents.
(Map<String, String>, List<String>) _scanPGN(String pgn) {
  final tags = <String, String>{};
  final tokens = <String>[];
  final token = StringBuffer();
  var braces = 0;
  var variations = 0;
  var lineComment = false;
  var lineStart = true;
  void flush() {
    if (token.isNotEmpty) {
      tokens.add(token.toString());
      token.clear();
    }
  }

  for (var i = 0; i < pgn.length; i++) {
    final c = pgn[i];
    if (lineComment) {
      if (c == '\n' || c == '\r') {
        lineComment = false;
        lineStart = true;
      }
      continue;
    }
    if (braces > 0) {
      if (c == '{') braces++;
      if (c == '}') braces--;
      continue;
    }
    if (c == '{') {
      flush();
      braces++;
      continue;
    }
    if (c == ';' || (c == '%' && lineStart)) {
      flush();
      lineComment = true;
      continue;
    }
    if (c == '\n' || c == '\r' || c == ' ' || c == '\t' || c == '\uFEFF') {
      flush();
      if (c == '\n' || c == '\r') lineStart = true;
      continue;
    }
    lineStart = false;
    if (c == '(') {
      flush();
      variations++;
      continue;
    }
    if (c == ')') {
      if (variations == 0) throw FormatException('Unmatched PGN variation');
      variations--;
      continue;
    }
    if (variations > 0) continue;
    if (c == '}' || c == ']') throw FormatException('Unmatched PGN delimiter');
    if (c == '[') {
      flush();
      i++;
      while (i < pgn.length && pgn.codeUnitAt(i) <= 32) {
        i++;
      }
      final start = i;
      while (i < pgn.length && pgn.codeUnitAt(i) > 32 && pgn[i] != '"') {
        i++;
      }
      final key = pgn.substring(start, i);
      while (i < pgn.length && pgn.codeUnitAt(i) <= 32) {
        i++;
      }
      if (!_tagName.hasMatch(key) || i >= pgn.length || pgn[i] != '"') {
        throw FormatException('Invalid PGN tag');
      }
      final value = StringBuffer();
      var closed = false;
      while (++i < pgn.length) {
        final ch = pgn[i];
        if (ch == '"') {
          closed = true;
          break;
        }
        if (ch == '\\') {
          if (++i >= pgn.length || (pgn[i] != '"' && pgn[i] != '\\')) {
            throw FormatException('Invalid PGN tag escape');
          }
          value.write(pgn[i]);
        } else {
          if (ch == '\n' || ch == '\r') {
            throw FormatException('Newline in PGN tag');
          }
          value.write(ch);
        }
      }
      if (!closed) throw FormatException('Unterminated PGN tag');
      i++;
      while (i < pgn.length && pgn.codeUnitAt(i) <= 32) {
        i++;
      }
      if (i >= pgn.length || pgn[i] != ']') {
        throw FormatException('Unterminated PGN tag');
      }
      if (tags.containsKey(key)) {
        throw FormatException('Duplicate PGN tag: $key');
      }
      tags[key] = value.toString();
      continue;
    }
    token.write(c);
  }
  if (braces != 0 || variations != 0) {
    throw FormatException('Unterminated PGN comment or variation');
  }
  flush();
  return (tags, tokens);
}

bool _isPGNResult(String tok) =>
    tok == '1-0' || tok == '0-1' || tok == '1/2-1/2' || tok == '*';

String _trimSANAnnotations(String san) {
  final dollar = san.indexOf(r'$');
  var s = (dollar < 0 ? san : san.substring(0, dollar)).trim();
  while (s.isNotEmpty && '+#!?'.contains(s[s.length - 1])) {
    s = s.substring(0, s.length - 1);
  }
  return s.replaceAll('0', 'O');
}

int _getTargetSquare(String san) {
  for (var i = san.length - 1; i > 0; i--) {
    final rank = 56 - san.codeUnitAt(i);
    final file = san.codeUnitAt(i - 1) - 97;
    if (rank >= 0 && rank < 8 && file >= 0 && file < 8) return rank * 8 + file;
  }
  return -1;
}

Variant _pgnVariant(String tag) {
  if (tag.isEmpty) return Variant.standard;
  final norm = tag.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  for (final variant in Variant.values) {
    for (final name in rulesForVariant(variant).pgnNames) {
      if (name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') == norm) {
        return variant;
      }
    }
  }
  throw FormatException('Unsupported PGN variant: $tag');
}

String _resolvePGNResult(String tag, String move, Game game) {
  if (tag.isNotEmpty && !_isPGNResult(tag)) {
    throw FormatException('Invalid PGN result');
  }
  if (tag.isNotEmpty &&
      tag != '*' &&
      move.isNotEmpty &&
      move != '*' &&
      tag != move) {
    throw FormatException('Conflicting PGN results');
  }
  if (tag.isNotEmpty && tag != '*') return tag;
  if (move.isNotEmpty && move != '*') return move;
  if (!game.isFinished) return '*';
  if (game.winner == whiteColor) return '1-0';
  if (game.winner == blackColor) return '0-1';
  return '1/2-1/2';
}

String _wrapText(String text, int width) {
  final buffer = StringBuffer();
  var lineLength = 0;
  for (final word in text.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    if (lineLength > 0 && lineLength + word.length + 1 > width) {
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
