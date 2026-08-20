---
name: Emerald Ledger
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
  on-surface-variant: '#3d4a42'
  inverse-surface: '#2e3132'
  inverse-on-surface: '#f0f1f2'
  outline: '#6d7a72'
  outline-variant: '#bccac0'
  surface-tint: '#006c4a'
  primary: '#006948'
  on-primary: '#ffffff'
  primary-container: '#00855d'
  on-primary-container: '#f5fff7'
  inverse-primary: '#68dba9'
  secondary: '#555f70'
  on-secondary: '#ffffff'
  secondary-container: '#d6e0f4'
  on-secondary-container: '#596374'
  tertiary: '#006947'
  on-tertiary: '#ffffff'
  tertiary-container: '#00855b'
  on-tertiary-container: '#f5fff6'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#85f8c4'
  primary-fixed-dim: '#68dba9'
  on-primary-fixed: '#002114'
  on-primary-fixed-variant: '#005137'
  secondary-fixed: '#d9e3f7'
  secondary-fixed-dim: '#bdc7db'
  on-secondary-fixed: '#121c2a'
  on-secondary-fixed-variant: '#3d4757'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#f8f9fa'
  on-background: '#191c1d'
  surface-variant: '#e1e3e4'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  mono-stats:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
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
  xl: 48px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 64px
  max-width: 1280px
---

## Brand & Style

The brand personality is **Efficient, Modern, and Professional**. This design system prioritizes clarity and speed of task completion, tailored for freelancers and small business owners who require a trustworthy financial tool. 

The design style is **Corporate / Modern** with a focus on **Minimalism**. It employs generous whitespace to reduce cognitive load during data entry, utilizing a high-contrast palette to ensure that critical financial figures and "Send Invoice" actions are immediately identifiable. The aesthetic leans into a "Digital Paper" feel—clean, structured, and organized—to evoke the reliability of traditional accounting with the speed of a modern SaaS platform.

## Colors

The palette is anchored by **Deep Emerald (#059669)**, a color that represents growth and financial stability. This is used for primary actions, success states, and brand markers. 

- **Primary**: Deep Emerald (#059669) for main buttons and active states.
- **Secondary**: Soft Charcoal (#374151) for primary text and iconography to maintain high legibility without the harshness of pure black.
- **Tertiary**: Vibrant Mint (#10B981) used sparingly for positive data trends and accent highlights.
- **Neutral**: A range of off-whites and cool grays (Base: #F9FAFB) for backgrounds and input fields to differentiate content areas from the canvas.
- **Semantic**: Errors are handled with a crisp Crimson (#DC2626), ensuring financial discrepancies are never missed.

## Typography

The typography system utilizes **Inter** for its exceptional legibility and systematic feel. For an invoice application, numerical clarity is paramount; therefore, the "tabular numbers" (tnum) feature should be enabled for all data tables and currency displays to ensure decimal points align vertically.

Headlines use a tighter letter-spacing and heavier weights to create a strong visual hierarchy. Body text is set with generous line heights to ensure readability during long form-filling sessions. Labels use a medium weight and optional uppercase styling to clearly distinguish "Metadata" (like Invoice ID) from "User Content" (like Client Name).

## Layout & Spacing

The design system employs a **12-column fluid grid** for desktop and a **4-column grid** for mobile. The spacing rhythm is built on a **4px baseline**, ensuring all components align to a consistent mathematical scale.

- **Desktop**: Layouts should be centered with a max-width of 1280px. Use the `xl` (48px) spacing for major section vertical padding to give the financial data "room to breathe."
- **Forms**: Use `md` (16px) spacing between related input fields and `lg` (24px) between field groups (e.g., "From" vs "To" sections).
- **Mobile**: Margins reduce to 16px. Invoices should reflow from a side-by-side layout to a single-column stack, ensuring the "Total Amount" remains sticky at the bottom or top of the viewport.

## Elevation & Depth

To maintain a professional and clean aesthetic, this design system uses **Tonal Layers** supplemented by **Low-contrast outlines**. 

- **Level 0 (Background)**: #F9FAFB. The main canvas.
- **Level 1 (Cards/Surface)**: #FFFFFF with a 1px solid border in #E5E7EB. No shadow. This is used for the main invoice body.
- **Level 2 (Dropdowns/Modals)**: #FFFFFF with a soft, diffused shadow (Offset: 0 10px, Blur: 15px, Opacity: 0.05, Color: #374151). This creates a subtle "lift" for temporary UI elements without breaking the minimalist vibe.
- **Active State**: Primary buttons should use a slight inner shadow to appear "pressed" when clicked, enhancing the tactile feedback of the interface.

## Shapes

The design system uses a **Rounded** (Level 2) shape language to soften the industrial feel of financial data.

- **Standard Elements**: Buttons, Input Fields, and Checkboxes use `rounded` (0.5rem / 8px).
- **Containers**: Main invoice previews and dashboard modules use `rounded-lg` (1rem / 16px) to define distinct content areas.
- **Badges/Chips**: Status indicators (e.g., "Paid", "Overdue") use `rounded-xl` or fully pill-shaped styling to distinguish them from actionable buttons.

## Components

### Buttons
- **Primary**: Solid Deep Emerald background with white text. 8px corner radius.
- **Secondary**: Ghost style with 1px Soft Charcoal border or light gray background.
- **Critical**: Crimson background for "Delete" or "Void" actions.

### Input Fields
- **Default State**: White background, 1px Gray-200 border.
- **Focus State**: 2px Deep Emerald border with a subtle teal outer glow (2px spread, 10% opacity).
- **Labels**: Small, bold, and placed consistently above the field.

### Status Chips
- **Paid**: Light green background with Deep Emerald text.
- **Pending**: Light amber background with dark brown text.
- **Overdue**: Light red background with Crimson text.

### Invoicing Table
- **Rows**: Subtle hover state change (#F3F4F6). 
- **Columns**: Right-aligned for numerical values to facilitate easier comparison.
- **Footer**: A "Total" block with a slightly darker neutral background to distinguish it from individual line items.

### Cards
- Used for dashboard metrics (e.g., "Total Revenue"). These should feature high-contrast typography for the value and a small sparkline chart in Deep Emerald for visual context.