// Chess960 back rank and FEN generator

String chess960BackRank(int position) {
  if (position < 0 || position > 959) {
    throw ArgumentError('Invalid Chess960 position: $position');
  }

  final List<String?> rank = List.filled(8, null);
  var n = position;

  final lightBishop = (n % 4) * 2 + 1;
  rank[lightBishop] = 'B';
  n = n ~/ 4;

  final darkBishop = (n % 4) * 2;
  rank[darkBishop] = 'B';
  n = n ~/ 4;

  final queenIndex = n % 6;
  rank[_emptySquares(rank)[queenIndex]] = 'Q';
  n = n ~/ 6;

  final knightIndex = n % 10;
  final knights = _knightSquares(_emptySquares(rank), knightIndex);
  rank[knights[0]] = 'N';
  rank[knights[1]] = 'N';

  final remaining = _emptySquares(rank);
  rank[remaining[0]] = 'R';
  rank[remaining[1]] = 'K';
  rank[remaining[2]] = 'R';

  return rank.join('');
}

String chess960StartingFEN(int position) {
  final whiteRank = chess960BackRank(position);
  final blackRank = whiteRank.toLowerCase();
  return '$blackRank/pppppppp/8/8/8/8/PPPPPPPP/$whiteRank w ${_chess960InitialCastlingField(whiteRank)} - 0 1';
}

String _chess960InitialCastlingField(String whiteRank) {
  final List<String> files = [];
  for (var i = 0; i < whiteRank.length; i++) {
    if (whiteRank[i] == 'R') {
      files.add(String.fromCharCode(65 + i)); // 'A' + i
    }
  }
  return '${files[1]}${files[0]}${files[1].toLowerCase()}${files[0].toLowerCase()}';
}

List<int> _emptySquares(List<String?> rank) {
  final List<int> squares = [];
  for (var i = 0; i < rank.length; i++) {
    if (rank[i] == null) squares.add(i);
  }
  return squares;
}

List<int> _knightSquares(List<int> squares, int index) {
  var current = 0;
  for (var first = 0; first < squares.length - 1; first++) {
    for (var second = first + 1; second < squares.length; second++) {
      if (current == index) {
        return [squares[first], squares[second]];
      }
      current++;
    }
  }
  return [];
}
