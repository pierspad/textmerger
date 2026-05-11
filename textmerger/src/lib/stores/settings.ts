import { writable } from 'svelte/store';

interface SettingsState {
    excludedPatterns: string[];
    automaticUpdateChecks: boolean;
}

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

const DEFAULT_SETTINGS: SettingsState = {
    excludedPatterns: defaultExcludedPatterns,
    automaticUpdateChecks: true
};

function createSettingsStore() {
    // Load from localStorage
    const savedPatterns = localStorage.getItem('excludedPatterns');
    const initialPatterns = savedPatterns ? JSON.parse(savedPatterns) : defaultExcludedPatterns;
    const savedAutomaticUpdateChecks = localStorage.getItem('automaticUpdateChecks');
    const initialAutomaticUpdateChecks = savedAutomaticUpdateChecks === null
        ? true
        : savedAutomaticUpdateChecks === 'true';

    const { subscribe, set, update } = writable<SettingsState>({
        ...DEFAULT_SETTINGS,
        excludedPatterns: initialPatterns,
        automaticUpdateChecks: initialAutomaticUpdateChecks
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
            update(s => ({ ...s, excludedPatterns: defaultExcludedPatterns }));
        },
        setAutomaticUpdateChecks: (enabled: boolean) => {
            localStorage.setItem('automaticUpdateChecks', String(enabled));
            update(s => ({ ...s, automaticUpdateChecks: enabled }));
        }
    };
}

export const settings = createSettingsStore();
