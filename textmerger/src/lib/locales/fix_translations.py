import json
import glob

# For all languages, I will supply generic translations or fallbacks.
translations = {
    'it': {
        'app.outputsHidden': 'Mostra output\nNotebook ridotti',
        'app.outputsReduced': 'Mostra output\nNotebook interi',
        'app.outputsFull': 'Nascondi output\nNotebook',
        'settings.hiddenFiles': 'File Nascosti',
        'settings.hiddenFilesDescription': 'I file e le cartelle che corrispondono a questi pattern verranno nascosti. Puoi ancora rivelarli manualmente.',
        'contextMenu.hideContent': 'Nascondi contenuto',
        'contextMenu.showContent': 'Mostra contenuto',
        'contextMenu.refreshFolderOnly': 'Aggiorna solo questa cartella',
        'contextMenu.refreshFolderRecursive': 'Aggiorna cartella ricorsivamente',
        'contextMenu.showRecursive': 'Mostra ricorsivamente',
        'settings.categoryAll': 'Tutte',
        'settings.categoryGeneral': 'Generale',
        'settings.categoryClipboard': 'Appunti',
        'settings.categoryTabs': 'Tab',
        'settings.categoryFileActions': 'Azioni File',
        'shortcuts.hideDirContent': 'Nascondi contenuto',
        'shortcuts.showDirContent': 'Mostra contenuto',
        'shortcuts.showDirRecursive': 'Mostra ricorsivamente',
        'shortcuts.revealDirRecursive': 'Mostra per intero ricorsivamente',
        'settings.clickToCustomize': 'Clicca per personalizzare'
    },
    'en': {
        'app.outputsHidden': 'Show reduced\nNotebook outputs',
        'app.outputsReduced': 'Show full\nNotebook outputs',
        'app.outputsFull': 'Hide Notebook\noutputs',
        'settings.hiddenFiles': 'Hidden Files',
        'settings.hiddenFilesDescription': 'Files and folders matching these patterns will be hidden. You can still reveal them manually.',
        'contextMenu.hideContent': 'Hide content',
        'contextMenu.showContent': 'Show content',
        'contextMenu.refreshFolderOnly': 'Refresh this folder only',
        'contextMenu.refreshFolderRecursive': 'Refresh folder recursively',
        'contextMenu.showRecursive': 'Show recursively',
        'settings.categoryAll': 'All',
        'settings.categoryGeneral': 'General',
        'settings.categoryClipboard': 'Clipboard',
        'settings.categoryTabs': 'Tabs',
        'settings.categoryFileActions': 'File Actions',
        'shortcuts.hideDirContent': 'Hide content',
        'shortcuts.showDirContent': 'Show content',
        'shortcuts.showDirRecursive': 'Show recursively',
        'shortcuts.revealDirRecursive': 'Reveal full content recursively',
        'settings.clickToCustomize': 'Click to customize'
    },
    'zh': {
        'app.outputsHidden': '显示精简\n笔记本输出',
        'app.outputsReduced': '显示完整\n笔记本输出',
        'app.outputsFull': '隐藏\n笔记本输出',
        'settings.hiddenFiles': '隐藏文件',
        'settings.hiddenFilesDescription': '匹配这些模式的文件和文件夹将被隐藏。您可以手动显示它们。',
        'contextMenu.hideContent': '隐藏内容',
        'contextMenu.showContent': '显示内容',
        'contextMenu.refreshFolderOnly': '仅刷新此文件夹',
        'contextMenu.refreshFolderRecursive': '递归刷新文件夹',
        'contextMenu.showRecursive': '递归显示',
        'settings.categoryAll': '全部',
        'settings.categoryGeneral': '常规',
        'settings.categoryClipboard': '剪贴板',
        'settings.categoryTabs': '标签页',
        'settings.categoryFileActions': '文件操作',
        'shortcuts.hideDirContent': '隐藏内容',
        'shortcuts.showDirContent': '显示内容',
        'shortcuts.showDirRecursive': '递归显示',
        'shortcuts.revealDirRecursive': '递归显示完整内容',
        'settings.clickToCustomize': '点击进行自定义'
    },
    'de': {
        'app.outputsHidden': 'Reduzierte Notebook\nAusgaben anzeigen',
        'app.outputsReduced': 'Vollständige Notebook\nAusgaben anzeigen',
        'app.outputsFull': 'Notebook Ausgaben\nausblenden',
        'settings.hiddenFiles': 'Versteckte Dateien',
        'settings.hiddenFilesDescription': 'Dateien und Ordner, die diesen Mustern entsprechen, werden ausgeblendet.',
        'contextMenu.hideContent': 'Inhalt ausblenden',
        'contextMenu.showContent': 'Inhalt anzeigen',
        'contextMenu.refreshFolderOnly': 'Nur diesen Ordner aktualisieren',
        'contextMenu.refreshFolderRecursive': 'Ordner rekursiv aktualisieren',
        'contextMenu.showRecursive': 'Rekursiv anzeigen',
        'settings.categoryAll': 'Alle',
        'settings.categoryGeneral': 'Allgemein',
        'settings.categoryClipboard': 'Zwischenablage',
        'settings.categoryTabs': 'Tabs',
        'settings.categoryFileActions': 'Dateiaktionen',
        'shortcuts.hideDirContent': 'Inhalt ausblenden',
        'shortcuts.showDirContent': 'Inhalt anzeigen',
        'shortcuts.showDirRecursive': 'Rekursiv anzeigen',
        'shortcuts.revealDirRecursive': 'Vollständigen Inhalt rekursiv anzeigen',
        'settings.clickToCustomize': 'Klicken zum Anpassen'
    },
    'es': {
        'app.outputsHidden': 'Mostrar salidas de\nNotebook reducidas',
        'app.outputsReduced': 'Mostrar salidas de\nNotebook completas',
        'app.outputsFull': 'Ocultar salidas de\nNotebook',
        'settings.hiddenFiles': 'Archivos Ocultos',
        'settings.hiddenFilesDescription': 'Los archivos y carpetas que coincidan con estos patrones se ocultarán.',
        'contextMenu.hideContent': 'Ocultar contenido',
        'contextMenu.showContent': 'Mostrar contenido',
        'contextMenu.refreshFolderOnly': 'Actualizar solo esta carpeta',
        'contextMenu.refreshFolderRecursive': 'Actualizar carpeta recursivamente',
        'contextMenu.showRecursive': 'Mostrar recursivamente',
        'settings.categoryAll': 'Todas',
        'settings.categoryGeneral': 'General',
        'settings.categoryClipboard': 'Portapapeles',
        'settings.categoryTabs': 'Pestañas',
        'settings.categoryFileActions': 'Acciones de Archivos',
        'shortcuts.hideDirContent': 'Ocultar contenido',
        'shortcuts.showDirContent': 'Mostrar contenido',
        'shortcuts.showDirRecursive': 'Mostrar recursivamente',
        'shortcuts.revealDirRecursive': 'Mostrar contenido completo recursivamente',
        'settings.clickToCustomize': 'Haz clic para personalizar'
    },
    'fr': {
        'app.outputsHidden': 'Afficher les sorties\nNotebook réduites',
        'app.outputsReduced': 'Afficher les sorties\nNotebook complètes',
        'app.outputsFull': 'Masquer les sorties\nNotebook',
        'settings.hiddenFiles': 'Fichiers Masqués',
        'settings.hiddenFilesDescription': 'Les fichiers et dossiers correspondant à ces motifs seront masqués.',
        'contextMenu.hideContent': 'Masquer le contenu',
        'contextMenu.showContent': 'Afficher le contenu',
        'contextMenu.refreshFolderOnly': 'Actualiser ce dossier uniquement',
        'contextMenu.refreshFolderRecursive': 'Actualiser le dossier récursivement',
        'contextMenu.showRecursive': 'Afficher récursivement',
        'settings.categoryAll': 'Toutes',
        'settings.categoryGeneral': 'Général',
        'settings.categoryClipboard': 'Presse-papiers',
        'settings.categoryTabs': 'Onglets',
        'settings.categoryFileActions': 'Actions Fichiers',
        'shortcuts.hideDirContent': 'Masquer le contenu',
        'shortcuts.showDirContent': 'Afficher le contenu',
        'shortcuts.showDirRecursive': 'Afficher récursivement',
        'shortcuts.revealDirRecursive': 'Afficher le contenu complet récursivement',
        'settings.clickToCustomize': 'Cliquer pour personnaliser'
    }
}

for filepath in glob.glob('*.json'):
    lang = filepath.replace('.json', '')
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    t_data = translations.get(lang, translations['en'])
    
    for key, val in t_data.items():
        parts = key.split('.')
        base_key, sub_key = parts[0], parts[1]
        if base_key not in data:
            data[base_key] = {}
        data[base_key][sub_key] = val
        
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

print("Done updating translations.")
