# World map (stub)

Sketch by the designer: [map_stub.png](map_stub.png). Not to scale.

## Overview
- **Neighbourhood**: lots of houses and shop spots; buildings stay empty shells for now.
- **Train station** (under construction): will allow travel to other areas later.
- **Truck** parks on a yard east of the loading area.
- NOTE: the town layout was redone after the first sketch to follow an aerial photo
  (see "Town" below); the sea/rocky beach of the first sketch is gone, replaced by lakes.
- **Warehouse** (north): loading area + reception/boxes at the south, three shelf
  regions (X east, Z west, Y north across the top), and a separate **Storage**
  room to the east (bulk boxes for restocking, Phase 3).

## Night spots (south of the shopping street)
Two apartment blocks stand on the neighbourhood's south street at (42, 130) and (60, 130): the one with the
shady **Back Room** (top floor, Mon-Fri) and the one with the **Underground Club** (back door in the yard on its
north side, Fri-Sun nights). Both are marked on the phone map; opening hours are in the Places app.

## Warehouse layout (the big version)
```
 z=-31.7  +---------------------- Y room (8 corridors, YA at the east) ----------------+   +-----------+
          |  2nd floor over both ends, open in the middle                             |===| EXTRA     |
 z=-20.9  +-----------+---------+------------------+-------+------------------------+   | STOCK     |
          |  Z room   | utility |      X room (XA at the south door)                 |   |           |
 z=2      +--[door]---+---------+--------------------[door]------------------------+   +-----------+
          | HALL |      CORRIDOR (belt, desk, boxes)                                  |
 z=10     +--[door]-+----+--[belt hole]----------------------------------------------+
          x=10  (hall + office are west of x=10)                                     x=53.5   (stock x 59.5..75.5)
```
Aisles between the shelf rows are 2.6 m wide (`StorageRegion.aisle_width`), the rooms have 2-3 m of free floor around the shelves.
Outside: plaza + parking (west), loading yard (belt end, robot, pallet, trucks) south of the corridor.
Older layouts are kept for reference in docs/old_layout/.

## Storeroom regions (built: `scripts/world/storage_region.gd`)
Regions X, Y and Z are blocks of parallel corridors made of free-standing boltless
shelves (`boltlessshelf.glb`, one layer per shelf, stacked). Shelves stand back
to back between corridors; there are no walls inside the regions.

| Region | Corridors | Notes |
|---|---|---|
| X | 5 (A-E) | east, below Y |
| Z | 5 (A-E) | west, below Y |
| Y | 8 (A-H) | north, across the top |

Each corridor has 10 columns (5 per side) and 4 shelf levels = 40 shelves, so X/Z
have 200 shelves each and Y has 320. Counts are exports on the region node
(`corridor_count`, `columns_per_side`, `levels`, `aisle_width`).

## Shelf IDs
`<region><corridor letter> <column> <level>` - e.g. **XC 04 03**:
region X, corridor C (3rd), column 04, level 03 (3rd board, counted from the bottom).

- Walking into a corridor from its entrance: the **left** side holds the **odd**
  columns, the **right** side the **even** columns.
- Columns grow as you walk further in: 01 (left) / 02 (right) are at the entrance,
  03 / 04 behind them, and so on.
- Levels count from the bottom starting at 1.
- Shelves are created empty. Items will be assigned per ID later
  (`StorageRegion.get_shelf("XC 04 03")`).

## Test level placement
`scenes/levels/warehouse.tscn`: the old work area (desk, box piles, pallet, the 9
test shelves on the back wall) stays around the origin; the regions sit north of
the work area (Z at x -22.8, X at x 4.8, both starting z -8; Y at x -14.4, z -19.7).
The test back wall was removed; the 9 test shelves stand free as 3 stacks of 3.

## Route through the storeroom (built)
The storeroom is a one-way loop: **entrance door (reception wall, above region X) ->
X -> up to the cross aisle -> Y (up one corridor, along the north aisle, down
another) -> Z -> exit door (reception wall, below Z)**. A divider wall between X
and Z, closed corners at the cross aisle and the outer walls force this order.
Verified with a flood fill over the physics world: with Y blocked off, Z and the
exit are unreachable from the entrance. (The doors are open gaps, so walking
backwards is possible; real one-way doors/turnstiles come later.)

## Scenes
- `scenes/levels/world.tscn` - MAIN SCENE: sky/sun/moon, player, town, warehouse
  shell (outer walls + door) and the `WarehouseSite` entrance logic.
- `scenes/levels/warehouse.tscn` - the INTERIOR only: floor, work area, storeroom
  regions, inner walls. Created when you walk in, deleted when you walk out.
- The town is part of `world.tscn` (node `Town`); see "Town" below.

## Town (built: blockout from an aerial reference photo)
Reference: [map_reference_photo.webp](map_reference_photo.webp). The town is generated
as ordinary nodes in `world.tscn` under `Town` (ground, roads, railway, lakes, fields,
buildings, props, trees: move them in the editor). Only the neighbourhood's houses, the
sidewalks and the vegetation are generated at start-up by `scripts/world/town_builder.gd`,
which first reads those nodes so nothing lands on them (see docs/SYSTEMS.md "Town").
Map coordinates are metres, x east, z south, origin = warehouse centre.

- **Industrial terrain** (north-west, around the warehouse): paved estate with ring
  roads (the bigger warehouse leaves no room for the random factory boxes of the first
  version: place `Buildings/Industrial` boxes by hand); truck yard east of the warehouse.
- **Neighbourhood** (south-west): 74 houses with pitched roofs, 7 apartment blocks (all placed nodes under
  `Town/Buildings/Houses`, `House01`..`Apartment07`) on a street grid, a
  shopping street with 6 shops on the entrance street.
- **Railway and main road** curve between industry and neighbourhood; the station
  (under construction, with a train car) sits on the rail beside the neighbourhood.
- **Lakes** (south-east): three lakes, one with a sand beach, ringed with trees and
  fenced with invisible shore barriers; each lake is a real basin (bank, bed, water 0.7 m below the ground). **Farmland** with farm buildings and hedgerows
  to the east. Woods between neighbourhood and lakes.
- **Park**: west of the neighbourhood, (-46, 120): lawn, benches, trees, lamps and a dog-park pen (`Town/Props/Park`).
- **Trees**: 238 instances of `scenes/props/tree.tscn` (your tree1.glb + a trunk collider)
  placed by hand under `Town/Trees` in `world.tscn` with random rotations: rings around the
  lakes, woods and hedgerows along the fields. Move/delete/add them in the editor.
- **Cliffs**: a cliff wall (about 40 m high) closes the town on every side, just behind the invisible border walls.
- **Tunnels**: the main road leaves the map through two tunnels, north (185, -95) and west (-60, 298); each is a node under `Town/Tunnels`. The main road got two extra points so it meets the border straight.
- **World border**: invisible walls around x -60..360, z -95..300, a huge ground slab
  beyond it, and distance fog (colour follows the sky) so the edge is never seen.
  Far chunks of houses/trees are also not drawn beyond `view_distance` (330 m).
- You spawn on the entrance street in the neighbourhood (about 85 m from the door).

## Lobby (built)
Behind the outer door is a small lobby (16 x 5 m) that belongs to the building shell
and is ALWAYS loaded, so entering never shows an unloaded room. A second wall with
the "WAREHOUSE FLOOR - CLOCK IN" door separates it from the warehouse floor. Standing
in the lobby loads the interior; the inner door stays shut until it is ready, then
slides down into the floor. Stepping onto the floor clocks you in; stepping back into
the lobby clocks you out (what you carry stays behind); leaving to town deletes the
interior. Logic: `scripts/world/warehouse_site.gd` (LobbyZone and WorkZone).
