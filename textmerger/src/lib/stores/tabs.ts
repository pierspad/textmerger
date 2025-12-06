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

function generateId() {
    return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
}

function createTabsStore() {
    const defaultTabId = generateId();
    const { subscribe, set, update } = writable<TabsState>({
        tabs: [{ id: defaultTabId, name: 'Tab 1', files: [] }],
        activeTabId: defaultTabId
    });

    return {
        subscribe,
        addTab: () => update(s => {
            const id = generateId();
            const num = s.tabs.length + 1;
            return {
                ...s,
                tabs: [...s.tabs, { id, name: `Tab ${num}`, files: [] }],
                activeTabId: id
            };
        }),
        closeTab: (id: string) => update(s => {
            if (s.tabs.length <= 1) return s;
            const index = s.tabs.findIndex(t => t.id === id);
            const newTabs = s.tabs.filter(t => t.id !== id);
            let newActiveId = s.activeTabId;

            if (s.activeTabId === id) {
                // Determine new active tab (previous one, or next one if first)
                const newIndex = index > 0 ? index - 1 : 0;
                newActiveId = newTabs[newIndex].id;
            }
            return { tabs: newTabs, activeTabId: newActiveId };
        }),
        setActiveTab: (id: string) => update(s => ({ ...s, activeTabId: id })),

        // Updates files for the ACTIVE tab (common use case) or specific tab
        addFilesToTab: (id: string, newFiles: FileNode[]) => update(s => {
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

        removeFileFromTab: (id: string, path: string) => update(s => ({
            ...s,
            tabs: s.tabs.map(t => t.id === id ? { ...t, files: t.files.filter(f => f.path !== path) } : t)
        })),

        setFilesForTab: (id: string, files: FileNode[]) => update(s => ({
            ...s,
            tabs: s.tabs.map(t => t.id === id ? { ...t, files } : t)
        })),

        renameTab: (id: string, name: string) => update(s => ({
            ...s,
            tabs: s.tabs.map(t => t.id === id ? { ...t, name } : t)
        })),

        // Move the active tab left or right
        moveTab: (id: string, direction: 'left' | 'right') => update(s => {
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
        uniteTabs: (targetId: string, sourceId: string) => update(s => {
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

        reorderTabs: (fromId: string, toId: string) => update(s => {
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
