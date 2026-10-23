import 'dart:convert';
import 'dart:io';

import 'package:chess_on_dart/chess_on_dart.dart';

// The browser displays recorded native-engine output. It never simulates rules.
Future<void> main(List<String> args) async {
  final examples = <String, Object>{};
  for (final name in ['quickstart', 'notation', 'variants', 'search']) {
    final file = 'docs/examples/$name.dart';
    final result = await Process.run(
      Platform.resolvedExecutable,
      ['--suppress-analytics', 'run', file],
    );
    if (result.exitCode != 0) {
      throw StateError('Example $name failed: ${result.stderr}');
    }
    examples[name] = {
      'source': File(file).readAsStringSync(),
      'output': (result.stdout as String).trimRight(),
    };
  }

  final demos = [
    record('opening', 'Ruy Lopez', Variant.standard, Game.startingPositionFen, [
      'e2e4',
      'e7e5',
      'g1f3',
      'b8c6',
      'f1b5',
      'a7a6',
      'b5a4',
      'g8f6',
      'e1g1'
    ]),
    record('chess960', 'Chess960 · position 0', Variant.chess960,
        chess960StartingFEN(0), ['c2c4', 'c7c5', 'g2g3', 'g7g6']),
    record('hill', 'King of the Hill', Variant.kingOfTheHill,
        'k7/8/8/8/8/3K4/8/8 w - - 0 1', ['d3d4']),
    record('checks', 'Three-Check', Variant.threeCheck,
        '4k3/8/8/8/8/8/8/3Q3K w - - 0 1 +2+0', ['d1e2']),
    record('en-passant', 'En passant', Variant.standard,
        '4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2', ['e5d6']),
    record('promotion', 'Promotion', Variant.standard,
        '4k3/P7/8/8/8/8/8/4K3 w - - 0 1', ['a7a8q']),
  ];
  final output = '${const JsonEncoder.withIndent('  ').convert({
        'examples': examples,
        'demos': demos,
      })}\n';
  final target = File('docs/src/engine-data.json');
  if (args.contains('--check')) {
    if (!target.existsSync() || target.readAsStringSync() != output) {
      stderr.writeln(
          'Documentation output is stale. Run dart run tool/generate_docs.dart.');
      exitCode = 1;
    }
  } else {
    target.writeAsStringSync(output);
    stdout.writeln(
        'Generated ${examples.length} examples and ${demos.length} engine traces.');
  }
}

Map<String, Object> record(
    String id, String title, Variant variant, String fen, List<String> moves) {
  final game = Game()..loadFEN(fen, variant);
  Map<String, Object> snapshot(String san, String uci) => {
        'fen': game.toFEN(),
        'san': san,
        'uci': uci,
        'turn': game.turn == whiteColor ? 'White' : 'Black',
        'legalMoves': game.legalMoves.length,
        'isCheck': game.isCheck,
        'finished': game.isFinished,
        'status': game.status.name,
      };
  final frames = [snapshot('Start', '')];
  for (final uci in moves) {
    final move = Move.parseUCI(uci);
    final san = game.getMoveSAN(move);
    game.tryMove(move);
    frames.add(snapshot(san, uci));
  }
  return {'id': id, 'title': title, 'variant': variant.name, 'frames': frames};
}
