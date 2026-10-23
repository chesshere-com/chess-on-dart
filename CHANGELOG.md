## Unreleased

- Reuse legal-move and pin buffers, cache castling geometry, restore parent move lists on undo, and format SAN without cloning the game.
- Maintain incremental Zobrist hashes during fast search; include en-passant in repetition keys only when a legal capture exists.
- Make FEN/PGN imports transactional and validate malformed fields, counters, castling rights, pawn placement, and en-passant geometry.
- Fix compact PGN move numbers, comment/variation nesting, escaped tags, declared results, and FEN-only exports.
- Correct variant material draws, knight-versus-knight adjudication, Chess960 castling capture clocks and move ambiguity, and unsigned bitboard shifts.
- Resolve coordinate moves before SAN/undo, reject mismatched undo operations, deep-copy cloned history, and restore PGN metadata on undo.
- Add independent oracle fixtures, exhaustive attack-table verification, all 960 starting layouts, state-integrity tests, and a repeatable native benchmark.
- Document search API preconditions, allocation behavior, and native-runtime requirements.

## 0.1.0

- Initial release of high-performance, zero-allocation chess engine for Dart.
- Supports Standard Chess, Chess960, King of the Hill, and Three-Check.
- High-performance bitboards, Magic Bitboards, FEN, PGN, SAN, and UCI support.
