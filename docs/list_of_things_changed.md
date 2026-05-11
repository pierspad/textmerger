# Modifiche recenti (in preparazione alla release)

## [Data Odierna] - UI, Settings e Navigazione Tab
- **Palette snackbar**: Esteso il feedback temporaneo con varianti `success`, `info`, `warning` ed `error`, ciascuna con colore, icona e barra di esaurimento dedicati.
- **Scorciatoie tab**: Aggiunte shortcut di navigazione rapida fra tab con `Ctrl+PageUp`, `Ctrl+PageDown` e selezione diretta tramite `Ctrl+1` fino a `Ctrl+9`.
- **Tooltip tab**: Aggiunti tooltip sulle tab con nome, numero file, totale caratteri e anteprima dei percorsi caricati.
- **Azioni tab contestuali**: Aggiunte le opzioni `Duplicate Tab` e `Close Tabs to the Right` nel menu contestuale delle tab.
- **Settings shortcut layout**: Riorganizzata la schermata scorciatoie in una griglia a due colonne sui layout larghi, cosi' da mostrare piu' comandi insieme.
- **Pannello app settings**: Aggiunto nella sidebar impostazioni un riquadro informativo con nome app, versione, stack, licenza e link al repository.

## [Data Odierna] - Release Automation e Harness LLM
- **Istruzioni Copilot/LLM**: Aggiunto un harness di progetto per obbligare gli agenti a documentare le modifiche e mantenere le release notes allineate.
- **Release notes sezionate**: Aggiornato il flusso di release affinche' GitHub pubblichi la sezione corretta di `docs/release-notes.md` invece di note generate automaticamente.
- **Formato markdown coerente**: Allineata la struttura di changelog operativo e release notes allo stile usato in VESTA, con sezioni leggibili e bullet descrittivi.
