// Where SEALED lives. Override with VITE_* env vars (see web/README.md).
export const CHAIN_ID = import.meta.env.VITE_CHAIN_ID ?? "onyx-1";
export const CHAIN_NAME = import.meta.env.VITE_CHAIN_NAME ?? "Gno.land Onyx";
export const RPC_URL = import.meta.env.VITE_RPC_URL ?? "https://rpc.onyx.testnets.gno.land:443";
export const REALM_PATH =
  import.meta.env.VITE_REALM_PATH ?? "gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1";
export const GNOWEB_URL = import.meta.env.VITE_GNOWEB_URL ?? "https://onyx.testnets.gno.land";

// Mirrors the realm's constants (realms/sealed/sealed.gno).
export const MIN_DEPOSIT = 100_000n; // ugnot, 0.1 GNOT
export const FORFEIT_PERCENT = 10;

// Fees for our calls: 1 ugnot per 1,000 gas on Onyx. Claim uses ~12M gas.
export const GAS_WANTED = 50_000_000;
export const GAS_FEE = 100_000; // ugnot
