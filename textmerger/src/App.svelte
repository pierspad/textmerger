<script lang="ts">
  import { invoke } from "@tauri-apps/api/core";
  import { getCurrentWebview } from "@tauri-apps/api/webview";
  import { open, save } from "@tauri-apps/plugin-dialog";
  import { writeTextFile } from "@tauri-apps/plugin-fs";
  import { open as openExternal } from "@tauri-apps/plugin-shell";
  import authorAvatar from "./assets/avatar.png";
  import { onMount, onDestroy, tick } from "svelte";
  import FileTree from "./lib/FileTree.svelte";
  import Settings from "./lib/components/Settings.svelte";
  import Modal from "./lib/components/Modal.svelte";
  import { t, tShortcut, locale } from "./lib/stores/i18n";
  import { settings } from "./lib/stores/settings";
  import { shortcuts } from "./lib/stores/shortcuts";
  import { tabs, type FileNode } from "./lib/stores/tabs";

  interface AddFilesResult {
    files: FileNode[];
    errors: string[];
  }

  type SnackbarVariant = "success" | "info" | "copy" | "warning" | "error";
  type SnackbarEventDetail = string | { message: string; variant?: SnackbarVariant };

  const snackbarPalette: Record<SnackbarVariant, {
    container: string;
    icon: string;
    progress: string;
    path: string;
  }> = {
    success: {
      container: "bg-emerald-950 text-emerald-50 border-emerald-600/70 shadow-emerald-950/30",
      icon: "text-emerald-300",
      progress: "bg-emerald-400",
      path: "M5 13l4 4L19 7",
    },
    info: {
      container: "bg-blue-950 text-blue-50 border-blue-600/70 shadow-blue-950/30",
      icon: "text-blue-300",
      progress: "bg-blue-400",
      path: "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z",
    },
    copy: {
      container: "bg-purple-950 text-purple-50 border-purple-600/70 shadow-purple-950/30",
      icon: "text-purple-300",
      progress: "bg-purple-400",
      path: "M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 01-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H6.75m9 10.5h3.375c.621 0 1.125-.504 1.125-1.125V11.25c0-4.46-3.243-8.161-7.5-8.876a9.06 9.06 0 00-1.5-.124H9.375c-.621 0-1.125.504-1.125 1.125v3.5m7.5 10.375H9.375a1.125 1.125 0 01-1.125-1.125v-9.25",
    },
    warning: {
      container: "bg-amber-950 text-amber-50 border-amber-600/70 shadow-amber-950/30",
      icon: "text-amber-300",
      progress: "bg-amber-400",
      path: "M12 9v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z",
    },
    error: {
      container: "bg-red-950 text-red-50 border-red-600/70 shadow-red-950/30",
      icon: "text-red-300",
      progress: "bg-red-400",
      path: "M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z",
    },
  };

  function focusElement(node: HTMLElement) {
      node.focus();
  }

  const normalize = (p: string) => p.replace(/\\/g, '/').replace(/\/$/, '');

  function truncatePath(path: string, limit = 50): string {
    if (!path) return "";
    if (path.length <= limit) return path;
    const charsToShow = limit - 3;
    const frontChars = Math.ceil(charsToShow / 2);
    const backChars = Math.floor(charsToShow / 2);
    return path.substring(0, frontChars) + "..." + path.substring(path.length - backChars);
  }

  function getCompactedRoots(paths: string[]): string[] {
    if (paths.length === 0) return [];
    const stdPaths = paths.map(p => p.replace(/\\/g, '/'));
    
    const tree: Record<string, { path: string; isFile: boolean; children: Set<string>; parent?: string }> = {};
    
    stdPaths.forEach(path => {
      const parts = path.split('/');
      let current = "";
      parts.forEach((part, idx) => {
        if (!part && idx === 0) {
          current = "/";
          return;
        }
        if (!part) return;
        
        const isLast = idx === parts.length - 1;
        const sep = current === "/" || current === "" ? "" : "/";
        const next = current + sep + part;
        
        if (!tree[next]) {
          tree[next] = { path: next, isFile: isLast, children: new Set(), parent: current || undefined };
          if (current && tree[current]) {
            tree[current].children.add(next);
          }
        }
        current = next;
      });
    });
    
    const roots = Object.keys(tree).filter(k => !tree[k].parent || !tree[tree[k].parent!]);
    
    const compactedRoots = roots.map(rootPath => {
      let current = rootPath;
      while (tree[current]) {
        const children = Array.from(tree[current].children);
        if (children.length === 1 && !tree[children[0]].isFile) {
          current = children[0];
        } else {
          break;
        }
      }
      return current;
    });
    
    return compactedRoots;
  }

  function getRelativePathFromRoot(path: string, compactedRoots: string[]): string {
    const stdPath = path.replace(/\\/g, '/');
    let bestRoot = "";
    for (const root of compactedRoots) {
      if (stdPath === root) {
        return "~";
      }
      if (stdPath.startsWith(root + '/')) {
        if (root.length > bestRoot.length) {
          bestRoot = root;
        }
      }
    }
    
    if (bestRoot) {
      const rel = stdPath.slice(bestRoot.length + 1);
      return "~/" + rel;
    }
    
    return path;
  }

  function formatRelativePath(relativePath: string): string {
    if (!relativePath.startsWith('~/')) return relativePath;
    
    const rel = relativePath.slice(2);
    const parts = rel.split('/');
    const dirs = parts.slice(0, parts.length - 1);
    const filename = parts[parts.length - 1];
    
    if (dirs.length <= 3) {
      return relativePath;
    }
    
    const keptDirs = dirs.slice(dirs.length - 3);
    return `~/.../${keptDirs.join('/')}/${filename}`;
  }

  function getFormattedContextMenuTitle(path: string, roots: string[], defaultName: string): string {
    if (!path) return defaultName;
    const relPath = getRelativePathFromRoot(path, roots);
    if (relPath === "~") {
      return path; // Return the full absolute path for root folders
    }
    if (relPath.startsWith("~/")) {
      return formatRelativePath(relPath);
    }
    return defaultName;
  }

  $: files = $tabs.tabs.find((t) => t.id === $tabs.activeTabId)?.files || [];

  let compactedRoots: string[] = [];
  $: {
    const paths = files.map(f => f.path);
    compactedRoots = getCompactedRoots(paths);
  }

  let mergedContent = "";
  let fileContentsCache: Record<string, string> = {};
  let fileTokensCache: Record<string, number> = {};
  let totalCharacterCount = 0;
  let tokenCount = 0;
  let encoder: any = null;
  let loadedTiktokenModel = "";

  let geminiTokenizer: any = null;
  let isGeminiLoading = false;
  let isGeminiLoaded = false;

  // Lazy-load tiktoken BPE ranks per model: avoids bundling ~6MB of rank
  // tables into the startup chunk (each rank becomes its own lazy chunk).
  const tiktokenRankLoaders: Record<string, () => Promise<any>> = {
    o200k_base: () => import("js-tiktoken/ranks/o200k_base"),
    cl100k_base: () => import("js-tiktoken/ranks/cl100k_base"),
    p50k_base: () => import("js-tiktoken/ranks/p50k_base"),
    r50k_base: () => import("js-tiktoken/ranks/r50k_base"),
  };

  async function loadTiktokenEncoder(model: string) {
    if (loadedTiktokenModel === model) return;
    const loader = tiktokenRankLoaders[model];
    if (!loader) return;
    try {
      const [{ Tiktoken }, ranks] = await Promise.all([
        import("js-tiktoken/lite"),
        loader(),
      ]);
      // The user may have switched model while the chunk was loading
      if ($settings.tokenizerModel !== model) return;
      encoder = new Tiktoken(ranks.default);
      loadedTiktokenModel = model;
    } catch (e) {
      console.error("Failed to load tokenizer:", model, e);
    }
  }

  $: if (tiktokenRankLoaders[$settings.tokenizerModel]) {
    void loadTiktokenEncoder($settings.tokenizerModel);
  }

  // True when the currently selected tokenizer can produce exact counts
  $: isTokenizerReady =
    $settings.tokenizerModel === "chars_ratio"
      ? true
      : $settings.tokenizerModel === "gemini"
        ? isGeminiLoaded
        : loadedTiktokenModel === $settings.tokenizerModel;

  async function loadGeminiTokenizer() {
    if (isGeminiLoaded || isGeminiLoading) return;
    isGeminiLoading = true;
    try {
      const module = await import("@lenml/tokenizer-gemini");
      geminiTokenizer = module.fromPreTrained();
      isGeminiLoaded = true;
    } catch (e) {
      console.error("Failed to load Gemini tokenizer:", e);
    } finally {
      isGeminiLoading = false;
    }
  }

  $: {
    if ($settings.tokenizerModel === "gemini") {
      void loadGeminiTokenizer();
    }
  }

  function calculateTokenCount(plainText: string, model: string): number {
    if (!plainText) return 0;
    if (model === "chars_ratio") {
      return Math.round(plainText.length / 4);
    }
    if (model === "gemini") {
      if (isGeminiLoaded && geminiTokenizer) {
        try {
          return geminiTokenizer.encode(plainText).length;
        } catch (e) {
          console.error("Gemini tokenization error:", e);
          return Math.round(plainText.length / 4);
        }
      }
      return 0;
    }

    try {
      if (!encoder || loadedTiktokenModel !== model) {
        // Encoder chunk not loaded yet: fall back to estimate
        return Math.round(plainText.length / 4);
      }
      return encoder.encode(plainText).length;
    } catch (e) {
      console.error("Tokenization error:", e);
      return Math.round(plainText.length / 4);
    }
  }

  // Highly optimized HTML plain-text extraction to avoid DOM layout overhead and browser freezes
  function extractPlainText(html: string): string {
    if (!html) return "";
    return html
      .replace(/<[^>]*>/g, "")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, '"')
      .replace(/&#x27;/g, "'")
      .replace(/&amp;/g, "&");
  }

  // Truncation notice appended to oversized files. Single source of truth so
  // char/token accounting everywhere matches getFilesPlainText exactly.
  const TRUNCATION_NOTICE = "\n\n[... The rest of the file was truncated due to its length ...]";

  function isForcedFullLoad(path: string, forcePaths: Set<string>): boolean {
    return forcePaths.has(path) || Array.from(forcePaths).some(p =>
      path.startsWith(p) && (path.charAt(p.length) === '/' || path.charAt(p.length) === '\\')
    );
  }

  // Length of a single file's section in the merged output, EXCLUDING the "\n"
  // join separator between sections. Used by every char total (bottom bar,
  // folder, single file) so they stay perfectly consistent.
  function getFileSectionCharLen(
    f: any,
    cache: Record<string, string>,
    largeFileThreshold: number,
    forcePaths: Set<string>
  ): number {
    if (f.hidden) {
      return `-------------------\n${f.path} \n-------------------\n${$t("messages.fileOmitted")}\n`.length;
    }
    // header + trailing "\n" after the content
    const headerLen = `-------------------\n${f.path} \n-------------------\n`.length + 1;
    const fileContent = cache[f.path];
    let len = fileContent !== undefined ? fileContent.length : f.char_count;
    if (
      largeFileThreshold > 0 &&
      f.char_count > largeFileThreshold &&
      !isForcedFullLoad(f.path, forcePaths) &&
      len > largeFileThreshold
    ) {
      len = largeFileThreshold + TRUNCATION_NOTICE.length;
    }
    return headerLen + len;
  }

  // Sum of section lengths + the "\n" separators joining the sections.
  function getTotalCharLen(
    fileList: any[],
    cache: Record<string, string>,
    largeFileThreshold: number,
    forcePaths: Set<string>
  ): number {
    if (fileList.length === 0) return 0;
    let sum = 0;
    for (const f of fileList) sum += getFileSectionCharLen(f, cache, largeFileThreshold, forcePaths);
    return sum + (fileList.length - 1);
  }

  // Reactive total character count (instant computation using metadata)
  $: totalCharacterCount = getTotalCharLen(files, fileContentsCache, $settings.largeFileThreshold, forceFullLoadPaths);

  // Cache for header tokens
  let headerTokensCache: Record<string, number> = {};
  function getHeaderTokens(path: string, model: string): number {
    const cacheKey = `${model}:${path}`;
    if (headerTokensCache[cacheKey] !== undefined) {
      return headerTokensCache[cacheKey];
    }
    const headerText = `-------------------\n${path} \n-------------------\n`;
    const tokens = calculateTokenCount(headerText, model) + 1; // +1 for newline join
    headerTokensCache[cacheKey] = tokens;
    return tokens;
  }

  function getFileTokenCount(
    f: any,
    cache: Record<string, string>,
    tokensCache: Record<string, number>,
    model: string,
    largeFileThreshold: number,
    forceFullLoadPaths: Set<string>
  ): number {
    if (f.hidden) {
      const headerText = `-------------------\n${f.path} \n-------------------\n${$t("messages.fileOmitted")}\n`;
      return calculateTokenCount(headerText, model);
    }

    const headerTokens = getHeaderTokens(f.path, model);

    if (tokensCache[f.path] !== undefined) {
      return headerTokens + tokensCache[f.path];
    }

    // Estimate:
    let contentLen = f.char_count;
    if (largeFileThreshold > 0 && f.char_count > largeFileThreshold && !isForcedFullLoad(f.path, forceFullLoadPaths)) {
      contentLen = largeFileThreshold + TRUNCATION_NOTICE.length;
    }
    return headerTokens + Math.round(contentLen / 4);
  }

  // Reactive total token count
  $: {
    const currentModel = $settings.tokenizerModel;
    const currentFiles = files;
    const cache = fileContentsCache;
    const tokensCache = fileTokensCache;
    const largeFileThreshold = $settings.largeFileThreshold;
    const forcePaths = forceFullLoadPaths;
    const isReady = isTokenizerReady;

    if (isReady && currentFiles.length > 0) {
      let total = 0;
      for (const f of currentFiles) {
        total += getFileTokenCount(f, cache, tokensCache, currentModel, largeFileThreshold, forcePaths);
      }
      tokenCount = total;
    } else {
      tokenCount = 0;
    }
  }

  let selectedFiles: Set<string> = new Set();
  let focusedFilePath: string | null = null;
  let fileTreeRef: any;
  let forceFullLoadPaths: Set<string> = new Set();
  let isSidebarExpanded = true;
  let sidebarWidth = 300;
  const repoUrl = "https://github.com/pierspad/textmerger";
  const releasesUrl = "https://github.com/pierspad/textmerger/releases";
  const licenseUrl = "https://github.com/pierspad/textmerger/blob/main/docs/LICENSE";
  const authorUrl = "https://pierspad.com";
  const authorIconUrl = authorAvatar;
  const appVersionNum = "v2.7.1";
  const appLicense = "GPL-3.0";
  let ipynbOutputMode: "none" | "reduced" | "full" = "none";
  let hasIpynb = false;
  let snackbarMessage = "";
  let snackbarVariant: SnackbarVariant = "success";
  let snackbarTimeout: any;
  let snackbarAnimationKey = 0;
  const snackbarDuration = 2500;
  let showSettings = false;
  let settingsActiveTab = "general";
  let highlightTokenizer = false;

  function openTokenizerSettings() {
    settingsActiveTab = "general";
    showSettings = true;
    // Trigger highlight after a short delay so the component mounts
    setTimeout(() => { highlightTokenizer = true; }, 50);
  }
  let contextMenu = { show: false, x: 0, y: 0, path: "", name: "", isFile: true };
  $: contextMenuFile = files.find(f => f.path === contextMenu.path);
  $: showTruncateOption = contextMenu.isFile && contextMenuFile && $settings.largeFileThreshold > 0 && contextMenuFile.char_count > $settings.largeFileThreshold;
  let tabContextMenu = { show: false, x: 0, y: 0, tabId: "" };
  let isLoading = false;

  // WebKitGTK (with compositing disabled) paints element scrollbars ABOVE
  // position:fixed content regardless of z-index. Workaround: make scrollbar
  // thumbs transparent while a context menu is open (no layout shift).
  $: if (typeof document !== "undefined") {
    document.body.classList.toggle("ctx-menu-open", contextMenu.show || tabContextMenu.show);
  }

  // Track the active model and active ipynb mode to know when to clear caches
  let lastCachedModel = "";
  let lastCachedIpynbMode = "";

  $: {
    const currentModel = $settings.tokenizerModel;
    const currentIpynbMode = ipynbOutputMode;
    const isReady = isTokenizerReady;

    if (isReady && (currentModel !== lastCachedModel || currentIpynbMode !== lastCachedIpynbMode)) {
      if (currentIpynbMode !== lastCachedIpynbMode) {
        // Clear all cached contents and tokens because ipynb mode changed
        fileContentsCache = {};
        fileTokensCache = {};
      } else if (currentModel !== lastCachedModel) {
        // Only clear tokens cache, keep file contents cache!
        fileTokensCache = {};
      }
      lastCachedModel = currentModel;
      lastCachedIpynbMode = currentIpynbMode;
    }
  }

  // Reactive trigger to load contents and calculate tokens for any new/missing files
  $: {
    const currentModel = $settings.tokenizerModel;
    const currentIpynbMode = ipynbOutputMode;
    const isReady = isTokenizerReady;

    if (isReady && files && files.length > 0) {
      void loadMissingFileStatsProgressively(files, currentModel, currentIpynbMode);
    }
  }

  async function loadMissingFileStatsProgressively(currentFiles: FileNode[], model: string, ipynbMode: string) {
    const batchSize = 16;
    let cacheChanged = false;
    let tokensChanged = false;

    // Filter files that actually need loading or tokenizing
    const filesToProcess = currentFiles.filter(
      f => fileContentsCache[f.path] === undefined || fileTokensCache[f.path] === undefined
    );

    for (let i = 0; i < filesToProcess.length; i += batchSize) {
      // Abort if context changed while waiting for next batch
      if ($settings.tokenizerModel !== model || ipynbOutputMode !== ipynbMode || files !== currentFiles) {
        return;
      }

      const batch = filesToProcess.slice(i, i + batchSize);
      
      await Promise.all(batch.map(async (f) => {
        const path = f.path;
        
        // 1. Load content if missing
        let content = fileContentsCache[path];
        if (content === undefined) {
          try {
            content = await invoke("get_file_content", { path, ipynbOutputMode: ipynbMode });
            fileContentsCache[path] = content;
            cacheChanged = true;
          } catch (e) {
            console.error(`Failed to fetch content for ${path}:`, e);
            fileContentsCache[path] = "";
            content = "";
            cacheChanged = true;
          }
        }

        // 2. Compute token count if missing
        if (fileTokensCache[path] === undefined) {
          fileTokensCache[path] = calculateTokenCount(content || "", model);
          tokensChanged = true;
        }
      }));

      // Trigger reactive updates
      if (cacheChanged) {
        fileContentsCache = { ...fileContentsCache };
        cacheChanged = false;
      }
      if (tokensChanged) {
        fileTokensCache = { ...fileTokensCache };
        tokensChanged = false;
      }

      // Yield to the event loop
      await new Promise(resolve => setTimeout(resolve, 5));
    }
  }

  let contextMenuStats: { chars: number, tokens: number, fileCount?: number, isLoaded: boolean } | null = null;
  let contextMenuStatsPath = "";

  // Computes the chars/tokens shown in the context-menu header. Uses the SAME
  // per-file primitives (getFileSectionCharLen / getFileTokenCount) as the
  // bottom-bar totals, so a folder's recursive count always matches the sum of
  // its files in the bottom bar. Crucially it never tokenizes the whole
  // concatenated text (BPE is not additive, so that would diverge from the sum).
  function updateContextMenuStats(
    menu: typeof contextMenu,
    currentFiles: FileNode[],
    cache: typeof fileContentsCache,
    tokensCache: typeof fileTokensCache,
    model: string,
    largeFileThreshold: number,
    forcePaths: Set<string>
  ) {
    // When the menu is closed, KEEP the last stats so reopening at the same
    // item shows the numbers instantly with no loading flash.
    if (!menu.show || !menu.path) return;

    if (menu.isFile) {
      const file = currentFiles.find(f => f.path === menu.path);
      if (!file) {
        contextMenuStats = null;
        contextMenuStatsPath = "";
        return;
      }
      contextMenuStats = {
        chars: getFileSectionCharLen(file, cache, largeFileThreshold, forcePaths),
        tokens: getFileTokenCount(file, cache, tokensCache, model, largeFileThreshold, forcePaths),
        isLoaded: file.hidden || tokensCache[file.path] !== undefined,
      };
      contextMenuStatsPath = menu.path;
    } else {
      const normFolder = normalize(menu.path);
      const folderFiles = currentFiles.filter(f => {
        const normPath = normalize(f.path);
        return normPath === normFolder || normPath.startsWith(normFolder + '/');
      });

      let tokens = 0;
      let allTokensReady = true;
      for (const f of folderFiles) {
        tokens += getFileTokenCount(f, cache, tokensCache, model, largeFileThreshold, forcePaths);
        if (!f.hidden && tokensCache[f.path] === undefined) allTokensReady = false;
      }

      contextMenuStats = {
        chars: getTotalCharLen(folderFiles, cache, largeFileThreshold, forcePaths),
        tokens,
        fileCount: folderFiles.length,
        isLoaded: allTokensReady,
      };
      contextMenuStatsPath = menu.path;
    }
  }

  $: updateContextMenuStats(
    contextMenu,
    files,
    fileContentsCache,
    fileTokensCache,
    $settings.tokenizerModel,
    $settings.largeFileThreshold,
    forceFullLoadPaths
  );

  // Clear selected files when active tab changes
  $: {
    if ($tabs.activeTabId) {
      selectedFiles = new Set();
    }
  }

  let showRenameModal = false;
  let showMergeModal = false;
  let newTabName = "";
  
  const savedSortType = localStorage.getItem('textmerger_sort_type');
  let sortType: 'original' | 'alphabetical' | 'size' = 
    (savedSortType === 'original' || savedSortType === 'alphabetical' || savedSortType === 'size') 
      ? savedSortType 
      : 'original';
      
  const savedSortAscending = localStorage.getItem('textmerger_sort_ascending');
  let sortAscending = savedSortAscending === null ? true : savedSortAscending === 'true';

  $: {
    localStorage.setItem('textmerger_sort_type', sortType);
  }
  $: {
    localStorage.setItem('textmerger_sort_ascending', String(sortAscending));
  }
  
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
  
  $: if ($tabs.tabs) {
      tick().then(checkScroll);
  }

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
  
  let draggedTabId: string | null = null;
  let dragOverTabId: string | null = null;

  $: hasIpynb = files.some((f) => {
    if (!f.path.toLowerCase().endsWith(".ipynb")) return false;
    const isTruncated = $settings.largeFileThreshold > 0 && f.char_count > $settings.largeFileThreshold && !forceFullLoadPaths.has(f.path);
    return !isTruncated;
  });
  $: snackbarStyle = snackbarPalette[snackbarVariant];
  
  $: if (files) {
      debouncedUpdateContent();
  }

  let liveSyncIntervalId: ReturnType<typeof setInterval> | undefined;

  $: {
    if (liveSyncIntervalId) {
      clearInterval(liveSyncIntervalId);
      liveSyncIntervalId = undefined;
    }
    if ($settings.liveSyncInterval > 0) {
      liveSyncIntervalId = setInterval(() => {
        if (!isLoading) {
          updateContent();
        }
      }, $settings.liveSyncInterval * 1000);
    }
  }

  onDestroy(() => {
    if (liveSyncIntervalId) {
      clearInterval(liveSyncIntervalId);
    }
  });

  onMount(() => {
    void restoreFilesForSession();
  });

  function showSnackbar(msg: string, variant: SnackbarVariant = "success") {
    snackbarMessage = msg;
    snackbarVariant = variant;
    snackbarAnimationKey += 1;
    if (snackbarTimeout) clearTimeout(snackbarTimeout);
    snackbarTimeout = setTimeout(() => {
      snackbarMessage = "";
    }, snackbarDuration);
  }

  async function updateContent() {
    try {
      if (files.length === 0) {
        mergedContent = "";
        return;
      }
      const paths = files.map((f) => f.path);
      const hiddenPaths = files.filter(f => f.hidden).map(f => f.path);
      mergedContent = await invoke("get_merged_content", {
        paths,
        hiddenPaths,
        ipynbOutputMode,
        loadFullLargeFiles: $settings.largeFileThreshold === 0,
        forceFullLoadPaths: Array.from(forceFullLoadPaths),
        largeFileThreshold: $settings.largeFileThreshold,
        hiddenPlaceholder: $t("messages.fileOmitted")
      });
    } catch (e) {
      console.error(e);
      const msg = String(e).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
      mergedContent = `<div class='error'>Error: ${msg}</div>`;
    }
  }

  let updateTimeout: any;
  function debouncedUpdateContent() {
    if (updateTimeout) clearTimeout(updateTimeout);
    updateTimeout = setTimeout(() => {
      updateContent();
    }, 10);
  }

  async function restoreFilesForSession() {
    const tabsToRestore = $tabs.tabs.map((tab) => ({
      id: tab.id,
      paths: tab.files.map((file) => file.path),
    }));

    if (tabsToRestore.every((tab) => tab.paths.length === 0)) {
      return;
    }

    isLoading = true;
    await tick();

    try {
      await Promise.all(
        tabsToRestore.map(async ({ id, paths }) => {
          if (paths.length === 0) {
            tabs.setFilesForTab(id, []);
            return;
          }

          try {
            const result = await invoke("add_files", {
              paths,
              excludedPatterns: $settings.excludedPatterns,
              hiddenPatterns: $settings.hiddenPatterns,
            });

            const { files: validFiles } = result as AddFilesResult;
            tabs.setFilesForTab(id, validFiles);
          } catch {
            tabs.setFilesForTab(id, []);
          }
        }),
      );
    } finally {
      isLoading = false;
    }
  }

  function toggleOutputs() {
    if (ipynbOutputMode === "none") ipynbOutputMode = "reduced";
    else if (ipynbOutputMode === "reduced") ipynbOutputMode = "full";
    else ipynbOutputMode = "none";
    updateContent();
  }

  function formatOutputModeText(text: string): string {
    const lastSpaceIdx = text.lastIndexOf(' ');
    if (lastSpaceIdx === -1) return text;
    return text.substring(0, lastSpaceIdx) + '\n' + text.substring(lastSpaceIdx + 1);
  }

  // Note: sortType/sortAscending only affect the sidebar tree, not the merged
  // content, so they must NOT trigger a re-merge (which re-reads files from disk).
  $: {
    if ($settings || ipynbOutputMode) {
      debouncedUpdateContent();
    }
  }

  async function addFiles(paths: string[]) {
    isLoading = true;
    await tick();
    await new Promise((resolve) => setTimeout(resolve, 50));

    try {
      const result = await invoke("add_files", {
        paths,
        excludedPatterns: $settings.excludedPatterns,
        hiddenPatterns: $settings.hiddenPatterns,
      });

      const { files: newFiles, errors } = result as AddFilesResult;
      tabs.addFilesToTab($tabs.activeTabId, newFiles);

      if (errors.length > 0) {
        const errorMsg =
          errors.slice(0, 3).join("\n") +
          (errors.length > 3 ? `\n...and ${errors.length - 3} more` : "");
        showSnackbar(
          $t("messages.filesAddedWithErrors") + " " + errorMsg,
          "warning",
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

  async function handleDrop(event: DragEvent) {
    event.preventDefault();
  }

  onMount(() => {
    let unlisten: () => void;

    const setup = async () => {
      unlisten = await getCurrentWebview().onDragDropEvent(async (event) => {
        if (event.payload.type === "drop") {
          await addFiles(event.payload.paths);
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
        const paths = Array.isArray(selected) ? selected : [selected];
        await addFiles(paths);
      }
    } catch (e) {
      console.error(e);
    }
  }

  async function removeSelected() {
    if (selectedFiles.size === 0) return;

    const filesToRemove = new Set<string>();

    for (const selectedPath of selectedFiles) {
      if (files.some(f => f.path === selectedPath)) {
        filesToRemove.add(selectedPath);
      } else {
         const normSelected = normalize(selectedPath);
         
         files.forEach(f => {
             const normPath = normalize(f.path);
             if (normPath === normSelected || normPath.startsWith(normSelected + '/')) {
                 filesToRemove.add(f.path);
             }
         });
      }
    }
    
    const remaining = files.filter(f => !filesToRemove.has(f.path));
    tabs.setFilesForTab($tabs.activeTabId, remaining);

    selectedFiles = new Set();
    showSnackbar($t("messages.selectedRemoved"));
  }

  async function removeAll() {
    tabs.setFilesForTab($tabs.activeTabId, []);
    selectedFiles = new Set();
    showSnackbar($t("messages.allRemoved"));
  }

  async function copyToClipboard() {
    try {
      const text = extractPlainText(mergedContent);

      await navigator.clipboard.writeText(text);
      showSnackbar($t("messages.copied"), "copy");
    } catch (e) {
      console.error("Failed to copy", e);
      showSnackbar($t("messages.copyFailed"), "error");
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
        // Fast regex-based extraction (same as copyToClipboard): avoids
        // building a huge DOM which can freeze the UI on large merges.
        const text = extractPlainText(mergedContent);

        await writeTextFile(path, text);
        showSnackbar($t("messages.saved"));
      }
    } catch (e) {
      console.error(e);
      showSnackbar($t("messages.saveFailed"), "error");
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
      
      // Viewport boundary check
      const menuWidth = 200;
      const menuHeight = 220;
      let x = e.clientX;
      let y = e.clientY;
      
      if (x + menuWidth > window.innerWidth) {
        x = Math.max(10, window.innerWidth - menuWidth - 10);
      }
      if (y + menuHeight > window.innerHeight) {
        y = Math.max(10, window.innerHeight - menuHeight - 10);
      }

      tabContextMenu = {
          show: true,
          x,
          y,
          tabId: id
      };
  }

  function getTabIndex(tabId: string) {
      return $tabs.tabs.findIndex(t => t.id === tabId);
  }

  function getTabsToRightCount(tabId: string) {
      const index = getTabIndex(tabId);
      return index === -1 ? 0 : Math.max(0, $tabs.tabs.length - index - 1);
  }

  function formatNumber(value: number) {
      return new Intl.NumberFormat().format(value);
  }

  function getTabTooltip(tab: { name: string; files: FileNode[] }) {
      const fileCount = tab.files.length;
      const charCount = tab.files.reduce((total, file) => total + file.char_count, 0);
      const paths = tab.files.map(file => file.path);
      const visiblePaths = paths.slice(0, 5);
      const hiddenCount = Math.max(0, paths.length - visiblePaths.length);
      const pathLines = visiblePaths.length > 0
          ? visiblePaths.map(path => `- ${path}`).join("\n")
          : "- No files";
      const moreLine = hiddenCount > 0 ? `\n- +${hiddenCount} more` : "";

      return [
          tab.name,
          `${formatNumber(fileCount)} ${fileCount === 1 ? "file" : "files"}`,
          `${formatNumber(charCount)} characters`,
          "Paths:",
          `${pathLines}${moreLine}`
      ].join("\n");
  }
  
  function openRenameModal() {
      const tab = $tabs.tabs.find(t => t.id === tabContextMenu.tabId);
      if (tab) {
          newTabName = tab.name;
          showRenameModal = true;
      }
      closeContextMenu();
  }

  function duplicateContextTab() {
      const tab = $tabs.tabs.find(t => t.id === tabContextMenu.tabId);
      if (!tab) {
          closeContextMenu();
          return;
      }

      tabs.duplicateTab(tab.id);
      showSnackbar($t("messages.duplicatedTab").replace("{name}", tab.name));
      closeContextMenu();
  }

  function closeTabsToRight() {
      const count = getTabsToRightCount(tabContextMenu.tabId);
      if (count === 0) {
          closeContextMenu();
          return;
      }

      tabs.closeTabsToRight(tabContextMenu.tabId);
      const msg = count === 1 
          ? $t("messages.closedTabToRight") 
          : $t("messages.closedTabsToRight").replace("{count}", String(count));
      showSnackbar(msg, "warning");
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
            showSnackbar($t("messages.tabsMerged"));
      }
      showMergeModal = false;
  }

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

  function activateTabByIndex(index: number) {
    const target = $tabs.tabs[index];
    if (target) {
      tabs.setActiveTab(target.id);
    }
  }

  function activateRelativeTab(direction: -1 | 1) {
    const activeIndex = $tabs.tabs.findIndex((tab) => tab.id === $tabs.activeTabId);
    if (activeIndex === -1 || $tabs.tabs.length === 0) return;

    const nextIndex = (activeIndex + direction + $tabs.tabs.length) % $tabs.tabs.length;
    activateTabByIndex(nextIndex);
  }

  function getAllTreePaths(): string[] {
    const paths = new Set<string>();
    files.forEach(f => {
      const parts = f.path.split(/[/\\]/);
      let currentPath = "";
      parts.forEach((part, i) => {
        if (!part && i === 0) {
          currentPath = "/";
          paths.add(currentPath);
          return;
        }
        if (!part) return;
        const sep = currentPath === "/" || currentPath === "" ? "" : "/";
        currentPath = (currentPath ? currentPath : "") + sep + part;
        paths.add(currentPath);
      });
    });
    return Array.from(paths);
  }

  function handleKeydown(event: KeyboardEvent) {
    if (showRenameModal || showMergeModal) return;

    const target = event.target as HTMLElement;
    const isEditing = target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable;

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

    const combo = keys.join("+").toUpperCase();
    const isShortcut = (s: string) => combo === s.toUpperCase();

    if (isShortcut($shortcuts.open)) {
      event.preventDefault();
      openFiles();
    } else if (isShortcut($shortcuts.save)) {
      event.preventDefault();
      saveFile();
    } else if (isShortcut($shortcuts.exit)) {
      event.preventDefault();
      exitApp();
    } else if (isShortcut($shortcuts.remove)) {
      event.preventDefault();
      removeSelected();
    } else if (isShortcut($shortcuts.removeAll)) {
      event.preventDefault();
      removeAll();
    } else if (isShortcut($shortcuts.copyText)) {
      event.preventDefault();
      copyToClipboard();
    } else if (isShortcut($shortcuts.refresh)) {
      event.preventDefault();
      fileContentsCache = {};
      fileTokensCache = {};
      updateContent();
      showSnackbar($t("messages.refreshed"));
    } else if (isShortcut($shortcuts.newTab)) {
      event.preventDefault();
      handleAddTab();
    } else if (isShortcut($shortcuts.closeTab)) {
      event.preventDefault();
      if ($tabs.activeTabId) {
          tabs.closeTab($tabs.activeTabId);
      }
    } else if (isShortcut($shortcuts.previousTab)) {
      event.preventDefault();
      activateRelativeTab(-1);
    } else if (isShortcut($shortcuts.nextTab)) {
      event.preventDefault();
      activateRelativeTab(1);
    } else if (isShortcut($shortcuts.copyPath)) {
      event.preventDefault();
      copyPath();
    } else if (isShortcut($shortcuts.copyFilename)) {
      event.preventDefault();
      copyFilename();
    } else if (isShortcut($shortcuts.copyFileContent)) {
      event.preventDefault();
      copyFileContent();
    } else if (isShortcut($shortcuts.copyFileContentWithHeader)) {
      event.preventDefault();
      copyFileContentWithHeader();
    } else if (isShortcut($shortcuts.copyFolderContent)) {
      event.preventDefault();
      copyFolderContent(false);
    } else if (isShortcut($shortcuts.copyFolderContentRecursive)) {
      event.preventDefault();
      copyFolderContent(true);
    } else if (isShortcut($shortcuts.toggleVisibility)) {
      event.preventDefault();
      toggleFileVisibility();
    } else if (isShortcut($shortcuts.refreshFolder)) {
      event.preventDefault();
      refreshDirectory(false);
    } else if (isShortcut($shortcuts.refreshFolderRecursive)) {
      event.preventDefault();
      refreshDirectory(true);
    } else if (isShortcut($shortcuts.revealFullContent)) {
      event.preventDefault();
      revealFullContent();
    } else if (isShortcut($shortcuts.hideDirContent)) {
      event.preventDefault();
      hideDirectoryContent();
    } else if (isShortcut($shortcuts.showDirContent)) {
      event.preventDefault();
      showDirectoryContentNonRecursive();
    } else if (isShortcut($shortcuts.showDirRecursive)) {
      event.preventDefault();
      showDirectoryContentRecursive();
    } else if (isShortcut($shortcuts.revealDirRecursive)) {
      event.preventDefault();
      revealFullContentRecursive();
    } else if (isShortcut($shortcuts.truncateDirRecursive)) {
      event.preventDefault();
      truncateDirRecursive();
    } else if (combo === "CTRL+ARROWDOWN") {
      if (!isEditing) {
        event.preventDefault();
        navigateFileTree(1);
      }
    } else if (combo === "CTRL+ARROWUP") {
      if (!isEditing) {
        event.preventDefault();
        navigateFileTree(-1);
      }
    } else if (combo === "CTRL+A") {
      if (!isEditing) {
        event.preventDefault();
        selectedFiles = new Set(getAllTreePaths());
      }
    } else if (combo === "ENTER") {
      if (!isEditing) {
        const targetPath = focusedFilePath || (selectedFiles.size === 1 ? Array.from(selectedFiles)[0] : null);
        if (targetPath) {
          event.preventDefault();
          const isFile = files.some(f => f.path === targetPath);
          if (isFile) {
            scrollToFile(targetPath);
          } else {
            if (fileTreeRef && typeof fileTreeRef.toggleNode === 'function') {
              fileTreeRef.toggleNode(targetPath);
            }
          }
        }
      }
    } else {
      const targetTabIndex = [
        $shortcuts.tab1,
        $shortcuts.tab2,
        $shortcuts.tab3,
        $shortcuts.tab4,
        $shortcuts.tab5,
        $shortcuts.tab6,
        $shortcuts.tab7,
        $shortcuts.tab8,
        $shortcuts.tab9,
      ].findIndex((shortcut) => isShortcut(shortcut));

      if (targetTabIndex !== -1) {
        event.preventDefault();
        activateTabByIndex(targetTabIndex);
      }
    }
  }

  function handleSnackbarEvent(e: CustomEvent<SnackbarEventDetail>) {
    if (typeof e.detail === "string") {
      showSnackbar(e.detail);
      return;
    }

    showSnackbar(e.detail.message, e.detail.variant || "success");
  }

  function handleContextMenu(e: CustomEvent) {
    const { event, path, name, isFile } = e.detail;
    event.preventDefault();
    
    // Viewport boundary check
    const menuWidth = 340;
    const menuHeight = isFile !== false ? 300 : 410;
    let x = event.clientX;
    let y = event.clientY;
    
    if (x + menuWidth > window.innerWidth) {
      x = Math.max(10, window.innerWidth - menuWidth - 10);
    }
    if (y + menuHeight > window.innerHeight) {
      y = Math.max(10, window.innerHeight - menuHeight - 10);
    }

    contextMenu = {
      show: true,
      x,
      y,
      path,
      name,
      isFile: isFile !== false,
    };
  }

  async function refreshDirectory(recursive: boolean) {
    const dirPath = contextMenu.path;
    if (!dirPath) return;

    isLoading = true;
    await tick();
    closeContextMenu();

    try {
      const result = await invoke("scan_directory", {
        path: dirPath,
        recursive,
        excludedPatterns: $settings.excludedPatterns,
        hiddenPatterns: $settings.hiddenPatterns,
      });

      const { files: newFiles, errors } = result as AddFilesResult;

      const activeTab = $tabs.tabs.find(t => t.id === $tabs.activeTabId);
      if (activeTab) {
          const normFolder = normalize(dirPath);

          const unchangedFiles = activeTab.files.filter(f => {
              const normPath = normalize(f.path);
              return !(normPath === normFolder || normPath.startsWith(normFolder + '/'));
          });

          const updatedFiles = [...unchangedFiles, ...newFiles];

          // Invalidate caches for updated files
          newFiles.forEach(f => {
              delete fileContentsCache[f.path];
              delete fileTokensCache[f.path];
          });
          fileContentsCache = { ...fileContentsCache };
          fileTokensCache = { ...fileTokensCache };

          tabs.setFilesForTab($tabs.activeTabId, updatedFiles);

          if (errors.length > 0) {
            const errorMsg =
              errors.slice(0, 3).join("\n") +
              (errors.length > 3 ? `\n...and ${errors.length - 3} more` : "");
            showSnackbar($t("messages.filesAddedWithErrors") + " " + errorMsg, "warning");
          } else {
            showSnackbar($t("messages.refreshed"));
          }
      }
    } catch (e) {
      console.error("Failed to refresh directory", e);
      showSnackbar($t("messages.refreshError").replace("{error}", String(e)), "error");
    } finally {
      isLoading = false;
    }
  }

  function toggleFileVisibility() {
    const targetPath = contextMenu.path;
    if (!targetPath) return;

    const activeTab = $tabs.tabs.find(t => t.id === $tabs.activeTabId);
    if (activeTab) {
      const updatedFiles = activeTab.files.map(f => {
        if (f.path === targetPath) {
          return { ...f, hidden: !f.hidden };
        }
        return f;
      });
      tabs.setFilesForTab($tabs.activeTabId, updatedFiles);
      updateContent();
    }
    closeContextMenu();
  }

  function hideDirectoryContent() {
    const dirPath = contextMenu.path;
    if (!dirPath) return;

    const activeTab = $tabs.tabs.find(t => t.id === $tabs.activeTabId);
    if (activeTab) {
      const normFolder = normalize(dirPath);

      const updatedFiles = activeTab.files.map(f => {
        const normPath = normalize(f.path);
        if (normPath === normFolder || normPath.startsWith(normFolder + '/')) {
          return { ...f, hidden: true };
        }
        return f;
      });
      tabs.setFilesForTab($tabs.activeTabId, updatedFiles);
      updateContent();
      showSnackbar($t("messages.refreshed"));
    }
    closeContextMenu();
  }

  function showDirectoryContentNonRecursive() {
    const dirPath = contextMenu.path;
    if (!dirPath) return;

    const activeTab = $tabs.tabs.find(t => t.id === $tabs.activeTabId);
    if (activeTab) {
      const normFolder = normalize(dirPath);

      const updatedFiles = activeTab.files.map(f => {
        const normPath = normalize(f.path);
        const isChild = normPath.startsWith(normFolder + '/');
        const relativePart = isChild ? normPath.substring(normFolder.length + 1) : "";
        const isDirectChild = isChild && !relativePart.includes('/');

        if (isDirectChild) {
          return { ...f, hidden: false };
        }
        return f;
      });
      tabs.setFilesForTab($tabs.activeTabId, updatedFiles);
      updateContent();
    }
    closeContextMenu();
  }

  function showDirectoryContentRecursive() {
    const dirPath = contextMenu.path;
    if (!dirPath) return;

    const activeTab = $tabs.tabs.find(t => t.id === $tabs.activeTabId);
    if (activeTab) {
      const normFolder = normalize(dirPath);

      const updatedFiles = activeTab.files.map(f => {
        const normPath = normalize(f.path);
        if (normPath === normFolder || normPath.startsWith(normFolder + '/')) {
          return { ...f, hidden: false };
        }
        return f;
      });
      tabs.setFilesForTab($tabs.activeTabId, updatedFiles);
      updateContent();
    }
    closeContextMenu();
  }

  function revealFullContentRecursive() {
    const targetPath = contextMenu.path || focusedFilePath;
    if (!targetPath) return;

    const normTarget = normalize(targetPath);
    
    const activeTab = $tabs.tabs.find(t => t.id === $tabs.activeTabId);
    if (activeTab) {
      activeTab.files.forEach(f => {
        const normPath = normalize(f.path);
        if (normPath === normTarget || normPath.startsWith(normTarget + '/')) {
          forceFullLoadPaths.add(f.path);
        }
      });
    } else {
      forceFullLoadPaths.add(targetPath);
    }
    forceFullLoadPaths = forceFullLoadPaths;
    updateContent();
    closeContextMenu();
  }

  function truncateDirRecursive() {
    const targetPath = contextMenu.path || focusedFilePath;
    if (!targetPath) return;

    const normTarget = normalize(targetPath);
    
    const activeTab = $tabs.tabs.find(t => t.id === $tabs.activeTabId);
    if (activeTab) {
      activeTab.files.forEach(f => {
        const normPath = normalize(f.path);
        if (normPath === normTarget || normPath.startsWith(normTarget + '/')) {
          forceFullLoadPaths.delete(f.path);
        }
      });
    } else {
      forceFullLoadPaths.delete(targetPath);
    }
    forceFullLoadPaths = forceFullLoadPaths;
    updateContent();
    closeContextMenu();
  }

  $: isCurrentFileHidden = files.find(f => f.path === contextMenu.path)?.hidden || false;

  function closeContextMenu() {
    contextMenu.show = false;
    tabContextMenu.show = false;
  }

  async function copyPath() {
    try {
      const target = contextMenu.path || focusedFilePath;
      if (!target) return;
      await navigator.clipboard.writeText(target);
      showSnackbar($t("messages.pathCopied"));
    } catch (e) {
      console.error(e);
    }
    closeContextMenu();
  }

  async function copyFilename() {
    try {
      const target = contextMenu.path || focusedFilePath;
      if (!target) return;
      const basename = target.split(/[/\\]/).pop() || contextMenu.name;
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
           "info",
         );
       }
     }
  }

  function navigateFileTree(direction: 1 | -1) {
      if (fileTreeRef && typeof fileTreeRef.navigate === 'function') {
          fileTreeRef.navigate(direction);
      }
  }

  function revealFullContent() {
    const targetPath = contextMenu.path || focusedFilePath;
    if (!targetPath) return;
    
    if (forceFullLoadPaths.has(targetPath)) {
        forceFullLoadPaths.delete(targetPath);
    } else {
        forceFullLoadPaths.add(targetPath);
    }
    forceFullLoadPaths = forceFullLoadPaths;
    updateContent();
    closeContextMenu();
  }

  async function copyFileContent() {
      const targetPath = contextMenu.path || focusedFilePath;
      if (!targetPath) return;

      try {
          const el = document.querySelector(`div[data-path="${CSS.escape(targetPath)}"]`);
          if (el && el.nextElementSibling) {
              const codeEl = el.nextElementSibling.querySelector('code');
              if (codeEl) {
                  await navigator.clipboard.writeText(codeEl.textContent || "");
                  showSnackbar($t("messages.copied"), "copy");
              }
          }
      } catch (e) {
          console.error(e);
          showSnackbar($t("messages.copyFailed"), "error");
      }
      closeContextMenu();
  }

  function getFilesPlainText(matchingFiles: any[]): string {
    if (!matchingFiles || matchingFiles.length === 0) return "";
    return matchingFiles.map(f => {
      const path = f.path;
      if (f.hidden) {
        return `-------------------\n${path} \n-------------------\n${$t("messages.fileOmitted")}\n`;
      }
      
      let fileContent = fileContentsCache[path] || "";
      
      if ($settings.largeFileThreshold > 0 && f.char_count > $settings.largeFileThreshold) {
        if (!isForcedFullLoad(path, forceFullLoadPaths)) {
          if (fileContent.length > $settings.largeFileThreshold) {
            fileContent = fileContent.slice(0, $settings.largeFileThreshold) + TRUNCATION_NOTICE;
          }
        }
      }
      
      return `-------------------\n${path} \n-------------------\n${fileContent}\n`;
    }).join("\n");
  }

  async function copyFileContentWithHeader() {
    const targetPath = contextMenu.path || focusedFilePath;
    if (!targetPath) return;
    const file = files.find(f => f.path === targetPath);
    if (!file) return;

    try {
      const plainText = getFilesPlainText([file]);
      await navigator.clipboard.writeText(plainText);
      showSnackbar($t("messages.copied"), "copy");
    } catch (e) {
      console.error(e);
      showSnackbar($t("messages.copyFailed"), "error");
    }
    closeContextMenu();
  }

  async function copyFolderContent(recursive: boolean) {
    const dirPath = contextMenu.path;
    if (!dirPath) return;

    try {
      const normFolder = normalize(dirPath);
      const folderFiles = files.filter(f => {
        const normPath = normalize(f.path);
        if (recursive) {
          return normPath === normFolder || normPath.startsWith(normFolder + '/');
        } else {
          if (normPath.startsWith(normFolder + '/')) {
            const relPath = normPath.slice(normFolder.length + 1);
            return !relPath.includes('/');
          }
          return false;
        }
      });

      if (folderFiles.length === 0) {
        showSnackbar($t("messages.noContent") || "No files to copy", "info");
        closeContextMenu();
        return;
      }

      const combinedText = getFilesPlainText(folderFiles);
      await navigator.clipboard.writeText(combinedText);
      showSnackbar($t("messages.copied"), "copy");
    } catch (e) {
      console.error(e);
      showSnackbar($t("messages.copyFailed"), "error");
    }
    closeContextMenu();
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
    if (target.closest('.tab-item')) return;
    e.preventDefault();
  }
</script>

<svelte:window
  on:keydown={handleKeydown}
  on:click={closeContextMenu}
  on:contextmenu={handleGlobalContextMenu}
/>

<main
  class="flex h-full w-full overflow-hidden bg-[var(--bg)] text-[var(--text)] font-sans relative z-10"
>
  {#if snackbarMessage}
    {#key snackbarAnimationKey}
      <div
        class={`fixed bottom-20 left-1/2 -translate-x-1/2 ${snackbarStyle.container} rounded-lg shadow-xl z-50 border animate-fade-in-up min-w-[240px] max-w-[min(92vw,420px)] overflow-hidden`}
        role="status"
        aria-live="polite"
      >
        <div class="px-5 py-3 flex items-center gap-3">
          <svg
            class={`w-5 h-5 ${snackbarStyle.icon} flex-shrink-0`}
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={snackbarStyle.path} />
          </svg>
          <span class="flex-1 text-sm font-medium leading-snug">{snackbarMessage}</span>
        </div>
        <div
          class={`h-1 ${snackbarStyle.progress}`}
          style="animation: textmerger-snackbar-shrink {snackbarDuration}ms linear forwards;"
        ></div>
      </div>
    {/key}
  {/if}

  {#if isLoading}
    <div
      class="fixed inset-0 bg-black/50 z-[60] flex items-center justify-center backdrop-blur-sm"
    >
      <div
        class="bg-[var(--surface)] p-6 rounded-lg shadow-xl flex flex-col items-center gap-4 border border-[var(--border-light)]"
      >
        <div
          class="w-10 h-10 border-4 border-[var(--muted)] border-t-[var(--text)] rounded-full animate-spin"
        ></div>
        <span class="text-[var(--text)] font-medium"
          >Processing files...</span
        >
      </div>
    </div>
  {/if}

  {#if showSettings}
    <Settings
      {sidebarWidth}
      bind:activeTab={settingsActiveTab}
      bind:highlightTokenizer
      on:close={() => (showSettings = false)}
      on:snackbar={handleSnackbarEvent}
    />
  {/if}
  
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
                  class="w-full px-3 py-2 bg-[var(--bg)] border border-[var(--border)] rounded focus:outline-none focus:border-blue-500 text-[var(--text)]"
                  placeholder="Enter tab name..."
                  use:focusElement
                  on:keydown={(e) => e.key === 'Enter' && confirmRename()}
              />
          </div>
      </Modal>
  {/if}

  {#if showMergeModal}
      <Modal 
          title="Merge Tabs" 
          confirmText="Merge" 
          disabled={!selectedMergeSourceId}
          on:close={() => showMergeModal = false} 
          on:confirm={confirmMerge}
      >
          <div class="flex flex-col gap-2">
              <p class="text-sm text-[var(--muted)] mb-2">
                  Select a tab to merge into <strong>{$tabs.tabs.find(t => t.id === tabContextMenu.tabId)?.name}</strong>.
              </p>
              <label for="merge-select" class="text-sm font-medium text-[var(--text-secondary)]">Source Tab</label>
              <select 
                  id="merge-select"
                  bind:value={selectedMergeSourceId}
                  class="w-full px-3 py-2 bg-[var(--bg)] border border-[var(--border)] rounded focus:outline-none focus:border-blue-500 text-[var(--text)]"
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


  {#if isSidebarExpanded}
    <aside
      class="flex flex-col border-r border-[var(--border)] bg-[var(--surface)] relative z-[1]"
      style="width: {sidebarWidth}px; min-width: 250px;"
    >
      <div
        class="h-12 px-2 border-b border-[var(--border)] bg-[var(--surface-2)] flex items-center gap-2"
      >
        <button
          class="p-2 hover:bg-[var(--bg-hover-strong)] rounded text-[var(--text-secondary)] transition-colors"
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
        class="px-3 py-2 text-xs font-semibold text-[var(--muted)] uppercase tracking-wider bg-[var(--surface)] flex items-center justify-between"
      >
        <span>{$t("app.addedFiles")} {files.length ? `(${files.length})` : ''}</span>
        
        <div class="flex items-center gap-1">
          <button
            class="bg-[var(--surface-2)] border border-[var(--border)] text-[var(--text)] rounded px-2 py-1 text-xs cursor-pointer hover:bg-[var(--bg-hover)] transition-colors select-none font-medium min-w-[80px] text-center"
            on:click={() => {
              const options = ['original', 'alphabetical', 'size'] as const;
              const idx = options.indexOf(sortType);
              sortType = options[(idx + 1) % options.length];
            }}
          >
            {sortType === 'original' ? $t('app.sortOriginal') : sortType === 'alphabetical' ? $t('app.sortAlphabetical') : $t('app.sortCharacters')}
          </button>
          <button 
            class="p-1 hover:bg-[var(--bg-hover-strong)] hover:text-[var(--text)] rounded text-[var(--muted)] transition-colors"
            on:click={() => sortAscending = !sortAscending}
            title={sortAscending ? $t("app.sortAscending") : $t("app.sortDescending")}
          >
            {#if sortAscending}
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4">
                <path stroke-linecap="round" stroke-linejoin="round" d="M3 4.5h14.25M3 9h9.75M3 13.5h5.25m5.25-4.5L16.5 5.25m0 0L20.25 9m-3.75-3.75v13.5" />
              </svg>
            {:else}
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4">
                <path stroke-linecap="round" stroke-linejoin="round" d="M3 4.5h14.25M3 9h9.75M3 13.5h5.25m5.25 4.5L16.5 21m0 0L20.25 17.25m-3.75 3.75V5.25" />
              </svg>
            {/if}
          </button>
        </div>
      </div>

      <div
        class="flex-1 overflow-y-auto p-2 relative z-[1]"
        role="list"
        on:drop={handleDrop}
        on:dragover={handleDragOver}
      >
        {#if files.length === 0}
          <div
            class="h-full flex flex-col items-center justify-center text-[var(--muted)] text-sm border border-dashed border-[var(--border-light)] rounded-lg m-2 bg-[var(--bg)]"
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
            bind:this={fileTreeRef}
            {files}
            {fileTokensCache}
            bind:selectedFiles
            bind:focusedFilePath
            {sortType}
            {sortAscending}
            {forceFullLoadPaths}
            largeFileThreshold={$settings.largeFileThreshold}
            on:contextmenu={handleContextMenu}
            on:dblclick={handleFileDblClick}
          />
        {/if}
      </div>

      <div
        class="h-[76px] px-3 border-t border-[var(--border)] bg-[var(--surface-2)] flex items-center gap-2"
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

  <section class="flex-1 flex flex-col h-full min-w-0 bg-[var(--bg)]">
    <header
      class="h-12 border-b border-[var(--border)] flex items-center px-4 justify-between bg-[var(--surface-2)]"
    >
      <div class="flex items-center gap-3 overflow-hidden flex-1 h-full pt-2">
        <button
          class="p-1 hover:bg-[var(--bg-hover-strong)] rounded text-[var(--muted)] mb-1"
          on:click={toggleSidebar}
          aria-label="Toggle Sidebar"
          title={isSidebarExpanded ? "Collapse Sidebar" : "Expand Sidebar"}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="1.5"
            stroke="currentColor"
            class="w-5 h-5"
          >
            {#if isSidebarExpanded}
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M15.75 19.5L8.25 12l7.5-7.5"
              />
            {:else}
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
              />
            {/if}
          </svg>
        </button>
        
         <div class="flex items-center flex-1 min-w-0 h-full gap-1 pt-2 relative">
            {#if showScrollButtons}
              <button 
                class="h-8 w-6 flex items-center justify-center hover:bg-[var(--bg-hover-strong)] rounded text-[var(--muted)] z-10"
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
               class="tab-item group relative flex items-center px-3 py-1.5 min-w-[120px] max-w-[200px] rounded-t-lg cursor-pointer border-t border-l border-r border-transparent transition-all duration-200 select-none
               {tab.id === $tabs.activeTabId 
                  ? 'bg-[var(--tab-bg-active)] text-[var(--text)] z-10 border-[var(--border)] border-b-0 shadow-sm' 
                  : 'bg-[var(--tab-bg-inactive)] text-[var(--muted)] hover:bg-[var(--tab-bg-hover)] border-b border-[var(--border)] opacity-80 hover:opacity-100'}"
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
               title={getTabTooltip(tab)}
            >
                
                <div class="truncate text-xs font-medium pr-5 flex-1">{tab.name}</div>
                <button 
                  class="absolute right-1 top-1/2 -translate-y-1/2 p-0.5 rounded-full hover:bg-[var(--bg-hover-strong)] hover:text-white opacity-0 group-hover:opacity-100 transition-opacity
                  {tab.id === $tabs.activeTabId ? 'opacity-100 text-[var(--muted)]' : 'text-[var(--muted)]'}"
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

            <div class="h-full flex items-center border-b border-[var(--border)] px-1 relative z-20 shrink-0">
                <button 
                   class="p-1 rounded hover:bg-[var(--bg-hover-strong)] text-[var(--muted)]"
                   on:click={handleAddTab}
                   title="New Tab"
                   aria-label="New Tab"
                 >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 5a1 1 0 011 1v3h3a1 1 0 110 2h-3v3a1 1 0 11-2 0v-3H6a1 1 0 110-2h3V6a1 1 0 011-1z" clip-rule="evenodd" />
                    </svg>
                </button>
            </div>
          
            {#if showScrollButtons}
              <button 
                class="h-8 w-6 flex items-center justify-center hover:bg-[var(--bg-hover-strong)] rounded text-[var(--muted)] z-10"
                on:click={() => scrollTabs('right')}
                aria-label="Scroll tabs right"
              >
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-4 h-4">
                    <path fill-rule="evenodd" d="M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z" clip-rule="evenodd" />
                  </svg>
              </button>
            {/if}


         </div>

      </div>
    </header>

    <div class="flex-1 relative min-h-0 flex flex-col">
      {#if hasIpynb}
        <button
          class="group absolute top-6 right-6 h-12 w-max max-w-12 hover:max-w-xs flex items-center justify-start rounded-lg p-3 backdrop-blur-md text-white transition-all duration-300 ease-in-out shadow-lg z-20 overflow-hidden cursor-pointer border
          {ipynbOutputMode === 'none' 
            ? 'bg-[#0ea5e9]/80 hover:bg-[#0ea5e9]/95 border-[#0ea5e9]/40' 
            : (ipynbOutputMode === 'reduced' 
              ? 'bg-[#f59e0b]/80 hover:bg-[#f59e0b]/95 border-[#f59e0b]/40' 
              : 'bg-[#10b981]/80 hover:bg-[#10b981]/95 border-[#10b981]/40')}"
          on:click={toggleOutputs}
        >
          <div class="flex items-center w-max gap-2.5 pr-1">
            <div class="w-6 h-6 flex items-center justify-center shrink-0">
              {#if ipynbOutputMode === 'none'}
                <!-- Closed Eye Icon (Eye Slashed) -->
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2.5" stroke="currentColor" class="w-5 h-5 opacity-90">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88" />
                </svg>
              {:else if ipynbOutputMode === 'reduced'}
                <!-- Reduced Eye Icon (contour with horizontal minus instead of pupil) -->
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2.5" stroke="currentColor" class="w-5 h-5 opacity-90">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
                  <path stroke-linecap="round" stroke-linejoin="round" d="M10 12h4" />
                </svg>
              {:else}
                <!-- Fully Open Eye Icon -->
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2.5" stroke="currentColor" class="w-5 h-5 opacity-90">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
              {/if}
            </div>
            
            <span class="flex-1 text-xs font-bold leading-tight whitespace-pre-line text-left text-white opacity-0 group-hover:opacity-100 transition-opacity duration-300">
              {#if ipynbOutputMode === 'none'}
                {formatOutputModeText($t("app.outputsHidden"))}
              {:else if ipynbOutputMode === 'reduced'}
                {formatOutputModeText($t("app.outputsReduced"))}
              {:else}
                {formatOutputModeText($t("app.outputsFull"))}
              {/if}
            </span>
          </div>
        </button>
      {/if}

      <div class="flex-1 overflow-auto p-6 bg-[var(--bg)] relative z-[1]">
        <div
          class="prose prose-invert max-w-none prose-pre:bg-[var(--surface-2)] prose-pre:border prose-pre:border-[var(--border-light)] pb-16"
        >
          {@html mergedContent ||
            `<div class="flex flex-col items-center justify-center h-64 text-[var(--muted)] italic"><span>${$t("app.noContent")}</span><span class="text-sm mt-2">${$t("app.addFilesHint")}</span></div>`}
        </div>
      </div>
    </div>

    <div
      class="h-[76px] border-t border-[var(--border)] bg-[var(--surface-2)] flex items-center px-4 justify-between"
    >
      <div class="text-xs text-[var(--muted)] flex items-center gap-2 flex-wrap select-none">
        <span>{$t("app.characters")}: {totalCharacterCount.toLocaleString()}</span>
        <span>|</span>
        <button 
          type="button" 
          class="hover:text-[var(--text)] hover:bg-[var(--bg-hover)] px-1.5 py-0.5 rounded transition-all cursor-pointer flex items-center focus:outline-none text-xs font-normal"
          on:click={openTokenizerSettings}
          title={$locale === 'it' ? 'Clicca per modificare il tokenizer nelle impostazioni' : 'Click to change the tokenizer in settings'}
        >
          {$locale === 'it' ? 'Token' : 'Tokens'}: {!isTokenizerReady ? ($locale === 'it' ? 'Caricamento...' : 'Loading...') : tokenCount.toLocaleString()}
        </button>
      </div>
      <div class="flex gap-3">
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
    class="fixed border border-[var(--border-light)] shadow-xl rounded py-1 text-sm min-w-[340px] max-w-[420px]"
    style="top: {contextMenu.y}px; left: {contextMenu.x}px; z-index: 9999999; background-color: var(--surface-2); transform: translate3d(0, 0, 9999px); will-change: transform;"
  >
    <div class="px-4 py-2 border-b border-[var(--border-light)] mb-1 select-text max-w-[420px]">
      <div class="text-xs font-bold text-[var(--muted)] truncate" title={contextMenu.path}>
        {getFormattedContextMenuTitle(contextMenu.path, compactedRoots, contextMenu.name)}
      </div>
      {#if contextMenuStats}
        <div class="mt-1.5 text-[11px] select-none w-full">
          <div class="flex items-center justify-between text-[var(--muted)] whitespace-nowrap w-full">
            <div class="flex items-center gap-1.5">
              <span>{$t("app.characters") || "Characters"}: <span class="font-mono text-[var(--text)]">{formatNumber(contextMenuStats.chars)}</span></span>
              <span>|</span>
              <span>
                {$t("app.tokens") || "Tokens"}: 
                <span class="font-mono text-[var(--text)]">
                  {#if contextMenuStats.isLoaded}
                    {formatNumber(contextMenuStats.tokens)}
                  {:else}
                    <span class="animate-pulse text-[var(--muted)]">loading...</span>
                  {/if}
                </span>
              </span>
            </div>
            {#if !contextMenu.isFile}
              <div class="flex items-center gap-1">
                <span>Files:</span>
                <span class="font-mono text-[var(--text)]">{contextMenuStats.fileCount}</span>
              </div>
            {/if}
          </div>
        </div>
      {/if}
    </div>
    <button
      class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors flex items-center gap-2"
      on:click={copyPath}
    >
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-[var(--muted)]">
        <path stroke-linecap="round" stroke-linejoin="round" d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244" />
      </svg>
      <span class="flex-1">{$t("contextMenu.copyPath")}</span>
      <span class="ml-4 text-[10px] text-[var(--muted)] tracking-wider">{$tShortcut($shortcuts.copyPath)}</span>
    </button>
    <button
      class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors flex items-center gap-2"
      on:click={copyFilename}
    >
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-[var(--muted)]">
        <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
      </svg>
      <span class="flex-1">{$t("contextMenu.copyFilename")}</span>
      <span class="ml-4 text-[10px] text-[var(--muted)] tracking-wider">{$tShortcut($shortcuts.copyFilename)}</span>
    </button>
    
    <div class="border-t border-[var(--border-light)] my-1"></div>
    
    {#if contextMenu.isFile}
      <button
        class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors flex items-center gap-2"
        on:click={copyFileContent}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-[var(--muted)]">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 01-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H6.75m9 10.5h3.375c.621 0 1.125-.504 1.125-1.125V11.25c0-4.46-3.243-8.161-7.5-8.876a9.06 9.06 0 00-1.5-.124H9.375c-.621 0-1.125.504-1.125 1.125v3.5m7.5 10.375H9.375a1.125 1.125 0 01-1.125-1.125v-9.25" />
        </svg>
        <span class="flex-1">{$t("contextMenu.copyFileContent")}</span>
        <span class="ml-4 text-[10px] text-[var(--muted)] tracking-wider">{$tShortcut($shortcuts.copyFileContent)}</span>
      </button>
      <button
        class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors flex items-center gap-2"
        on:click={copyFileContentWithHeader}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-[var(--muted)]">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 01-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H6.75m9 10.5h3.375c.621 0 1.125-.504 1.125-1.125V11.25c0-4.46-3.243-8.161-7.5-8.876a9.06 9.06 0 00-1.5-.124H9.375c-.621 0-1.125.504-1.125 1.125v3.5m7.5 10.375H9.375a1.125 1.125 0 01-1.125-1.125v-9.25" />
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 9v6m-3-3h6" />
        </svg>
        <span class="flex-1">{$t("contextMenu.copyFileContentWithHeader")}</span>
        <span class="ml-4 text-[10px] text-[var(--muted)] tracking-wider">{$tShortcut($shortcuts.copyFileContentWithHeader)}</span>
      </button>
      {#if showTruncateOption}
        <button
          class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors flex items-center gap-2"
          on:click={revealFullContent}
        >
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-[var(--muted)]">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5M9 11.25v1.5M12 9v3.75m3-6v6" />
          </svg>
          <span class="flex-1">{forceFullLoadPaths.has(contextMenu.path) ? $t("contextMenu.truncateFile") : $t("contextMenu.revealFullContent")}</span>
          <span class="ml-4 text-[10px] text-[var(--muted)] tracking-wider">{$tShortcut($shortcuts.revealFullContent)}</span>
        </button>
      {/if}
      <button
        class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors flex items-center gap-2"
        on:click={toggleFileVisibility}
      >
        {#if isCurrentFileHidden}
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-[var(--muted)]">
            <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
        {:else}
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-[var(--muted)]">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88" />
          </svg>
        {/if}
        <span class="flex-1">{isCurrentFileHidden ? $t("contextMenu.showContent") : $t("contextMenu.hideContent")}</span>
        <span class="ml-4 text-[10px] text-[var(--muted)] tracking-wider">{$tShortcut($shortcuts.toggleVisibility)}</span>
      </button>
    {:else}
      <button
        class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors flex items-center gap-2"
        on:click={() => refreshDirectory(false)}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-[var(--muted)]">
          <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182m0-4.991v4.99" />
        </svg>
        <span class="flex-1">{$t("contextMenu.refreshFolderOnly")}</span>
        <span class="ml-4 text-[10px] text-[var(--muted)] tracking-wider">{$tShortcut($shortcuts.refreshFolder)}</span>
      </button>
      <button
        class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors flex items-center gap-2"
        on:click={() => refreshDirectory(true)}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-[var(--muted)] relative">
          <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182m0-4.991v4.99" />
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 9v6m-3-3h6" />
        </svg>
        <span class="flex-1">{$t("contextMenu.refreshFolderRecursive")}</span>
        <span class="ml-4 text-[10px] text-[var(--muted)] tracking-wider">{$tShortcut($shortcuts.refreshFolderRecursive)}</span>
      </button>
      
      <div class="border-t border-[var(--border-light)] my-1"></div>
      
      <button
        class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors flex items-center gap-2"
        on:click={() => copyFolderContent(false)}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-[var(--muted)]">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 01-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H6.75m9 10.5h3.375c.621 0 1.125-.504 1.125-1.125V11.25c0-4.46-3.243-8.161-7.5-8.876a9.06 9.06 0 00-1.5-.124H9.375c-.621 0-1.125.504-1.125 1.125v3.5m7.5 10.375H9.375a1.125 1.125 0 01-1.125-1.125v-9.25" />
        </svg>
        <span class="flex-1">{$t("contextMenu.copyFolderContent")}</span>
        <span class="ml-4 text-[10px] text-[var(--muted)] tracking-wider">{$tShortcut($shortcuts.copyFolderContent)}</span>
      </button>
      <button
        class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors flex items-center gap-2"
        on:click={() => copyFolderContent(true)}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-[var(--muted)]">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 01-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H6.75m9 10.5h3.375c.621 0 1.125-.504 1.125-1.125V11.25c0-4.46-3.243-8.161-7.5-8.876a9.06 9.06 0 00-1.5-.124H9.375c-.621 0-1.125.504-1.125 1.125v3.5m7.5 10.375H9.375a1.125 1.125 0 01-1.125-1.125v-9.25" />
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 9v6m-3-3h6" />
        </svg>
        <span class="flex-1">{$t("contextMenu.copyFolderContentRecursive")}</span>
        <span class="ml-4 text-[10px] text-[var(--muted)] tracking-wider">{$tShortcut($shortcuts.copyFolderContentRecursive)}</span>
      </button>
      
      <div class="border-t border-[var(--border-light)] my-1"></div>
      
      <button
        class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors flex items-center gap-2"
        on:click={hideDirectoryContent}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-[var(--muted)]">
          <path stroke-linecap="round" stroke-linejoin="round" d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88" />
        </svg>
        <span class="flex-1">{$t("contextMenu.hideContent")}</span>
        <span class="ml-4 text-[10px] text-[var(--muted)] tracking-wider">{$tShortcut($shortcuts.hideDirContent)}</span>
      </button>
      <button
        class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors flex items-center gap-2"
        on:click={showDirectoryContentNonRecursive}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-[var(--muted)]">
          <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
          <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
        </svg>
        <span class="flex-1">{$t("contextMenu.showContent")}</span>
        <span class="ml-4 text-[10px] text-[var(--muted)] tracking-wider">{$tShortcut($shortcuts.showDirContent)}</span>
      </button>
      <button
        class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors flex items-center gap-2"
        on:click={showDirectoryContentRecursive}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-[var(--muted)]">
          <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
          <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M18 17v4m-2-2h4" />
        </svg>
        <span class="flex-1">{$t("contextMenu.showRecursive")}</span>
        <span class="ml-4 text-[10px] text-[var(--muted)] tracking-wider">{$tShortcut($shortcuts.showDirRecursive)}</span>
      </button>
      <button
        class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors flex items-center gap-2"
        on:click={revealFullContentRecursive}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-[var(--muted)]">
          <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
          <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M21 9v4m-2-2h4" />
        </svg>
        <span class="flex-1">{$t("contextMenu.revealFullContentRecursive")}</span>
        <span class="ml-4 text-[10px] text-[var(--muted)] tracking-wider">{$tShortcut($shortcuts.revealDirRecursive)}</span>
      </button>
      <button
        class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors flex items-center gap-2"
        on:click={truncateDirRecursive}
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-[var(--muted)]">
          <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
          <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M19 11h4" />
        </svg>
        <span class="flex-1">{$t("contextMenu.truncateDirRecursive")}</span>
        <span class="ml-4 text-[10px] text-[var(--muted)] tracking-wider">{$tShortcut($shortcuts.truncateDirRecursive)}</span>
      </button>
    {/if}
  </div>
{/if}

{#if tabContextMenu.show}
  <div
    class="fixed border border-[var(--border-light)] shadow-xl rounded py-1 text-sm min-w-[150px]"
    style="top: {tabContextMenu.y}px; left: {tabContextMenu.x}px; z-index: 9999999; background-color: var(--surface-2); transform: translate3d(0, 0, 9999px); will-change: transform;"
  >
    <button
      class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors"
      on:click={openRenameModal}
    >
      Rename Tab
    </button>
    <button
      class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors"
      on:click={duplicateContextTab}
    >
      Duplicate Tab
    </button>
    <button
      class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
      on:click={closeTabsToRight}
      disabled={getTabsToRightCount(tabContextMenu.tabId) === 0}
    >
      Close Tabs to the Right
    </button>
    <button
      class="w-full text-left px-4 py-2 hover:bg-[var(--bg-hover-strong)] text-[var(--text)] transition-colors"
      on:click={openMergeModal}
    >
      Merge with...
    </button>
  </div>
{/if}


