# Contributing

Search existing issues before opening a new one. For major changes, discuss the scope in an issue first.

## Issues

Use the bug report or feature request template. Include exact versions, reproduction steps, expected and actual behavior. Use small sample files when relevant; remove personal content and credentials from attachments.

## Pull requests

Keep changes focused. Explain the problem and resulting behavior, link related issues, and report the checks you ran and their results. Add regression coverage for behavior changes and update affected documentation. For interface changes, include a screenshot and update translations where needed.

## Development

Run from `textmerger/`:

```sh
npm ci
npm run check
npm run build
cargo test --manifest-path src-tauri/Cargo.toml
```

Rust checks require the native build dependencies listed in the [README](README.md#building-from-source).
