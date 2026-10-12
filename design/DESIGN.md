# atesoraroseta: website design handoff

Portfolio site for a collage artist who works with ripped fragments of billboard posters.
A plain graphite gallery wall: works floating with soft shadows, quiet type, no clutter.

- **Design canvas (visual source of truth):** https://claude.ai/artifact/1ztW4VbnoU3EeApQhkp8vo
  - Desktop artboards at 1440: `Main` (Obra, the home page), `Obra-detalle` (artwork page), `Torn-posters`, `Sobre-mi`, `Contacto`
  - Mobile artboards at 390: the same pages rendered at phone width
  - `Guia`: build guide with tokens, type, layout table, states, routes and content model
  - `Font-options`: the type exploration. Option D, Fashion, was chosen.
  - A Claude Code agent can read any artboard's source with the Artifact tool (`read_file`, path `project/<Name>.dc.html`). Layout values are the inline styles there. Images and the stylesheet are canvas assets (`/_blob/<id>`); the same files are in this folder.
- **`site.css` (in this folder):** tokens, shared text styles, and every hover, focus, current-page and responsive rule. Every artboard links it. Reuse it as-is and move the inline layout values below into classes.
- **`img/` (in this folder):** the sample piece prepared for the web (`obra-01.webp`, cut out on transparency), its detail crops (`obra-01-d1…d8.jpg`) and stand-in crops (`obra-02…09.jpg`). Use them only as placeholders until the real photos arrive.
- **`explorations/`:** a billboard-paper background texture that was tried and set aside. It is not part of the design.

## Site basics

- Language: Spanish, `<html lang="es">`. Page titles: `Obra — atesoraroseta`, `Sobre mí — atesoraroseta`, and so on.
- Wordmark: **atesoraroseta**, always in lower case. It links home.
- Menu, in this order: **Obra · Torn Posters · Sobre mí · Contacto**. "Obra" is the home page.
- A static site is enough. The UI needs no JavaScript (hover is pure CSS). Suggested: Astro with content collections and its image pipeline, or plain HTML and CSS. Any static host works.

## Routes

| Route | Page |
|---|---|
| `/` | Obra: the artwork grid and nothing else besides the header |
| `/obra/[slug]` | One artwork: image, title, year, medium, size, optional text, every detail photo, previous and next |
| `/torn-posters` | Grid of photos of the torn posters that inspired the work |
| `/sobre-mi` | About the artist |
| `/contacto` | Email as a `mailto:` link, plus Instagram |

## Tokens

| Token | Value | Use |
|---|---|---|
| `--ground` | `#222221` | Plain graphite page background (`html, body`) |
| `--surface` | `#2A2A29` | Image placeholders and loading backgrounds |
| `--ink` | `#ECEAE6` | Wordmark, titles, body, current menu item (13:1 on ground) |
| `--ink-2` | `#A8A59F` | Menu, labels, secondary copy (6.5:1) |
| `--ink-label` | `#C9C6C0` | Meta line inside the hover label |
| `--line` | `rgba(236,234,230,.12)` | Hairlines |
| `--underline` | `rgba(236,234,230,.30)` | Text-link underlines |
| `--veil` | `rgba(34,34,33,.84)` + `backdrop-filter: blur(14px) saturate(1.2)` + inset 1px hairline at 8% | Hover label, smoked glass |
| `--accent` | `#D9A55B` (ochre from the work) | Focus ring, link hover, `::selection` (7.3:1) |
| `--ease` | `cubic-bezier(.22, 1, .36, 1)` | Every transition |
| `--shadow-rest` | `drop-shadow(0 2px 3px rgba(0,0,0,.30)) drop-shadow(0 18px 30px rgba(0,0,0,.42))` | Artwork at rest |
| `--shadow-lift` | `drop-shadow(0 4px 6px rgba(0,0,0,.28)) drop-shadow(0 34px 46px rgba(0,0,0,.56))` | Artwork on hover or focus |

Shadows are `filter: drop-shadow`, not `box-shadow`, so a cut-out PNG or WebP casts a shadow that follows the torn edge. A plain rectangular photo still gets a soft rectangle.

### Type

Google Fonts: `https://fonts.googleapis.com/css2?family=Bodoni+Moda:ital,opsz,wght@0,6..96,400..900;1,6..96,400..900&family=Jost:ital,wght@0,100..900;1,100..900&display=swap`

- Serif: `"Bodoni Moda", "Bodoni 72", Didot, Georgia, serif`. Sans: `"Jost", Futura, "Century Gothic", ui-sans-serif, system-ui, sans-serif`.
- **Artwork titles are always Bodoni Moda italic**, as in writing about art. Menus and labels use Jost in spaced capitals.

| Role | Style |
|---|---|
| Wordmark | Bodoni Moda 400, `clamp(27px, 2.35vw, 34px)`, line-height 1, −0.005em, lower case |
| Artwork page title (h1) | Bodoni Moda italic 400, `clamp(34px, 3.4vw, 50px)` / 1.08, `text-wrap: balance` |
| Hover label title | Bodoni Moda italic, 21px / 1.15 (photo tiles 20px) |
| Previous / next titles | Bodoni Moda italic, 22px / 1.2 |
| Lead (Sobre mí) | Bodoni Moda 400, `clamp(28px, 2.65vw, 38px)` / 1.25 |
| Contacto headline | Bodoni Moda 400, `clamp(48px, 6.7vw, 96px)` / 1, −0.01em |
| Email link | Bodoni Moda 400, `clamp(24px, 3.35vw, 48px)` / 1.15 |
| Menu | Jost 450, 12px / 20px, +0.18em, uppercase (+0.12em on phones so it fits one row) |
| Back link | Jost 450, 11.5px / 20px, +0.18em, uppercase, Ink 2 |
| Body | Jost 400, 16px / 1.75 (artwork text 15px / 1.75 in Ink 2) |
| Data values (dd) | Jost 400, 15px / 22px |
| Meta (hover label) | Jost 400, 12.5px / 1.45, +0.02em, `--ink-label` |
| Label (dt, section heads, eyebrows) | Jost 500, 11px / 14px, +0.22em, uppercase, Ink 2 |

## Layout

Container: `max-width: 1440px; margin-inline: auto; padding-inline: clamp(20px, 4.45vw, 64px); padding-bottom: clamp(64px, 8.4vw, 120px)`.

| | Phone, up to 640 | Tablet, 641–1023 | Desktop, 1024 and up |
|---|---|---|---|
| Header | Wordmark, then the four menu items in one row below. No hamburger. | One row | One row: wordmark left, menu right. Not sticky. |
| Obra grid | 1 column, each work full width at its own ratio | 2 columns of 4:5 cells | 3 columns of 4:5 cells |
| Torn Posters | 2 columns of squares, gap 12 | 3 columns, gap 20 | 4 columns, gap 20 |
| Artwork page | Image, then text, then details in 1 column | Same, details in 2 masonry columns | Image (max 860 tall) beside a 360 text column; details in 3 masonry columns |

## Components

### Header
`display:flex; flex-wrap:wrap; justify-content:space-between; align-items:center; gap:0 40px; padding-top:clamp(16px,2.8vw,40px); padding-bottom:clamp(12px,2.5vw,36px)`.
Wordmark has `padding-block: 8px`. Menu `<nav aria-label="Principal"><ul>`, flex with `gap: 0 clamp(14px, 2.2vw, 32px)`. Each link: `display:block; padding-block:12px` so it is 44px tall. The current page gets `aria-current="page"` (Ink plus 1px underline, offset 7px). Inactive items are Ink 2; hover is Ink.

### Obra grid and artwork tile
- Grid: `display:grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 300px), 1fr)); gap: clamp(36px, 3.9vw, 56px)`.
- Each cell is 4:5. The work is **contained at its own proportions and centred**, like works hung on a common line. It is never cropped. The frame gets `aspect-ratio: <width> / <height>` and `width: min(100%, 125% × width/height)`; on phones, `width: 100%`.
- The home page has no visible text besides the header. Add a visually hidden `<h1>Obra</h1>`.

```html
<a class="work" href="/obra/[slug]">
  <figure class="work-frame" style="width: 93.81%; aspect-ratio: 1179 / 1571">
    <img class="work-img" src="…" width="1179" height="1571" alt="…" loading="lazy" decoding="async">
    <figcaption class="hover-label">
      <span class="hover-title">[Título]</span>
      <span class="hover-meta">[Año] · Carteles publicitarios arrancados sobre [soporte]</span>
    </figcaption>
  </figure>
</a>
```

```css
.work-img { display: block; width: 100%; height: 100%; object-fit: contain; }
.hover-label { position: absolute; left: 14px; bottom: 14px; max-width: calc(100% - 28px); box-sizing: border-box;
  display: flex; flex-direction: column; gap: 4px; padding: 11px 14px 12px; border-radius: 2px; }
```
`site.css` already holds `.work`, `.work-frame`, the shadows, the label's glass, its type, and the hover, focus, touch and reduced-motion states.

**Hover and focus:** the frame lifts 6px and the shadow deepens over 700ms. The label fades in over 350ms and rises 8px over 450ms, after a 60ms delay. **Touch (`hover: none`):** no label; a tap opens the artwork page. **Reduced motion:** nothing moves, opacity only. **Keyboard focus:** same as hover, plus a 2px ochre ring around the artwork at offset 10px.

### Artwork page (`/obra/[slug]`)
- Back link "← OBRA" (spaced caps, Ink 2, hover Ink; inline stroke SVG arrow) above the hero.
- Hero: `display:flex; flex-wrap:wrap; align-items:flex-start; gap:clamp(32px,4.45vw,64px)`.
  - Media: `flex: 999 1 560px; min-width:0; display:flex; justify-content:center`. Image `max-width:100%; max-height:860px; width:auto; height:auto` with `drop-shadow(0 2px 3px rgba(0,0,0,.30)) drop-shadow(0 24px 40px rgba(0,0,0,.48))`.
  - Text: `flex: 1 1 300px; max-width: 360px; display:flex; flex-direction:column; gap:28px`. It holds the h1 (Bodoni italic title); a `<dl>` with rows **Año / Técnica / Medidas**, each row `display:flex; gap:16px; padding-block:13px; border-top:1px solid var(--line)` with the dt as an 84px `.label` column and the dd in Jost 15/22; an optional short text (15/1.75, Ink 2); and the text link "Ver los N detalles" to `#detalles`.
- Details: `<section id="detalles">`, `margin-top: clamp(64px, 8.4vw, 120px)`. The `.label` h2 "Detalles" sits over a hairline (padding-bottom 20, margin-bottom 28). Masonry: `columns: 3 300px; column-gap: 24px`. Each `<figure class="detail">` has `margin: 0 0 24px; background: var(--surface)`. Images are flat (no shadow), full column width, natural ratio, lazy-loaded.
- Previous and next: `<nav aria-label="Otras obras">` with a hairline on top, `padding-top: 24px; margin-top: clamp(48px, 6.7vw, 96px)`, `flex-wrap`. Each side shows a spaced-caps label ("ANTERIOR" / "SIGUIENTE" with an arrow) over the Bodoni italic title. "Siguiente" uses `margin-left:auto` and right alignment.

### Torn Posters (`/torn-posters`)
Visually hidden `<h1>`. One intro line: "Fotografías de carteles arrancados que inspiran la obra." (Jost 15/1.6, Ink 2, max-width 520, margin `8px 0 clamp(28px, 2.8vw, 40px)`). Grid `.photo-grid` (in `site.css`). Each tile is `<figure class="photo">` holding an `<img>` with `width:100%; height:100%; object-fit:cover`. Tiles are flat at rest; on hover they lift 4px with a soft shadow and show the same hover label: place (Bodoni italic 20px), then "city · year". Inset 12px, padding 10/13/11. The canvas uses muted flat tints with a faint dot screen as placeholders.

### Sobre mí (`/sobre-mi`)
`flex-wrap` row, gap `clamp(40px, 6.7vw, 96px)`. Portrait: `flex: 1 1 320px; max-width: 540px; aspect-ratio: 4/5`, cropped with cover (placeholder: `--surface` with a faint dot screen). Text column: `flex: 1 1 420px; max-width: 640px; gap: 24px`, holding the `.label` h1 "Sobre mí", the Bodoni lead, Jost body paragraphs, and the text link "Escríbeme" to `/contacto`.

### Contacto (`/contacto`)
`padding-top: clamp(40px, 8.4vw, 120px)`. A column with max-width 920 and gap 22 holds the `.label` h1 "Contacto", the Bodoni headline "Escríbeme" and the email as a Bodoni text link (`mailto:`, `overflow-wrap:anywhere`). Below it, after a hairline row (margin-top `clamp(28px, 3.9vw, 56px)`, padding-top 24), comes the "INSTAGRAM" label with the handle as a text link.

### Links
- `.text-link`: Ink, 1px underline in `--underline`, offset .24em; on hover, ochre with a matching underline.
- `.quiet-link`: Ink 2, no underline; on hover, Ink.
- Focus everywhere: `outline: 2px solid var(--accent); outline-offset: 4px`.

## Content model

```
Artwork  { slug, title, year, medium, size?, text?, order,
           image:   { src, width, height, alt, cutout: boolean },
           details: [ { src, width, height, alt } ] }
Poster   { src, width, height, alt, place, city, year }
Site     { email, instagram, bio (markdown), portrait? }
```
The artist must be able to add works and photos without touching code, for example through Markdown or YAML files in content collections. Order Obra by `order`, then by year descending.

## Images

- **Artworks:** 2400px on the long edge, WebP or AVIF, with `srcset` (600/1200/2400). The best version is cut out along the torn edge on a transparent background, so the shadow follows the paper (`img/obra-01.webp` is prepared this way). Otherwise crop to the paper's edge. Photos shot on black also sit well on the graphite ground.
- **Detail photos and Torn Posters photos:** 2000px, any ratio. Torn Posters are cropped square in CSS.
- Always set `width` and `height`. Lazy-load everything below the first row.
- Alt text: the title plus a short visual description for artworks, and a short description for details and photos.

## Placeholders still to fill
`[Título de la obra]`, `[Año]`, `[soporte]`, `[alto] × [ancho] cm`, the optional artwork text, the previous and next titles, `[Lugar]`, `[Ciudad]`, the portrait, both bio paragraphs, `[tu-correo@dominio.com]` (the mailto currently points at example.com) and `[@usuario]`.
The Sobre mí lead is draft copy for the artist to approve: "Trabajo con fragmentos arrancados de carteles publicitarios: los recojo, los guardo y los vuelvo a componer."

## Done when
- The home page shows only the header and the grid. Labels appear on hover and keyboard focus, never on touch.
- Every tile links to its artwork page, and that page shows every detail photo.
- Each page matches the canvas at 1440 and 390, and nothing scrolls sideways at 320.
- No layout shift as images load. Lighthouse accessibility scores 95 or higher. Reduced motion is respected.
