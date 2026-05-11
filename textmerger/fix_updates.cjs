const fs = require('fs');

// 1. Update it.json
let itJsonPath = '/home/ribben/Desktop/Various_Projects/textmerger/textmerger/src/lib/locales/it.json';
let itJson = JSON.parse(fs.readFileSync(itJsonPath, 'utf8'));
itJson.settings.automaticUpdateChecks = "Controllo automatico\naggiornamenti";
itJson.settings.liveSyncHint = "Imposta a 0 per disabilitare la funzione.";
itJson.settings.largeFileThresholdHint = "Seleziona dopo quanti caratteri un file viene troncato. Imposta a 0 per disabilitare la funzione (non troncare mai).";
itJson.shortcuts.hideDirContent = "Nascondi contenuto";
itJson.shortcuts.showDirContent = "Mostra contenuto";
itJson.shortcuts.showDirRecursive = "Mostra ricorsivamente";
itJson.shortcuts.revealDirRecursive = "Mostra per intero ricorsivamente";
fs.writeFileSync(itJsonPath, JSON.stringify(itJson, null, 2));

// 2. Update en.json
let enJsonPath = '/home/ribben/Desktop/Various_Projects/textmerger/textmerger/src/lib/locales/en.json';
let enJson = JSON.parse(fs.readFileSync(enJsonPath, 'utf8'));
enJson.settings.liveSyncHint = "Set to 0 to disable this feature.";
enJson.settings.largeFileThresholdHint = "Select after how many characters a file is truncated. Set to 0 to disable this feature (never truncate).";
enJson.shortcuts.hideDirContent = "Hide content";
enJson.shortcuts.showDirContent = "Show content";
enJson.shortcuts.showDirRecursive = "Show recursively";
enJson.shortcuts.revealDirRecursive = "Reveal full content recursively";
fs.writeFileSync(enJsonPath, JSON.stringify(enJson, null, 2));

// 3. Update tauri.conf.json
let tauriPath = '/home/ribben/Desktop/Various_Projects/textmerger/textmerger/src-tauri/tauri.conf.json';
let tauriConf = JSON.parse(fs.readFileSync(tauriPath, 'utf8'));
tauriConf.app.windows[0].minHeight = 780;
fs.writeFileSync(tauriPath, JSON.stringify(tauriConf, null, 2));

console.log('JSON files updated');
