-- Mission Control Tower Output Combinator
-- Hidden constant combinator used for space->ground signal output
-- Created automatically when a Mission Control Tower is built

local output_combinator = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])

-- Basic properties
output_combinator.name = "mission-control-tower-output"
output_combinator.icon = "__base__/graphics/icons/constant-combinator.png"
output_combinator.icon_size = 64

-- Make it hidden (not selectable, not minable, not shown in menus)
-- Add get-by-unit-number flag so it can be retrieved globally
output_combinator.flags = {"not-on-map", "placeable-off-grid", "not-blueprintable", "not-deconstructable", "get-by-unit-number"}
output_combinator.selectable_in_game = false
output_combinator.minable = nil

-- No collision (shares space with tower)
output_combinator.collision_box = {{0, 0}, {0, 0}}
output_combinator.collision_mask = {layers={}}
output_combinator.selection_box = {{0, 0}, {0, 0}}

-- Minimal health (indestructible in practice)
output_combinator.max_health = 1

-- Circuit connections (same as regular constant combinator)
output_combinator.circuit_wire_max_distance = default_circuit_wire_max_distance

-- Make sprites invisible or minimal
output_combinator.sprites = {
  north = {
    filename = "__core__/graphics/empty.png",
    width = 1,
    height = 1,
    shift = {0, 0}
  },
  east = {
    filename = "__core__/graphics/empty.png",
    width = 1,
    height = 1,
    shift = {0, 0}
  },
  south = {
    filename = "__core__/graphics/empty.png",
    width = 1,
    height = 1,
    shift = {0, 0}
  },
  west = {
    filename = "__core__/graphics/empty.png",
    width = 1,
    height = 1,
    shift = {0, 0}
  }
}

-- Extend data
data:extend({
  output_combinator
})
