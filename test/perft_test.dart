import 'package:chess_on_dart/chess_on_dart.dart';
import 'package:test/test.dart';

int perft(Game g, int depth) {
  if (depth == 0) return 1;

  final moves = List<Move>.from(g.legalMoves);
  if (depth == 1) return moves.length;

  int nodes = 0;
  for (var i = 0; i < moves.length; i++) {
    final m = moves[i];
    g.makeMoveFast(m);
    nodes += perft(g, depth - 1);
    g.undoMoveFast(m);
  }
  return nodes;
}

class PerftPosition {
  final String name;
  final String fen;
  final Map<int, int> expectedNodes;

  const PerftPosition({
    required this.name,
    required this.fen,
    required this.expectedNodes,
  });
}

const knownPositions = [
  PerftPosition(
    name: 'Initial Position',
    fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    expectedNodes: {
      1: 20,
      2: 400,
      3: 8902,
      4: 197281,
      5: 4865609,
    },
  ),
  PerftPosition(
    name: 'Kiwipete',
    fen: 'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
    expectedNodes: {
      1: 48,
      2: 2039,
      3: 97862,
      4: 4085603,
    },
  ),
  PerftPosition(
    name: 'Position 3',
    fen: '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1',
    expectedNodes: {
      1: 14,
      2: 191,
      3: 2812,
      4: 43238,
      5: 674624,
    },
  ),
  PerftPosition(
    name: 'Position 4',
    fen: 'r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1',
    expectedNodes: {
      1: 6,
      2: 264,
      3: 9467,
      4: 422333,
    },
  ),
  PerftPosition(
    name: 'Position 5',
    fen: 'rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8',
    expectedNodes: {
      1: 44,
      2: 1486,
      3: 62379,
      4: 2103487,
    },
  ),
  PerftPosition(
    name: 'Position 6',
    fen:
        'r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10',
    expectedNodes: {
      1: 46,
      2: 2079,
      3: 89890,
      4: 3894594,
    },
  ),
];

void main() {
  group('Perft Tests', () {
    for (final pos in knownPositions) {
      group(pos.name, () {
        for (final entry in pos.expectedNodes.entries) {
          final depth = entry.key;
          final expected = entry.value;

          test('depth $depth', () {
            final game = Game();
            game.loadFEN(pos.fen);
            final nodes = perft(game, depth);
            expect(nodes, equals(expected));
          }, timeout: const Timeout(Duration(minutes: 5)));
        }
      });
    }
  });
}
