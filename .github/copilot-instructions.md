---
description: Linee guida LLM per TextMerger, stack Svelte+Tauri e release.
---

# Istruzioni Copilot per TextMerger

Queste istruzioni vengono lette automaticamente da GitHub Copilot e da altri LLM compatibili quando lavorano in questo workspace.

## 1. Conventional Commits obbligatori

I messaggi di commit SONO le release notes: semantic-release genera il body della GitHub Release e il `CHANGELOG.md` direttamente dai commit. Non esistono file di note manuali da aggiornare.

- Usa sempre il formato Conventional Commits: `tipo(scope): descrizione`.
  - `feat:` → minor bump, sezione "✨ New Features";
  - `fix:` → patch bump, sezione "🐛 Bug Fixes";
  - `perf:`/`refactor:` → patch bump;
  - `feat!:`/`fix!:` o footer `BREAKING CHANGE:` → major bump;
  - `chore:`/`docs:`/`test:`/`ci:` → nessun rilascio.
- Scrivi la descrizione pensando all'utente finale che la leggerà nella release: sintetica, concreta, con lo scope che indica l'area toccata.
- Il dettaglio tecnico va nel body del commit, non serve altrove.

## 2. UI e i18n

TextMerger usa Svelte, Tauri e Tailwind. Quando modifichi UI o testi visibili:

- Preferisci le chiavi in `src/lib/locales/*.json` alle stringhe hardcoded.
- Mantieni allineate almeno le lingue gia' presenti: `en`, `it`, `es`, `fr`, `de`.
- Dopo modifiche frontend, esegui `npm run check` dalla cartella `textmerger/`.

## 3. Release

Il rilascio è interamente gestito da **semantic-release** (`release.yml`, config in `.releaserc`), stesso design di vesta. Nessuno script locale, nessun file di note manuale.

- **Push su `main`** → release stabile `vX.Y.Z`, marcata Latest su GitHub e pubblicata su AUR.
- **Push su `dev`** → prerelease `vX.Y.Z-dev.N`, marcata Pre-release: non diventa mai Latest e non va mai su AUR.
- Il body della release e `CHANGELOG.md` sono generati dai Conventional Commits (§1). Non riscriverli a mano.
- Il PKGBUILD (`build-publish-scripts/PKGBUILD`) è la Single Source of Truth della versione: `update_project_info.sh` la propaga a tauri.conf.json, Cargo.toml, Cargo.lock, package.json e .desktop. Non bumpare versioni a mano.
- Coerenza versioni verificata in CI con `build-publish-scripts/check_version_consistency.sh` (include anche `Cargo.lock`).
- Flusso: semantic-release calcola il bump → propaga versione → commit `chore: Release vX.Y.Z [skip ci]` + tag → crea la GitHub Release → dispatcha "Build and Release" sul tag (upload binari) → backmerge `main → dev`.
