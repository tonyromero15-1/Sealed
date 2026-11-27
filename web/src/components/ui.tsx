import type { ReactNode } from "react";
import type { Phase } from "../lib/sealed";

const PHASE_STYLE: Record<Phase, string> = {
  Commit: "border-seal/40 bg-seal-dim text-seal",
  Reveal: "border-sky-400/30 bg-sky-400/10 text-sky-300",
  "Ready to settle": "border-ink-500 bg-ink-800 text-ink-100",
  Settled: "border-emerald-400/30 bg-emerald-400/10 text-emerald-300",
};
const PHASE_ICON: Record<Phase, string> = { Commit: "🔒", Reveal: "🔓", "Ready to settle": "⏳", Settled: "✅" };

export function PhaseBadge({ phase }: { phase: Phase }) {
  return (
    <span className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-semibold ${PHASE_STYLE[phase]}`}>
      <span>{PHASE_ICON[phase]}</span>
      {phase}
    </span>
  );
}

export function Stat({ label, value, hint }: { label: string; value: ReactNode; hint?: ReactNode }) {
  return (
    <div>
      <div className="label">{label}</div>
      <div className="text-lg font-semibold">{value}</div>
      {hint && <div className="text-xs text-ink-500">{hint}</div>}
    </div>
  );
}

export function Notice({ tone = "info", children }: { tone?: "info" | "warn" | "error" | "ok"; children: ReactNode }) {
  const style = {
    info: "border-ink-700 bg-ink-800 text-ink-300",
    warn: "border-seal/50 bg-seal-dim text-seal-soft",
    error: "border-red-500/40 bg-red-500/10 text-red-300",
    ok: "border-emerald-400/30 bg-emerald-400/10 text-emerald-300",
  }[tone];
  return <div className={`rounded-xl border px-4 py-3 text-sm ${style}`}>{children}</div>;
}

export function Mono({ children }: { children: ReactNode }) {
  return <span className="break-all font-mono text-xs text-ink-300">{children}</span>;
}
