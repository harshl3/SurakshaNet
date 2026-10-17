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
        canvas: '#F3F0EE',
        lifted: '#FCFBFA',
        bone: '#F4F4F4',
        ink: {
          DEFAULT: '#141413',
          900: '#1c1c1a',
          800: '#262627',
          700: '#383836',
        },
        signal: {
          DEFAULT: '#CF4500',
          hover: '#B53C00',
          light: '#F37338',
          pale: '#FDF2EB',
        },
        clay: '#9A3A0A',
        'slate-gray': '#696969',
        dust: '#D1CDC7',
        'link-blue': '#3860BE',
        // Support backward compatibility
        navy: {
          950: '#141413',
          900: '#1c1c1a',
          850: '#262627',
          800: '#323230',
          700: '#424240',
        },
        police: {
          50: '#EFF6FF',
          100: '#DBEAFE',
          200: '#BFDBFE',
          300: '#93C5FD',
          400: '#60A5FA',
          500: '#3B82F6',
          600: '#2563EB',
          700: '#1D4ED8',
          800: '#1E40AF',
          900: '#141413',
          950: '#0F172A',
        },
      },
      fontFamily: {
        sans: ['"Sofia Sans"', 'Inter', 'ui-sans-serif', 'system-ui', '-apple-system', 'sans-serif'],
      },
      borderRadius: {
        'sm': '8px',
        'md': '12px',
        'pill': '20px',
        'pill-lg': '24px',
        'stadium': '40px',
        'full': '9999px',
      },
      boxShadow: {
        'xs': '0 1px 2px 0 rgba(0, 0, 0, 0.05)',
        'mc-nav': '0 4px 24px rgba(20, 20, 19, 0.05)',
        'mc-card': '0 16px 40px rgba(20, 20, 19, 0.06), 0 2px 6px rgba(20, 20, 19, 0.02)',
        'mc-elevated': '0 24px 48px rgba(20, 20, 19, 0.08)',
        'card': '0 12px 32px rgba(20, 20, 19, 0.05), 0 2px 6px rgba(20, 20, 19, 0.02)',
      },
      letterSpacing: {
        'tightest': '-0.02em',
        'eyebrow': '+0.04em',
      }
    },
  },
  plugins: [],
}
