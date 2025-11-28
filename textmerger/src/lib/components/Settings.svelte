<script lang="ts">
  import { createEventDispatcher } from "svelte";
  import { shortcuts, ACTION_LABELS, ACTION_ICONS, type Shortcuts } from "../stores/shortcuts";
  import { settings } from "../stores/settings";
  import { theme } from "../stores/theme";
  import { t, locale } from "../stores/i18n";
  import KeybindRecorder from "./KeybindRecorder.svelte";
  import { ask } from "@tauri-apps/plugin-dialog";

  const dispatch = createEventDispatcher();

  let activeTab = "shortcuts";
  let recordingAction: string | null = null;
  let newPattern = "";

  function addPattern() {
    if (newPattern.trim()) {
        settings.addPattern(newPattern.trim());
        newPattern = "";
    }
  }

  function closeSettings() {
    dispatch("close");
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
        dispatch("snackbar", $t('settings.resetSuccess'));
      }
    } catch (e) {
      console.error("Failed to reset defaults:", e);
      dispatch("snackbar", $t('settings.resetError'));
    }
  }

  function handleShortcutChange(action: string, newBind: string) {
    shortcuts.updateShortcut(action as keyof Shortcuts, newBind);
  }

  function getIcon(action: string) {
    return ACTION_ICONS[action as keyof Shortcuts];
  }

  function getLabel(action: string) {
    return ACTION_LABELS[action as keyof Shortcuts];
  }

  function toggleTheme() {
    theme.toggle();
  }
</script>

<div class="absolute inset-0 bg-[var(--bg-primary)] z-40 flex overflow-hidden">
  <!-- Settings Sidebar -->
  <aside class="w-64 bg-[var(--bg-secondary)] border-r border-[var(--border-color)] flex flex-col">
    <div class="p-4 border-b border-[var(--border-color)] flex items-center gap-2">
      <button 
        class="p-1 hover:bg-[var(--bg-hover-strong)] rounded text-[var(--text-muted)]"
        on:click={closeSettings}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" />
        </svg>
      </button>
      <h2 class="font-bold text-[var(--text-primary)]">{$t('settings.title')}</h2>
    </div>
    
    <nav class="flex-1 p-2 space-y-1">
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
  </aside>

  <!-- Settings Content -->
  <main class="flex-1 p-8 overflow-y-auto">
    {#if activeTab === 'general'}
      <div class="max-w-2xl">
        <h3 class="text-xl font-bold text-[var(--text-primary)] mb-6">{$t('settings.generalSettings')}</h3>
        
        <div class="space-y-4">
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

          <div class="w-full p-4 bg-[var(--bg-tertiary)] rounded border border-[var(--border-color)] flex flex-col gap-3">
            <div class="flex items-center gap-3 mb-2">
              <div class="p-2 bg-blue-600 rounded text-white">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 21l5.25-11.25L21 21m-9-3h7.5M3 5.621a48.474 48.474 0 016-.371m0 0c1.12 0 2.233.038 3.334.114M9 5.25V3m3.334 2.364C11.176 10.658 7.69 15.08 3 17.502m9.334-12.138c.896.061 1.785.147 2.666.257m-4.589 8.495a18.023 18.023 0 01-3.827-5.802" />
                </svg>
              </div>
              <span class="font-medium text-[var(--text-primary)]">{$t('settings.language')}</span>
            </div>
            
            <div class="grid grid-cols-5 gap-2">
                {#each ['en', 'it', 'es', 'fr', 'de'] as lang}
                    <button 
                        class="px-3 py-2 rounded text-sm font-bold transition-colors border border-[var(--border-color)]
                        {$locale === lang ? 'bg-[#0e639c] text-white border-[#0e639c]' : 'bg-[var(--bg-primary)] text-[var(--text-muted)] hover:bg-[var(--bg-hover)]'}"
                        on:click={() => locale.set(lang)}
                    >
                        {lang.toUpperCase()}
                    </button>
                {/each}
            </div>
          </div>
        </div>
      </div>
    {:else if activeTab === 'shortcuts'}
      <div class="max-w-3xl">
        <h3 class="text-xl font-bold text-[var(--text-primary)] mb-6">{$t('settings.keyboardShortcuts')}</h3>
        
        <div class="bg-[var(--bg-secondary)] rounded border border-[var(--border-color)] overflow-hidden">
          <div class="grid grid-cols-12 gap-4 p-3 bg-[var(--bg-tertiary)] border-b border-[var(--border-color)] text-xs font-bold text-[var(--text-muted)] uppercase tracking-wider">
            <div class="col-span-1 text-center">{$t('settings.icon')}</div>
            <div class="col-span-6">{$t('settings.action')}</div>
            <div class="col-span-5 text-center">{$t('settings.shortcut')}</div>
          </div>
          
          <div class="divide-y divide-[var(--border-color)]">
            {#each Object.entries($shortcuts) as [key, keybind]}
              <!-- svelte-ignore indent -->
              {@const action = key}
              <div class="grid grid-cols-12 gap-4 p-3 items-center hover:bg-[var(--bg-hover)] transition-colors">
                <div class="col-span-1 flex justify-center text-[var(--text-muted)]">
                  {@html getIcon(action)}
                </div>
                <div class="col-span-6 font-medium text-[var(--text-secondary)]">
                  {getLabel(action)}
                </div>
                <div class="col-span-5 flex justify-center">
                  <KeybindRecorder 
                    value={keybind} 
                    recording={recordingAction === action}
                    on:start={() => recordingAction = action}
                    on:stop={() => recordingAction = null}
                    on:change={(e) => handleShortcutChange(action, e.detail)}
                  />
                </div>
              </div>
            {/each}
          </div>
        </div>

        <div class="mt-8 flex justify-center">
          <button
            class="px-4 py-2 bg-[#ef4444] hover:bg-[#dc2626] text-white rounded font-medium transition-colors shadow-lg shadow-red-900/20"
            on:click={handleResetDefaults}
          >
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
                <li><code>*.png</code> - Matches all PNG files</li>
                <li><code>node_modules</code> - Matches exact folder/file name</li>
                <li><code>.git</code> - Matches exact folder/file name</li>
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
