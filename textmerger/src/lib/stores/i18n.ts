import { derived, writable } from 'svelte/store';
import de from '../locales/de.json';
import en from '../locales/en.json';
import es from '../locales/es.json';
import fr from '../locales/fr.json';
import it from '../locales/it.json';

const translations = {
    en,
    it,
    es,
    fr,
    de
};

function createI18nStore() {
    // Try to get saved language from localStorage, default to 'en'
    const savedLang = localStorage.getItem('language') || 'en';
    const { subscribe, set, update } = writable(savedLang);

    return {
        subscribe,
        set: (lang: string) => {
            localStorage.setItem('language', lang);
            set(lang);
        },
        toggle: () => update(n => n === 'en' ? 'it' : 'en')
    };
}

export const locale = createI18nStore();

export const t = derived(locale, ($locale) => {
    return (key: string) => {
        const keys = key.split('.');
        // @ts-ignore
        let value = translations[$locale];
        for (const k of keys) {
            if (value && value[k]) {
                value = value[k];
            } else {
                return key;
            }
        }
        return value;
    };
});
