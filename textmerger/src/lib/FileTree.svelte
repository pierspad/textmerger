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
                // Root slash handling
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
