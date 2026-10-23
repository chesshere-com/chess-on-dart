# Documentation website

Four static pages inspired by the dark, green-accented [ChessHere chessboard documentation](https://chesshere-com.github.io/chessboard/). The header, footer, and homepage link to [www.chesshere.com](https://www.chesshere.com/).

No npm dependencies, CDN resources, web fonts, or client framework are required. Node.js 20+ builds the pages; Python is only used for the optional local server.

```sh
node tool/build_docs.mjs
python3 -m http.server 8783 --bind 127.0.0.1 --directory docs/dist
```

Open http://127.0.0.1:8783/. All asset and navigation paths are relative, so the site also works under a GitHub Pages repository path.

## Content and verification

- Edit page content and shared markup in `docs/src/pages.mjs`.
- Edit appearance in `docs/src/styles.css` and interactions in `docs/src/app.js`.
- Complete runnable Dart examples live in `docs/examples/`.
- `tool/generate_docs.dart` runs the examples and records the move-replay positions using the native library. The browser only replays this data; it does not run a Dart chess engine.
- Benchmark charts and tables read `benchmark/results/native_audit.json` at build time. The raw data and harness are included as downloads. CPU and wall-time measurements remain distinct.
- The documentation is pinned to audited library commit `44906d82aec047b7b33cf94557047eb0cf940236`; the published 0.1.0 package predates those changes. Update the pin and performance evidence together when documenting another revision.

After changing examples or the library:

```sh
dart run tool/generate_docs.dart
dart run tool/generate_docs.dart --check
node tool/build_docs.mjs
node tool/check_docs.mjs
```

The check validates local pages, anchors, downloads, benchmark values, and replay data. Browser checks additionally cover menu navigation, API filtering, clipboard behavior, replay controls, and benchmark selection.

## Publishing

`.github/workflows/docs.yml` checks and builds the site on pull requests. It deploys `docs/dist` on pushes to `main` or a manual run from `main`, using GitHub Pages Actions. The repository must have **Settings → Pages → Build and deployment → Source: GitHub Actions** enabled.

The expected GitHub Pages location after merge and deployment is https://chesshere-com.github.io/chess-on-dart/. A successful workflow deployment, not this URL alone, confirms publication.

A separate private Sites preview uses the ignored `.site-preview/chess-on-dart-docs/` checkout. It contains the static output and its own hosting identity; it does not change the library repository’s Git remotes.
