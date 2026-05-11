---
description: Linee guida LLM per TextMerger, stack Svelte+Tauri e release notes.
---

# Istruzioni Copilot per TextMerger

Queste istruzioni vengono lette automaticamente da GitHub Copilot e da altri LLM compatibili quando lavorano in questo workspace.

## 1. Changelog operativo obbligatorio

Ogni volta che completi un task, bugfix o refactor significativo, documenta le modifiche accodandole in `docs/list_of_things_changed.md`.

- Mantieni il titolo principale esattamente: `# Modifiche recenti (in preparazione alla release)`.
- Raggruppa le modifiche sotto sezioni `## [Data Odierna] - Categoria`.
- Usa bullet nel formato `- **Etichetta breve**: Descrizione concreta della modifica`.
- Scrivi cosa e' cambiato e perche' e' utile all'utente.
- Non chiedere prima conferma: il file serve a compilare le release notes prima della pubblicazione.

## 2. UI e i18n

TextMerger usa Svelte, Tauri e Tailwind. Quando modifichi UI o testi visibili:

- Preferisci le chiavi in `src/lib/locales/*.json` alle stringhe hardcoded.
- Mantieni allineate almeno le lingue gia' presenti: `en`, `it`, `es`, `fr`, `de`.
- Dopo modifiche frontend, esegui `npm run check` dalla cartella `textmerger/`.

## 3. Release

La release GitHub deve usare `docs/release-notes.md` come corpo curato della release. Non sostituirla con release notes generate automaticamente.

Il formato deve seguire questo schema:

```markdown
## Release Notes

### Fixes

* **Area**: Fix sintetico e concreto

### Improvements

* **Area**: Miglioramento sintetico e concreto
```

Regole:

- usa `*` nelle release notes, non `-`;
- mantieni categorie brevi come `Fixes`, `Improvements`, `Packaging`, se servono;
- non creare sezioni vuote;
- evita cronologia verbosa: le release notes sono per utenti finali, il dettaglio operativo resta in `docs/list_of_things_changed.md`.

Prima di pubblicare:

- controlla `docs/list_of_things_changed.md`;
- aggiorna `docs/release-notes.md` nel formato `## Release Notes`;
- verifica la sezione con `build-publish-scripts/extract-release-notes.sh vX.Y.Z`;
- usa `build-publish-scripts/git-release.sh` per commit, tag e push.
