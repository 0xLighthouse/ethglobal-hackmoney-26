import { create } from "zustand";

type CreateSaleFormValues = {
  amount: string;
  price: string;
  startDate: string | null;
  startTime: string;
  endDate: string | null;
  endTime: string;
  refundableBps: string;
  decayDelay: string;
  decayDuration: string;
};

const createSaleFormDefaults: CreateSaleFormValues = {
  amount: "",
  price: "",
  startDate: null,
  startTime: "00:00",
  endDate: null,
  endTime: "00:00",
  refundableBps: "80.00",
  decayDelay: "100",
  decayDuration: "200",
};

type CreateSaleState = {
  form: CreateSaleFormValues;
  setForm: (values: CreateSaleFormValues) => void;
  reset: () => void;
};

const useCreateSaleStore = create<CreateSaleState>()((set) => ({
  form: createSaleFormDefaults,
  setForm: (values) => set({ form: values }),
  reset: () => set({ form: createSaleFormDefaults }),
}));

export { createSaleFormDefaults, useCreateSaleStore };
