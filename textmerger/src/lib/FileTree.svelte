<script lang="ts">
  import { createEventDispatcher } from "svelte";
  import FileTreeNode from "./FileTreeNode.svelte";
  import type { FileNode } from "./stores/tabs";

  export let files: FileNode[] = [];
  export let fileTokensCache: Record<string, number> = {};
  export let selectedFiles: Set<string> = new Set();
  export let focusedFilePath: string | null = null;
  export let maxCharCount = 0;
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
    tokenCount?: number;
    extension?: string;
    hidden?: boolean;
  }

  let tree: Record<string, TreeNode> = {};
  let rootNodes: string[] = [];
  let nodeMap: Record<string, TreeNode> = {};

  $: {
    updateTree(files, sortType, sortAscending, fileTokensCache);
  }

  function updateTree(currentFiles: FileNode[], currentSortType: string, currentSortAsc: boolean, currentTokensCache: Record<string, number>) {
    nodeMap = {};
    tree = {};
    rootNodes = [];
    maxCharCount = 0;

    currentFiles.forEach(f => {
        if ((f.char_count ?? 0) > maxCharCount) maxCharCount = f.char_count;
    });
    
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
        const parts = file.path.split(/[/\\]/);
        
        let parent: TreeNode | null = null;
        let currentPath = "";
        
        parts.forEach((part, i) => {
            if (!part && i === 0) {
                currentPath = "/"; 
                return;
            }
            if (!part) return;
            
            const isLast = i === parts.length - 1;
            const sep = currentPath === "/" || currentPath === "" ? "" : "/";
            const myPath = (currentPath ? currentPath : "") + sep + part;
            
            if (!parent) {
                if (!tree[myPath]) {
                    tree[myPath] = getNode(part, myPath, isLast);
                    rootNodes.push(myPath);
                }
                parent = tree[myPath];
            } else {
                if (!parent.children) parent.children = {}; 
                if (!parent.children[myPath]) {
                     parent.children[myPath] = getNode(part, myPath, isLast);
                }
                parent = parent.children[myPath];
            }
            
            if (isLast) {
                const leaf = nodeMap[myPath];
                if (leaf) {
                    leaf.charCount = file.char_count;
                    leaf.sizeBytes = file.size_bytes;
                    leaf.extension = file.extension;
                    leaf.path = file.path;
                    leaf.hidden = file.hidden;
                    leaf.tokenCount = currentTokensCache[file.path];
                }
            }
            
            currentPath = myPath;
        });
    });

    // Recursively aggregate statistics (post-order traversal)
    const aggregateStats = (node: TreeNode): { charCount: number; sizeBytes: number; tokenCount: number } => {
        if (node.isFile) {
            return {
                charCount: node.charCount || 0,
                sizeBytes: node.sizeBytes || 0,
                tokenCount: node.tokenCount || 0
            };
        }

        let charSum = 0;
        let sizeSum = 0;
        let tokenSum = 0;

        if (node.children) {
            Object.values(node.children).forEach(child => {
                const stats = aggregateStats(child);
                charSum += stats.charCount;
                sizeSum += stats.sizeBytes;
                tokenSum += stats.tokenCount;
            });
        }

        node.charCount = charSum;
        node.sizeBytes = sizeSum;
        node.tokenCount = tokenSum;

        return { charCount: charSum, sizeBytes: sizeSum, tokenCount: tokenSum };
    };

    // Run aggregation for all root nodes
    rootNodes.forEach(key => {
        if (tree[key]) {
            aggregateStats(tree[key]);
        }
    });

    const compactNode = (node: TreeNode) => {
        if (!node.children || node.isFile) return;
        
        Object.values(node.children).forEach(compactNode);
        
        const childrenKeys = Object.keys(node.children);
        if (childrenKeys.length === 1) {
             const childKey = childrenKeys[0];
             const child = node.children[childKey];
             if (!child.isFile) {
                  node.name = `${node.name}/${child.name}`;
                  node.path = child.path; 
                  node.children = child.children;
                  
                  compactNode(node);
             }
        }
    };
    
    [...rootNodes].forEach(key => {
        compactNode(tree[key]);
    });
    
    rootNodes.sort((aPath, bPath) => {
         const a = tree[aPath];
         const b = tree[bPath];
         if (!a || !b) return 0;
         
         if (a.isFile === b.isFile) {
             if (currentSortType === 'alphabetical') {
                 return currentSortAsc ? a.name.localeCompare(b.name) : b.name.localeCompare(a.name);
             } else if (currentSortType === 'size') {
                 const aSize = a.sizeBytes || a.charCount || 0;
                 const bSize = b.sizeBytes || b.charCount || 0;
                 return currentSortAsc ? aSize - bSize : bSize - aSize;
             }
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

  let lastSelectedPath: string | null = null;

  function getVisiblePaths(): string[] {
      const paths: string[] = [];
      
      const traverse = (nodes: any[]) => {
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
      
      if (e.shiftKey) {
        window.getSelection()?.removeAllRanges();
      }

      if (e.shiftKey && lastSelectedPath) {
          const visiblePaths = getVisiblePaths();
          const startIdx = visiblePaths.indexOf(lastSelectedPath);
          const endIdx = visiblePaths.indexOf(path);
          
          if (startIdx !== -1 && endIdx !== -1) {
              const start = Math.min(startIdx, endIdx);
              const end = Math.max(startIdx, endIdx);
              
              const range = visiblePaths.slice(start, end + 1);
              
              if (!e.ctrlKey && !e.metaKey) {
                   selectedFiles.clear();
              }
              
              range.forEach(p => selectedFiles.add(p));
          }
      } else if (e.ctrlKey || e.metaKey) {
          if (selectedFiles.has(path)) {
              selectedFiles.delete(path);
              lastSelectedPath = path; 
          } else {
              selectedFiles.add(path);
              lastSelectedPath = path;
          }
      } else {
          selectedFiles.clear();
          selectedFiles.add(path);
          lastSelectedPath = path;
      }
      
      selectedFiles = selectedFiles;
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
