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

## Warehouse layout (since the new sketch)
```
 z=-23.4  +----------------- Y room -----------------+   +-----------+
          |  (2nd floor over its ends, open middle)   |===|           |
 z=-14    +--------+--------+---------+--------+------+   | EXTRA     |
          | OFFICE |  Z room | utility |  X room |      |   | STOCK     |
 z=4      +--+-----+---+----+-+-------+--+------+--+--+   +-----------+
          |  HALL  |door|      CORRIDOR (belt, desk, boxes) |
 z=10     +--[door]-+----+--[belt hole]------------------+
          x=-10    x=10   x=15                          x=50
```
Outside: plaza + parking (west), loading yard (belt end, robot, pallet, trucks) south of the corridor.
The old layout is kept for reference in docs/old_layout/.

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
- `scenes/levels/town.tscn` - blockout town.

## Town (built: blockout from an aerial reference photo)
Reference: [map_reference_photo.webp](map_reference_photo.webp). The town is generated
at start-up by `scripts/world/town_builder.gd` from the data in
`scripts/world/town_layout.gd` (roads, railway, lakes, fields, zones - edit the numbers
to reshape it). Map coordinates are metres, x east, z south, origin = warehouse centre.

- **Industrial terrain** (north-west, around the warehouse): paved estate with ring
  roads and ~15 large grey boxes; truck yard east of the warehouse.
- **Neighbourhood** (south-west): ~90 houses with pitched roofs on a street grid, a
  shopping street with 6 shops on the entrance street.
- **Railway and main road** curve between industry and neighbourhood; the station
  (under construction, with a train car) sits on the rail beside the neighbourhood.
- **Lakes** (south-east): three lakes, one with a sand beach, ringed with trees and
  fenced with invisible shore barriers. **Farmland** with farm buildings and hedgerows
  to the east. Woods between neighbourhood and lakes.
- **Trees**: 238 instances of `scenes/props/tree.tscn` (your tree1.glb + a trunk collider)
  placed by hand in `scenes/levels/trees.tscn` with random rotations: rings around the
  lakes, woods and hedgerows along the fields. Move/delete/add them in the editor.
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
