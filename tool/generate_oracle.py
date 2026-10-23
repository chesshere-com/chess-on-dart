"""Regenerate deterministic test data with python-chess (tested with 1.11.2).

Development only: pip install python-chess==1.999
Run from the repository root: python3 tool/generate_oracle.py
"""
import json
import random
from pathlib import Path

import chess
import chess.variant

rng = random.Random(0xC0D3)


def fen(board):
    # Preserve this package's +checks-given FEN extension for Three-Check.
    result = ' '.join([
        board.board_fen(), 'w' if board.turn else 'b',
        board.castling_shredder_fen() if board.chess960 else board.castling_xfen(),
        chess.square_name(board.ep_square) if board.ep_square is not None else '-',
        str(board.halfmove_clock), str(board.fullmove_number),
    ])
    if isinstance(board, chess.variant.ThreeCheckBoard):
        result += f' +{3-board.remaining_checks[chess.WHITE]}+{3-board.remaining_checks[chess.BLACK]}'
    return result


def move_key(board, move):
    if board.is_castling(move):
        rank = chess.square_rank(move.from_square)
        target = chess.square(6 if board.is_kingside_castling(move) else 2, rank)
        return chess.square_name(move.from_square) + chess.square_name(target) + ' castle'
    return move.uci()


cases = []
seen = set()


def add(board, variant):
    key = (fen(board), variant)
    if key in seen:
        return
    seen.add(key)
    moves = list(board.legal_moves)
    selected = rng.choice(moves) if moves else None
    case = {
        'variant': variant,
        'fen': fen(board),
        'moves': sorted(move_key(board, m) for m in moves),
        'check': board.is_check(),
        'insufficient': board.is_insufficient_material(),
    }
    if selected:
        case['selected'] = move_key(board, selected)
        case['san'] = board.san(selected)
        board.push(selected)
        case['after'] = fen(board)
        board.pop()
    cases.append(case)


for variant in ['standard', 'chess960', 'kingOfTheHill', 'threeCheck']:
    for game in range(8):
        if variant == 'standard':
            board = chess.Board()
        elif variant == 'chess960':
            board = chess.Board.from_chess960_pos(rng.randrange(960))
        elif variant == 'kingOfTheHill':
            board = chess.variant.KingOfTheHillBoard()
        else:
            board = chess.variant.ThreeCheckBoard()
        for ply in range(96):
            if ply % 12 == 0:
                add(board, variant)
            moves = list(board.legal_moves)
            if not moves or board.is_game_over():
                add(board, variant)
                break
            # Include captures preferentially to exercise sparse endgames.
            captures = [m for m in moves if board.is_capture(m)]
            board.push(rng.choice(captures if captures and rng.random() < .4 else moves))

# Every pair of king/rook files, including stationary kings/rooks and swaps,
# with both colors to move. The enemy king is kept out of the rook's file.
for color in chess.COLORS:
    for king_file in range(8):
        for rook_file in range(8):
            if king_file == rook_file:
                continue
            board = chess.Board(None, chess960=True)
            rank = 0 if color else 7
            board.set_piece_at(chess.square(king_file, rank), chess.Piece(chess.KING, color))
            rook_square = chess.square(rook_file, rank)
            board.set_piece_at(rook_square, chess.Piece(chess.ROOK, color))
            board.set_piece_at(chess.square((rook_file + 4) % 8, 7 - rank), chess.Piece(chess.KING, not color))
            board.turn = color
            board.castling_rights = chess.BB_SQUARES[rook_square]
            assert board.is_valid()
            add(board, 'chess960')

Path('test/fixtures/oracle_positions.json').write_text(json.dumps({
    'source': f'python-chess {chess.__version__}', 'seed': 0xC0D3, 'positions': cases,
}, indent=2) + '\n')
print(f'Generated {len(cases)} oracle positions')
