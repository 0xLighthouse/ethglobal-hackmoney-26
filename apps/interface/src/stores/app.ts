import { create } from "zustand";
import type { User } from "@privy-io/react-auth";

type AppStatus = "idle" | "initializing" | "ready" | "error";

interface AppState {
  isInitialized: boolean;
  user: User | undefined;

  // App state
  status: AppStatus;
  error: string | null;

  initialize: (user: User) => Promise<void>;
  logout: () => void;
  reset: () => void;
}

const initialState = {
  isInitialized: false,
  user: undefined,
  status: "idle" as AppStatus,
  error: null as string | null,
};

export const useAppStore = create<AppState>()((set) => ({
  ...initialState,

  initialize: async (user: User) => {
    set({ status: "initializing", user, error: null });
    set({ status: "ready", isInitialized: true });
  },

  logout: () => {
    set({
      ...initialState,
      status: "ready",
    });
  },

  reset: () => {
    set({
      ...initialState,
      status: "ready",
    });
  },
}));

export type { AppState, AppStatus };
