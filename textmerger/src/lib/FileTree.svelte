<script lang="ts">
  import { createEventDispatcher } from "svelte";
  import FileTreeNode from "./FileTreeNode.svelte";

  import type { FileNode } from "./stores/tabs";
  export let files: FileNode[] = [];
  export let selectedFiles: Set<string> = new Set();

  const dispatch = createEventDispatcher();

  interface TreeNode {
    name: string;
    path: string;
    children: Record<string, TreeNode>;
    isFile: boolean;
    isOpen: boolean;
    charCount?: number;
  }

  let tree: TreeNode = {
    name: "root",
    path: "",
    children: {},
    isFile: false,
    isOpen: true,
  };

  $: {
    tree = {
      name: "root",
      path: "",
      children: {},
      isFile: false,
      isOpen: true,
    };
    // Sort files to ensure consistent tree building
    [...files].sort((a, b) => a.path.localeCompare(b.path)).forEach((file) => {
      const path = file.path;
      // Handle Windows/Unix paths
      const normalizedPath = path.replace(/\\/g, "/");
      const parts = normalizedPath.split("/");

      let current = tree;
      let currentPath = "";

      parts.forEach((part, index) => {
        if (!part) return; // Skip empty parts
        
        // Update current path for this level
        // If it's the first part, it's just part (or /part if absolute? paths are usually absolute)
        // But here we are splitting by /. If path starts with /, first part is empty.
        // Let's assume paths are absolute.
        // If I split "/home/user", parts are ["", "home", "user"].
        // index 0 is "".
        
        if (currentPath === "") {
            currentPath = part; // If path was empty, now it's part (e.g. "C:" or just "home" if relative)
            // If the original path started with /, then parts[0] is empty.
            // If parts[0] is empty, currentPath stays empty?
            // Let's handle the separator.
        } else {
            currentPath += "/" + part;
        }
        
        // If the original path started with /, we might miss the leading /.
        // But `path` variable holds the full string.
        // Let's rely on the fact that we are traversing.
        // Actually, for the folder path, we can just use the part of the string.
        // But `parts` logic is a bit fragile for reconstruction.
        // Better: `currentPath` logic needs to be robust.
        // If `normalizedPath` starts with `/`, `parts[0]` is empty.
        // If I just join parts up to index, I get the path.
        
        const nodePath = parts.slice(0, index + 1).join("/");

        if (!current.children[part]) {
          current.children[part] = {
            name: part,
            path: nodePath, // Assign correct folder path
            children: {},
            isFile: false,
            isOpen: true,
          };
        }

        if (index === parts.length - 1) {
          current.children[part].isFile = true;
          current.children[part].path = path; // Use original full path for file to be safe
          current.children[part].charCount = file.char_count;
        }

        current = current.children[part];
      });
    });

    // Compress tree: merge single-child directories
    compressTree(tree);
    tree = tree; // Trigger update
  }

  function compressTree(node: TreeNode) {
    // Compress children first
    for (const child of Object.values(node.children)) {
      compressTree(child);
    }

    // Now check if we can compress this node with its single child
    // We don't compress the root
    if (node.name === "root") return;

    // While this node has exactly one child and that child is a directory
    while (Object.keys(node.children).length === 1) {
      const childKey = Object.keys(node.children)[0];
      const child = node.children[childKey];

      if (child.isFile) break;

      // Merge
      node.name = `${node.name}/${child.name}`;
      node.path = child.path; // Update path to the child's path (which is the deeper folder)
      node.children = child.children;
    }
  }

  function handleSelect(event: CustomEvent) {
    const { path, event: mouseEvent } = event.detail;

    if (mouseEvent.ctrlKey || mouseEvent.metaKey) {
      if (selectedFiles.has(path)) {
        selectedFiles.delete(path);
      } else {
        selectedFiles.add(path);
      }
    } else {
      // If clicking an already selected item (and it's the only one), deselect it.
      // If multiple are selected and we click one of them, usually we select just that one.
      // But user asked: "se clicco su un elemento selezionato deve ritornare normale e deve deselezionarsi"
      const wasSelected = selectedFiles.has(path);
      selectedFiles.clear();
      if (!wasSelected) {
        selectedFiles.add(path);
      }
    }
    selectedFiles = selectedFiles; // Trigger reactivity
    dispatch("select", selectedFiles);
  }

  function handleToggle(event: CustomEvent) {
    // Tree update is handled by object reference in Svelte
    tree = tree;
  }
  
  function handleDblClick(event: CustomEvent) {
      dispatch("dblclick", event.detail);
  }
</script>

<div class="select-none text-sm overflow-x-hidden">
  {#each Object.values(tree.children).sort((a, b) => {
    if (a.isFile === b.isFile) return a.name.localeCompare(b.name);
    return a.isFile ? 1 : -1;
  }) as node}
    <FileTreeNode
      {node}
      {selectedFiles}
      on:select={handleSelect}
      on:toggle={handleToggle}
      on:contextmenu
      on:dblclick={handleDblClick}
    />
  {/each}
</div>
