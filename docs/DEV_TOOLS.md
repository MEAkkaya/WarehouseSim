# Dev tools (DEVELOPMENT ONLY - REMOVE BEFORE PUBLISHING)

The phone has a **Dev** app (button "DEV", last on the home screen) with cheats for testing:

- **Time:** +1 h, +6 h, jump to 06:00 / 08:00 (next day) / noon / 18:00 / 23:00 / midnight, clock speed x1 / x5 / x20 / x60, freeze the clock.
- **Money and shift:** +$1,000, +$100,000, clock in / out, multiplier +0.5, power outage (blackout) toggle.
- **Body:** refill energy, refill health, infinite energy toggle.
- **Teleport:** start, warehouse entrance, home, gambling apartment, club apartment, park, station, each tunnel, each lake (from the town layout). The phone closes after a teleport.
  "Copy my position" puts `Vector2(x, z)` on the clipboard (handy for adding places). The page also shows your live coordinates.

It only exists in **debug builds** (`DevPage.AVAILABLE = OS.is_debug_build()`), so an exported release never shows it. That is only a safety net - take the code out anyway.

## Before publishing: remove it

1. Delete the folder `scripts/dev/` (`dev_page.gd` and its `.uid`).
2. In `scripts/ui/phone.gd` delete every line marked `DEV-ONLY`: the two lines in `_build_ui` (`if DevPage.AVAILABLE:` and the call under it) and the function `_build_dev_app` at the end of the file.
   Search for `DEV-ONLY` to find them all.
3. Run `--headless --import` and make sure nothing reports a missing `DevPage`.
4. Tick it off in `docs/ROADMAP.md` ("Release checklist").

Adding a cheat or a place: edit `scripts/dev/dev_page.gd` (`PLACES` for teleports, `_ready` for buttons). Nothing else in the game knows about it.
