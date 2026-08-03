## [2.10.1](https://github.com/pierspad/textmerger/compare/v2.10.0...v2.10.1) (2026-08-03)

### 🐛 Bug Fixes

* automatic AUR publish trigger on release tags and retry logic ([02c3526](https://github.com/pierspad/textmerger/commit/02c35266583411da266bec011c110ca7e2e44435))

## [2.10.0](https://github.com/pierspad/textmerger/compare/v2.9.6...v2.10.0) (2026-08-03)

### ✨ New Features

* **core:** upgrade to Rust 2024 & Rust 1.97 with multi-folder parallel scanning and reactive UI tree memoization ([b0bfa00](https://github.com/pierspad/textmerger/commit/b0bfa00960930d230be04a5ae15ec18dc3b13bf2))

### 🔧 Improvements

* memoize FileIcon SVG string to eliminate inline re-parsing ([c88e859](https://github.com/pierspad/textmerger/commit/c88e859d0b0edd7dd3419f751bf82c49fc673fda))
* memoize FileTreeNode sortedChildren and nodeHidden reactively ([9e1dff4](https://github.com/pierspad/textmerger/commit/9e1dff484a388f9fc4095593f04ebef7507b66a9))
* optimize backend filesystem traversal, frontend tree memoization, and single-pass html extraction ([2a3bcbf](https://github.com/pierspad/textmerger/commit/2a3bcbfd6cd295e0f99f97da2a86433f5629c596))
* optimize directory traversal using cached file_type and parallel flat_map, fix stack limit in tab path calculation ([abd98b9](https://github.com/pierspad/textmerger/commit/abd98b9c3d3d64c90ccfa0b4188ecf817d2779c1))
* optimize tree compaction, isForcedFullLoad, removeSelected lookups, and avoid redundant re-merging on settings changes ([616ba62](https://github.com/pierspad/textmerger/commit/616ba62635aaf1308330a192dc79a4e678e6d24c))

## [2.9.6](https://github.com/pierspad/textmerger/compare/v2.9.5...v2.9.6) (2026-08-03)

### 🔧 Improvements

* **rust:** upgrade rust-version to 1.97.0 and leverage zero-alloc stack buffer & let-else idioms ([a11ce7e](https://github.com/pierspad/textmerger/commit/a11ce7e8d2eab818cc9fcf81eaa85dfe6b4a793d))

## [2.9.5](https://github.com/pierspad/textmerger/compare/v2.9.4...v2.9.5) (2026-08-03)

### 🐛 Bug Fixes

* **deps:** update postcss to >=8.5.18 to resolve security vulnerability ([2f6919a](https://github.com/pierspad/textmerger/commit/2f6919acaa1a2a06bd32d4f7f74c30ea83d9921e))

### ♻️ Refactoring

* **rust:** upgrade to Rust 2024 edition and implement modern Rust idioms ([7e583a8](https://github.com/pierspad/textmerger/commit/7e583a8ed582e410ea704318258588dd63d9a279))
