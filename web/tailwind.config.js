/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: { 950: "#0a0c0f", 900: "#101318", 800: "#171b22", 700: "#232934", 500: "#5b6474", 300: "#a3acba", 100: "#e6e9ee" },
        // the one accent color: sealing-wax amber
        seal: { DEFAULT: "#f5a524", dim: "#3a2a0e", soft: "#fbd38d" },
      },
      fontFamily: {
        sans: ["Inter", "ui-sans-serif", "system-ui", "sans-serif"],
        mono: ["JetBrains Mono", "ui-monospace", "SFMono-Regular", "monospace"],
      },
    },
  },
  plugins: [],
};
