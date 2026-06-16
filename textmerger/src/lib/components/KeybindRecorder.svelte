<script lang="ts">
  import { createEventDispatcher, onMount } from "svelte";
  import { tShortcut } from "../stores/i18n";

  export let value = "";
  export let recording = false;
  export let recordingLabel = "Recording keys";

  const dispatch = createEventDispatcher();

  function handleKeyDown(e: KeyboardEvent) {
    if (!recording) return;
    e.preventDefault();
    e.stopPropagation();

    if (e.key === "Escape") {
      recording = false;
      dispatch("cancel");
      dispatch("stop");
      return;
    }

    const keys = [];
    if (e.ctrlKey) keys.push("Ctrl");
    if (e.altKey) keys.push("Alt");
    if (e.shiftKey) keys.push("Shift");
    if (e.metaKey) keys.push("Meta");

    if (!["Control", "Alt", "Shift", "Meta"].includes(e.key)) {
      let key = e.key.toUpperCase();
      if (key === " ") key = "SPACE";
      keys.push(key);
      
      const shortcut = keys.join("+");
      dispatch("change", shortcut);
      recording = false;
      dispatch("stop");
    }
  }

  function startRecording() {
    recording = true;
    dispatch("start");
  }

  $: if (recording) {
    window.addEventListener("keydown", handleKeyDown, true);
  } else {
    window.removeEventListener("keydown", handleKeyDown, true);
  }

  onMount(() => {
    return () => {
      window.removeEventListener("keydown", handleKeyDown, true);
    };
  });
</script>

<div class="flex items-center gap-2">
  {#if recording}
    <button
      class="px-3 py-1 bg-red-600 text-white rounded text-sm font-medium animate-pulse border border-red-400 min-w-[118px]"
      type="button"
    >
      {recordingLabel}
    </button>
  {:else}
    <button
      on:click={startRecording}
      type="button"
      class="flex items-center gap-1 px-1 py-0.5 bg-transparent hover:bg-white/5 active:scale-[0.98] rounded transition-all cursor-pointer focus:outline-none focus:ring-1 focus:ring-[#0e639c]"
      aria-label="Change shortcut"
    >
      {#if !value}
        <span class="px-2 py-0.5 bg-[#3c3c3c] text-gray-400 rounded text-[11px] font-mono border border-[#555] text-center shadow-sm italic select-none">
          none
        </span>
      {:else}
        {#each value.split("+") as key, i}
          {#if i > 0}
            <span class="text-[var(--muted)] text-[10px] font-semibold select-none">+</span>
          {/if}
          <span class="px-2 py-0.5 bg-[#3c3c3c] text-gray-200 rounded text-[11px] font-mono border border-[#555] text-center shadow-sm select-none">
            {$tShortcut(key)}
          </span>
        {/each}
      {/if}
    </button>
  {/if}
</div>
