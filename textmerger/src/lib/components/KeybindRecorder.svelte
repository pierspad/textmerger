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
      class="px-3 py-1 bg-[#3c3c3c] hover:bg-[#4c4c4c] text-gray-200 rounded text-sm font-mono border border-[#555] min-w-[100px] text-center transition-colors"
      on:click={startRecording}
      type="button"
    >
      {$tShortcut(value)}
    </button>
  {/if}
</div>
