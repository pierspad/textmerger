<script lang="ts">
  import { createEventDispatcher, onMount } from "svelte";

  export let value = "";
  export let recording = false;

  const dispatch = createEventDispatcher();

  function handleKeyDown(e: KeyboardEvent) {
    if (!recording) return;
    e.preventDefault();
    e.stopPropagation();

    const keys = [];
    if (e.ctrlKey) keys.push("Ctrl");
    if (e.altKey) keys.push("Alt");
    if (e.shiftKey) keys.push("Shift");
    if (e.metaKey) keys.push("Meta");

    // Don't add modifier keys themselves if they are the only key pressed
    if (
      !["Control", "Alt", "Shift", "Meta"].includes(e.key)
    ) {
      // Convert key to uppercase for consistency
      let key = e.key.toUpperCase();
      // Handle special keys if needed, but usually e.key is fine
      if (key === " ") key = "SPACE";
      keys.push(key);
      
      const shortcut = keys.join("+");
      dispatch("change", shortcut);
      recording = false;
    }
  }

  function startRecording() {
    recording = true;
    dispatch("start");
  }

  function stopRecording() {
    recording = false;
    dispatch("stop");
  }

  // Global listener when recording
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
      class="px-3 py-1 bg-red-600 text-white rounded text-sm font-medium animate-pulse border border-red-400"
      on:click={stopRecording}
    >
      Recording keys... (Click again to stop recording)
    </button>
  {:else}
    <button
      class="px-3 py-1 bg-[#3c3c3c] hover:bg-[#4c4c4c] text-gray-200 rounded text-sm font-mono border border-[#555] min-w-[100px] text-center transition-colors"
      on:click={startRecording}
    >
      {value}
    </button>
  {/if}
</div>
