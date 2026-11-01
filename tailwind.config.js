/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        obsidian: {
          950: '#06090F',
          900: '#090D16',
          800: '#0E1524',
        },
        slate: {
          850: '#151F32',
          900: '#111827',
          950: '#0B0F19',
        },
        tactical: {
          cyan: '#00F0FF',
          'cyan-dark': '#00A8B3',
          emerald: '#10B981',
          crimson: '#EF4444',
          amber: '#F59E0B',
          purple: '#A855F7',
          border: '#1F2937',
          'border-bright': '#374151',
        },
      },
      fontFamily: {
        mono: ['"JetBrains Mono"', 'ui-monospace', 'SFMono-Regular', 'Menlo', 'Monaco', 'Consolas', 'monospace'],
        sans: ['Inter', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif'],
      },
      boxShadow: {
        'tactical-cyan': '0 0 15px rgba(0, 240, 255, 0.25)',
        'tactical-crimson': '0 0 20px rgba(239, 68, 68, 0.4)',
        'tactical-emerald': '0 0 15px rgba(16, 185, 129, 0.25)',
      },
      animation: {
        'pulse-fast': 'pulse 1s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'radar-ping': 'radar 2s cubic-bezier(0, 0, 0.2, 1) infinite',
      },
      keyframes: {
        radar: {
          '0%': { transform: 'scale(0.95)', opacity: '0.9' },
          '100%': { transform: 'scale(2.5)', opacity: '0' },
        },
      },
    },
  },
  plugins: [],
}
