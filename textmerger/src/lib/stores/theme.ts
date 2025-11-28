import { writable } from 'svelte/store';

function createThemeStore() {
    const stored = localStorage.getItem('textmerger_theme') || 'dark';
    const { subscribe, set } = writable(stored);

    // Apply theme to document
    if (typeof document !== 'undefined') {
        document.documentElement.setAttribute('data-theme', stored);
    }

    return {
        subscribe,
        setTheme: (theme: 'light' | 'dark') => {
            set(theme);
            localStorage.setItem('textmerger_theme', theme);
            document.documentElement.setAttribute('data-theme', theme);
        },
        toggle: () => {
            const current = localStorage.getItem('textmerger_theme') === 'light' ? 'dark' : 'light';
            set(current);
            localStorage.setItem('textmerger_theme', current);
            document.documentElement.setAttribute('data-theme', current);
        }
    };
}

export const theme = createThemeStore();
