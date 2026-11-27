import { CHAIN_ID, CHAIN_NAME, GAS_FEE, GAS_WANTED, REALM_PATH, RPC_URL } from "../config";

// Thin wrapper over the injected Adena wallet (window.adena).
// API: https://docs.adena.app/integrations (AddEstablish, GetAccount,
// GetNetwork, AddNetwork, SwitchNetwork, DoContract, On).

interface AdenaResponse<T = unknown> {
  code: number;
  status: "success" | "failure";
  type: string;
  message: string;
  data: T;
}

interface AdenaApi {
  AddEstablish(name: string): Promise<AdenaResponse>;
  GetAccount(): Promise<AdenaResponse<{ address: string; coins: string; chainId: string; status: string }>>;
  GetNetwork(): Promise<AdenaResponse<{ chainId: string; networkName: string; rpcUrl: string }>>;
  AddNetwork(n: { chainId: string; chainName: string; rpcUrl: string }): Promise<AdenaResponse>;
  SwitchNetwork(chainId: string): Promise<AdenaResponse>;
  DoContract(
    tx: {
      messages: { type: string; value: Record<string, unknown> }[];
      gasFee: number;
      gasWanted: number;
      memo?: string;
      networkInfo?: { chainId: string; rpcUrl: string };
    },
    options?: { withNotification?: boolean; isVisibleResult?: boolean } | boolean,
  ): Promise<AdenaResponse<{ hash?: string; height?: string }>>;
  On(event: "changedAccount" | "changedNetwork", cb: (v: string) => void): void;
}

declare global {
  interface Window {
    adena?: AdenaApi;
  }
}

export class WalletError extends Error {}

export function hasAdena(): boolean {
  return typeof window !== "undefined" && !!window.adena;
}

function api(): AdenaApi {
  if (!window.adena) throw new WalletError("Adena wallet not found. Install it from adena.app.");
  return window.adena;
}

function ok<T>(r: AdenaResponse<T>, what: string): T {
  if (r.status !== "success") throw new WalletError(`${what}: ${r.message || r.type} (${r.code})`);
  return r.data;
}

// Connects, makes sure Adena is on Onyx, and returns the account address.
export async function connect(): Promise<string> {
  const a = api();
  const est = await a.AddEstablish("SEALED");
  if (est.status !== "success" && est.type !== "ALREADY_CONNECTED") ok(est, "Connect");
  await ensureNetwork();
  const acct = ok(await a.GetAccount(), "Get account");
  return acct.address;
}

export async function ensureNetwork(): Promise<void> {
  const a = api();
  const net = await a.GetNetwork();
  if (net.status === "success" && net.data?.chainId === CHAIN_ID) return;
  let sw = await a.SwitchNetwork(CHAIN_ID);
  if (sw.status !== "success" && sw.type === "UNADDED_NETWORK") {
    ok(await a.AddNetwork({ chainId: CHAIN_ID, chainName: CHAIN_NAME, rpcUrl: RPC_URL }), "Add Onyx network");
    sw = await a.SwitchNetwork(CHAIN_ID);
  }
  if (sw.status !== "success" && sw.type !== "REDUNDANT_CHANGE_REQUEST") ok(sw, "Switch to Onyx");
}

export function onAccountChange(cb: (address: string) => void) {
  window.adena?.On("changedAccount", cb);
}

// Calls a SEALED function from the connected account, optionally sending ugnot.
export async function callSealed(caller: string, func: string, args: string[], sendUgnot = 0n): Promise<string> {
  const r = await api().DoContract({
    messages: [
      {
        type: "/vm.m_call",
        value: {
          caller,
          send: sendUgnot > 0n ? `${sendUgnot}ugnot` : "",
          pkg_path: REALM_PATH,
          func,
          args,
        },
      },
    ],
    gasFee: GAS_FEE,
    gasWanted: GAS_WANTED,
    memo: "SEALED",
    // Pin the tx to Onyx whatever network the wallet has selected.
    networkInfo: { chainId: CHAIN_ID, rpcUrl: RPC_URL },
  });
  const data = ok(r, `${func} transaction`);
  return data?.hash ?? "";
}
