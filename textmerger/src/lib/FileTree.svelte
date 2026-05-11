<script lang="ts">
  import { createEventDispatcher } from "svelte";
  import FileTreeNode from "./FileTreeNode.svelte";
  import type { FileNode } from "./stores/tabs";

  export let files: FileNode[] = [];
  export let selectedFiles: Set<string> = new Set();
  export let focusedFilePath: string | null = null;
  export let maxCharCount = 0; // Exported to be bindable if needed, but primarily read-only
  export let sortType: 'original' | 'alphabetical' | 'size' = 'original';
  export let sortAscending = true;
  export let forceFullLoadPaths: Set<string> = new Set();
  export let largeFileThreshold = 20000;
  
  const dispatch = createEventDispatcher();
  
  interface TreeNode {
    name: string;
    path: string;
    children?: Record<string, TreeNode>;
    isFile: boolean;
    isOpen?: boolean;
    charCount?: number;
    sizeBytes?: number;
    extension?: string;
    hidden?: boolean;
  }

  // Build tree from flat list of files
  // Also calculate maxCharCount for relative coloring
  let tree: Record<string, TreeNode> = {};
  let rootNodes: string[] = [];
  let nodeMap: Record<string, TreeNode> = {};

  $: {
    updateTree(files, sortType, sortAscending);
  }

  function updateTree(currentFiles: FileNode[], currentSortType: string, currentSortAsc: boolean) {
    // Reset
    nodeMap = {};
    tree = {};
    rootNodes = [];
    maxCharCount = 0;

    // First pass to find maxCharCount
    currentFiles.forEach(f => {
        if ((f.char_count ?? 0) > maxCharCount) maxCharCount = f.char_count;
    });
    
    // Helper to get or create node
    const getNode = (name: string, path: string, isFile: boolean): TreeNode => {
        if (!nodeMap[path]) {
            nodeMap[path] = {
                name,
                path,
                isFile,
                children: {},
                isOpen: true
            };
        }
        return nodeMap[path];
    };

    [...currentFiles].sort((a, b) => a.path.localeCompare(b.path)).forEach((file) => {
        // Normalize
        const parts = file.path.split(/[/\\]/);
        
        let parent: TreeNode | null = null;
        let currentPath = "";
        
        parts.forEach((part, i) => {
            if (!part && i === 0) {
                // Root slash handling
                currentPath = "/"; 
                return;
            }
            if (!part) return;
            
            const isLast = i === parts.length - 1;
            // append to currentPath logic 
            const sep = currentPath === "/" || currentPath === "" ? "" : "/";
            const myPath = (currentPath ? currentPath : "") + sep + part;
            
            // Checking if we are treating this as a top level
            if (!parent) {
                // Top level node
                if (!tree[myPath]) {
                    tree[myPath] = getNode(part, myPath, isLast);
                    rootNodes.push(myPath);
                }
                parent = tree[myPath];
            } else {
                // Child node
                if (!parent.children) parent.children = {}; 
                if (!parent.children[myPath]) {
                     parent.children[myPath] = getNode(part, myPath, isLast);
                }
                parent = parent.children[myPath];
            }
            
            if (isLast) {
                // Add metadata to the file node
                const leaf = nodeMap[myPath];
                if (leaf) {
                    leaf.charCount = file.char_count;
                    leaf.sizeBytes = file.size_bytes;
                    leaf.extension = file.extension;
                    leaf.path = file.path; // Preserve original exact path string
                    leaf.hidden = file.hidden;
                }
            }
            
            currentPath = myPath;
        });
    });

    // Compact folders (flatten single directory chains)
    const compactNode = (node: TreeNode) => {
        if (!node.children || node.isFile) return;
        
        // Compact children first (bottom-up recursion)
        Object.values(node.children).forEach(compactNode);
        
        // Check if I have exactly one child and it is a folder (not a file)
        const childrenKeys = Object.keys(node.children);
        if (childrenKeys.length === 1) {
             const childKey = childrenKeys[0];
             const child = node.children[childKey];
             // Ensure child is not a file and we are not losing info?
             // Users want to see "home/user/code" 
             if (!child.isFile) {
                 // Merge child into current node
                 node.name = `${node.name}/${child.name}`;
                 // We don't change the KEY in the parent's children map because the parent points to US (node object ref).
                 // We just mutate US.
                 // Update our path to match the child's path (more specific)
                 node.path = child.path; 
                 // Adopt grandchildren
                 node.children = child.children;
                 
                 // Re-run compaction on self because we might now be a single child of our new self?
                 // No, we consumed a child. We might now have 1 grandchild that is strict.
                 compactNode(node);
             }
        }
    };
    
    // Run compaction on root nodes
    // Using a copy of keys because we might modify tree if we were re-assigning, 
    // but here we are modifying the objects in place.
    [...rootNodes].forEach(key => {
        // If the root node itself gets compacted? 
        // Example: root is "home", child "user". "home" becomes "home/user". 
        // The tree[key] object is mutated.
        // references in tree are strictly object refs.
        compactNode(tree[key]);
    });
    
    // Sort rootNodes to match getSortedChildren logic (Folders first, then Files)
    rootNodes.sort((aPath, bPath) => {
         const a = tree[aPath];
         const b = tree[bPath];
         // Safe check if nodes exist (should exist)
         if (!a || !b) return 0;
         
         if (a.isFile === b.isFile) {
             if (currentSortType === 'alphabetical') {
                 return currentSortAsc ? a.name.localeCompare(b.name) : b.name.localeCompare(a.name);
             } else if (currentSortType === 'size') {
                 const aSize = a.sizeBytes || a.charCount || 0;
                 const bSize = b.sizeBytes || b.charCount || 0;
                 return currentSortAsc ? aSize - bSize : bSize - aSize;
             }
             // Original
             return a.name.localeCompare(b.name);
         }
         return a.isFile ? 1 : -1;
    });
  }

  function handleDblClick(event: CustomEvent) {
      dispatch("dblclick", event.detail);
  }

  function handleContextMenu(event: CustomEvent) {
      dispatch("contextmenu", event.detail);
  }

  // --- Selection Logic ---
  let lastSelectedPath: string | null = null;

  // Flatten the visible tree into a list of paths
  function getVisiblePaths(): string[] {
      const paths: string[] = [];
      
      // We traverse using Node objects directly because 'tree' only contains roots
      const traverse = (nodes: any[]) => {
          // Sort nodes to match visual display
          const sortedNodes = [...nodes].sort((a, b) => {
             if (a.isFile === b.isFile) {
                 if (sortType === 'alphabetical') {
                     return sortAscending ? a.name.localeCompare(b.name) : b.name.localeCompare(a.name);
                 } else if (sortType === 'size') {
                     const aSize = a.sizeBytes || a.charCount || 0;
                     const bSize = b.sizeBytes || b.charCount || 0;
                     return sortAscending ? aSize - bSize : bSize - aSize;
                 }
                 return a.name.localeCompare(b.name);
             }
             return a.isFile ? 1 : -1;
          });

          for (const node of sortedNodes) {
              paths.push(node.path);
              
              // If folder and open, recurse
              if (!node.isFile && node.isOpen && node.children) {
                   traverse(Object.values(node.children));
              }
          }
      };

      const roots = rootNodes.map(key => tree[key]).filter(n => !!n);
      traverse(roots);
      return paths;
  }

  function handleSelect(event: CustomEvent) {
      const { path, event: originalEvent } = event.detail;
      const e = originalEvent as MouseEvent;
      
      focusedFilePath = path;
      
      // Prevent text selection
      if (e.shiftKey) {
        window.getSelection()?.removeAllRanges();
      }

      if (e.shiftKey && lastSelectedPath) {
          // Range selection
          const visiblePaths = getVisiblePaths();
          const startIdx = visiblePaths.indexOf(lastSelectedPath);
          const endIdx = visiblePaths.indexOf(path);
          
          if (startIdx !== -1 && endIdx !== -1) {
              const start = Math.min(startIdx, endIdx);
              const end = Math.max(startIdx, endIdx);
              
              const range = visiblePaths.slice(start, end + 1);
              
              // If ctrl is NOT pressed, clear previous unless we are adding to a set?
              // Standard behavior: Shift+Click extends selection from anchor.
              // Usually it clears everything else unless Ctrl is also held?
              // Let's implement robust: Shift+Click selects range. 
              // If Ctrl is NOT held, we should technically clear outside range, but keeping it additive is often friendlier or we just add the range.
              // User asked for "cliccare selezionarne di più" (ctrl) and "shift + click per porzione continua".
              
              if (!e.ctrlKey && !e.metaKey) {
                   selectedFiles.clear();
              }
              
              range.forEach(p => selectedFiles.add(p));
          }
      } else if (e.ctrlKey || e.metaKey) {
          // Toggle selection
          if (selectedFiles.has(path)) {
              selectedFiles.delete(path);
              // Update last selected to null? No, keep it or move it? 
              // Usually anchor doesn't change on deselect, but on select it does.
              lastSelectedPath = path; 
          } else {
              selectedFiles.add(path);
              lastSelectedPath = path;
          }
      } else {
          // Single select
          selectedFiles.clear();
          selectedFiles.add(path);
          lastSelectedPath = path;
      }
      
      selectedFiles = selectedFiles; // Trigger reactivity
  }

  export function navigate(direction: 1 | -1) {
      const visiblePaths = getVisiblePaths();
      if (visiblePaths.length === 0) return;
      
      let nextPath = visiblePaths[0];
      if (focusedFilePath) {
          const currentIndex = visiblePaths.indexOf(focusedFilePath);
          if (currentIndex !== -1) {
              let nextIndex = currentIndex + direction;
              if (nextIndex < 0) nextIndex = 0;
              if (nextIndex >= visiblePaths.length) nextIndex = visiblePaths.length - 1;
              nextPath = visiblePaths[nextIndex];
          }
      } else if (selectedFiles.size === 1) {
          const currentSelected = Array.from(selectedFiles)[0];
          const currentIndex = visiblePaths.indexOf(currentSelected);
          if (currentIndex !== -1) {
              let nextIndex = currentIndex + direction;
              if (nextIndex < 0) nextIndex = 0;
              if (nextIndex >= visiblePaths.length) nextIndex = visiblePaths.length - 1;
              nextPath = visiblePaths[nextIndex];
          }
      }
      
      focusedFilePath = nextPath;
      
      if (selectedFiles.size <= 1) {
          selectedFiles.clear();
          selectedFiles.add(nextPath);
          selectedFiles = selectedFiles;
      }
      
      // Scroll to element
      setTimeout(() => {
          const treeNode = document.querySelector(`[data-filepath="${CSS.escape(nextPath)}"]`);
          if (treeNode) {
              treeNode.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
          }
      }, 0);
  }

  export function toggleNode(path: string) {
      const node = nodeMap[path];
      if (node && !node.isFile) {
          node.isOpen = !node.isOpen;
          // Force update tree reactivity
          tree = tree;
          return true;
      }
      return false;
  }
</script>

<div class="select-none text-sm overflow-x-hidden">
  {#each rootNodes as nodeId (nodeId)}
    <FileTreeNode 
       node={tree[nodeId]} 
       tree={tree} 
       bind:selectedFiles 
       {focusedFilePath}
       {sortType}
       {sortAscending}
       on:contextmenu={handleContextMenu}
       on:dblclick={handleDblClick}
       on:select={handleSelect}
       maxCharCount={maxCharCount}
       forceFullLoadPaths={forceFullLoadPaths}
       largeFileThreshold={largeFileThreshold}
    />
  {/each}
</div>
