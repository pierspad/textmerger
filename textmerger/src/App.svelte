<script lang="ts">
  import { invoke } from "@tauri-apps/api/core";
  import { getCurrentWebview } from "@tauri-apps/api/webview";
  import { open, save } from "@tauri-apps/plugin-dialog";
  import { writeTextFile } from "@tauri-apps/plugin-fs";
  import { onMount, tick } from "svelte";
  import FileTree from "./lib/FileTree.svelte";
  import Settings from "./lib/components/Settings.svelte";
  import Modal from "./lib/components/Modal.svelte";
  import { t } from "./lib/stores/i18n";
  import { settings } from "./lib/stores/settings";
  import { shortcuts } from "./lib/stores/shortcuts";
  import { tabs, type FileNode } from "./lib/stores/tabs";

  interface AddFilesResult {
    files: FileNode[];
    errors: string[];
  }

  // Action to focus element on mount
  function focusElement(node: HTMLElement) {
      node.focus();
  }

  // Reactive state from store
  $: files = $tabs.tabs.find((t) => t.id === $tabs.activeTabId)?.files || [];

  let mergedContent = "";
  let selectedFiles: Set<string> = new Set();
  let isSidebarExpanded = true;
  let sidebarWidth = 300;
  let showOutputs = false;
  let hasIpynb = false;
  let snackbarMessage = "";
  let snackbarTimeout: any;
  let showSettings = false;
  let contextMenu = { show: false, x: 0, y: 0, path: "", name: "" };
  let tabContextMenu = { show: false, x: 0, y: 0, tabId: "" };
  let isLoading = false;
  
  // Dialog States
  let showRenameModal = false;
  let showMergeModal = false;
  let newTabName = "";
  
  // Tab Scrolling
  let tabContainer: HTMLElement;
  let showScrollButtons = false;

  function scrollTabs(direction: 'left' | 'right') {
    if (!tabContainer) return;
    const scrollAmount = 200;
    tabContainer.scrollBy({
      left: direction === 'left' ? -scrollAmount : scrollAmount,
      behavior: 'smooth'
    });
  }

  function checkScroll() {
    if (!tabContainer) return;
    showScrollButtons = tabContainer.scrollWidth > tabContainer.clientWidth;
  }
  
  // Update scroll buttons on resize and tab changes
  $: if ($tabs.tabs) {
      tick().then(checkScroll);
  }

  // Scroll active tab into view
  $: if ($tabs.activeTabId && tabContainer) {
      tick().then(() => {
          const activeTabEl = tabContainer.querySelector(`[data-id="${$tabs.activeTabId}"]`) as HTMLElement;
          if (activeTabEl) {
              activeTabEl.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
          }
      });
  }
  
  onMount(() => {
    window.addEventListener('resize', checkScroll);
    return () => window.removeEventListener('resize', checkScroll);
  });

  let selectedMergeSourceId = "";
  
  // Drag and drop for tabs
  let draggedTabId: string | null = null;
  let dragOverTabId: string | null = null;

  $: hasIpynb = files.some((f) => f.path.toLowerCase().endsWith(".ipynb"));
  
  // Auto-update content when files change
  $: if (files) {
      updateContent();
  }

  function showSnackbar(msg: string) {
    snackbarMessage = msg;
    if (snackbarTimeout) clearTimeout(snackbarTimeout);
    snackbarTimeout = setTimeout(() => {
      snackbarMessage = "";
    }, 2000);
  }

  async function updateContent() {
    try {
      if (files.length === 0) {
        mergedContent = "";
        return;
      }
      // Pass paths to backend
      const paths = files.map((f) => f.path);
      mergedContent = await invoke("get_merged_content", {
        paths,
        showOutputs,
      });
    } catch (e) {
      console.error(e);
      mergedContent = `<div class='error'>Error: ${e}</div>`;
    }
  }

  function toggleOutputs() {
    showOutputs = !showOutputs;
    updateContent();
    showSnackbar(
      showOutputs
        ? $t("messages.showingOutputs")
        : $t("messages.hidingOutputs"),
    );
  }

  async function handleDrop(event: DragEvent) {
    event.preventDefault();
  }

  onMount(() => {
    let unlisten: () => void;

    const setup = async () => {
      unlisten = await getCurrentWebview().onDragDropEvent(async (event) => {
        if (event.payload.type === "drop") {
          isLoading = true;
          await tick();
          await new Promise((resolve) => setTimeout(resolve, 50));

          try {
            const result = await invoke("add_files", {
              paths: event.payload.paths,
              excludedPatterns: $settings.excludedPatterns,
            });

            const { files: newFiles, errors } = result as AddFilesResult;
            tabs.addFilesToTab($tabs.activeTabId, newFiles);
            // files updates reactively

            if (errors.length > 0) {
              const errorMsg =
                errors.slice(0, 3).join("\n") +
                (errors.length > 3 ? `\n...and ${errors.length - 3} more` : "");
              showSnackbar(
                $t("messages.filesAddedWithErrors") + " " + errorMsg,
              );
            } else {
              showSnackbar($t("messages.filesAdded"));
            }
          } catch (e) {
            console.error(e);
          } finally {
            isLoading = false;
          }
        }
      });
    };

    setup();

    return () => {
      if (unlisten) unlisten();
    };
  });

  async function openFiles() {
    try {
      const selected = await open({
        multiple: true,
        directory: false,
      });

      if (selected) {
        isLoading = true;
        await tick();
        await new Promise((resolve) => setTimeout(resolve, 50));

        const paths = Array.isArray(selected) ? selected : [selected];
        const result = await invoke("add_files", {
          paths,
          excludedPatterns: $settings.excludedPatterns,
        });
        const { files: newFiles, errors } = result as AddFilesResult;
        tabs.addFilesToTab($tabs.activeTabId, newFiles);
        
        if (errors.length > 0) {
          const errorMsg =
            errors.slice(0, 3).join("\n") +
            (errors.length > 3 ? `\n...and ${errors.length - 3} more` : "");
          showSnackbar($t("messages.filesAddedWithErrors") + " " + errorMsg);
        } else {
          showSnackbar($t("messages.filesAdded"));
        }
      }
    } catch (e) {
      console.error(e);
    } finally {
      isLoading = false;
    }
  }

  async function removeSelected() {
    if (selectedFiles.size === 0) return;

    // Check all files in active tab
    const filesToRemove = new Set<string>();

    for (const selectedPath of selectedFiles) {
      // Check if selectedPath is exactly one of the files
      if (files.some(f => f.path === selectedPath)) {
        filesToRemove.add(selectedPath);
      } else {
         // Check if it's a directory (prefix)
         const prefix =
          selectedPath.endsWith("/") || selectedPath.endsWith("\\")
            ? selectedPath
            : selectedPath + "/";
            
         files.forEach(f => {
             if (f.path.startsWith(prefix) || f.path.startsWith(selectedPath + "\\")) {
                 filesToRemove.add(f.path);
             }
         });
      }
    }
    
    // Convert to removeFile calls or just setFiles
    // We can just filter the current list
    const remaining = files.filter(f => !filesToRemove.has(f.path));
    tabs.setFilesForTab($tabs.activeTabId, remaining);

    selectedFiles.clear();
    selectedFiles = selectedFiles;
    showSnackbar($t("messages.selectedRemoved"));
  }

  async function removeAll() {
    tabs.setFilesForTab($tabs.activeTabId, []);
    showSnackbar($t("messages.allRemoved"));
  }

  async function copyToClipboard() {
    try {
      const temp = document.createElement("div");
      temp.innerHTML = mergedContent;
      const text = temp.textContent || temp.innerText || "";

      await navigator.clipboard.writeText(text);
      showSnackbar($t("messages.copied"));
    } catch (e) {
      console.error("Failed to copy", e);
      showSnackbar($t("messages.copyFailed"));
    }
  }

  async function saveFile() {
    try {
      const activeTab = $tabs.tabs.find(t => t.id === $tabs.activeTabId);
      const defaultName = activeTab ? activeTab.name : "merged";
      const path = await save({
        defaultPath: defaultName + ".txt",
        filters: [
          {
            name: "Text",
            extensions: ["txt", "md"],
          },
        ],
      });

      if (path) {
        const temp = document.createElement("div");
        temp.innerHTML = mergedContent;
        const text = temp.textContent || temp.innerText || "";

        await writeTextFile(path, text);
        showSnackbar($t("messages.saved"));
      }
    } catch (e) {
      console.error(e);
      showSnackbar($t("messages.saveFailed"));
    }
  }

  async function exitApp() {
    await invoke("exit_app");
  }

  function handleDragOver(event: DragEvent) {
    event.preventDefault();
  }

  function toggleSidebar() {
    isSidebarExpanded = !isSidebarExpanded;
  }
  
  // Tab functions
  function handleTabClick(id: string) {
      tabs.setActiveTab(id);
  }
  
  function handleAddTab() {
      tabs.addTab();
  }
  
  function handleCloseTab(e: MouseEvent, id: string) {
      e.stopPropagation();
      tabs.closeTab(id);
  }
  
  function handleTabContextMenu(e: MouseEvent, id: string) {
      e.preventDefault();
      tabContextMenu = {
          show: true,
          x: e.clientX,
          y: e.clientY,
          tabId: id
      };
  }
  
  function openRenameModal() {
      const tab = $tabs.tabs.find(t => t.id === tabContextMenu.tabId);
      if (tab) {
          newTabName = tab.name;
          showRenameModal = true;
      }
      closeContextMenu();
  }
  
  function confirmRename() {
      if (newTabName.trim()) {
           tabs.renameTab(tabContextMenu.tabId, newTabName.trim());
      }
      showRenameModal = false;
  }
  
  function openMergeModal() {
     selectedMergeSourceId = "";
     showMergeModal = true;
     closeContextMenu();
  }
  
  function confirmMerge() {
      if (selectedMergeSourceId && selectedMergeSourceId !== tabContextMenu.tabId) {
           tabs.uniteTabs(tabContextMenu.tabId, selectedMergeSourceId);
           showSnackbar("Tabs merged successfully");
      }
      showMergeModal = false;
  }

    // Drag and Drop Tabs
  function handleTabDragStart(e: DragEvent, id: string) {
      draggedTabId = id;
      if (e.dataTransfer) {
          e.dataTransfer.effectAllowed = 'move';
          e.dataTransfer.dropEffect = 'move';
      }
  }

  function handleTabDragOver(e: DragEvent, id: string) {
      e.preventDefault();
      dragOverTabId = id;
  }

  function handleTabDrop(e: DragEvent, id: string) {
      e.preventDefault();
      if (draggedTabId && draggedTabId !== id) {
           reorderTabs(draggedTabId, id);
      }
      draggedTabId = null;
      dragOverTabId = null;
  }

  function reorderTabs(fromId: string, toId: string) {
      tabs.reorderTabs(fromId, toId);
  }


  function handleKeydown(event: KeyboardEvent) {
    // If modal is open, let modal handle keys or check specific conditions
    if (showRenameModal || showMergeModal) return;

    const keys = [];
    if (event.ctrlKey) keys.push("Ctrl");
    if (event.altKey) keys.push("Alt");
    if (event.shiftKey) keys.push("Shift");
    if (event.metaKey) keys.push("Meta");

    if (!["Control", "Alt", "Shift", "Meta"].includes(event.key)) {
      let key = event.key.toUpperCase();
      if (key === " ") key = "SPACE";
      keys.push(key);
    } else {
      return;
    }

    const combo = keys.join("+");

    if (combo === $shortcuts.open) {
      event.preventDefault();
      openFiles();
    } else if (combo === $shortcuts.save) {
      event.preventDefault();
      saveFile();
    } else if (combo === $shortcuts.exit) {
      event.preventDefault();
      exitApp();
    } else if (combo === $shortcuts.remove) {
      event.preventDefault();
      removeSelected();
    } else if (combo === $shortcuts.removeAll) {
      event.preventDefault();
      removeAll();
    } else if (combo === $shortcuts.copyText) {
      event.preventDefault();
      copyToClipboard();
    } else if (combo === $shortcuts.refresh) {
      event.preventDefault();
      updateContent();
      showSnackbar($t("messages.refreshed"));
    }
  }

  function handleSnackbarEvent(e: CustomEvent<string>) {
    showSnackbar(e.detail);
  }

  function handleContextMenu(e: CustomEvent) {
    const { event, path, name } = e.detail;
    event.preventDefault();
    contextMenu = {
      show: true,
      x: event.clientX,
      y: event.clientY,
      path,
      name,
    };
  }

  function closeContextMenu() {
    contextMenu.show = false;
    tabContextMenu.show = false;
  }

  async function copyPath() {
    try {
      await navigator.clipboard.writeText(contextMenu.path);
      showSnackbar($t("messages.pathCopied"));
    } catch (e) {
      console.error(e);
    }
    closeContextMenu();
  }

  async function copyFilename() {
    try {
      const basename =
        contextMenu.path.split(/[/\\]/).pop() || contextMenu.name;
      await navigator.clipboard.writeText(basename);
      showSnackbar($t("messages.filenameCopied"));
    } catch (e) {
      console.error(e);
    }
    closeContextMenu();
  }

  function scrollToFile(path: string) {
     const tab = $tabs.tabs.find(t => t.id === $tabs.activeTabId);
     if (!tab) return;
     const index = tab.files.findIndex(f => f.path === path);
     if (index !== -1) {
       const el = document.getElementById(`file-${index}`);
       if (el) {
         el.scrollIntoView({ behavior: "smooth", block: "start" });
         showSnackbar(
           `${$t("messages.scrolledTo")} ${path.split(/[/\\]/).pop()}`,
         );
       }
     }
  }

  function handleFileDblClick(e: CustomEvent) {
    const { path } = e.detail;
    scrollToFile(path);
  }

  function handleGlobalContextMenu(e: MouseEvent) {
    const target = e.target as HTMLElement;
    if (target.tagName === "INPUT" || target.tagName === "TEXTAREA") {
      return;
    }
    if (target.closest('.tab-item')) return; // Allow tab context menu
    e.preventDefault();
  }
</script>

<svelte:window
  on:keydown={handleKeydown}
  on:click={closeContextMenu}
  on:contextmenu={handleGlobalContextMenu}
/>

<main
  class="flex h-full w-full overflow-hidden bg-[var(--bg-primary)] text-[var(--text-primary)] font-sans relative"
>
  <!-- Snackbar -->
  {#if snackbarMessage}
    <div
      class="fixed bottom-20 left-1/2 transform -translate-x-1/2 bg-[var(--bg-hover-strong)] text-white px-4 py-2 rounded shadow-lg z-50 border border-[var(--border-light)] animate-fade-in-up"
    >
      {snackbarMessage}
    </div>
  {/if}

  <!-- Loading Overlay -->
  {#if isLoading}
    <div
      class="fixed inset-0 bg-black/50 z-[60] flex items-center justify-center backdrop-blur-sm"
    >
      <div
        class="bg-[var(--bg-secondary)] p-6 rounded-lg shadow-xl flex flex-col items-center gap-4 border border-[var(--border-light)]"
      >
        <div
          class="w-10 h-10 border-4 border-[var(--text-muted)] border-t-[var(--text-primary)] rounded-full animate-spin"
        ></div>
        <span class="text-[var(--text-primary)] font-medium"
          >Processing files...</span
        >
      </div>
    </div>
  {/if}

  <!-- Settings Overlay -->
  {#if showSettings}
    <Settings
      on:close={() => (showSettings = false)}
      on:snackbar={handleSnackbarEvent}
    />
  {/if}
  
  <!-- Rename Modal -->
  {#if showRenameModal}
      <Modal 
          title="Rename Tab" 
          confirmText="Rename" 
          on:close={() => showRenameModal = false} 
          on:confirm={confirmRename}
      >
          <div class="flex flex-col gap-2">
              <label for="rename-input" class="text-sm font-medium text-[var(--text-secondary)]">New Name</label>
              <input 
                  id="rename-input"
                  type="text" 
                  bind:value={newTabName}
                  class="w-full px-3 py-2 bg-[var(--bg-primary)] border border-[var(--border-color)] rounded focus:outline-none focus:border-blue-500 text-[var(--text-primary)]"
                  placeholder="Enter tab name..."
                  use:focusElement
                  on:keydown={(e) => e.key === 'Enter' && confirmRename()}
              />
          </div>
      </Modal>
  {/if}

  <!-- Merge Modal -->
  {#if showMergeModal}
      <Modal 
          title="Merge Tabs" 
          confirmText="Merge" 
          disabled={!selectedMergeSourceId}
          on:close={() => showMergeModal = false} 
          on:confirm={confirmMerge}
      >
          <div class="flex flex-col gap-2">
              <p class="text-sm text-[var(--text-muted)] mb-2">
                  Select a tab to merge into <strong>{$tabs.tabs.find(t => t.id === tabContextMenu.tabId)?.name}</strong>.
              </p>
              <label for="merge-select" class="text-sm font-medium text-[var(--text-secondary)]">Source Tab</label>
              <select 
                  id="merge-select"
                  bind:value={selectedMergeSourceId}
                  class="w-full px-3 py-2 bg-[var(--bg-primary)] border border-[var(--border-color)] rounded focus:outline-none focus:border-blue-500 text-[var(--text-primary)]"
              >
                  <option value="" disabled selected>Select a tab...</option>
                  {#each $tabs.tabs.filter(t => t.id !== tabContextMenu.tabId) as tab}
                      <option value={tab.id}>{tab.name}</option>
                  {/each}
              </select>
              {#if $tabs.tabs.length <= 1}
                   <p class="text-xs text-red-400 mt-1">No other tabs available to merge.</p>
              {/if}
          </div>
      </Modal>
  {/if}


  <!-- Sidebar -->
  {#if isSidebarExpanded}
    <aside
      class="flex flex-col border-r border-[var(--border-color)] bg-[var(--bg-secondary)]"
      style="width: {sidebarWidth}px; min-width: 250px;"
    >
      <!-- Sidebar Header / Toolbar -->
      <div
        class="h-12 px-2 border-b border-[var(--border-color)] bg-[var(--bg-tertiary)] flex items-center gap-2"
      >
        <button
          class="p-2 bg-[var(--bg-hover-strong)] hover:bg-[var(--bg-hover)] rounded text-[var(--text-secondary)] transition-colors"
          on:click={() => (showSettings = true)}
          title="Settings"
          aria-label="Settings"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="1.5"
            stroke="currentColor"
            class="w-5 h-5"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z"
            />
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
            />
          </svg>
        </button>
        <button
          class="flex-1 px-3 py-2 bg-[#0e639c] hover:bg-[#1177bb] text-white rounded font-bold text-sm flex items-center justify-center gap-2 transition-colors shadow-lg shadow-blue-900/20"
          on:click={openFiles}
          aria-label="Open Files"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="2"
            stroke="currentColor"
            class="w-4 h-4"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M2.25 12.75V12A2.25 2.25 0 014.5 9.75h15A2.25 2.25 0 0121.75 12v.75m-8.69-6.44l-2.12-2.12a1.5 1.5 0 00-1.061-.44H4.5A2.25 2.25 0 002.25 6v12a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9a2.25 2.25 0 00-2.25-2.25h-5.379a1.5 1.5 0 01-1.06-.44z"
            />
          </svg>
          {$t("app.open")}
        </button>
      </div>
      

      <div
        class="px-3 py-2 text-xs font-semibold text-[var(--text-muted)] uppercase tracking-wider bg-[var(--bg-secondary)]"
      >
        {$t("app.addedFiles")} {files.length ? `(${files.length})` : ''}
      </div>

      <div
        class="flex-1 overflow-y-auto p-2"
        role="list"
        on:drop={handleDrop}
        on:dragover={handleDragOver}
      >
        {#if files.length === 0}
          <div
            class="h-full flex flex-col items-center justify-center text-[var(--text-muted)] text-sm border border-dashed border-[var(--border-light)] rounded-lg m-2 bg-[var(--bg-primary)]"
          >
            <p class="mb-2">{$t("app.dragFiles")}</p>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="w-8 h-8 opacity-50"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"
              />
            </svg>
          </div>
        {:else}
          <FileTree
            {files}
            bind:selectedFiles
            on:contextmenu={handleContextMenu}
            on:dblclick={handleFileDblClick}
          />
        {/if}
      </div>

      <div
        class="h-16 px-3 border-t border-[var(--border-color)] bg-[var(--bg-tertiary)] flex items-center gap-2"
      >
        <button
          class="flex-1 px-3 py-2 bg-[#ef4444] hover:bg-[#dc2626] text-white rounded font-bold text-xs flex items-center justify-center gap-1 transition-colors shadow-lg shadow-red-900/20 disabled:opacity-50 disabled:cursor-not-allowed"
          on:click={removeSelected}
          title="Remove Selected"
          disabled={selectedFiles.size === 0}
          aria-label="Remove Selected"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="currentColor"
            class="w-4 h-4"
            ><path
              d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"
            /></svg
          >
          {$t("app.remove")}
        </button>
        <button
          class="flex-1 px-3 py-2 bg-[#b91c1c] hover:bg-[#991b1b] text-white rounded font-bold text-xs flex items-center justify-center gap-1 transition-colors shadow-lg shadow-red-900/20 disabled:opacity-50 disabled:cursor-not-allowed"
          on:click={removeAll}
          title="Remove All"
          disabled={files.length === 0}
          aria-label="Remove All"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="currentColor"
            class="w-4 h-4"
            ><path
              d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"
            /></svg
          >
          {$t("app.removeAll")}
        </button>
      </div>
    </aside>
  {/if}

  <!-- Main Content -->
  <section class="flex-1 flex flex-col h-full min-w-0 bg-[var(--bg-primary)]">
    <header
      class="h-12 border-b border-[var(--border-color)] flex items-center px-4 justify-between bg-[var(--bg-tertiary)]"
    >
      <div class="flex items-center gap-3 overflow-hidden flex-1 h-full pt-2">
        <button
          class="p-1 hover:bg-[var(--bg-hover-strong)] rounded text-[var(--text-muted)] mb-1"
          on:click={toggleSidebar}
          aria-label="Toggle Sidebar"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="1.5"
            stroke="currentColor"
            class="w-5 h-5"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
            />
          </svg>
        </button>
        
        <!-- Tab Bar in Header -->
         <div class="flex items-center flex-1 min-w-0 h-full gap-1 pt-2 relative">
            {#if showScrollButtons}
              <button 
                class="h-8 w-6 flex items-center justify-center hover:bg-[var(--bg-hover-strong)] rounded text-[var(--text-muted)] z-10"
                on:click={() => scrollTabs('left')}
                aria-label="Scroll tabs left"
              >
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-4 h-4">
                    <path fill-rule="evenodd" d="M12.79 5.23a.75.75 0 01-.02 1.06L8.832 10l3.938 3.71a.75.75 0 11-1.04 1.08l-4.5-4.25a.75.75 0 010-1.08l4.5-4.25a.75.75 0 011.06.02z" clip-rule="evenodd" />
                  </svg>
              </button>
            {/if}
            
            <div 
              class="flex overflow-x-auto scrollbar-hide h-full items-end gap-1 select-none flex-1 px-1"
              bind:this={tabContainer}
              on:scroll={checkScroll}
            >

          {#each $tabs.tabs as tab (tab.id)}
            <div 
               class="group relative flex items-center px-3 py-1.5 min-w-[120px] max-w-[200px] rounded-t-lg cursor-pointer border-t border-l border-r border-transparent transition-all duration-200 select-none
               {tab.id === $tabs.activeTabId 
                  ? 'bg-[var(--tab-bg-active)] text-[var(--text-primary)] z-10 border-[var(--border-color)] border-b-0 shadow-sm' 
                  : 'bg-[var(--tab-bg-inactive)] text-[var(--text-muted)] hover:bg-[var(--tab-bg-hover)] border-b border-[var(--border-color)] opacity-80 hover:opacity-100'}"
               draggable="true"
               role="button"
               tabindex="0"
               data-id={tab.id}
               on:click={() => handleTabClick(tab.id)}
               on:keydown={(e) => (e.key === 'Enter' || e.key === ' ') && handleTabClick(tab.id)}
               on:contextmenu={(e) => handleTabContextMenu(e, tab.id)}
               on:dragstart={(e) => handleTabDragStart(e, tab.id)}
               on:dragover={(e) => handleTabDragOver(e, tab.id)}
               on:drop={(e) => handleTabDrop(e, tab.id)}
               class:brightness-110={dragOverTabId === tab.id}
               aria-label={`Tab: ${tab.name}`}
            >
                <!-- Separator (visual trick for inactive tabs, strictly optional, relying on spacing for now) -->
                
                <div class="truncate text-xs font-medium pr-5 flex-1">{tab.name}</div>
                <button 
                  class="absolute right-1 top-1/2 -translate-y-1/2 p-0.5 rounded-full hover:bg-[var(--bg-hover-strong)] hover:text-white opacity-0 group-hover:opacity-100 transition-opacity
                  {tab.id === $tabs.activeTabId ? 'opacity-100 text-[var(--text-muted)]' : 'text-[var(--text-muted)]'}"
                  on:click={(e) => handleCloseTab(e, tab.id)}
                  aria-label={`Close ${tab.name}`}
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                    </svg>
                </button>
            </div>
          {/each}
          </div>
          
            {#if showScrollButtons}
              <button 
                class="h-8 w-6 flex items-center justify-center hover:bg-[var(--bg-hover-strong)] rounded text-[var(--text-muted)] z-10"
                on:click={() => scrollTabs('right')}
                aria-label="Scroll tabs right"
              >
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-4 h-4">
                    <path fill-rule="evenodd" d="M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z" clip-rule="evenodd" />
                  </svg>
              </button>
            {/if}

          <div class="h-full flex items-center border-b border-[var(--border-color)] px-1 relative z-20">
            <button 
               class="p-1 rounded hover:bg-[var(--bg-hover-strong)] text-[var(--text-muted)]"
               on:click={handleAddTab}
               title="New Tab"
               aria-label="New Tab"
            >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M10 5a1 1 0 011 1v3h3a1 1 0 110 2h-3v3a1 1 0 11-2 0v-3H6a1 1 0 110-2h3V6a1 1 0 011-1z" clip-rule="evenodd" />
                </svg>
            </button>
          </div>
         </div>

      </div>
    </header>

    <div class="flex-1 overflow-auto p-6 relative">
      <div
        class="prose prose-invert max-w-none prose-pre:bg-[var(--bg-tertiary)] prose-pre:border prose-pre:border-[var(--border-light)] pb-16"
      >
        {@html mergedContent ||
          `<div class="flex flex-col items-center justify-center h-64 text-[var(--text-muted)] italic"><span>${$t("app.noContent")}</span><span class="text-sm mt-2">${$t("app.addFilesHint")}</span></div>`}
      </div>
    </div>

    <!-- Bottom Action Bar -->
    <div
      class="h-16 border-t border-[var(--border-color)] bg-[var(--bg-tertiary)] flex items-center px-4 justify-between"
    >
      <div class="text-xs text-[var(--text-muted)]">
        {$t("app.characters")}: {mergedContent.length.toLocaleString()}
      </div>
      <div class="flex gap-3">
        {#if hasIpynb}
          <button
            class="px-4 py-2 {showOutputs
              ? 'bg-[#4b5563] hover:bg-[#374151]'
              : 'bg-[#059669] hover:bg-[#047857]'} text-white rounded font-bold text-sm flex items-center gap-2 transition-colors shadow-lg"
            on:click={toggleOutputs}
          >
            {#if showOutputs}
              <!-- Eye Slash (Hide) -->
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="currentColor"
                class="w-4 h-4"
              >
                <path
                  d="M3.53 2.47a.75.75 0 00-1.06 1.06l18 18a.75.75 0 101.06-1.06l-18-18zM22.676 12.553a11.249 11.249 0 01-2.631 4.31l-3.099-3.099a5.25 5.25 0 00-6.71-6.71L7.759 4.577a11.217 11.217 0 014.242-.827c4.97 0 9.185 3.223 10.675 7.69.12.362.12.752 0 1.113z"
                />
                <path
                  d="M5.574 12.553A11.217 11.217 0 011.41 9.645a.75.75 0 011.061-1.06 9.716 9.716 0 002.181 1.802l.926-.926a.75.75 0 011.06 1.06l-.926.926c.441.374.904.72 1.387 1.034a.75.75 0 01-.83 1.26A12.72 12.72 0 015.574 12.553z"
                />
                <path d="M10.5 14.25a3.75 3.75 0 005.25-5.25l-5.25 5.25z" />
              </svg>
            {:else}
              <!-- Eye (Show) -->
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="currentColor"
                class="w-4 h-4"
              >
                <path d="M12 15a3 3 0 100-6 3 3 0 000 6z" />
                <path
                  fill-rule="evenodd"
                  d="M1.323 11.447C2.811 6.976 7.028 3.75 12.001 3.75c4.97 0 9.185 3.223 10.675 7.69.12.362.12.752 0 1.113-1.487 4.471-5.705 7.697-10.677 7.697-4.97 0-9.186-3.223-10.675-7.69a1.762 1.762 0 010-1.113zM17.25 12a5.25 5.25 0 11-10.5 0 5.25 5.25 0 0110.5 0z"
                  clip-rule="evenodd"
                />
              </svg>
            {/if}
            {showOutputs ? $t("app.hideOutputs") : $t("app.showOutputs")}
          </button>
        {/if}

        <button
          class="px-4 py-2 bg-[#8b5cf6] hover:bg-[#7c3aed] text-white rounded font-bold text-sm flex items-center gap-2 transition-colors shadow-lg shadow-purple-900/20"
          on:click={copyToClipboard}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="currentColor"
            class="w-4 h-4"
            ><path
              d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"
            /></svg
          >
          {$t("app.copyText")}
        </button>

        <button
          class="px-4 py-2 bg-[#10b981] hover:bg-[#059669] text-white rounded font-bold text-sm flex items-center gap-2 transition-colors shadow-lg shadow-green-900/20"
          on:click={() => {
            updateContent();
            showSnackbar($t("messages.refreshed"));
          }}
          title="Reload content from files"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="2"
            stroke="currentColor"
            class="w-4 h-4"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182m0-4.991v4.99"
            />
          </svg>
          {$t("app.refresh")}
        </button>

        <button
          class="px-4 py-2 bg-[#f59e0b] hover:bg-[#d97706] text-white rounded font-bold text-sm flex items-center gap-2 transition-colors shadow-lg shadow-orange-900/20"
          on:click={saveFile}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="currentColor"
            class="w-4 h-4"
            ><path
              d="M17 3H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V7l-4-4zm-5 16c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3zm3-10H5V5h10v4z"
            /></svg
          >
          {$t("app.save")}
        </button>
        <button
          class="px-4 py-2 bg-[#4b5563] hover:bg-[#374151] text-white rounded font-bold text-sm flex items-center gap-2 transition-colors shadow-lg"
          on:click={exitApp}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="currentColor"
            class="w-4 h-4"
          >
            <path
              d="M10.09 15.59L11.5 17l5-5-5-5-1.41 1.41L12.67 11H3v2h9.67l-2.58 2.59zM19 3H5c-1.11 0-2 .9-2 2v4h2V5h14v14H5v-4H3v4c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"
            />
          </svg>
          {$t("app.exit")}
        </button>
      </div>
    </div>
  </section>
</main>

<!-- Context Menu for Files -->
{#if contextMenu.show}
  <div
    class="fixed bg-[var(--bg-tertiary)] border border-[var(--border-light)] shadow-xl rounded py-1 z-50 text-sm min-w-[150px]"
    style="top: {contextMenu.y}px; left: {contextMenu.x}px"
  >
    <button
      class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text-primary)] transition-colors"
      on:click={copyPath}
    >
      {$t("contextMenu.copyPath")}
    </button>
    <button
      class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text-primary)] transition-colors"
      on:click={copyFilename}
    >
      {$t("contextMenu.copyFilename")}
    </button>
  </div>
{/if}

<!-- Context Menu for Tabs -->
{#if tabContextMenu.show}
  <div
    class="fixed bg-[var(--bg-tertiary)] border border-[var(--border-light)] shadow-xl rounded py-1 z-50 text-sm min-w-[150px]"
    style="top: {tabContextMenu.y}px; left: {tabContextMenu.x}px"
  >
    <button
      class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text-primary)] transition-colors"
      on:click={openRenameModal}
    >
      Rename Tab
    </button>
    <button
      class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text-primary)] transition-colors"
      on:click={openMergeModal}
    >
      Merge with...
    </button>
  </div>
{/if}

<style>
  @keyframes fade-in-up {
    from {
      opacity: 0;
      transform: translate(-50%, 20px);
    }
    to {
      opacity: 1;
      transform: translate(-50%, 0);
    }
  }
  .animate-fade-in-up {
    animation: fade-in-up 0.3s ease-out;
  }
</style>
