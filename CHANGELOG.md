## [2.11.1](https://github.com/pierspad/textmerger/compare/v2.11.0...v2.11.1) (2026-10-08)

### 🐛 Bug Fixes

* **packaging:** enable AppImage updates and validate desktop metadata ([66c7f34](https://github.com/pierspad/textmerger/commit/66c7f34aa0b782424cc606de02813428fb7d31e7))

## [2.11.0](https://github.com/pierspad/textmerger/compare/v2.10.8...v2.11.0) (2026-10-07)

### ✨ New Features

* support UTF-16 text and complete notebook extraction ([08c46c4](https://github.com/pierspad/textmerger/commit/08c46c4d1d2b6e9e1c69e6e2aef8ebcd8b3321f0))

## [2.10.8](https://github.com/pierspad/textmerger/compare/v2.10.7...v2.10.8) (2026-10-07)

### 🐛 Bug Fixes

* unify TextMerger branding and describe its purpose ([0f340be](https://github.com/pierspad/textmerger/commit/0f340bebd095b2ee24d5665415c13b98667905cf))

## [2.10.7](https://github.com/pierspad/textmerger/compare/v2.10.6...v2.10.7) (2026-10-07)

### 🐛 Bug Fixes

* patch vulnerable frontend development dependencies ([a355f8e](https://github.com/pierspad/textmerger/commit/a355f8e078a9b180215485068954386ff039e658))

## [2.10.6](https://github.com/pierspad/textmerger/compare/v2.10.5...v2.10.6) (2026-10-07)

### 🐛 Bug Fixes

* sync merged content with natural file sorting ([48e564b](https://github.com/pierspad/textmerger/commit/48e564b5c49b0a73a19e352075413b077afa7c7c))

## [2.10.5](https://github.com/pierspad/textmerger/compare/v2.10.4...v2.10.5) (2026-09-28)

### 🐛 Bug Fixes

* **appimage:** fix .DirIcon symlink, desktop categories, and add AppStream metainfo ([9c595fe](https://github.com/pierspad/textmerger/commit/9c595fe852c6f4f23aebcbaad0a9707ddace0bc8))

## [2.10.4](https://github.com/pierspad/textmerger/compare/v2.10.3...v2.10.4) (2026-09-10)

### 🐛 Bug Fixes

* **aur:** correggi URL LICENSE (root, non docs/) ([e3e4619](https://github.com/pierspad/textmerger/commit/e3e461961c6760eddb6ac0dc43bf7606a0ef1caf))
* **ci:** pubblicazione AUR affidabile e auto-diagnosticante ([745cbd5](https://github.com/pierspad/textmerger/commit/745cbd5485ce30162621c8bcab912f4c8771c584))

## [2.10.3](https://github.com/pierspad/textmerger/compare/v2.10.2...v2.10.3) (2026-08-03)

### 🐛 Bug Fixes

* integrate AUR publish step directly into Build and Release pipeline ([6ee0ee7](https://github.com/pierspad/textmerger/commit/6ee0ee79d7a390256f96266e7a7d9d161ebb5830))

## [2.10.2](https://github.com/pierspad/textmerger/compare/v2.10.1...v2.10.2) (2026-08-03)

### 🐛 Bug Fixes

* **deps:** update Cargo.lock to resolve Dependabot alerts (serde_with 3.21.0) ([32164d2](https://github.com/pierspad/textmerger/commit/32164d2319b2e60fa64c32ba6b2d518242ec4eb5))

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
