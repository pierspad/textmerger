import { open, save } from "@tauri-apps/plugin-dialog";

let dialogInFlight = false;

async function withDialogLock<T>(action: () => Promise<T>): Promise<T | null> {
  if (dialogInFlight) return null;
  dialogInFlight = true;
  try {
    return await action();
  } finally {
    dialogInFlight = false;
  }
}

export async function guardedOpen(
  options?: Parameters<typeof open>[0],
): Promise<Awaited<ReturnType<typeof open>> | null> {
  return withDialogLock(() => open(options));
}

export async function guardedSave(
  options?: Parameters<typeof save>[0],
): Promise<Awaited<ReturnType<typeof save>> | null> {
  return withDialogLock(() => save(options));
}
