## 0.2.1 — 2026-10-24

### Added

- `Game(enforceGameEnd: false)` lets recorded moves and `loadPGN` continue past automatic draws (insufficient material, fivefold repetition, the 75-move rule) for applications that decide game end themselves. `isFinished` and `status` still describe each position. The default keeps 0.2.0 behaviour.

## 0.2.0 — 2026-10-24

### Performance

- Reuse legal-move and pin buffers, cache castling geometry, restore parent move lists on undo, and format SAN without cloning the game.
- Maintain incremental Zobrist hashes during fast search; include en-passant in repetition keys only when a legal capture exists.
- Measure 59.3% less user CPU time (2.46× throughput per CPU second) on the fixed native AOT perft suite with Dart 3.13.4 on macOS ARM64. Results are workload- and machine-specific; raw samples are in `benchmark/results/native_audit.json`.

### Correctness and robustness

- Make FEN/PGN imports transactional and validate malformed fields, counters, castling rights, pawn placement, and en-passant geometry.
- Fix compact PGN move numbers, comment/variation nesting, escaped tags, declared results, and FEN-only exports.
- Correct variant material draws, knight-versus-knight adjudication, Chess960 castling capture clocks and move ambiguity, and unsigned bitboard shifts.
- Resolve coordinate moves before SAN/undo, reject mismatched undo operations, deep-copy cloned history, and restore PGN metadata on undo.

### Verification and documentation

- Add independent oracle fixtures, exhaustive attack-table verification, all 960 starting layouts, state-integrity tests, and a repeatable native benchmark.
- Document search API preconditions, allocation behavior, and native-runtime requirements.
- Add a documentation website with runnable examples, a searchable API guide, recorded move replays, performance analysis, and downloadable benchmark evidence.
- Link the public documentation at https://chesshere-com.github.io/chess-on-dart/ from the README and package metadata.
- Keep website assets and build tooling out of the Dart package archive while retaining native examples, tests, and benchmarks.

### Compatibility notes

- FEN/PGN validation is stricter. Rejected imports preserve the previous game state.
- Recorded moves reject terminal board states. Undo must match the latest move and its recorded or fast API.
- Fast moves require a current legal move and skip PGN, repetition counts, and terminal-status refresh. Treat board arrays and generated move buffers as read-only.
- Threefold repetition and the 50-move rule are claimable draws; they do not automatically finish a game. Fivefold repetition and the 75-move rule do.
- Native 64-bit Dart VM/AOT is required. JavaScript and Flutter web are unsupported; WebAssembly has not been validated. Undo records and import/export APIs still allocate.

## 0.1.0

- Initial release of high-performance, zero-allocation chess engine for Dart.
- Supports Standard Chess, Chess960, King of the Hill, and Three-Check.
- High-performance bitboards, Magic Bitboards, FEN, PGN, SAN, and UCI support.
