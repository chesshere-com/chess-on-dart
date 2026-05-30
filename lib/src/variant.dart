import 'move.dart';
import 'game_state.dart';
import 'piece.dart';
import 'square.dart';
import 'game.dart';

enum Variant {
  standard,
  chess960,
  kingOfTheHill,
  threeCheck,
}

enum GameStatus {
  ongoing,
  check,
  checkmate,
  stalemate,
  drawInsufficientMaterial,
  drawThreefoldRepetition,
  drawFivefoldRepetition,
  drawFiftyMoveRule,
  drawSeventyFiveMoveRule,
  variantWin,
}

// Interface to override status during game checks
class ComputedStatus {
  bool isCheckmate = false;
  bool isStalemate = false;
  bool isMaterialDraw = false;
  bool isThreefoldRepetition = false;
  bool isFiftyMoveRule = false;
  bool isSeventyFiveMoveRule = false;
  bool isFinished = false;
  int winner = noColor;
  GameStatus status = GameStatus.ongoing;
}

// Abstract/Base representation of variant hooks
class VariantRules {
  final Variant variant;
  final String name;
  final bool implemented;
  final void Function(Game game, Move move, GameState prev)? afterMove;
  final void Function(Game game, ComputedStatus status)? overrideStatus;
  final int Function(Game game)? hashExtra;
  final String pgnVariantTag;
  final List<String> pgnNames;

  const VariantRules({
    required this.variant,
    required this.name,
    required this.implemented,
    this.afterMove,
    this.overrideStatus,
    this.hashExtra,
    required this.pgnVariantTag,
    required this.pgnNames,
  });
}

// Standard Variant Rules
const standardVariantRules = VariantRules(
  variant: Variant.standard,
  name: 'standard',
  implemented: true,
  pgnVariantTag: 'Standard',
  pgnNames: ['Standard', 'standard', 'Chess', 'chess'],
);

// Chess960 Variant Rules
const chess960VariantRules = VariantRules(
  variant: Variant.chess960,
  name: 'chess960',
  implemented: true,
  pgnVariantTag: 'Fischerandom',
  pgnNames: [
    'Fischerandom',
    'Fischer Random',
    'fischerandom',
    'fischer random',
    'chess960',
    'Chess960'
  ],
);

// King of the Hill rules
final kingOfTheHillCenter = (1 << const Square(27).value) |
    (1 << const Square(28).value) |
    (1 << const Square(35).value) |
    (1 << const Square(36).value);

void kingOfTheHillStatus(Game game, ComputedStatus status) {
  final wKing = game.whites[typeKing].value;
  if ((wKing & kingOfTheHillCenter) != 0) {
    status.isFinished = true;
    status.winner = whiteColor;
    status.status = GameStatus.variantWin;
    return;
  }
  final bKing = game.blacks[typeKing].value;
  if ((bKing & kingOfTheHillCenter) != 0) {
    status.isFinished = true;
    status.winner = blackColor;
    status.status = GameStatus.variantWin;
  }
}

final kingOfTheHillVariantRules = VariantRules(
  variant: Variant.kingOfTheHill,
  name: 'kingofthehill',
  implemented: true,
  overrideStatus: kingOfTheHillStatus,
  pgnVariantTag: 'King of the Hill',
  pgnNames: ['King of the Hill', 'KingOfTheHill', 'kingofthehill'],
);

// Three-Check rules
void threeCheckAfterMove(Game game, Move move, GameState prev) {
  if (!game.computeIsCheck()) {
    return;
  }
  final mover = game.turn == whiteColor ? blackColor : whiteColor;
  final idx = mover == whiteColor ? 0 : 1;
  if (game.variantState.checksGiven[idx] < 3) {
    game.variantState.checksGiven[idx]++;
  }
}

void threeCheckStatus(Game game, ComputedStatus status) {
  if (game.variantState.checksGiven[0] >= 3) {
    status.isFinished = true;
    status.winner = whiteColor;
    status.status = GameStatus.variantWin;
    return;
  }
  if (game.variantState.checksGiven[1] >= 3) {
    status.isFinished = true;
    status.winner = blackColor;
    status.status = GameStatus.variantWin;
  }
}

int threeCheckHashExtra(Game game) {
  return (game.variantState.checksGiven[0] << 2) |
      game.variantState.checksGiven[1];
}

final threeCheckVariantRules = VariantRules(
  variant: Variant.threeCheck,
  name: 'threecheck',
  implemented: true,
  afterMove: threeCheckAfterMove,
  overrideStatus: threeCheckStatus,
  hashExtra: threeCheckHashExtra,
  pgnVariantTag: 'Three-check',
  pgnNames: ['Three-check', 'ThreeCheck', '3-check', '3check'],
);

VariantRules rulesForVariant(Variant variant) {
  switch (variant) {
    case Variant.standard:
      return standardVariantRules;
    case Variant.chess960:
      return chess960VariantRules;
    case Variant.kingOfTheHill:
      return kingOfTheHillVariantRules;
    case Variant.threeCheck:
      return threeCheckVariantRules;
  }
}
