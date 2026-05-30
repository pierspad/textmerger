# Modifiche recenti (in preparazione alla release)

* **Refactoring delle Variabili CSS**:
  * Sostituite tutte le vecchie proprietà CSS personalizzate (legacy) come `--bg-primary`, `--bg-secondary`, `--bg-tertiary`, `--text-primary`, `--text-secondary`, `--text-muted`, `--border-color`, `--border-light`, `--accent-color`, `--accent-hover` con i nomi canonici abbreviati (`--bg`, `--surface`, `--surface-2`, `--text`, `--muted`, `--border`, `--accent`, `--accent-hover`) in tutta l'applicazione.
  * Aggiornate le definizioni in `textmerger/textmerger/src/app.css` per dichiarare esclusivamente le variabili canoniche con transizioni fluide globali.
  * Aggiornate le variabili inline e le classi in `textmerger/textmerger/src/lib/components/Modal.svelte`, `textmerger/textmerger/src/lib/components/Settings.svelte` e `textmerger/textmerger/src/App.svelte`.
  * Risolto un bug di sintassi in `Settings.svelte` (un tag `</div>` duplicato alla fine del file introdotto durante la sostituzione delle variabili).

* **Aggiornamento delle Regole di Sviluppo (.cursorrules)**:
  * Sincronizzato il file `.cursorrules` con l'introduzione dei principi avanzati di Armonia Visiva UI/UX (gestione stati di validazione, CSS shimmer skeleton, empty states animati, accessibilità del contrasto, CSS logical properties per internazionalizzazione e ottimizzazione GPU specifica per Tauri).
  * Rimosse le vecchie mappature e note di compatibilità per le variabili CSS legacy ormai deprecate.
