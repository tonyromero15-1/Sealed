import { describe, expect, it } from "vitest";
import { formatCountdown, formatGNOT, parseGNOT, parseUnits } from "./format";

describe("format", () => {
  it("formats ugnot like the realm page", () => {
    expect(formatGNOT(1_500_000n)).toBe("1.5 GNOT");
    expect(formatGNOT(1n)).toBe("0.000001 GNOT");
    expect(formatGNOT(1_200_000_000n)).toBe("1,200 GNOT");
  });
  it("parses GNOT input exactly (no floats)", () => {
    expect(parseGNOT("0.3")).toBe(300_000n);
    expect(parseGNOT("12.000001")).toBe(12_000_001n);
    expect(() => parseGNOT("0.0000001")).toThrow();
    expect(() => parseGNOT("-1")).toThrow();
  });
  it("parses whole token amounts", () => {
    expect(parseUnits("40")).toBe(40n);
    expect(() => parseUnits("0")).toThrow();
    expect(() => parseUnits("1.5")).toThrow();
  });
  it("counts down", () => {
    expect(formatCountdown(125)).toBe("2m 05s");
    expect(formatCountdown(0)).toBe("0s");
  });
});

import { parseFirstString, parseScalar, parseString } from "./rpc";

describe("qeval value parsing", () => {
  it("reads strings and scalars", () => {
    expect(parseString('("8|1,795,783,197|—|TAVERN" string)')).toBe("8|1,795,783,197|—|TAVERN");
    expect(parseScalar("(1795783197 int64)")).toBe("1795783197");
    expect(parseScalar("(true bool)")).toBe("true");
  });
  it("reads the key from avl GetByIndex's two return values", () => {
    const lit = '("g16cyxw8jdpj8wy2gqd0kr0v77x84fpjc673dely" string)\n(&(struct{("g16cyxw8jdpj8wy2gqd0kr0v77x84fpjc673dely" .uverse.address)} sealed.Bid) *sealed.Bid)';
    expect(parseFirstString(lit)).toBe("g16cyxw8jdpj8wy2gqd0kr0v77x84fpjc673dely");
  });
});
