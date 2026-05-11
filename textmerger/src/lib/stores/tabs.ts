import { writable } from 'svelte/store';

export interface FileNode {
    path: string;
    name: string;
    char_count: number;
    size_bytes: number;
    extension: string;
}

export interface Tab {
    id: string;
    name: string;
    files: FileNode[];
}

export interface TabsState {
    tabs: Tab[];
    activeTabId: string;
}

const TABS_STORAGE_KEY = 'textmerger_tabs_state_v1';

function generateId() {
    return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
}

function createDuplicateName(tabs: Tab[], baseName: string) {
    const existingNames = new Set(tabs.map(tab => tab.name));
    let name = `${baseName} copy`;
    let count = 2;

    while (existingNames.has(name)) {
        name = `${baseName} copy ${count}`;
        count++;
    }

    return name;
}

function createDefaultState(): TabsState {
    const defaultTabId = generateId();
    return {
        tabs: [{ id: defaultTabId, name: 'Tab 1', files: [] }],
        activeTabId: defaultTabId
    };
}

function isValidFileNode(file: unknown): file is FileNode {
    if (!file || typeof file !== 'object') return false;
    const maybeFile = file as Partial<FileNode>;

    return (
        typeof maybeFile.path === 'string' &&
        typeof maybeFile.name === 'string' &&
        typeof maybeFile.char_count === 'number' &&
        typeof maybeFile.size_bytes === 'number' &&
        typeof maybeFile.extension === 'string'
    );
}

function loadTabsState(): TabsState {
    const fallback = createDefaultState();

    if (typeof localStorage === 'undefined') {
        return fallback;
    }

    const raw = localStorage.getItem(TABS_STORAGE_KEY);
    if (!raw) {
        return fallback;
    }

    try {
        const parsed = JSON.parse(raw) as Partial<TabsState>;
        if (!parsed || !Array.isArray(parsed.tabs)) {
            return fallback;
        }

        const safeTabs = parsed.tabs
            .filter((tab): tab is Tab => {
                if (!tab || typeof tab !== 'object') return false;
                return (
                    typeof tab.id === 'string' &&
                    tab.id.length > 0 &&
                    typeof tab.name === 'string' &&
                    Array.isArray(tab.files)
                );
            })
            .map(tab => ({
                id: tab.id,
                name: tab.name,
                files: tab.files.filter(isValidFileNode)
            }));

        if (safeTabs.length === 0) {
            return fallback;
        }

        const activeTabId =
            typeof parsed.activeTabId === 'string' && safeTabs.some(t => t.id === parsed.activeTabId)
                ? parsed.activeTabId
                : safeTabs[0].id;

        return {
            tabs: safeTabs,
            activeTabId
        };
    } catch {
        return fallback;
    }
}

function persistTabsState(state: TabsState) {
    if (typeof localStorage === 'undefined') {
        return;
    }

    try {
        localStorage.setItem(TABS_STORAGE_KEY, JSON.stringify(state));
    } catch {
        // Ignore storage write errors and keep app functional.
    }
}

function createTabsStore() {
    const { subscribe, update } = writable<TabsState>(loadTabsState());

    const withPersistence = (updater: (state: TabsState) => TabsState) => {
        update(state => {
            const next = updater(state);
            persistTabsState(next);
            return next;
        });
    };

    return {
        subscribe,
        addTab: () => withPersistence(s => {
            const id = generateId();
            const num = s.tabs.length + 1;
            const activeIndex = s.tabs.findIndex(t => t.id === s.activeTabId);
            const newTab = { id, name: `Tab ${num}`, files: [] };

            const newTabs = [...s.tabs];
            if (activeIndex !== -1) {
                newTabs.splice(activeIndex + 1, 0, newTab);
            } else {
                newTabs.push(newTab);
            }

            return {
                ...s,
                tabs: newTabs,
                activeTabId: id
            };
        }),
        closeTab: (id: string) => withPersistence(s => {
            if (s.tabs.length <= 1) return s;
            const index = s.tabs.findIndex(t => t.id === id);
            if (index === -1) return s;
            const newTabs = s.tabs.filter(t => t.id !== id);
            let newActiveId = s.activeTabId;

            if (s.activeTabId === id) {
                // Determine new active tab (previous one, or next one if first)
                const newIndex = index > 0 ? index - 1 : 0;
                newActiveId = newTabs[newIndex].id;
            }
            return { tabs: newTabs, activeTabId: newActiveId };
        }),
        duplicateTab: (id: string) => withPersistence(s => {
            const index = s.tabs.findIndex(t => t.id === id);
            if (index === -1) return s;

            const source = s.tabs[index];
            const duplicate = {
                ...source,
                id: generateId(),
                name: createDuplicateName(s.tabs, source.name),
                files: source.files.map(file => ({ ...file }))
            };
            const newTabs = [...s.tabs];
            newTabs.splice(index + 1, 0, duplicate);

            return {
                ...s,
                tabs: newTabs,
                activeTabId: duplicate.id
            };
        }),
        closeTabsToRight: (id: string) => withPersistence(s => {
            const index = s.tabs.findIndex(t => t.id === id);
            if (index === -1 || index === s.tabs.length - 1) return s;

            const newTabs = s.tabs.slice(0, index + 1);
            const activeTabId = newTabs.some(tab => tab.id === s.activeTabId)
                ? s.activeTabId
                : id;

            return {
                tabs: newTabs,
                activeTabId
            };
        }),
        setActiveTab: (id: string) => withPersistence(s => ({ ...s, activeTabId: id })),

        // Updates files for the ACTIVE tab (common use case) or specific tab
        addFilesToTab: (id: string, newFiles: FileNode[]) => withPersistence(s => {
            return {
                ...s,
                tabs: s.tabs.map(t => {
                    if (t.id === id) {
                        let newName = t.name;
                        // Auto-rename logic
                        if (t.files.length === 0 && newFiles.length > 0 && t.name.startsWith("Tab ")) {
                            // Find common prefix
                            if (newFiles.length === 1) {
                                newName = newFiles[0].name;
                            } else {
                                const splitPaths = newFiles.map(f => f.path.split(/[/\\]/));
                                // Find shortest path length
                                const minLen = Math.min(...splitPaths.map(p => p.length));
                                let commonLen = 0;
                                for (let i = 0; i < minLen; i++) {
                                    const part = splitPaths[0][i];
                                    if (splitPaths.every(p => p[i] === part)) {
                                        commonLen++;
                                    } else {
                                        break;
                                    }
                                }

                                // if commonLen > 0, we have a common path.
                                // The common path ends at index commonLen - 1.
                                // Example: /home/user/dir/file1, /home/user/dir/file2
                                // Split: ["", "home", "user", "dir", "file1"]
                                // Common: ["", "home", "user", "dir"] (len 4)
                                // Name should be "dir" -> index 3 (commonLen - 1)
                                if (commonLen > 0) {
                                    const commonPart = splitPaths[0][commonLen - 1];
                                    // If commonPart is empty (root?), grab next? NO.
                                    newName = commonPart || newFiles[0].name;
                                } else {
                                    newName = newFiles[0].name;
                                }
                            }
                        }

                        // Filter duplicates based on path
                        const existingPaths = new Set(t.files.map(f => f.path));
                        const uniqueNew = newFiles.filter(f => !existingPaths.has(f.path));
                        return { ...t, name: newName, files: [...t.files, ...uniqueNew] };
                    }
                    return t;
                })
            };
        }),

        removeFileFromTab: (id: string, path: string) => withPersistence(s => ({
            ...s,
            tabs: s.tabs.map(t => t.id === id ? { ...t, files: t.files.filter(f => f.path !== path) } : t)
        })),

        setFilesForTab: (id: string, files: FileNode[]) => withPersistence(s => ({
            ...s,
            tabs: s.tabs.map(t => t.id === id ? { ...t, files } : t)
        })),

        renameTab: (id: string, name: string) => withPersistence(s => ({
            ...s,
            tabs: s.tabs.map(t => t.id === id ? { ...t, name } : t)
        })),

        // Move the active tab left or right
        moveTab: (id: string, direction: 'left' | 'right') => withPersistence(s => {
            const index = s.tabs.findIndex(t => t.id === id);
            if (index === -1) return s;

            const newTabs = [...s.tabs];
            if (direction === 'left' && index > 0) {
                [newTabs[index - 1], newTabs[index]] = [newTabs[index], newTabs[index - 1]];
            } else if (direction === 'right' && index < newTabs.length - 1) {
                [newTabs[index + 1], newTabs[index]] = [newTabs[index], newTabs[index + 1]];
            }
            return { ...s, tabs: newTabs };
        }),

        // Merge contents of sourceId into targetId
        uniteTabs: (targetId: string, sourceId: string) => withPersistence(s => {
            const sourceTab = s.tabs.find(t => t.id === sourceId);
            if (!sourceTab) return s;

            return {
                ...s,
                tabs: s.tabs.map(t => {
                    if (t.id === targetId) {
                        const existingPaths = new Set(t.files.map(f => f.path));
                        const uniqueNew = sourceTab.files.filter(f => !existingPaths.has(f.path));
                        return { ...t, files: [...t.files, ...uniqueNew] };
                    }
                    return t;
                })
            };
        }),

        reorderTabs: (fromId: string, toId: string) => withPersistence(s => {
            const fromIndex = s.tabs.findIndex(t => t.id === fromId);
            const toIndex = s.tabs.findIndex(t => t.id === toId);
            if (fromIndex === -1 || toIndex === -1) return s;

            const newTabs = [...s.tabs];
            const [moved] = newTabs.splice(fromIndex, 1);
            newTabs.splice(toIndex, 0, moved);

            return { ...s, tabs: newTabs };
        })
    };
}

export const tabs = createTabsStore();
