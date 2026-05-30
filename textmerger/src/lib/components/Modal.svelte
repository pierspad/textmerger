<script lang="ts">
  import { createEventDispatcher, onMount } from "svelte";
  import { fade, scale } from "svelte/transition";

  export let title: string = "";
  export let confirmText: string = "Confirm";
  export let cancelText: string = "Cancel";
  export let showCancel: boolean = true;
  export let disabled: boolean = false;

  const dispatch = createEventDispatcher();

  function handleClose() {
    dispatch("close");
  }

  function handleConfirm() {
    if (!disabled) {
      dispatch("confirm");
    }
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === "Escape") {
      handleClose();
    } else if (e.key === "Enter" && !disabled) {
        handleConfirm();
    }
  }
</script>

<div
  class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm"
  transition:fade={{ duration: 200 }}
  on:click={handleClose}
  on:keydown={(e) => e.key === 'Escape' && handleClose()}
  role="presentation"
  tabindex="-1"
>
  <div
    class="w-full max-w-md bg-[var(--surface)] border border-[var(--border-light)] rounded-xl shadow-2xl overflow-hidden transform"
    transition:scale={{ duration: 200, start: 0.95 }}
    on:click|stopPropagation
    on:keydown={(e) => {}}
    role="dialog"
    tabindex="-1"
    aria-modal="true"
    aria-labelledby="modal-title"
  >

    <div class="px-6 py-4 border-b border-[var(--border)] flex items-center justify-between bg-[var(--surface-2)]">
      <h3 id="modal-title" class="text-lg font-semibold text-[var(--text)]">
        {title}
      </h3>
      <button
        type="button"
        class="text-[var(--muted)] hover:text-[var(--text)] transition-colors p-1 rounded-md hover:bg-[var(--bg-hover)]"
        on:click={handleClose}
        aria-label="Close"
      >
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
          <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
        </svg>
      </button>
    </div>


    <div class="px-6 py-6 text-[var(--text)]">
      <slot />
    </div>


    <div class="px-6 py-4 bg-[var(--surface-2)] border-t border-[var(--border)] flex justify-end gap-3">
      {#if showCancel}
        <button
          class="px-4 py-2 text-sm font-medium text-[var(--text)] bg-[var(--bg-hover-strong)] hover:bg-[var(--bg-hover)] rounded-lg transition-colors border border-[var(--border)]"
          on:click={handleClose}
        >
          {cancelText}
        </button>
      {/if}
      <button
        class="px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-lg shadow-lg shadow-blue-900/20 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
        on:click={handleConfirm}
        {disabled}
      >
        {confirmText}
      </button>
    </div>
  </div>
</div>

<svelte:window on:keydown={handleKeydown} />
