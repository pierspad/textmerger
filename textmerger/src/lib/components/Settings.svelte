<script lang="ts">
  import { createEventDispatcher, onMount } from "svelte";
  import { getName, getVersion } from "@tauri-apps/api/app";
  import { open as openExternal } from "@tauri-apps/plugin-shell";
  import { shortcuts, ACTION_ICONS, type Shortcuts } from "../stores/shortcuts";
  import { settings } from "../stores/settings";
  import { theme } from "../stores/theme";
  import { availableUILanguages, t, locale } from "../stores/i18n";
  import KeybindRecorder from "./KeybindRecorder.svelte";
  import FileIcon from "./FileIcon.svelte";
  import { ask } from "@tauri-apps/plugin-dialog";

  type SnackbarVariant = "success" | "info" | "warning" | "error";

  function handleWindowKeydown(e: KeyboardEvent) {
    if (showConfirmModal) {
      if (e.key === 'Enter') {
        e.preventDefault();
        showConfirmModal = false;
        onConfirm();
        return;
      }
      if (e.key === 'Escape') {
        e.preventDefault();
        showConfirmModal = false;
        return;
      }
    }

    if (e.ctrlKey && !e.shiftKey && !e.altKey) {
      if (e.key === 'PageDown' || e.key === 'ArrowRight') {
        e.preventDefault();
        const tabs = ['general', 'shortcuts', 'exclusions', 'hiddenFiles'];
        const idx = tabs.indexOf(activeTab);
        activeTab = tabs[(idx + 1) % tabs.length];
      } else if (e.key === 'PageUp' || e.key === 'ArrowLeft') {
        e.preventDefault();
        const tabs = ['general', 'shortcuts', 'exclusions', 'hiddenFiles'];
        const idx = tabs.indexOf(activeTab);
        activeTab = tabs[(idx - 1 + tabs.length) % tabs.length];
      }
    }
  }


  let liveSyncInput = ''; 
  $: liveSyncInput = $settings.liveSyncInterval.toString();

  let largeFileInput = '';
  $: largeFileInput = new Intl.NumberFormat().format($settings.largeFileThreshold);

  function resetGeneralDefaults() {
    locale.set('en');
    theme.setTheme('dark');
    settings.setAutomaticUpdateChecks(true);
    settings.setLiveSyncInterval(0);
    settings.setLargeFileThreshold(30000);
    liveSyncInput = '0';
    largeFileInput = '30,000';
  }

  function handleLiveSyncInput(e: Event) {
    let val = (e.currentTarget as HTMLInputElement).value;
    val = val.replace(/\D/g, '');
    if (val === '' || val === '0') {
      (e.currentTarget as HTMLInputElement).value = '0';
      liveSyncInput = '0';
      settings.setLiveSyncInterval(0);
    } else {
      const num = parseInt(val, 10);
      (e.currentTarget as HTMLInputElement).value = num.toString();
      liveSyncInput = num.toString();
      settings.setLiveSyncInterval(num);
    }
  }

  function handleLargeFileInput(e: Event) {
    let val = (e.currentTarget as HTMLInputElement).value;
    val = val.replace(/\D/g, '');
    if (val === '' || val === '0') {
      (e.currentTarget as HTMLInputElement).value = '0';
      largeFileInput = '0';
      settings.setLargeFileThreshold(0);
    } else {
      const num = parseInt(val, 10);
      const formatted = new Intl.NumberFormat().format(num);
      (e.currentTarget as HTMLInputElement).value = formatted;
      largeFileInput = formatted;
      settings.setLargeFileThreshold(num);
    }
  }

  const shortcutCategories = [
    { id: 'all', key: 'settings.categoryAll', actions: null },
    { id: 'general', key: 'settings.categoryGeneral', actions: ['open', 'save', 'exit', 'refresh'] },
    { id: 'clipboard', key: 'settings.categoryClipboard', actions: ['copyText', 'copyPath', 'copyFilename', 'copyFileContent'] },
    { id: 'tabs', key: 'settings.categoryTabs', actions: ['newTab', 'closeTab', 'previousTab', 'nextTab', 'tab1', 'tab2', 'tab3', 'tab4', 'tab5', 'tab6', 'tab7', 'tab8', 'tab9'] },
    { id: 'fileActions', key: 'settings.categoryFileActions', actions: ['remove', 'removeAll', 'toggleVisibility', 'refreshFolder', 'refreshFolderRecursive', 'revealFullContent'] }
  ];
  let selectedShortcutCategory = 'all';
  
  $: filteredShortcuts = shortcutEntries.filter(([actionKey, _]) => {
      if (selectedShortcutCategory === 'all') return true;
      const cat = shortcutCategories.find(c => c.id === selectedShortcutCategory);
      return cat?.actions?.includes(actionKey);
  });

  type UpdateStatus = "idle" | "checking" | "available" | "current" | "error" | "disabled";

  interface GitHubRelease {
    tag_name?: string;
    html_url?: string;
    name?: string;
  }

  export let sidebarWidth = 300;

  const dispatch = createEventDispatcher();

  let activeTab = "general";
  let recordingAction: string | null = null;
  let newPattern = "";
  let newHiddenPattern = "";
  let appName = "TextMerger";
  let appVersion = "";
  let updateStatus: UpdateStatus = "idle";
  let latestVersion = "";
  let updateError = "";

  const repoUrl = "https://github.com/pierspad/textmerger";
  const latestReleaseApiUrl = "https://api.github.com/repos/pierspad/textmerger/releases/latest";
  const authorUrl = "https://pierspad.com";
  const licenseUrl = "https://www.gnu.org/licenses/gpl-3.0.html";

  $: shortcutEntries = Object.entries($shortcuts) as [keyof Shortcuts, string][];
  $: releaseUrl = appVersion ? `${repoUrl}/releases/tag/v${appVersion}` : `${repoUrl}/releases`;
  $: formattedAppVersion = appVersion ? formatVersion(appVersion) : $t('settings.versionUnavailable');

  onMount(async () => {
    try {
      const [name, version] = await Promise.all([getName(), getVersion()]);
      appName = name === "textmerger" ? "TextMerger" : name || appName;
      appVersion = version || appVersion;
    } catch (e) {
      console.warn("Could not read Tauri app metadata", e);
    } finally {
      if ($settings.automaticUpdateChecks) {
        void checkForUpdates("auto");
      } else {
        updateStatus = "disabled";
      }
    }
  });

  function addPattern() {
    if (newPattern.trim()) {
        settings.addPattern(newPattern.trim());
        newPattern = "";
    }
  }

  function addHiddenPattern() {
    if (newHiddenPattern.trim()) {
        settings.addHiddenPattern(newHiddenPattern.trim());
        newHiddenPattern = "";
    }
  }

  function closeSettings() {
    dispatch("close");
  }

  function notify(message: string, variant: SnackbarVariant = "success") {
    dispatch("snackbar", { message, variant });
  }

  async function openExternalLink(url: string) {
    try {
      await openExternal(url);
    } catch (e) {
      console.error("Failed to open external link", e);
      notify($t('messages.openLinkFailed'), "error");
    }
  }

  let showConfirmModal = false;
  let confirmTitle = "";
  let confirmMessage = "";
  let onConfirm: () => void = () => {};

  function triggerResetConfirmation() {
    if (activeTab === 'shortcuts') {
      confirmTitle = $t('settings.resetDefaults');
      confirmMessage = $t('settings.resetConfirm');
      onConfirm = () => {
        try {
          shortcuts.resetDefaults();
          notify($t('settings.resetSuccess'));
        } catch (e) {
          console.error("Failed to reset defaults:", e);
          notify($t('settings.resetError'), "error");
        }
      };
      showConfirmModal = true;
    } else if (activeTab === 'exclusions') {
      confirmTitle = $t('settings.resetPatterns');
      confirmMessage = $locale === 'it' 
        ? "Sei sicuro di voler ripristinare tutti i pattern di esclusione ai valori predefiniti?" 
        : "Are you sure you want to reset all excluded patterns to default?";
      onConfirm = () => {
        try {
          settings.resetPatterns();
          notify($locale === 'it' ? "Pattern di esclusione ripristinati" : "Excluded patterns reset");
        } catch (e) {
          console.error("Failed to reset patterns:", e);
          notify($locale === 'it' ? "Errore nel ripristino dei pattern" : "Error resetting patterns", "error");
        }
      };
      showConfirmModal = true;
    } else if (activeTab === 'hiddenFiles') {
      confirmTitle = $locale === 'it' ? "Ripristina File Nascosti" : "Reset Hidden Files";
      confirmMessage = $locale === 'it' 
        ? "Sei sicuro di voler ripristinare tutti i pattern dei file nascosti ai valori predefiniti?" 
        : "Are you sure you want to reset all hidden file patterns to default?";
      onConfirm = () => {
        try {
          settings.resetHiddenPatterns();
          notify($locale === 'it' ? "Pattern file nascosti ripristinati" : "Hidden file patterns reset");
        } catch (e) {
          console.error("Failed to reset hidden patterns:", e);
          notify($locale === 'it' ? "Errore nel ripristino dei pattern" : "Error resetting patterns", "error");
        }
      };
      showConfirmModal = true;
    } else if (activeTab === 'general') {
      confirmTitle = $t('settings.resetDefaults');
      confirmMessage = $locale === 'it' 
        ? "Sei sicuro di voler ripristinare tutte le impostazioni generali ai valori predefiniti?" 
        : "Are you sure you want to reset all general settings to default?";
      onConfirm = () => {
        try {
          resetGeneralDefaults();
          notify($locale === 'it' ? "Impostazioni generali ripristinate" : "General settings reset");
        } catch (e) {
          console.error("Failed to reset general defaults:", e);
          notify($locale === 'it' ? "Errore nel ripristino delle impostazioni" : "Error resetting settings", "error");
        }
      };
      showConfirmModal = true;
    }
  }

  function handleShortcutChange(action: string, newBind: string) {
    const duplicate = shortcutEntries.find(([key, keybind]) => {
      return key !== action && normalizeShortcut(keybind) === normalizeShortcut(newBind);
    });

    if (duplicate) {
      notify(`${$t('settings.duplicateShortcut')} ${getLabel(duplicate[0])}.`, "warning");
      recordingAction = null;
      return;
    }

    shortcuts.updateShortcut(action as keyof Shortcuts, newBind);
    recordingAction = null;
  }

  function getIcon(action: string) {
    return ACTION_ICONS[action as keyof Shortcuts];
  }

  function getLabel(action: string) {
    return $t(`shortcuts.${action}`);
  }

  function normalizeShortcut(shortcut: string) {
    return shortcut.trim().toUpperCase();
  }

  function getRecordingHintParts() {
    const hint = $t('settings.recordingHint');
    const parts = hint.match(/^(.+?[.。])\s*(.*)$/s);
    return {
      first: parts?.[1] || hint,
      second: parts?.[2] || "",
    };
  }

  function toggleTheme() {
    theme.toggle();
  }

  function formatVersion(version: string) {
    if (!version) return "";
    return version.startsWith("v") ? version : `v${version}`;
  }

  function normalizeVersion(version: string) {
    return version.trim().replace(/^v/i, "");
  }

  function compareVersions(candidate: string, current: string) {
    const left = normalizeVersion(candidate).split(/[.-]/).map((part) => Number.parseInt(part, 10) || 0);
    const right = normalizeVersion(current).split(/[.-]/).map((part) => Number.parseInt(part, 10) || 0);
    const length = Math.max(left.length, right.length, 3);

    for (let index = 0; index < length; index += 1) {
      const diff = (left[index] || 0) - (right[index] || 0);
      if (diff !== 0) return diff > 0 ? 1 : -1;
    }

    return 0;
  }

  async function checkForUpdates(source: "auto" | "manual" = "manual") {
    if (source === "auto" && !$settings.automaticUpdateChecks) {
      updateStatus = "disabled";
      return;
    }

    if (!appVersion) {
      updateStatus = "error";
      updateError = $t('settings.currentVersionUnavailable');
      if (source === "manual") notify(updateError, "error");
      return;
    }

    updateStatus = "checking";
    updateError = "";

    try {
      const response = await fetch(latestReleaseApiUrl, {
        headers: {
          Accept: "application/vnd.github+json",
        },
      });

      if (!response.ok) {
        throw new Error(`GitHub API returned ${response.status}`);
      }

      const release = (await response.json()) as GitHubRelease;
      latestVersion = normalizeVersion(release.tag_name || release.name || "");

      if (!latestVersion) {
        throw new Error("Latest release version missing");
      }

      if (compareVersions(latestVersion, appVersion) > 0) {
        updateStatus = "available";
        notify($t('settings.updateAvailable').replace('{version}', formatVersion(latestVersion)), "info");
      } else {
        updateStatus = "current";
        if (source === "manual") notify($t('settings.updateCurrent'), "success");
      }
    } catch (e) {
      console.error("Failed to check for updates", e);
      updateStatus = "error";
      updateError = $t('settings.updateError');
      if (source === "manual") notify(updateError, "error");
    }
  }

  function toggleAutomaticUpdateChecks() {
    const enabled = !$settings.automaticUpdateChecks;
    settings.setAutomaticUpdateChecks(enabled);

    if (enabled) {
      void checkForUpdates("manual");
    } else {
      updateStatus = "disabled";
      updateError = "";
    }
  }
</script>

<svelte:window on:keydown={handleWindowKeydown} />

<div class="absolute inset-0 bg-[var(--bg-primary)] z-40 flex overflow-hidden">
  <aside
    class="bg-[var(--bg-secondary)] border-r border-[var(--border-color)] flex flex-col"
    style="width: {sidebarWidth}px; min-width: 250px;"
  >
    <div class="h-12 px-2 border-b border-[var(--border-color)] flex items-center gap-2">
      <button 
        class="p-2 hover:bg-[var(--bg-hover-strong)] rounded text-[var(--text-secondary)] transition-colors"
        on:click={closeSettings}
        aria-label="Close Settings"
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" />
        </svg>
      </button>
      <h2 class="font-bold text-[var(--text-primary)]">{$t('settings.title')}</h2>
    </div>
    
    <nav class="flex-1 p-2 space-y-1 overflow-y-auto">
      <button
        class="w-full text-left px-3 py-2 rounded text-sm font-medium transition-colors flex items-center gap-2
        {activeTab === 'general' ? 'bg-[#0e639c] text-white' : 'text-[var(--text-muted)] hover:bg-[var(--bg-hover)] hover:text-[var(--text-primary)]'}"
        on:click={() => activeTab = 'general'}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4">
          <path stroke-linecap="round" stroke-linejoin="round" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
          <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
        </svg>
        {$t('settings.general')}
      </button>
      <button
        class="w-full text-left px-3 py-2 rounded text-sm font-medium transition-colors flex items-center gap-2
        {activeTab === 'shortcuts' ? 'bg-[#0e639c] text-white' : 'text-[var(--text-muted)] hover:bg-[var(--bg-hover)] hover:text-[var(--text-primary)]'}"
        on:click={() => activeTab = 'shortcuts'}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4">
          <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z" />
        </svg>
        {$t('settings.shortcuts')}
      </button>
      <button
        class="w-full text-left px-3 py-2 rounded text-sm font-medium transition-colors flex items-center gap-2
        {activeTab === 'exclusions' ? 'bg-[#0e639c] text-white' : 'text-[var(--text-muted)] hover:bg-[var(--bg-hover)] hover:text-[var(--text-primary)]'}"
        on:click={() => activeTab = 'exclusions'}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4">
          <path stroke-linecap="round" stroke-linejoin="round" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
        </svg>
        {$t('settings.exclusions')}
      </button>
      <button
        class="w-full text-left px-3 py-2 rounded text-sm font-medium transition-colors flex items-center gap-2
        {activeTab === 'hiddenFiles' ? 'bg-[#0e639c] text-white' : 'text-[var(--text-muted)] hover:bg-[var(--bg-hover)] hover:text-[var(--text-primary)]'}"
        on:click={() => activeTab = 'hiddenFiles'}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4">
          <path stroke-linecap="round" stroke-linejoin="round" d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88" />
        </svg>
        {$t('settings.hiddenFiles')}
      </button>
    </nav>

    <div class="h-[76px] px-3 border-t border-[var(--border-color)] bg-[var(--bg-tertiary)] flex items-center justify-between gap-2 shrink-0">
      <div class="min-w-0 flex flex-col gap-1 justify-center">
          <div class="text-sm font-semibold text-[var(--text-primary)] flex items-center gap-1">
            <button
              type="button"
              class="hover:text-[var(--text-secondary)] transition-colors"
              title={$t('settings.release')}
              on:click={() => openExternalLink(releaseUrl)}
            >
              {formattedAppVersion}
            </button>
            <span class="text-xs text-[var(--text-muted)] font-normal">- Tauri + Svelte</span>
          </div>
          <div class="flex items-center gap-2 text-[13px] text-[var(--text-muted)]">
            <button
              type="button"
              class="hover:text-[var(--text-primary)] hover:underline hover:scale-[1.05] active:scale-[0.98] transition-[transform,color] duration-150 font-medium inline-block"
              on:click={() => openExternalLink(authorUrl)}
            >
              pierspad
            </button>
            <span>•</span>
            <button
              type="button"
              class="hover:text-[var(--text-primary)] hover:underline hover:scale-[1.05] active:scale-[0.98] transition-[transform,color] duration-150 font-medium inline-block"
              on:click={() => openExternalLink(licenseUrl)}
            >
              GPL-3.0
            </button>
          </div>
        </div>
        <button
          type="button"
          class="shrink-0 text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:scale-110 active:scale-90 transition-all duration-150"
          aria-label={$t('settings.repository')}
          title={$t('settings.repository')}
          on:click={() => openExternalLink(repoUrl)}
        >
          <svg class="w-7 h-7" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path fill-rule="evenodd" d="M12 2C6.48 2 2 6.58 2 12.26c0 4.53 2.87 8.37 6.84 9.73.5.09.68-.22.68-.49 0-.24-.01-1.05-.01-1.9-2.78.62-3.37-1.22-3.37-1.22-.45-1.18-1.11-1.49-1.11-1.49-.91-.64.07-.63.07-.63 1 .07 1.53 1.06 1.53 1.06.89 1.56 2.34 1.11 2.91.85.09-.66.35-1.11.64-1.37-2.22-.26-4.56-1.14-4.56-5.07 0-1.12.39-2.04 1.03-2.76-.1-.26-.45-1.31.1-2.72 0 0 .84-.28 2.75 1.05A9.42 9.42 0 0112 6.96c.85 0 1.71.12 2.51.34 1.91-1.33 2.75-1.05 2.75-1.05.54 1.41.2 2.46.1 2.72.64.72 1.03 1.64 1.03 2.76 0 3.94-2.34 4.81-4.57 5.06.36.32.68.94.68 1.9 0 1.37-.01 2.47-.01 2.81 0 .27.18.59.69.49A10.1 10.1 0 0022 12.26C22 6.58 17.52 2 12 2z" clip-rule="evenodd" />
          </svg>
        </button>
    </div>
  </aside>

  <main class="flex-1 flex flex-col min-w-0">
    <div class="flex-1 p-8 overflow-y-auto flex flex-col">
    {#if activeTab === 'general'}
      <div class="w-full max-w-none">
        
        <div class="grid gap-4 grid-cols-5">
          <div class="relative overflow-hidden group w-full p-4 bg-[var(--bg-tertiary)] rounded border border-[var(--border-color)] flex flex-col gap-3 col-span-5">
            <div class="relative z-10 grid grid-cols-2 sm:grid-cols-3 xl:grid-cols-5 gap-2">
                {#each availableUILanguages as lang}
                    <button 
                        class="px-3 py-2 rounded text-sm font-bold transition-colors border border-[var(--border-color)] flex items-center justify-center gap-2 min-w-0
                        {$locale === lang.code ? 'bg-[#0e639c] text-white border-[#0e639c]' : 'bg-[var(--bg-primary)] text-[var(--text-muted)] hover:bg-[var(--bg-hover)]'}"
                        on:click={() => locale.set(lang.code)}
                        title={`${lang.name} / ${lang.nativeName}`}
                    >
                        <span class="text-lg leading-none">{lang.flag}</span>
                        <span class="min-w-0 text-left leading-tight">
                          <span class="block truncate">{lang.name}</span>
                          <span class="block truncate text-[11px] font-medium opacity-80">{lang.nativeName}</span>
                        </span>
                    </button>
                {/each}
            </div>
          </div>

          <button 
            class="relative overflow-hidden group w-full p-4 bg-[var(--bg-tertiary)] rounded border border-[var(--border-color)] flex justify-center items-center hover:bg-[var(--bg-hover-strong)] transition-colors col-span-2"
            on:click={toggleTheme}
          >
            <div class="relative z-10 inline-flex items-center w-28 h-14 transition-colors duration-200 ease-in-out rounded-full {$theme === 'light' ? 'bg-sky-400' : 'bg-indigo-900'} shrink-0">
              <span class="absolute left-1 flex items-center justify-center w-12 h-12 transform bg-white rounded-full shadow transition-transform duration-200 ease-in-out {$theme === 'light' ? 'translate-x-14' : 'translate-x-0'}">
                {#if $theme === 'light'}
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-6 h-6 text-yellow-500">
                    <path d="M12 2.25a.75.75 0 01.75.75v2.25a.75.75 0 01-1.5 0V3a.75.75 0 01.75-.75zM7.5 12a4.5 4.5 0 119 0 4.5 4.5 0 01-9 0zM18.894 6.166a.75.75 0 00-1.06-1.06l-1.591 1.59a.75.75 0 101.06 1.061l1.591-1.59zM21.75 12a.75.75 0 01-.75.75h-2.25a.75.75 0 010-1.5H21a.75.75 0 01.75.75zM17.834 18.894a.75.75 0 001.06-1.06l-1.59-1.591a.75.75 0 10-1.061 1.06l1.59 1.591zM12 18a.75.75 0 01.75.75V21a.75.75 0 01-1.5 0v-2.25A.75.75 0 0112 18zM7.758 17.303a.75.75 0 00-1.061-1.06l-1.591 1.59a.75.75 0 001.06 1.061l1.591-1.59zM6 12a.75.75 0 01-.75.75H3a.75.75 0 010-1.5h2.25A.75.75 0 016 12zM6.697 7.757a.75.75 0 001.06-1.06l-1.59-1.591a.75.75 0 00-1.061 1.06l1.59 1.591z" />
                  </svg>
                {:else}
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-6 h-6 text-indigo-900">
                    <path fill-rule="evenodd" d="M9.528 1.718a.75.75 0 01.162.819A8.97 8.97 0 009 6a9 9 0 009 9 8.97 8.97 0 003.463-.69.75.75 0 01.981.98 10.503 10.503 0 01-9.694 6.46c-5.799 0-10.5-4.701-10.5-10.5 0-4.368 2.667-8.112 6.46-9.694a.75.75 0 01.818.162z" clip-rule="evenodd" />
                  </svg>
                {/if}
              </span>
            </div>
          </button>

          <div class="relative overflow-hidden group w-full p-4 bg-[var(--bg-tertiary)] rounded border border-[var(--border-color)] flex flex-row items-stretch justify-center gap-3 col-span-3">
            <button
              type="button"
              class="flex-1 rounded border border-[var(--border-color)] bg-[var(--bg-primary)] px-3 py-2 flex flex-col items-center justify-between gap-2 hover:bg-[var(--bg-hover)] transition-colors min-w-0"
              on:click={toggleAutomaticUpdateChecks}
              title={$t('settings.automaticUpdateChecksHint')}
            >
              <span class="text-sm font-medium text-[var(--text-primary)] leading-tight text-center whitespace-pre-line">{$t('settings.automaticUpdateChecks')}</span>
              <span class="relative inline-block w-8 h-4 transition duration-200 ease-in-out rounded-full {$settings.automaticUpdateChecks ? 'bg-green-500' : 'bg-gray-600'} shrink-0">
                <span class="absolute left-0 inline-block w-4 h-4 transform bg-white rounded-full shadow transition-transform duration-200 ease-in-out {$settings.automaticUpdateChecks ? 'translate-x-4' : 'translate-x-0'}"></span>
              </span>
            </button>

            <button
              type="button"
              class="flex-1 rounded border border-[var(--border-light)] bg-[var(--bg-primary)] px-3 py-2 flex flex-col items-center justify-between gap-2 hover:bg-[var(--bg-hover)] transition-colors disabled:opacity-60 min-w-0"
              on:click={() => checkForUpdates("manual")}
              disabled={updateStatus === 'checking'}
            >
              <span class="text-sm font-semibold text-[var(--text-secondary)] text-center leading-tight whitespace-pre-line">{$t('settings.checkNow')}</span>
              <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-[var(--text-secondary)] shrink-0 {updateStatus === 'checking' ? 'animate-spin' : ''}" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992m0 0v-.001M21.015 9.348l-3.181-3.182a8.25 8.25 0 00-13.803 3.7M7.977 14.652H2.985m0 0v.001m0-.001l3.181 3.182a8.25 8.25 0 0013.803-3.7" />
              </svg>
            </button>
          </div>

          <div class="relative overflow-visible group w-full p-4 bg-[var(--bg-tertiary)] rounded border border-[var(--border-color)] flex items-center justify-center gap-2 col-span-5">
            <div class="cursor-help flex items-center">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-[var(--text-muted)] hover:text-[#0e639c]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <div class="absolute bottom-full mb-2 left-1/2 -translate-x-1/2 px-3 py-2 bg-[var(--bg-secondary)] border border-[var(--border-light)] text-[var(--text-primary)] text-xs rounded shadow-lg opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 whitespace-nowrap z-50">
                {$t('settings.liveSyncHint')}
              </div>
            </div>
            <span class="text-sm font-medium text-[var(--text-primary)] whitespace-nowrap">{$t('settings.liveSyncPrefix')}</span>
            <input 
              type="text" 
              value={liveSyncInput}
              on:input={handleLiveSyncInput}
              class="w-16 px-2 py-1 bg-[var(--bg-primary)] border border-[var(--border-color)] rounded text-[var(--text-primary)] focus:outline-none focus:border-[#0e639c] text-center font-mono"
            />
            <span class="text-sm font-medium text-[var(--text-primary)] whitespace-nowrap">{$t('settings.liveSyncSuffix')}</span>
          </div>

          <div class="relative overflow-visible group w-full p-4 bg-[var(--bg-tertiary)] rounded border border-[var(--border-color)] flex items-center justify-center gap-2 col-span-5">
            <div class="cursor-help flex items-center">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-[var(--text-muted)] hover:text-[#0e639c]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <div class="absolute bottom-full mb-2 left-1/2 -translate-x-1/2 px-3 py-2 bg-[var(--bg-secondary)] border border-[var(--border-light)] text-[var(--text-primary)] text-xs rounded shadow-lg opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 z-50 flex flex-col items-center text-center w-72">
                <span class="font-medium">{$locale === 'it' ? 'Seleziona dopo quanti caratteri un file viene troncato.' : 'Select after how many characters a file is truncated.'}</span>
                <span class="text-[var(--text-muted)] mt-1 font-normal">{$locale === 'it' ? 'Imposta a 0 per disabilitare il limite.' : 'Set to 0 to disable the limit.'}</span>
              </div>
            </div>
            <span class="text-sm font-medium text-[var(--text-primary)] whitespace-nowrap">{$t('settings.largeFileThreshold')}</span>
            <input 
              type="text" 
              value={largeFileInput}
              on:input={handleLargeFileInput}
              class="w-24 px-2 py-1 bg-[var(--bg-primary)] border border-[var(--border-color)] rounded text-[var(--text-primary)] focus:outline-none focus:border-[#0e639c] text-center font-mono text-sm"
            />
            <span class="text-sm font-medium text-[var(--text-primary)] whitespace-nowrap">{$t('app.characters').toLowerCase()}</span>
          </div>

        </div>
      </div>
    {:else if activeTab === 'shortcuts'}
      <div class="max-w-none flex flex-col flex-1 min-h-0">
        <div class="mb-6 flex flex-wrap items-center gap-4">
          <div class="flex flex-wrap gap-2">
            {#each shortcutCategories as cat}
              <button
                class="px-3 py-1 text-sm rounded font-medium transition-colors border {selectedShortcutCategory === cat.id ? 'bg-[#0e639c] border-[#0e639c] text-white' : 'bg-[var(--bg-secondary)] border-[var(--border-color)] text-[var(--text-secondary)] hover:text-[var(--text-primary)]'}"
                on:click={() => selectedShortcutCategory = cat.id}
              >
                {$t(cat.key)}
              </button>
            {/each}
          </div>
          <div class="w-px h-6 bg-[var(--border-color)] hidden sm:block"></div>
          <div class="text-xs font-medium transition-colors duration-200 {recordingAction ? 'text-red-400' : 'text-[var(--text-muted)]'}">
            {#if recordingAction}
              <span>{getRecordingHintParts().second || getRecordingHintParts().first}</span>
            {:else}
              <span>{$t('settings.clickToCustomize')}</span>
            {/if}
          </div>
        </div>
        
        <div class="bg-[var(--bg-secondary)] rounded border border-[var(--border-color)] overflow-hidden flex-1 min-h-0 flex flex-col p-2">
          <div class="overflow-y-auto overflow-x-hidden flex-1 grid gap-3 [grid-template-columns:repeat(auto-fit,minmax(min(100%,340px),1fr))] content-start">
          {#each filteredShortcuts as [key, keybind]}
              <!-- svelte-ignore indent -->
              <!-- svelte-ignore a11y-click-events-have-key-events -->
              {@const action = key}
              <div 
                class="grid grid-cols-[32px_minmax(0,1fr)_auto] gap-3 p-3 items-center bg-[var(--bg-secondary)] hover:bg-[var(--bg-hover)] rounded border border-[var(--border-color)] transition-colors min-h-[60px] cursor-pointer"
                on:click={() => recordingAction = action}
                on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') recordingAction = action; }}
                role="button"
                tabindex="0"
              >
                <div class="flex justify-center text-[var(--text-muted)]">
                  {@html getIcon(action)}
                </div>
                <div class="min-w-0 font-medium leading-snug text-[var(--text-secondary)]">
                  {getLabel(action)}
                </div>
                <div class="flex justify-end">
                  <KeybindRecorder 
                    value={keybind} 
                    recording={recordingAction === action}
                    recordingLabel={$t('settings.recordingKeys')}
                    on:start={() => recordingAction = action}
                    on:stop={() => recordingAction = null}
                    on:cancel={() => recordingAction = null}
                    on:change={(e) => handleShortcutChange(action, e.detail)}
                  />
                </div>
              </div>
          {/each}
          </div>
        </div>
      </div>
    {:else if activeTab === 'exclusions'}
      <div class="max-w-none flex flex-col h-full">
        
        <div class="mb-4 text-sm text-[var(--text-muted)]">
            <p class="mb-2">{$t('settings.exclusionDescription')}</p>
            <ul class="list-disc list-inside space-y-1 ml-2">
                <li><code>*.png</code> - {$t('settings.exclusionExampleGlob')}</li>
                <li><code>node_modules</code> - {$t('settings.exclusionExampleExact')}</li>
                <li><code>.git</code> - {$t('settings.exclusionExampleExact')}</li>
            </ul>
        </div>

        <div class="flex gap-2 mb-4">
            <input 
                type="text" 
                bind:value={newPattern} 
                placeholder={$t('settings.patternPlaceholder')}
                class="flex-1 px-3 py-2 bg-[var(--bg-tertiary)] border border-[var(--border-color)] rounded text-[var(--text-primary)] focus:outline-none focus:border-[#0e639c]"
                on:keydown={(e) => e.key === 'Enter' && addPattern()}
            />
            <button 
                class="px-4 py-2 bg-[#0e639c] hover:bg-[#1177bb] text-white rounded font-bold text-sm transition-colors"
                on:click={addPattern}
            >
                {$t('settings.addPattern')}
            </button>
        </div>

        <div class="bg-[var(--bg-secondary)] rounded border border-[var(--border-color)] overflow-hidden flex-1 min-h-0 flex flex-col p-2">
            <div class="overflow-y-auto overflow-x-hidden flex-1 gap-2 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 content-start">
                {#each $settings.excludedPatterns as pattern}
                    <div class="flex justify-between items-center p-2 bg-[var(--bg-tertiary)] border border-[var(--border-color)] rounded hover:bg-[var(--bg-hover)] transition-colors group">
                        <div class="flex items-center gap-2 min-w-0">
                            <FileIcon name={pattern} />
                            <span class="font-mono text-sm text-[var(--text-primary)] truncate">{pattern}</span>
                        </div>
                        <button 
                            class="text-red-500 hover:text-red-400 px-2 py-1 rounded hover:bg-[var(--bg-hover-strong)] transition-colors shrink-0"
                            on:click={() => { settings.removePattern(pattern); notify($t('settings.patternRemoved') + ': ' + pattern, 'info'); }}
                            title={$t('app.remove')}
                        >
                            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5">
                                <path fill-rule="evenodd" d="M5.47 5.47a.75.75 0 011.06 0L12 10.94l5.47-5.47a.75.75 0 111.06 1.06L13.06 12l5.47 5.47a.75.75 0 11-1.06 1.06L12 13.06l-5.47 5.47a.75.75 0 01-1.06-1.06L10.94 12 5.47 6.53a.75.75 0 010-1.06z" clip-rule="evenodd" />
                            </svg>
                        </button>
                    </div>
                {/each}
            </div>
        </div>
      </div>
    {:else if activeTab === 'hiddenFiles'}
      <div class="max-w-none flex flex-col h-full">
        
        <div class="mb-4 text-sm text-[var(--text-muted)]">
            <p class="mb-2">{$t('settings.hiddenFilesDescription')}</p>
            <ul class="list-disc list-inside space-y-1 ml-2">
                <li><code>*.txt</code> - {$t('settings.exclusionExampleGlob')}</li>
                <li><code>.env</code> - {$t('settings.exclusionExampleExact')}</li>
            </ul>
        </div>

        <div class="flex gap-2 mb-4">
            <input 
                type="text" 
                bind:value={newHiddenPattern} 
                placeholder={$t('settings.patternPlaceholder')}
                class="flex-1 px-3 py-2 bg-[var(--bg-tertiary)] border border-[var(--border-color)] rounded text-[var(--text-primary)] focus:outline-none focus:border-[#0e639c]"
                on:keydown={(e) => e.key === 'Enter' && addHiddenPattern()}
            />
            <button 
                class="px-4 py-2 bg-[#0e639c] hover:bg-[#1177bb] text-white rounded font-bold text-sm transition-colors"
                on:click={addHiddenPattern}
            >
                {$t('settings.addPattern')}
            </button>
        </div>

        <div class="bg-[var(--bg-secondary)] rounded border border-[var(--border-color)] overflow-hidden flex-1 min-h-0 flex flex-col p-2">
            <div class="overflow-y-auto overflow-x-hidden flex-1 gap-2 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 content-start">
                {#each $settings.hiddenPatterns as pattern}
                    <div class="flex justify-between items-center p-2 bg-[var(--bg-tertiary)] border border-[var(--border-color)] rounded hover:bg-[var(--bg-hover)] transition-colors group">
                        <div class="flex items-center gap-2 min-w-0">
                            <FileIcon name={pattern} />
                            <span class="font-mono text-sm text-[var(--text-primary)] truncate">{pattern}</span>
                        </div>
                        <button 
                            class="text-red-500 hover:text-red-400 px-2 py-1 rounded hover:bg-[var(--bg-hover-strong)] transition-colors"
                            on:click={() => { settings.removeHiddenPattern(pattern); notify($t('settings.patternRemoved') + ': ' + pattern, 'info'); }}
                            title={$t('app.remove')}
                        >
                            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5">
                                <path fill-rule="evenodd" d="M5.47 5.47a.75.75 0 011.06 0L12 10.94l5.47-5.47a.75.75 0 111.06 1.06L13.06 12l5.47 5.47a.75.75 0 11-1.06 1.06L12 13.06l-5.47 5.47a.75.75 0 01-1.06-1.06L10.94 12 5.47 6.53a.75.75 0 010-1.06z" clip-rule="evenodd" />
                            </svg>
                        </button>
                    </div>
                {/each}
            </div>
        </div>
      </div>
    {/if}
    </div>

      <div class="h-[76px] border-t border-[var(--border-color)] bg-[var(--bg-tertiary)] flex items-center justify-center shrink-0">
        <button
          class="px-4 py-2 bg-[#ef4444] hover:bg-[#dc2626] text-white rounded font-medium transition-colors shadow-lg shadow-red-900/20 inline-flex items-center gap-2"
          on:click={triggerResetConfirmation}
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke-width="1.8" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182m0-4.991v4.99" />
          </svg>
          {$t('settings.resetDefaults')}
        </button>
      </div>
  </main>

  {#if showConfirmModal}
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div 
      class="absolute inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 transition-all duration-200"
      on:click|self={() => showConfirmModal = false}
    >
      <div class="bg-[var(--bg-secondary)] border border-[var(--border-color)] rounded-lg shadow-2xl max-w-md w-full overflow-hidden p-6 flex flex-col gap-4 transform scale-100 transition-transform duration-200">
        <div class="flex items-start gap-4">
          <div class="p-3 bg-red-500/10 text-red-500 rounded-full shrink-0">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
            </svg>
          </div>
          <div class="min-w-0 flex-1">
            <h3 class="text-lg font-bold text-[var(--text-primary)] leading-tight">{confirmTitle}</h3>
            <p class="mt-2 text-sm text-[var(--text-secondary)] leading-relaxed">{confirmMessage}</p>
          </div>
        </div>
        <div class="flex justify-end gap-3 mt-3">
          <button
            type="button"
            class="px-4 py-2 bg-[var(--bg-tertiary)] border border-[var(--border-color)] hover:bg-[var(--bg-hover-strong)] text-[var(--text-primary)] rounded font-semibold text-sm transition-all duration-150 active:scale-95 cursor-pointer"
            on:click={() => showConfirmModal = false}
          >
            {$locale === 'it' ? 'Annulla' : ($locale === 'de' ? 'Abbrechen' : ($locale === 'es' ? 'Cancelar' : ($locale === 'fr' ? 'Annuler' : 'Cancel')))}
          </button>
          <button
            type="button"
            class="px-4 py-2 bg-[#ef4444] hover:bg-[#dc2626] text-white rounded font-semibold text-sm transition-all duration-150 active:scale-95 shadow-md shadow-red-900/10 cursor-pointer"
            on:click={() => {
              showConfirmModal = false;
              onConfirm();
            }}
          >
            {$locale === 'it' ? 'Conferma' : ($locale === 'de' ? 'Bestätigen' : ($locale === 'es' ? 'Confirmar' : ($locale === 'fr' ? 'Confirmer' : 'Confirm')))}
          </button>
        </div>
      </div>
    </div>
  {/if}
</div>
