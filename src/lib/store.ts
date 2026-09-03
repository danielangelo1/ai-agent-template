import { create } from "zustand";

interface UiState {
  isSubscribeDialogOpen: boolean;
  openSubscribeDialog: () => void;
  closeSubscribeDialog: () => void;
}

export const useUiStore = create<UiState>((set) => ({
  isSubscribeDialogOpen: false,
  openSubscribeDialog: () => set({ isSubscribeDialogOpen: true }),
  closeSubscribeDialog: () => set({ isSubscribeDialogOpen: false }),
}));
