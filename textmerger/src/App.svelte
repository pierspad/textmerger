<script lang="ts">
  import { invoke } from "@tauri-apps/api/core";
  import { getCurrentWebview } from "@tauri-apps/api/webview";
  import { open, save } from "@tauri-apps/plugin-dialog";
  import { writeTextFile } from "@tauri-apps/plugin-fs";
  import { onMount, tick } from "svelte";
  import FileTree from "./lib/FileTree.svelte";
  import Settings from "./lib/components/Settings.svelte";
  import { t } from "./lib/stores/i18n";
  import { settings } from "./lib/stores/settings";
  import { shortcuts } from "./lib/stores/shortcuts";

  interface AddFilesResult {
    files: string[];
    errors: string[];
  }

  let files: string[] = [];
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
  let isLoading = false;

  $: hasIpynb = files.some((f) => f.toLowerCase().endsWith(".ipynb"));

  function showSnackbar(msg: string) {
    snackbarMessage = msg;
    if (snackbarTimeout) clearTimeout(snackbarTimeout);
    snackbarTimeout = setTimeout(() => {
      snackbarMessage = "";
    }, 2000);
  }

  async function updateContent() {
    try {
      mergedContent = await invoke("get_merged_content", { showOutputs });
    } catch (e) {
      console.error(e);
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
            files = newFiles;
            await updateContent();

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
        files = newFiles;
        await updateContent();
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

    const filesToRemove = new Set<string>();

    for (const selectedPath of selectedFiles) {
      if (files.includes(selectedPath)) {
        filesToRemove.add(selectedPath);
      } else {
        const prefix =
          selectedPath.endsWith("/") || selectedPath.endsWith("\\")
            ? selectedPath
            : selectedPath + "/";
        for (const file of files) {
          if (
            file.startsWith(selectedPath + "/") ||
            file.startsWith(selectedPath + "\\")
          ) {
            filesToRemove.add(file);
          }
        }
      }
    }

    for (const path of filesToRemove) {
      try {
        files = await invoke("remove_file", { path });
      } catch (e) {
        console.error(e);
      }
    }

    selectedFiles.clear();
    selectedFiles = selectedFiles;
    await updateContent();
    showSnackbar($t("messages.selectedRemoved"));
  }

  async function removeAll() {
    const filesCopy = [...files];
    for (const path of filesCopy) {
      try {
        files = await invoke("remove_file", { path });
      } catch (e) {
        console.error(e);
      }
    }
    await updateContent();
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
      const path = await save({
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

  function handleKeydown(event: KeyboardEvent) {
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
    const index = files.indexOf(path);
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
        {$t("app.addedFiles")}
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
      <div class="flex items-center gap-3">
        <button
          class="p-1 hover:bg-[var(--bg-hover-strong)] rounded text-[var(--text-muted)]"
          on:click={toggleSidebar}
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
        <h1 class="font-bold text-[var(--text-primary)] text-lg">
          {$t("app.title")}
        </h1>
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
