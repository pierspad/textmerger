import { writable } from 'svelte/store';

const defaultExcludedPatterns = [
    '.git',
    '.svn',
    '.hg',
    '.DS_Store',
    'Thumbs.db',
    'node_modules',
    '__pycache__',
    '.venv',
    '.env',
    '.vscode',
    '.idea',
    'dist',
    'build',
    'target',
    '*.meta',
    '*.pyc',
    '*.pyo',
    '*.exe',
    '*.dll',
    '*.so',
    '*.dylib',
    '*.class',
    '*.jar',
    '*.war',
    '*.ear',
    '*.zip',
    '*.tar',
    '*.gz',
    '*.rar',
    '*.7z',
    '*.iso',
    '*.img',
    '*.dmg'
];

function createSettingsStore() {
    // Load from localStorage
    const savedPatterns = localStorage.getItem('excludedPatterns');
    const initialPatterns = savedPatterns ? JSON.parse(savedPatterns) : defaultExcludedPatterns;

    const { subscribe, set, update } = writable({
        excludedPatterns: initialPatterns
    });

    return {
        subscribe,
        addPattern: (pattern: string) => update(s => {
            const newPatterns = [...s.excludedPatterns, pattern];
            localStorage.setItem('excludedPatterns', JSON.stringify(newPatterns));
            return { ...s, excludedPatterns: newPatterns };
        }),
        removePattern: (pattern: string) => update(s => {
            const newPatterns = s.excludedPatterns.filter((p: string) => p !== pattern);
            localStorage.setItem('excludedPatterns', JSON.stringify(newPatterns));
            return { ...s, excludedPatterns: newPatterns };
        }),
        resetPatterns: () => {
            localStorage.setItem('excludedPatterns', JSON.stringify(defaultExcludedPatterns));
            set({ excludedPatterns: defaultExcludedPatterns });
        }
    };
}

export const settings = createSettingsStore();
