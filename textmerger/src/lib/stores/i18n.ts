import { derived, writable } from 'svelte/store';
import de from '../locales/de.json';
import en from '../locales/en.json';
import es from '../locales/es.json';
import fr from '../locales/fr.json';
import ar from '../locales/ar.json';
import hi from '../locales/hi.json';
import it from '../locales/it.json';
import ja from '../locales/ja.json';
import ko from '../locales/ko.json';
import nl from '../locales/nl.json';
import pl from '../locales/pl.json';
import pt from '../locales/pt.json';
import ru from '../locales/ru.json';
import tr from '../locales/tr.json';
import zh from '../locales/zh.json';

export interface UILanguage {
    code: string;
    name: string;
    nativeName: string;
    flag: string;
}

export const availableUILanguages: UILanguage[] = [
    { code: 'ar', name: 'Arabic', nativeName: 'العربية', flag: '🇸🇦' },
    { code: 'zh', name: 'Chinese', nativeName: '中文', flag: '🇨🇳' },
    { code: 'nl', name: 'Dutch', nativeName: 'Nederlands', flag: '🇳🇱' },
    { code: 'en', name: 'English', nativeName: 'English', flag: '🇬🇧' },
    { code: 'fr', name: 'French', nativeName: 'Français', flag: '🇫🇷' },
    { code: 'de', name: 'German', nativeName: 'Deutsch', flag: '🇩🇪' },
    { code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', flag: '🇮🇳' },
    { code: 'it', name: 'Italian', nativeName: 'Italiano', flag: '🇮🇹' },
    { code: 'ja', name: 'Japanese', nativeName: '日本語', flag: '🇯🇵' },
    { code: 'ko', name: 'Korean', nativeName: '한국어', flag: '🇰🇷' },
    { code: 'pl', name: 'Polish', nativeName: 'Polski', flag: '🇵🇱' },
    { code: 'pt', name: 'Portuguese', nativeName: 'Português', flag: '🇵🇹' },
    { code: 'ru', name: 'Russian', nativeName: 'Русский', flag: '🇷🇺' },
    { code: 'es', name: 'Spanish', nativeName: 'Español', flag: '🇪🇸' },
    { code: 'tr', name: 'Turkish', nativeName: 'Türkçe', flag: '🇹🇷' },
];

const translations: Record<string, any> = {
    en,
    it,
    es,
    fr,
    de,
    nl,
    pt,
    pl,
    ru,
    ja,
    ko,
    zh,
    ar,
    hi,
    tr
};

function createI18nStore() {
    // Try to get saved language from localStorage, default to 'en'
    const savedLang = localStorage.getItem('language') || 'en';
    const initialLang = translations[savedLang] ? savedLang : 'en';
    const { subscribe, set, update } = writable(initialLang);

    return {
        subscribe,
        set: (lang: string) => {
            if (!translations[lang]) return;
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
        let value = translations[$locale] || translations.en;
        let fallback = translations.en;

        for (const k of keys) {
            if (value && Object.prototype.hasOwnProperty.call(value, k)) {
                value = value[k];
            } else {
                value = undefined;
            }

            if (fallback && Object.prototype.hasOwnProperty.call(fallback, k)) {
                fallback = fallback[k];
            } else {
                fallback = undefined;
            }
        }

        return value ?? fallback ?? key;
    };
});

export const tShortcut = derived(locale, ($locale) => {
    return (keybind: string) => {
        if (!keybind) return '';
        let formatted = keybind;
        if ($locale === 'de') {
            formatted = formatted.replace(/\bCtrl\b/g, 'Strg');
        }
        return formatted;
    };
});
