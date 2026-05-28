<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { slide } from 'svelte/transition';
  import FileIcon from './components/FileIcon.svelte';

  export let node: any;
  export let tree: any;
  export let selectedFiles: Set<string>;
  export let focusedFilePath: string | null = null;
  export let depth = 0;
  export let maxCharCount = 0;
  export let largeFileThreshold = 20000;
  export let forceFullLoadPaths: Set<string> = new Set();
  export let sortType: 'original' | 'alphabetical' | 'size' = 'original';
  export let sortAscending = true;

  const dispatch = createEventDispatcher();

  function toggle() {
    if (!node.isFile) {
      node.isOpen = !node.isOpen;
      node = node;
      dispatch('toggle', node);
    }
  }

  function select(event: MouseEvent | KeyboardEvent) {
      dispatch('select', { path: node.path, event });
  }

  function handleDblClick(event: MouseEvent) {
      if (node.isFile) {
          dispatch('dblclick', { path: node.path, event });
      } else {
          toggle();
      }
  }

  function handleContextMenu(event: MouseEvent) {
      dispatch('contextmenu', { path: node.path, name: node.name, isFile: node.isFile, event });
  }

  function getHeavinessColor(charCount: number): string {
      if (!maxCharCount) return '#22c55e';
      
      const ratio = charCount / maxCharCount;
      
      if (ratio < 0.25) return '#22c55e';
      if (ratio < 0.50) return '#eab308';
      if (ratio < 0.75) return '#f97316';
      return '#ef4444';
  }

  function getSortedChildren(children: any): any[] {
     if (!children) return [];
     return Object.values(children).sort((a: any, b: any) => {
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
  }

  function isNodeHidden(n: any): boolean {
    if (n.isFile) {
      return n.hidden === true;
    }
    if (n.children && Object.keys(n.children).length > 0) {
      return Object.values(n.children).every(c => isNodeHidden(c));
    }
    return false;
  }
</script>

<div>
  <div 
    class="flex items-center py-1 px-2 hover:bg-[var(--bg-hover)] cursor-pointer {selectedFiles.has(node.path) ? 'bg-[#374151]' : ''} {focusedFilePath === node.path ? 'outline outline-1 outline-[#0e639c]' : ''}"
    class:opacity-40={isNodeHidden(node)}
    style="padding-left: {depth * 12 + 4}px"
    role="button"
    tabindex="0"
    data-filepath={node.path}
    on:click={select}
    on:dblclick={handleDblClick}
    on:contextmenu={handleContextMenu}
    on:keydown={(e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        select(e);
      }
    }}
  >
    <span class="mr-2 relative flex items-center shrink-0" on:click|stopPropagation={toggle} role="button" tabindex="0" on:keydown={() => {}}>
      <FileIcon name={node.name} isFile={node.isFile} isOpen={node.isOpen} />
      {#if isNodeHidden(node)}
        <div class="absolute inset-0 flex items-center justify-center opacity-40 pointer-events-none text-white drop-shadow-md">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2.5" stroke="currentColor" class="w-5 h-5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88" />
          </svg>
        </div>
      {/if}
    </span>
    <span class="truncate text-[var(--text-secondary)] flex-1 pr-5" style="mask-image: linear-gradient(to right, black calc(100% - 16px), transparent 100%); -webkit-mask-image: linear-gradient(to right, black calc(100% - 16px), transparent 100%);">{node.name}</span>
    {#if node.isFile && typeof node.charCount === 'number'}
      <div 
        class="w-2.5 h-2.5 rounded-full ml-auto mr-1 flex-shrink-0 transition-colors duration-300" 
        style="background-color: {node.charCount > largeFileThreshold && !forceFullLoadPaths.has(node.path) ? '#a855f7' : getHeavinessColor(node.charCount)}"
      ></div>
    {/if}
  </div>

  {#if !node.isFile && node.isOpen && node.children}
    <div transition:slide|local={{ duration: 200 }}>
      {#each getSortedChildren(node.children) as child (child.path)}
        <svelte:self 
          node={child} 
          tree={tree} 
          bind:selectedFiles 
          {focusedFilePath}
          depth={depth + 1} 
          on:toggle 
          on:select 
          on:contextmenu 
          on:dblclick 
          maxCharCount={maxCharCount}
          largeFileThreshold={largeFileThreshold}
          forceFullLoadPaths={forceFullLoadPaths}
          sortType={sortType}
          sortAscending={sortAscending}
        />
      {/each}
    </div>
  {/if}
</div>
