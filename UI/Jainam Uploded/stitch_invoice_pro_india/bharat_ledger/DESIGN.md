---
name: Bharat Ledger
colors:
  surface: '#f9f9ff'
  surface-dim: '#cfdaf2'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f0f3ff'
  surface-container: '#e7eeff'
  surface-container-high: '#dee8ff'
  surface-container-highest: '#d8e3fb'
  on-surface: '#111c2d'
  on-surface-variant: '#414752'
  inverse-surface: '#263143'
  inverse-on-surface: '#ecf1ff'
  outline: '#717783'
  outline-variant: '#c1c6d4'
  surface-tint: '#005faf'
  primary: '#005dac'
  on-primary: '#ffffff'
  primary-container: '#1976d2'
  on-primary-container: '#fffdff'
  inverse-primary: '#a5c8ff'
  secondary: '#006398'
  on-secondary: '#ffffff'
  secondary-container: '#6cbdfe'
  on-secondary-container: '#004b75'
  tertiary: '#006a48'
  on-tertiary: '#ffffff'
  tertiary-container: '#00865c'
  on-tertiary-container: '#fafff9'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d4e3ff'
  primary-fixed-dim: '#a5c8ff'
  on-primary-fixed: '#001c3a'
  on-primary-fixed-variant: '#004786'
  secondary-fixed: '#cde5ff'
  secondary-fixed-dim: '#94ccff'
  on-secondary-fixed: '#001d32'
  on-secondary-fixed-variant: '#004b74'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#f9f9ff'
  on-background: '#111c2d'
  surface-variant: '#d8e3fb'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-lg:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  title-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
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
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.5px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 16px
  margin-mobile: 16px
  margin-tablet: 24px
---

## Brand & Style
The design system is engineered for the Indian SME landscape, balancing high-end professionalism with the functional utility required by small business owners. The brand personality is **reliable, efficient, and transparent**, aimed at transitioning users from manual bookkeeping to digital precision. 

The aesthetic adheres to a **Modern Corporate** style influenced heavily by Material Design 3 (MD3). It utilizes a "Clean-First" approach, where information density is managed through strategic whitespace and clear typographic anchoring. This ensures that complex financial data—like GST calculations and multi-currency line items—remains approachable and error-free on mobile devices.

## Colors
The palette is rooted in "Business Blue," a color associated with trust and stability in the Indian financial sector. 

- **Primary (#1976D2):** Used for key actions, brand moments, and active states.
- **Secondary (#64B5F6):** Employed for tonal variations in charts, illustrations, and secondary button backgrounds.
- **Success (#10B981):** Critical for "Paid" statuses and positive GST reconciliation.
- **Surface (#F8FAFC):** A slightly cool-tinted off-white used to distinguish background layers from card content, reducing eye strain during long periods of data entry.
- **On-Surface (#1E293B):** A deep slate that provides higher legibility than pure black, maintaining a premium feel.

## Typography
Inter is chosen for its exceptional legibility in data-heavy environments. The system uses a strict hierarchy to ensure that "Total Amount" and "Customer Name" are instantly recognizable.

- **Numbers:** All numerical data (GST, Totals, Quantities) should use `font-variant-numeric: tabular-nums` to ensure columns align perfectly in invoice lists.
- **Multi-language Support:** For Hindi and Gujarati scripts, the line-height is increased by 15% automatically to prevent descender clipping.
- **Scale:** On mobile, `headline-lg` is swapped for `headline-lg-mobile` to maintain container padding integrity.

## Layout & Spacing
The design system employs an **8px linear scale** for consistent rhythm. 

- **Grid:** A 4-column fluid grid for mobile and an 8-column grid for tablet. 
- **Margins:** Standard mobile screens utilize a 16px side margin. Invoices and lists use a 12px gutter to maximize horizontal space for price columns.
- **Rhythm:** Use `md` (16px) for the majority of padding within cards and `lg` (24px) for vertical separation between distinct sections (e.g., between "Customer Info" and "Product List").

## Elevation & Depth
In line with MD3, depth is communicated through **Tonal Layers** supplemented by **Ambient Shadows**.

- **Level 0 (Background):** Pure `#FFFFFF` or `#F8FAFC`.
- **Level 1 (Cards):** Use a subtle shadow: `0px 1px 3px rgba(30, 41, 59, 0.12)`.
- **Level 2 (Active/Hover):** Deepened shadow: `0px 4px 6px rgba(30, 41, 59, 0.08)`.
- **Level 3 (FAB/Modals):** Floating elements use `0px 10px 15px -3px rgba(30, 41, 59, 0.1)`.
- **Scrim:** A 40% opacity blur of `On-Surface` is used when modals are active.

## Shapes
The shape language is "Friendly Professional." 
- **Large Containers:** Cards, bottom sheets, and dialogs use a **16px** (rounded-lg) radius.
- **Standard Components:** Buttons and Input fields use an **8px** radius.
- **Selection Elements:** Chips and the Floating Action Button (FAB) use **fully rounded (pill)** shapes to signify high interactivity.

## Components
- **Buttons:** Primary buttons are filled with white text. Secondary buttons use an outlined style with a 1px border of the primary color.
- **Input Fields:** Use MD3 **Outlined** style. The label should float to the top border on focus. Include a "prefix" area for currency symbols (₹) and a "suffix" area for units (kg, pcs).
- **FAB (Floating Action Button):** Located at the bottom right. It is a large, rounded-square or pill shape containing a "+" icon and the label "New Invoice."
- **Chips:** Used for "GST Registered," "Composition Scheme," or payment status (Paid, Unpaid, Overdue). Status chips use background tints of Success, Error, or Warning at 15% opacity.
- **Bottom Navigation:** Fixed at the bottom with four destinations: Home, Invoices, Customers, and Reports. Active icons use a tonal pill background indicator.
- **Lists:** Invoice list items include a leading icon for payment status, a title (Customer Name), a subtitle (Date & Invoice #), and a trailing value (Total Amount in Bold).
- **Indian Context Features:** 
    - **UPI QR Section:** A dedicated card component to display a generated UPI QR code for fast collections.
    - **GST Calculator:** A specialized input group with pre-set percentage chips (5%, 12%, 18%, 28%).