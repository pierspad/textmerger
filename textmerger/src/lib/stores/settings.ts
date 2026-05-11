import { writable } from 'svelte/store';

interface SettingsState {
    excludedPatterns: string[];
    hiddenPatterns: string[];
    automaticUpdateChecks: boolean;
    liveSyncInterval: number;
    largeFileThreshold: number;
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

const defaultHiddenPatterns = [
    '.*',
    'node_modules'
];

const DEFAULT_SETTINGS: SettingsState = {
    excludedPatterns: defaultExcludedPatterns,
    hiddenPatterns: defaultHiddenPatterns,
    automaticUpdateChecks: true,
    liveSyncInterval: 0,
    largeFileThreshold: 40000
};

function createSettingsStore() {
    // Load from localStorage
    const savedPatterns = localStorage.getItem('excludedPatterns');
    const initialPatterns = savedPatterns ? JSON.parse(savedPatterns) : defaultExcludedPatterns;
    const savedAutomaticUpdateChecks = localStorage.getItem('automaticUpdateChecks');
    const initialAutomaticUpdateChecks = savedAutomaticUpdateChecks === null
        ? true
        : savedAutomaticUpdateChecks === 'true';

    const savedHiddenPatterns = localStorage.getItem('hiddenPatterns');
    const initialHiddenPatterns = savedHiddenPatterns ? JSON.parse(savedHiddenPatterns) : defaultHiddenPatterns;

    const savedLiveSyncInterval = localStorage.getItem('liveSyncInterval');
    const initialLiveSyncInterval = savedLiveSyncInterval ? Number(savedLiveSyncInterval) : 0;

    const savedLargeFileThreshold = localStorage.getItem('largeFileThreshold');
    const initialLargeFileThreshold = savedLargeFileThreshold ? Number(savedLargeFileThreshold) : 30000;

    const { subscribe, set, update } = writable<SettingsState>({
        ...DEFAULT_SETTINGS,
        excludedPatterns: initialPatterns,
        hiddenPatterns: initialHiddenPatterns,
        automaticUpdateChecks: initialAutomaticUpdateChecks,
        liveSyncInterval: initialLiveSyncInterval,
        largeFileThreshold: initialLargeFileThreshold
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
        addHiddenPattern: (pattern: string) => update(s => {
            const newPatterns = [...s.hiddenPatterns, pattern];
            localStorage.setItem('hiddenPatterns', JSON.stringify(newPatterns));
            return { ...s, hiddenPatterns: newPatterns };
        }),
        removeHiddenPattern: (pattern: string) => update(s => {
            const newPatterns = s.hiddenPatterns.filter((p: string) => p !== pattern);
            localStorage.setItem('hiddenPatterns', JSON.stringify(newPatterns));
            return { ...s, hiddenPatterns: newPatterns };
        }),
        resetHiddenPatterns: () => {
            localStorage.setItem('hiddenPatterns', JSON.stringify(defaultHiddenPatterns));
            update(s => ({ ...s, hiddenPatterns: defaultHiddenPatterns }));
        },
        setAutomaticUpdateChecks: (enabled: boolean) => {
            localStorage.setItem('automaticUpdateChecks', String(enabled));
            update(s => ({ ...s, automaticUpdateChecks: enabled }));
        },
        setLiveSyncInterval: (interval: number) => {
            localStorage.setItem('liveSyncInterval', String(interval));
            update(s => ({ ...s, liveSyncInterval: interval }));
        },
        setLargeFileThreshold: (threshold: number) => {
            localStorage.setItem('largeFileThreshold', String(threshold));
            update(s => ({ ...s, largeFileThreshold: threshold }));
        }
    };
}

export const settings = createSettingsStore();
