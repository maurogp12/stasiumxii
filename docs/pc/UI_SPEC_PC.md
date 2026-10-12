# PC interface (HUD, inventory, character, tooltips, minimap): spec

*Requested by Mauro (12 Oct 2026): "estudia todo lo que nos falta para nuestro juego, vi que nuestra interface está muy feo, no hay mini mapa, no tenemos interface de nivel y características".*

- **Reference:** Wakfu's inventory, character and modulation UI.
- **Source of the reference:** Luca's team packed the video for us in PR #359 (`docs/pc-wakfu-ui-reference`). It holds `docs/pc/look_target/wakfu_ui/README.md`, 16 labelled frames, and a 480p copy of "WAKFU - Interfaz de Inventario y de modulación".
- **Status:** Proposed. **PC only.** It is 2D. Nothing here goes to `main` or `mobile`.

---

## 0. What we have today, and what is wrong

Reviewed from Mauro's screenshots and the PC code (`scenes/world/ui/`, the Crosshaven HUD):

| Today | Problem |
|---|---|
| A top-left debug block: zone name, `Cell 24,29 height 0`, `Eastmarch 20–30 safe`, `Weather: clear 16:28`, `Music: eastmarch`, the controls line | Developer data shown to players |
| A loose yellow stamina bar | No HP, no level and no XP on screen |
| Mission tracker: a dark box top right | Plain; it also lists the same objective twice (being fixed on `claude/pc-shoreline`) |
| `character_window.gd` and `inventory_window.gd` | Plain dark panels. No equipment paper-doll, no item tooltips with comparison, nothing for the new mobile gear slots |
| No minimap and no world map with "you are here" | Hard to find your way |
| No menu bar and no spell or item bar outside combat | No shortcuts |
| A small "Visuals" button | The only menu entry |

## 1. Visual language (from the reference, adapted to our painted world)

The Wakfu style:
- dark charcoal and deep teal panels with thin light borders;
- a ribbed teal title bar with a white centred title and an × on the right;
- green "Activa" and orange or gold "Guardar" buttons;
- clean sans-serif text;
- item frames coloured by rarity;
- windows open and close almost instantly (about 0.1 s fade).

Ours keeps that layout and readability, but uses our palette and a **painted frame kit** (Scenario), so it sits with the dungeon art:

| Token | Use | Proposed |
|---|---|---|
| `panel_bg` | window body | #1d2326, 94% opacity |
| `panel_edge` | 1 px border plus a 2 px inner glow | #6f8a86 |
| `title_bar` | ribbed bar, painted 9-slice | teal #2c5a5c to #1f4446 |
| `accent_ok` | confirm, active | #3fae5a |
| `accent_main` | primary action (Save, Create) | #e0912f |
| `text` / `text_dim` | | #f1ece2 / #a9b0ad |
| Rarity frames | Normal / Rare / Legendary / Ultra (mobile gear tiers) + Epic / Relic | grey #9a9a9a / blue #4a8fe0 / gold #e0b23a / purple #9a62e0 + orange #e07a2f / red #d04848 |

- **Font:** one sans-serif family for the UI. Use the game's current UI font if it has a bold weight, else bundle an open font such as Inter or Nunito.
- **Scaling:** follow Visual Settings, with a UI scale of 0.8–1.4.
- **Hotkeys** (Wakfu-like): **I** inventory, **O** character, **M** map, **L** quests, **Esc** menu, **1–0** slot bar.

## 2. HUD (always on screen in the world)

Reference: `t0050_hud_inventario.jpg`, `t0050_zoom_barra_inferior.jpg`, `t0050_zoom_arriba_derecha.jpg`.

| Area | Content |
|---|---|
| **Bottom centre** | **Class emblem orb**: the class crest in a round frame. **HP current / max** sits above it, with a red fill that drops as HP drops. The **level** sits in a small medallion under the orb. A thin **XP bar** runs along the whole bottom bar, with a "Lv 23 · 45%" tooltip. The **stamina** bar (run) hugs the orb as a small arc instead of a loose bar |
| **Bottom left** | **Menu buttons**, about 10 icons: Character (O), Inventory (I), Spells, Quests (L), Map (M), Dungeons and stars, Koliseo, Shop (premium), Settings (Esc) |
| **Bottom right** | **Slot bar**: 8 slots for consumables and items, with page arrows 1/2. In combat the existing combat HUD takes over; outside combat these are item slots |
| **Top right** | **Minimap** (§6), with the **Shop** button and quick icons (mail or notifications, Performance mode) under it |
| **Right edge, under the minimap** | **Quest tracker**, restyled: collapsible, title plus objectives with checkboxes, max 3 quests, click to open the quest log |
| **Top left** | **Zone banner**: zone name and level band (e.g. "Saltmaw Sea Caves · 20–30"), and a red **danger** tag in danger zones. It shows big for 3 s on entering a zone, then a small line |
| **Removed for players** | Cell, height, weather, time, music and the controls line. Keep them behind a debug toggle (F3 or a `--debug-hud` flag). The controls line shows only on the first play, as a hint that fades |

## 3. Inventory window (I)

Reference: `t0050_hud_inventario.jpg`, `t0275_zoom_inventario_cabecera.jpg`, `t0245_pestana_cosmeticos.jpg`, `t0190_menu_clic_derecho.jpg`.

- **Header:** title "Inventario" with ×. Below it, a row of tab icons: All, Equipment, Consumables, Resources, Keys, Cosmetics. Then a **search** field and a **sort** button (A–Z, rarity, level, newest).
- **Bags:** collapsible sections with a capacity count (e.g. "Bolsillos 24/30"), each a **5-column grid of square slots**. The quantity sits bottom-right, and the frame is coloured by rarity. A new-item dot marks fresh drops.
- **Footer:**
  - the money total (coins, with the coin icon);
  - the extra bag slots;
  - a **sell / trade** entry. Mauro wants selling and trading; it waits on that feature.
- **Interactions:**
  - **double-click** equips;
  - **right-click** opens a menu: Equip, Compare, Fuse (when 2 copies exist at the same +), Sell, Drop;
  - **drag** to the paper-doll or the slot bar.
- **Tooltips:** §5.

## 4. Character window (O), Wakfu-style 3 columns

Reference: `t0420_ventana_personaje_builds.jpg`, `t0470_comparar_equipado.jpg`, `t0530_filtro_casco_y_tooltip.jpg`, `t0555_biblioteca_hechizos.jpg`, `t0585_caracteristicas.jpg`.

| Column | Content |
|---|---|
| **Left: Builds** | A list of saved builds (name, level, Active tag), search and a **+ New** button. A build saves the equipment, spells and characteristic points. One build is active. **Phase 2**: the window works with a single build first |
| **Centre: the hero** | The **painted hero**, using the visible-gear layers from `claude/pc-visible-gear`, so what you wear shows here. The **equipment slots** sit around it: Weapon, Head, Chest, Legs, Boots (the mobile gear slots), plus Ring ×2 and Epic and Relic if those stay. Each slot shows the item icon, its **+ level** and a set-bonus pip. Clicking an empty slot filters the right column to that slot. Under the hero: the **set bonus panel** (2/4/5-piece, lit when active) |
| **Right: tabs** | **Equipables:** an owned-gear list filtered by class and slot, sortable, with tooltips. **Spells:** the class spell list with descriptions (read-only for now). **Characteristics:** see below |
| **Header** | The hero name and class; the build name and level; **Save**; **Active** |

**Characteristics tab** (our system, laid out like Wakfu's):
- **Totals block:** HP, AP, MP, Mastery, Resist, Init, Crit %. Each shows its sources on hover: base, level, gear, set bonus, characteristic points.
- **Points block:** the PC's four characteristic buckets (`pc_progress.spend()` / `stat_names`), each with **Remaining**, **− / +** and a hover tooltip showing the current and next value.
- **Respec** button, showing its cost from `next_respec_cost()`.
- **Points to spend:** a "+N" badge on the Character menu button.

## 5. Item tooltips (everywhere)

Reference: `t0150_tooltip_objeto.jpg`, `t0470_comparar_equipado.jpg`.

1. **Rarity banner** (Normal / Rare / Legendary / Ultra / Epic / Relic, in the rarity colour).
2. **Name and + level**, icon, type (Head, Chest…), class fit ("Ironjaw only" / "Any class"), and the level needed (in red if too high).
3. **Stats:** HP, Mastery, Resist, Init, Crit %, with the value at the current + and the next + in grey.
4. **Set block:** the set name, pieces owned / 5, and the 2/4/5 bonuses (lit if active).
5. **Comparison:** holding **Shift**, or always on for gear, shows a **second tooltip with the equipped item** side by side. The differences are green (+) or red (−).
6. **Source line:** where it drops (dungeon and star), or "Koliseo shop · 30 coins" for Ultra.

## 6. Minimap and world map

The video doesn't show one. Mauro and Luca both want it.
- **Minimap**, top right:
  - a **round painted frame**, about 190 px at 1080p;
  - it shows the current chunk, top-down and simplified (ground colours, water, roads, buildings as blocks);
  - the hero arrow sits in the centre;
  - icons for NPCs with a quest (!), dungeon doors, exits, and the quest target;
  - the zone name and coordinates under it;
  - **+ / −** zoom (3 levels).
  - Build it from the zone data (walkable, terrain and water cells) into a small texture per chunk, cached. Don't render the live scene. In Performance mode it updates at a lower rate.
- **World map (M):** the island with the 5 towns, the Crossroads, the outskirts and the dungeons. It shows the level band per area and the danger zones in red, "You are here", and the quest markers. Discovered areas are lit and undiscovered ones are fogged.

## 7. Packages (each: its own branch, green suites, before/after clip, CHANGE_LOG_PC.md row, no merge to main/mobile)

| # | Package | Content | Depends on |
|---|---|---|---|
| U0 | `pc/ui-style` | **3 full-screen HUD mockups** (Scenario) for Mauro to choose the style. Then the painted 9-slice frame kit, buttons, rarity frames, icons and font tokens | none |
| U1 | `pc/ui-hud` | The new HUD (§2). The debug block goes behind F3 | U0 |
| U2 | `pc/ui-minimap` | Minimap and world map (§6) | U0 |
| U3 | `pc/ui-inventory` | Inventory (§3) and tooltips (§5) | U0, mobile gear port (`claude/pc-mobile-gear`) |
| U4 | `pc/ui-character` | Character window (§4) with the paper-doll, slots, set bonuses and characteristics | U0, U3, visible gear (`claude/pc-visible-gear`) |
| U5 | later | Builds (Wakfu "modulation"), sell / trade, mail | Mauro's decisions |

**Tests to add:**
- every window opens and closes by its hotkey and by its button;
- the HUD values follow `pc_progress` and the hero HP;
- the debug block is hidden by default;
- tooltip comparison maths;
- the minimap shows the hero at the right cell;
- equipping from the inventory updates the paper-doll, the stats and the visible gear;
- Performance mode is respected.

## 8. Open questions for Mauro
1. **Who builds it:** Claude's team (my agents), or Luca's team? Luca's team packed the reference and asked for this spec.
2. **Builds (modulation):** in the first version or later? (Proposed: later.)
3. **Minimap shape:** round as proposed, or square?
4. **Slot bar outside combat:** consumables only, or also emotes and mounts later?
