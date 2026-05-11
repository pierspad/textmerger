<script lang="ts">
  import { createEventDispatcher, onMount } from "svelte";
  import { getName, getVersion } from "@tauri-apps/api/app";
  import { open as openExternal } from "@tauri-apps/plugin-shell";
  import { shortcuts, ACTION_ICONS, type Shortcuts } from "../stores/shortcuts";
  import { settings } from "../stores/settings";
  import { theme } from "../stores/theme";
  import { availableUILanguages, t, locale } from "../stores/i18n";
  import KeybindRecorder from "./KeybindRecorder.svelte";
  import { ask } from "@tauri-apps/plugin-dialog";

  type SnackbarVariant = "success" | "info" | "warning" | "error";
  type UpdateStatus = "idle" | "checking" | "available" | "current" | "error" | "disabled";

  interface GitHubRelease {
    tag_name?: string;
    html_url?: string;
    name?: string;
  }

  const dispatch = createEventDispatcher();

  let activeTab = "general";
  let recordingAction: string | null = null;
  let newPattern = "";
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

  async function handleResetDefaults() {
    try {
      let confirmed = false;
      try {
        confirmed = await ask($t('settings.resetConfirm'), {
          title: $t('settings.resetDefaults'),
          kind: "warning",
        });
      } catch (e) {
        console.warn("Tauri dialog failed, using native confirm", e);
        confirmed = window.confirm($t('settings.resetConfirm'));
      }

      if (confirmed) {
        shortcuts.resetDefaults();
        notify($t('settings.resetSuccess'));
      }
    } catch (e) {
      console.error("Failed to reset defaults:", e);
      notify($t('settings.resetError'), "error");
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

<div class="absolute inset-0 bg-[var(--bg-primary)] z-40 flex overflow-hidden">
  <!-- Settings Sidebar -->
  <aside class="w-64 bg-[var(--bg-secondary)] border-r border-[var(--border-color)] flex flex-col">
    <div class="h-12 px-4 border-b border-[var(--border-color)] flex items-center gap-2">
      <button 
        class="p-2 bg-[var(--bg-hover-strong)] hover:bg-[var(--bg-hover)] rounded text-[var(--text-secondary)] transition-colors"
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
          <path stroke-linecap="round" stroke-linejoin="round" d="M9.53 16.122a3 3 0 00-5.78 1.128 2.25 2.25 0 01-2.4 2.245 4.5 4.5 0 008.4-2.245c0-.399-.078-.78-.22-1.128zm0 0a15.998 15.998 0 003.388-1.62m-5.048 4.025a3 3 0 01-2.4-2.245 4.5 4.5 0 008.4-2.245c0-.399-.078-.78-.22-1.128v-.001zm3.278-5.504a3 3 0 00-5.332-1.582 2.25 2.25 0 01-1.383-1.931 4.5 4.5 0 008.09 2.212c.106.39.158.794.158 1.204.067.036.132.076.196.118l.071.05zm-2.033-4.347a3 3 0 01-2.245-2.4 4.5 4.5 0 008.4 2.245c0 .399.078.78.22 1.128v.001z" />
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
    </nav>

    <div class="p-4 border-t border-[var(--border-color)]">
      <div class="rounded border border-[var(--border-color)] bg-[var(--bg-tertiary)] p-3">
        <div class="flex items-center justify-between gap-3">
          <div class="min-w-0">
            <p class="truncate text-sm font-semibold text-[var(--text-primary)]">{appName}</p>
            <p class="text-xs text-[var(--text-muted)]">
              <button
                type="button"
                class="hover:text-[var(--text-primary)] transition-colors"
                title={$t('settings.release')}
                on:click={() => openExternalLink(releaseUrl)}
              >
                {formattedAppVersion}
              </button>
              <span class="mx-1">-</span>
              Tauri + Svelte
            </p>
          </div>
          <button
            type="button"
            class="shrink-0 text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-colors"
            aria-label={$t('settings.repository')}
            title={$t('settings.repository')}
            on:click={() => openExternalLink(repoUrl)}
          >
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path fill-rule="evenodd" d="M12 2C6.48 2 2 6.58 2 12.26c0 4.53 2.87 8.37 6.84 9.73.5.09.68-.22.68-.49 0-.24-.01-1.05-.01-1.9-2.78.62-3.37-1.22-3.37-1.22-.45-1.18-1.11-1.49-1.11-1.49-.91-.64.07-.63.07-.63 1 .07 1.53 1.06 1.53 1.06.89 1.56 2.34 1.11 2.91.85.09-.66.35-1.11.64-1.37-2.22-.26-4.56-1.14-4.56-5.07 0-1.12.39-2.04 1.03-2.76-.1-.26-.45-1.31.1-2.72 0 0 .84-.28 2.75 1.05A9.42 9.42 0 0112 6.96c.85 0 1.71.12 2.51.34 1.91-1.33 2.75-1.05 2.75-1.05.54 1.41.2 2.46.1 2.72.64.72 1.03 1.64 1.03 2.76 0 3.94-2.34 4.81-4.57 5.06.36.32.68.94.68 1.9 0 1.37-.01 2.47-.01 2.81 0 .27.18.59.69.49A10.1 10.1 0 0022 12.26C22 6.58 17.52 2 12 2z" clip-rule="evenodd" />
            </svg>
          </button>
        </div>
        <div class="mt-3 flex items-center justify-between gap-2 text-[10px] text-[var(--text-muted)]">
          <button type="button" class="hover:text-[var(--text-primary)] transition-colors" on:click={() => openExternalLink(authorUrl)}>
            pierspad
          </button>
          <span>•</span>
          <button type="button" class="hover:text-[var(--text-primary)] transition-colors" on:click={() => openExternalLink(repoUrl)}>
            {$t('settings.repository')}
          </button>
          <span>•</span>
          <button type="button" class="hover:text-[var(--text-primary)] transition-colors" on:click={() => openExternalLink(licenseUrl)}>
            GPL-3.0
          </button>
        </div>
      </div>
    </div>
  </aside>

  <!-- Settings Content -->
  <main class="flex-1 p-8 overflow-y-auto">
    {#if activeTab === 'general'}
      <div class="w-full max-w-6xl">
        <h3 class="text-xl font-bold text-[var(--text-primary)] mb-6">{$t('settings.generalSettings')}</h3>
        
        <div class="grid gap-4 xl:grid-cols-[minmax(280px,360px)_minmax(0,1fr)]">
          <button 
            class="w-full p-4 bg-[var(--bg-tertiary)] rounded border border-[var(--border-color)] flex justify-between items-center hover:bg-[var(--bg-hover-strong)] transition-colors"
            on:click={toggleTheme}
          >
            <div class="flex items-center gap-3">
              <div class="p-2 bg-purple-600 rounded text-white">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 3v2.25m6.364.386l-1.591 1.591M21 12h-2.25m-.386 6.364l-1.591-1.591M12 18.75V21m-4.773-4.227l-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z" />
                </svg>
              </div>
              <span class="font-medium text-[var(--text-primary)]">{$t('settings.lightMode')}</span>
            </div>
            <div class="relative inline-block w-10 h-6 transition duration-200 ease-in-out rounded-full {$theme === 'light' ? 'bg-green-500' : 'bg-gray-600'}">
                <span class="absolute left-0 inline-block w-6 h-6 transform bg-white rounded-full shadow transition-transform duration-200 ease-in-out {$theme === 'light' ? 'translate-x-4' : 'translate-x-0'}"></span>
            </div>
          </button>

          <div class="w-full p-4 bg-[var(--bg-tertiary)] rounded border border-[var(--border-color)] flex flex-col gap-4">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div class="flex items-center gap-3 min-w-0">
                <div class="p-2 bg-emerald-600 rounded text-white">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992m0 0v-.001M21.015 9.348l-3.181-3.182a8.25 8.25 0 00-13.803 3.7M7.977 14.652H2.985m0 0v.001m0-.001l3.181 3.182a8.25 8.25 0 0013.803-3.7" />
                  </svg>
                </div>
                <div class="min-w-0">
                  <p class="font-medium text-[var(--text-primary)]">{$t('settings.updates')}</p>
                  <p class="text-xs text-[var(--text-muted)]">{$t('settings.currentVersion').replace('{version}', formattedAppVersion)}</p>
                </div>
              </div>

              <button
                type="button"
                class="shrink-0 rounded border border-[var(--border-light)] bg-[var(--bg-primary)] px-3 py-2 text-xs font-semibold text-[var(--text-secondary)] hover:bg-[var(--bg-hover)] transition-colors disabled:opacity-60"
                on:click={() => checkForUpdates("manual")}
                disabled={updateStatus === 'checking'}
              >
                <span class="inline-flex items-center gap-2">
                  <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 {updateStatus === 'checking' ? 'animate-spin' : ''}" fill="none" viewBox="0 0 24 24" stroke-width="1.8" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992m0 0v-.001M21.015 9.348l-3.181-3.182a8.25 8.25 0 00-13.803 3.7M7.977 14.652H2.985m0 0v.001m0-.001l3.181 3.182a8.25 8.25 0 0013.803-3.7" />
                  </svg>
                  {$t('settings.checkNow')}
                </span>
              </button>
            </div>

            <button
              type="button"
              class="w-full rounded border border-[var(--border-color)] bg-[var(--bg-primary)] p-3 flex items-center justify-between gap-3 hover:bg-[var(--bg-hover)] transition-colors"
              on:click={toggleAutomaticUpdateChecks}
            >
              <span class="text-left">
                <span class="block text-sm font-medium text-[var(--text-primary)]">{$t('settings.automaticUpdateChecks')}</span>
                <span class="block text-xs text-[var(--text-muted)]">{$t('settings.automaticUpdateChecksHint')}</span>
              </span>
              <span class="relative inline-block w-10 h-6 transition duration-200 ease-in-out rounded-full {$settings.automaticUpdateChecks ? 'bg-green-500' : 'bg-gray-600'}">
                <span class="absolute left-0 inline-block w-6 h-6 transform bg-white rounded-full shadow transition-transform duration-200 ease-in-out {$settings.automaticUpdateChecks ? 'translate-x-4' : 'translate-x-0'}"></span>
              </span>
            </button>
          </div>

          <div class="w-full p-4 bg-[var(--bg-tertiary)] rounded border border-[var(--border-color)] flex flex-col gap-3 xl:col-span-2">
            <div class="flex items-center gap-3 mb-2">
              <div class="p-2 bg-blue-600 rounded text-white">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 21l5.25-11.25L21 21m-9-3h7.5M3 5.621a48.474 48.474 0 016-.371m0 0c1.12 0 2.233.038 3.334.114M9 5.25V3m3.334 2.364C11.176 10.658 7.69 15.08 3 17.502m9.334-12.138c.896.061 1.785.147 2.666.257m-4.589 8.495a18.023 18.023 0 01-3.827-5.802" />
                </svg>
              </div>
              <span class="font-medium text-[var(--text-primary)]">{$t('settings.language')}</span>
            </div>
            
            <div class="grid grid-cols-2 sm:grid-cols-3 xl:grid-cols-5 gap-2">
                {#each availableUILanguages as lang}
                    <button 
                        class="px-3 py-2 rounded text-sm font-bold transition-colors border border-[var(--border-color)] flex items-center gap-2 min-w-0
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
        </div>
      </div>
    {:else if activeTab === 'shortcuts'}
      <div class="max-w-6xl">
        <div class="mb-6 flex items-start justify-between gap-4">
          <h3 class="text-xl font-bold text-[var(--text-primary)]">{$t('settings.keyboardShortcuts')}</h3>
          {#if recordingAction}
            <div class="max-w-md rounded border border-red-500/50 bg-red-950/70 px-3 py-2 text-right text-xs font-medium text-red-100 shadow-lg shadow-red-950/20">
              <span class="block">{getRecordingHintParts().first}</span>
              {#if getRecordingHintParts().second}
                <span class="block">{getRecordingHintParts().second}</span>
              {/if}
            </div>
          {/if}
        </div>
        
        <div class="grid gap-3 [grid-template-columns:repeat(auto-fit,minmax(min(100%,340px),1fr))]">
          {#each shortcutEntries as [key, keybind]}
              <!-- svelte-ignore indent -->
              {@const action = key}
              <div class="grid grid-cols-[32px_minmax(0,1fr)_auto] gap-3 p-3 items-center bg-[var(--bg-secondary)] hover:bg-[var(--bg-hover)] rounded border border-[var(--border-color)] transition-colors min-h-[60px]">
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

        <div class="mt-8 flex justify-center">
          <button
            class="px-4 py-2 bg-[#ef4444] hover:bg-[#dc2626] text-white rounded font-medium transition-colors shadow-lg shadow-red-900/20 inline-flex items-center gap-2"
            on:click={handleResetDefaults}
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke-width="1.8" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 15L3 9m0 0l6-6M3 9h12a6 6 0 010 12h-3" />
            </svg>
            {$t('settings.resetDefaults')}
          </button>
        </div>
      </div>
    {:else if activeTab === 'exclusions'}
      <div class="h-full flex flex-col">
        <h3 class="text-xl font-bold text-[var(--text-primary)] mb-4">{$t('settings.exclusions')}</h3>
        
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

        <div class="bg-[var(--bg-secondary)] rounded border border-[var(--border-color)] overflow-hidden flex-1 min-h-0 flex flex-col">
            <div class="overflow-y-auto flex-1 divide-y divide-[var(--border-color)]">
                {#each $settings.excludedPatterns as pattern}
                    <div class="flex justify-between items-center p-3 hover:bg-[var(--bg-hover)] transition-colors group">
                        <span class="font-mono text-sm text-[var(--text-primary)]">{pattern}</span>
                        <button 
                            class="text-red-500 hover:text-red-400 px-3 py-1 rounded hover:bg-[var(--bg-hover-strong)] opacity-0 group-hover:opacity-100 transition-opacity"
                            on:click={() => settings.removePattern(pattern)}
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
        
        <div class="mt-8 flex justify-center">
            <button
                class="px-4 py-2 bg-[#ef4444] hover:bg-[#dc2626] text-white rounded font-medium transition-colors shadow-lg shadow-red-900/20"
                on:click={settings.resetPatterns}
            >
                {$t('settings.resetPatterns')}
            </button>
        </div>
      </div>
    {/if}
  </main>
</div>
