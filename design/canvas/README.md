# Design canvas, local copy

Source: https://claude.ai/artifact/1ztW4VbnoU3EeApQhkp8vo (version 1791660056-ca18, read 2026-10-10).

## `source/`: the artboards as published

Each `*.dc.html` file is one artboard. Layout values are its inline styles, and they are exact.
DESIGN.md summarises them. Where the two differ on a value, the artboard wins.

- Desktop at 1440: `Main` (Obra, the home page), `Obra-detalle`, `Torn-posters`, `Sobre-mi`, `Contacto`.
- Phone at 390: the `*-movil` files import the desktop artboard at 390px. Phone layouts come only from `site.css` media queries and flex-wrap.
- `Guia.dc.html` is the build guide. It says "Grids are intrinsic (auto-fill), so they reflow without extra breakpoints", so implement the grid formulas exactly. The breakpoint table in DESIGN.md is approximate.
- `/_blob/820bdd10bade960af13d0d291b9208bd` is `design/site.css` (byte-identical, sha256 9631bdde…).
- The canvas also holds a stale `project/site.css`: a light "paper" draft set in Instrument Serif. It is deliberately not copied here, so never use it.
- `{{demoClass}}` is the canvas's pinned hover demo (`is-demo`). Never ship it. In production every tile is `work` / `photo`.
- `Font-options` and `design/explorations/` are out of scope.

## `reference/`: renderable copies for visual comparison

The five desktop artboards as plain HTML, using `../../site.css` and `../../img/*`. Template slots are filled with the production values and the demo is off.
Open them with `file://`, or screenshot them next to the Rails pages at the same width.
Fonts load from Google Fonts here on purpose, to show the canvas's exact rendering. The production app self-hosts them.

**Screenshot gotcha:** headless Chrome's window can't be narrower than ~500px, so `--window-size=390,…` silently lays the page out at ~500px and crops it.
For 390 and 320, use CDP `Emulation.setDeviceMetricsOverride` (Selenium: `driver.execute_cdp`), or load the page inside an `<iframe>` of the exact width.

## Asset map (canvas blob → local file)

| Blob | File | Canvas use |
|---|---|---|
| 556e441e… | img/obra-01.webp (1179×1571, alpha) | Tile 1 + artwork page |
| cf52b065… | img/obra-03.jpg (620×480) | Tile 2 |
| 4098a38e… | img/obra-08.jpg (300×560) | Tile 3 |
| 9295ffaf… | img/obra-04.jpg (560×560) | Tile 4 |
| 804f39aa… | img/obra-02.jpg (460×600) | Tile 5 (the demo tile) |
| 3f967298… | img/obra-07.jpg (680×408) | Tile 6 |
| d439cbf4… | img/obra-06.jpg (380×470) | Tile 7 |
| c609e487… | img/obra-05.jpg (600×400) | Tile 8 |
| 3db345a1… | img/obra-09.jpg (535×420) | Tile 9 |
| fb312a8e… | img/obra-01-d5.jpg (340×420) | Detail 1 |
| a84f51d8… | img/obra-01-d1.jpg (420×290) | Detail 2 |
| 4e3b0b3d… | img/obra-01-d6.jpg (470×290) | Detail 3 |
| 990d5c4c… | img/obra-01-d8.jpg (250×400) | Detail 4 |
| 64f69b77… | img/obra-01-d3.jpg (420×290) | Detail 5 |
| c3f6174b… | img/obra-01-d2.jpg (400×400) | Detail 6 |
| d2d4218c… | img/obra-01-d4.jpg (440×330) | Detail 7 |
| f1ffcb2d… | img/obra-01-d7.jpg (420×315) | Detail 8 |
