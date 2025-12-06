<script lang="ts">
  import { createEventDispatcher } from "svelte";
  import FileTreeNode from "./FileTreeNode.svelte";
  import type { FileNode } from "./stores/tabs";

  export let files: FileNode[] = [];
  export let selectedFiles: Set<string> = new Set();
  export let maxCharCount = 0; // Exported to be bindable if needed, but primarily read-only
  
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
  }

  // Build tree from flat list of files
  // Also calculate maxCharCount for relative coloring
  let tree: Record<string, TreeNode> = {};
  let rootNodes: string[] = [];

  $: {
    updateTree(files);
  }

  function updateTree(currentFiles: FileNode[]) {
    // Map of path -> Node
    const nodeMap: Record<string, TreeNode> = {};
    
    // Reset
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
                // Handle root path if it starts with slash (linux)
                currentPath = ""; 
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
                // Note: getNode creates it if missing, but we need to ensure we update the specific node for this file
                // If it was created as a folder earlier (unlikely if loop order is correct, but possible), update it.
                // The sort ensures folders usually come before files if structure implies it? No.
                // But we are on the leaf now.
                const leaf = nodeMap[myPath];
                if (leaf) {
                    leaf.charCount = file.char_count;
                    leaf.sizeBytes = file.size_bytes;
                    leaf.extension = file.extension;
                    leaf.path = file.path; // Preserve original exact path string
                }
            }
            
            currentPath = myPath;
        });
    });
  }

  function handleDblClick(event: CustomEvent) {
      dispatch("dblclick", event.detail);
  }

  function handleContextMenu(event: CustomEvent) {
      dispatch("contextmenu", event.detail);
  }
</script>

<div class="select-none text-sm overflow-x-hidden">
  {#each rootNodes as nodeId (nodeId)}
    <FileTreeNode 
       node={tree[nodeId]} 
       tree={tree} 
       bind:selectedFiles 
       on:contextmenu={handleContextMenu}
       on:dblclick={handleDblClick}
       maxCharCount={maxCharCount}
    />
  {/each}
</div>
