# Models wanted

Everything is a placeholder until a model exists, so nothing here blocks
development. Ordered by when the game needs it. Make them when you have time.

## Export conventions (so they drop straight in)
- Format: `.glb`, saved to `assets/models/`, names in `snake_case` (`pallet.glb`).
- **Scale:** ideally model at real size, 1 Blender unit = 1 metre, scale applied
  (Ctrl+A > Scale). Current `cardboardbox_open.glb` and `shelf.glb` were made at a
  larger scale and are shrunk to 0.22 inside Godot. New models at real size need
  no scaling.
- **Origin:** bottom centre for anything that sits on a floor or shelf (items,
  props, furniture). Wall-mounted pieces: origin at the wall contact point.
- **Facing:** the front of the object should face Blender's front view (-Y), which
  becomes +Z in Godot.
- **Materials:** simple colours or one texture is fine; flat shading looks right
  for the placeholder style. Keep texture size modest (512 or 1024).
- **Animations:** name them exactly as listed below; they appear in Godot's
  AnimationPlayer. Export all actions, with Sampling Animations on.

## Box animation conventions (flat box model)
- Rest pose = the FLAT blank box. Actions named exactly `form` (flat -> open box,
  bottom flaps folded, top left open), `open` and `close` (open <-> closed).
- The last frame of `form` must be the same pose as the last frame of `open`.
- The dispenser plays `form` in the player's hands; boxes placed in the level skip
  straight to the end of it.

## Done
- [x] `cardboardbox_open.glb` - box with `open` / `close` animations
- [x] `shelf.glb` - wall-mounted board with brackets
- [x] `tree1.glb` - tree (real size, ~5.5 m; origin at the trunk base). Placed 238x in scenes/levels/trees.tscn
- [x] `pallet.glb` - wooden pallet (modelled large, scaled 0.2146 in Godot)

## Phase 1 - needed now / next
| Model | Notes |
|---|---|
| **Pallet** | Standard 1.2 x 0.8 x 0.15 m wooden pallet. Closed boxes get placed on top (step 1.3). |
| **Order desk + printer** | Supervisor/reception desk with a printer or terminal on it that prints orders (step 1.4). Can be one model or desk + printer separately. |
| **Box stack / dispenser** | Stack of flat-packed boxes or a box dispenser; players take empty boxes from it. Currently a placeholder of brown slabs. |
| **Paper bill** | A sheet/receipt (about 0.21 x 0.30 m, flat) that lies on the floor when dropped. Currently a flat white box. |
| **Product models** (replace the placeholder cuboids) | Each product as its own `.glb` (one model = one item). Make an `ItemData` in `data/items`, set its `model`, and `model_scale` to bring the model to real metres (a bar drawn 1.15 long that should be 15 cm: 0.13). The game centres the model and stands it on its feet, so its origin does not matter. Done so far: 8 bars (4 flavours x normal/bio), 3 whey tubs, chickpea powder, 3 pill packs (`i_*.glb`). |

## Phase 2-3 - warehouse itself
| Model | Notes |
|---|---|
| **Time clock** | Clock-in/out machine at the entrance. |
| **Entrance door / turnstile** | The boundary between town and warehouse. |
| **Wall, floor and pillar kit** | Plain wall segments, a door frame, floor trim, support pillars, so levels are built from pieces. |
| **Ceiling lights** | Long fluorescent tubes or industrial lamps. |
| **Floor pallet racking** | Tall metal shelving for the stockroom/back storage; 3-4 levels of boards. |
| **Bulk item crate** | Big sealed crate or large cardboard box, for restocking from back storage. |
| **Truck + loading dock** | Cargo area: box truck with open rear, plus a dock edge. |
| **Pallet jack / hand trolley** | Props for atmosphere (and possibly carrying later). |
| **Supervisor desk set** | Office chair, monitor, papers, lamp, phone. |
| **Bins, bags, small clutter** | Trash can, tape roll, clipboard, safety cones, wet-floor sign, fire extinguisher. |

## Phase 4-6 - people and mischief
| Model | Notes |
|---|---|
| **Supervisor character** | Rigged. Animations: `idle`, `walk`, `talk` (lecture), `point`. |
| **NPC employee characters** (2-3 variants) | Rigged. Animations: `idle`, `walk`, `carry` (box in hands), `pick_up`, `stumble`. |
| **Player hands / body** (optional) | Only if you want visible arms; first person works without. |
| **Break-area props** | Vending machine, bench, ashtray. |
| **Gambling spot** | Stacked crates as a table, dice, cards, stools. |
| **Hiding-spot props** | Stacked boxes and tall pallets that block supervisor sight lines. |
| **Black market snacks** | Chips, candy bar, energy drink, sandwich, soda can (edible goods). |
| **Corporate branding** | Logo, posters, banners, floor signs (mostly textures; can be flat planes). |

## Phase 7 - town and home
| Model | Notes |
|---|---|
| **Corporation supermarket + other buildings** | A few distinct low-poly buildings; branded supermarket is the most important. |
| **Your home** | Small interior shell. |
| **Furniture** | Bed (starter and upgrades), sofa, TV, fridge, desk, lamp, rug. Upgrades should look clearly better. |
| **Bike, scooter, car** | Starting bike first. Vehicles you can buy later. |
| **Street props** | Trees, street lamps, benches, fences, mailboxes, road pieces. |
| **Sun and moon** | Simple discs or small models for the sky. |

## Suggested order to make them
1. Pallet
2. Order desk + printer
3. Real models for the 3 starter products
4. Time clock + entrance door
5. Wall/floor kit
6. Bulk crate + floor racking
7. Truck
8. Characters (the biggest effort, so start once the earlier pieces are in)

## Diner furniture (replace the placeholders in `scenes/props/diner/`)
- **Booth** (`booth.tscn`): footprint 1.85 m across x 1.3 m deep, origin at the floor in the middle; the table is in the middle, a bench on each side, the
  open end faces -Z (the wall is behind +Z). Bench seat 0.45 m high, back 0.95 m high, table top 0.74 m. Keep the collision shapes of the scene when you put
  your model inside it (or replace the meshes `BenchLSeat`, `BenchLBack`... with your glb instance).
- **Stool** (`stool.tscn`): seat top 0.65 m, seat 0.38 m across, origin at the floor in the middle.
- **Leather look**: one shared material, `assets/materials/leather_red.tres`: red albedo, `leather_normal.png` (OpenGL/GL normal map, Godot's convention) as
  the normal map, and `leather_arm.png` (AO in R, roughness in G, metal in B, metal is unused) for ambient occlusion and roughness; roughness 0.6 x the map
  (about 0.3: shiny), clearcoat 0.8. It is TRIPLANAR in WORLD space (`uv1_world_triplanar`, 1.5 tiles per metre), so it needs no UVs and looks the same on every mesh,
  whatever its size; the grain stays still if you move the object (fine for furniture; for things that are carried, switch to object-space triplanar). Colour: change
  `albedo_color` (a second leather colour = duplicate the .tres). It is applied by two small inherited scenes, `scenes/props/diner/bar_couch.tscn` (surface
  `leather` of your glb) and `bar_stool.tscn` (surface 1, the seat). Your glb files stay untouched, so re-exporting does not break it. To use the leather on a new model: name its
  leather material `leather` in Blender (as you did), make an inherited scene and set `surface_material_override/<index>`.
- **Blender tip**: the couch and stool have non-uniform object scales (e.g. 0.45 / 0.023 / 0.225) and big mesh units. Apply scale (Ctrl+A > Scale) before export: then
  UVs, normals and physics behave, and the material scale does not depend on the model.
