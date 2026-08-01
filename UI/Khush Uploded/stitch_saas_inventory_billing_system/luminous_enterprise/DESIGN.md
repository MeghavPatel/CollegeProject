---
name: Luminous Enterprise
colors:
  surface: '#f8f9fa'
  surface-dim: '#d9dadb'
  surface-bright: '#f8f9fa'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f4f5'
  surface-container: '#edeeef'
  surface-container-high: '#e7e8e9'
  surface-container-highest: '#e1e3e4'
  on-surface: '#191c1d'
  on-surface-variant: '#434655'
  inverse-surface: '#2e3132'
  inverse-on-surface: '#f0f1f2'
  outline: '#737686'
  outline-variant: '#c3c6d7'
  surface-tint: '#0053db'
  primary: '#004ac6'
  on-primary: '#ffffff'
  primary-container: '#2563eb'
  on-primary-container: '#eeefff'
  inverse-primary: '#b4c5ff'
  secondary: '#505f76'
  on-secondary: '#ffffff'
  secondary-container: '#d0e1fb'
  on-secondary-container: '#54647a'
  tertiary: '#006242'
  on-tertiary: '#ffffff'
  tertiary-container: '#007d55'
  on-tertiary-container: '#bdffdb'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dbe1ff'
  primary-fixed-dim: '#b4c5ff'
  on-primary-fixed: '#00174b'
  on-primary-fixed-variant: '#003ea8'
  secondary-fixed: '#d3e4fe'
  secondary-fixed-dim: '#b7c8e1'
  on-secondary-fixed: '#0b1c30'
  on-secondary-fixed-variant: '#38485d'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#f8f9fa'
  on-background: '#191c1d'
  surface-variant: '#e1e3e4'
typography:
  headline-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-md:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  mono-md:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 20px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 40px
  container-max: 1440px
  gutter: 24px
---

## Brand & Style

This design system targets high-growth enterprises requiring a sophisticated yet functional interface for complex inventory and billing workflows. The brand personality is authoritative and precise, balanced by a modern, airy aesthetic that reduces the cognitive load of data-heavy environments.

The visual direction utilizes a **Refined Glassmorphism** style. It leverages semi-transparent surfaces, multi-layered depth, and soft background blurs to create a sense of hierarchy without the visual clutter of heavy borders. The interface should feel "light as air" while maintaining the professional rigor expected of financial and logistical software.

## Colors

The palette is anchored by a high-trust "Electric Blue" primary color. The neutral scale is carefully tuned to provide sufficient contrast for data density while supporting the glassmorphic layering.

### Implementation Guidelines
- **Light Mode:** Use `#F9FAFB` for the main canvas. Surface containers use `#FFFFFF` with 80-90% opacity and a 20px backdrop blur when positioned over dynamic content.
- **Dark Mode:** Transition to a deep navy background (`#0F172A`). Surfaces should use a semi-transparent slate (`rgba(30, 41, 59, 0.7)`) with an inner 1px border of `rgba(255, 255, 255, 0.1)` to simulate the edge of the glass.
- **Semantic Colors:** Use Success, Alert, and Warning colors sparingly for status badges, progress bars, and critical billing alerts.

## Typography

The system uses **Plus Jakarta Sans** for headings to inject a modern, premium feel, while **Inter** handles the heavy lifting of data tables and billing forms due to its exceptional legibility at small sizes.

- **Scale:** Large headings use tighter letter spacing to maintain a "locked-in" professional appearance.
- **Hierarchy:** Use `label-md` for table headers and section overviews. Use `mono-md` specifically for invoice numbers, SKU codes, and monetary values to ensure character alignment in columns.
- **Mobile:** Scale `headline-xl` down to 24px and `headline-lg` to 20px on mobile devices.

## Layout & Spacing

This design system employs a **Fluid Grid** model with a strict 4px baseline rhythm. This ensures that high-density tables and financial dashboards remain organized and scannable.

- **Desktop:** 12-column grid, 24px gutters, 40px side margins.
- **Tablet:** 8-column grid, 16px gutters, 24px side margins.
- **Mobile:** 4-column grid, 16px gutters, 16px side margins.
- **Data Density:** In inventory tables, vertical cell padding is reduced to `sm` (8px) to maximize information density, while dashboard widgets use `lg` (24px) padding to provide visual breathing room.

## Elevation & Depth

Hierarchy is established through "Luminous Layering" rather than traditional heavy shadows.

- **Level 0 (Canvas):** Base background color.
- **Level 1 (Cards/Widgets):** Surface color with 1px subtle stroke (`rgba(0,0,0,0.05)` in light, `rgba(255,255,255,0.1)` in dark). 
- **Level 2 (Modals/Dropdowns):** Increased backdrop blur (32px) and an ambient shadow: `0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)`.
- **Glass Effect:** All elevated surfaces must have a `backdrop-filter: blur(20px)` to maintain the premium SaaS aesthetic.

## Shapes

The design system uses a consistent **16px (1rem)** radius for primary containers and cards to evoke a friendly yet professional tone.

- **Buttons & Inputs:** Use `rounded-lg` (8px) to maintain a crisp look within the larger rounded containers.
- **Status Badges:** Use `rounded-full` (pill-shaped) to distinguish them from interactive buttons.
- **Checkboxes:** Use a smaller 4px radius to ensure they feel precise and mechanical.

## Components

### Buttons
- **Primary:** Solid `#2563EB` with white text. Subtle inner-glow on hover.
- **Secondary:** Glass-style. Semi-transparent background with a 1px border.
- **Action Density:** Buttons in table rows should be "ghost" style, only showing a background on hover.

### High-Density Tables
- **Header:** Sticky headers with `label-md` typography.
- **Rows:** Alternate row striping is replaced by a 1px bottom border. On hover, the entire row should gain a subtle glass tint and a slightly increased elevation.
- **Cells:** Numeric data must be right-aligned using monospaced fonts.

### Form Fields
- **Default State:** White background (light mode) with a 1px neutral-200 border. 16px height padding.
- **Focus State:** 2px primary color ring with a soft outer glow.
- **Floating Labels:** Use small, high-contrast labels to maximize vertical space in billing forms.

### Status Badges
- Used for "Paid," "Pending," "Overdue," or "In Stock."
- **Visuals:** Soft background tint (10% opacity of the semantic color) with high-contrast text and a small leading dot.

### Charts & Analytics
- Use the primary and tertiary colors as the main data series. 
- Use rounded caps on bar charts and smoothed (Catmull-Rom) lines for billing trends to match the shape language.