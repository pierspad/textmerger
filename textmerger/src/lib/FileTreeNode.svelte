<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { slide } from 'svelte/transition';

  export let node: any;
  export let selectedFiles: Set<string>;
  export let depth: number = 0;

  const dispatch = createEventDispatcher();

  function toggle() {
    if (!node.isFile) {
      node.isOpen = !node.isOpen;
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
      // Allow context menu on folders too? User said "rendi selezionabili anche le cartelle (sia per il discorso di copiare nome cartella/path assoluto...)"
      // So yes, context menu on folders too.
      dispatch('contextmenu', { path: node.path, name: node.name, event });
  }

  function getIcon(name: string, isFile: boolean, isOpen: boolean) {
    if (!isFile) {
      return isOpen ? 
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#fbbf24" class="w-5 h-5"><path d="M20 6h-8l-2-2H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2z"/></svg>' : 
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#fbbf24" class="w-5 h-5"><path d="M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"/></svg>';
    }
    
    const ext = name.split('.').pop()?.toLowerCase();
    let color = 'var(--text-muted)'; // default gray
    if (ext === 'py') color = '#3b82f6';
    if (ext === 'rs') color = '#ef4444';
    if (ext === 'js' || ext === 'ts') color = '#f59e0b';
    if (ext === 'html') color = '#ea580c';
    if (ext === 'css') color = '#3b82f6';
    if (ext === 'json') color = '#f59e0b';
    if (ext === 'md') color = '#ec4899';
    
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="${color}" class="w-4 h-4"><path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z"/></svg>`;
  }

  function sortChildren(children: any) {
    return Object.values(children).sort((a: any, b: any) => {
        if (a.isFile === b.isFile) return a.name.localeCompare(b.name);
        return a.isFile ? 1 : -1;
    });
  }
</script>

<div>
  <div 
    class="flex items-center py-1 px-2 hover:bg-[var(--bg-hover)] cursor-pointer {selectedFiles.has(node.path) ? 'bg-blue-900' : ''}"
    style="padding-left: {depth * 12 + 4}px"
    role="button"
    tabindex="0"
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
    <span class="mr-2" on:click|stopPropagation={toggle} role="button" tabindex="0" on:keydown={() => {}}>
      {@html getIcon(node.name, node.isFile, node.isOpen)}
    </span>
    <span class="truncate text-[var(--text-secondary)]">{node.name}</span>
  </div>

  {#if !node.isFile && node.isOpen}
    <div transition:slide|local={{ duration: 200 }}>
      {#each sortChildren(node.children) as child}
        <svelte:self 
          node={child} 
          {selectedFiles} 
          depth={depth + 1} 
          on:select 
          on:toggle 
          on:contextmenu
          on:dblclick
        />
      {/each}
    </div>
  {/if}
</div>
