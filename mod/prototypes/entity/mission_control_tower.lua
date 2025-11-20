-- Mission Control Tower Entity Prototype
-- Based on radar entity with circuit network capabilities

local mission_control_tower = table.deepcopy(data.raw["radar"]["radar"])

-- Basic properties
mission_control_tower.name = "mission-control-tower"
mission_control_tower.minable.result = "mission-control-tower"
mission_control_tower.icon = "__base__/graphics/icons/radar.png"
mission_control_tower.icon_size = 64

-- Health and resistances (same as radar, will scale with quality)
mission_control_tower.max_health = 250
mission_control_tower.corpse = "mission-control-tower-remnants"
mission_control_tower.dying_explosion = "radar-explosion"

-- Energy consumption (300kW constant, scales with quality)
mission_control_tower.energy_usage = "300kW"
mission_control_tower.energy_source = {
  type = "electric",
  usage_priority = "secondary-input"
}

-- Circuit connector specifications (4 terminals: red in, red out, green in, green out)
-- We'll use the radar's circuit connector as a base and modify for our needs
mission_control_tower.circuit_connector = circuit_connector_definitions["radar"]
mission_control_tower.circuit_wire_max_distance = default_circuit_wire_max_distance

-- Minimal radar scanning (required, cannot be disabled)
-- Set to minimal values but keep > 0 to satisfy engine requirements
mission_control_tower.energy_per_sector = "10kJ"  -- Minimal energy per sector (must be > 0)
mission_control_tower.max_distance_of_sector_revealed = 1  -- Very small scan range
mission_control_tower.max_distance_of_nearby_sector_revealed = 1  -- Very small nearby range

-- Graphics will use radar graphics for now
-- TODO: Replace with custom graphics later
mission_control_tower.pictures = data.raw["radar"]["radar"].pictures

-- Collision and selection
mission_control_tower.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
mission_control_tower.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}

-- Flags to ensure proper behavior
mission_control_tower.flags = {"placeable-player", "player-creation"}

-- Placement restrictions: planets only (not space platforms)
mission_control_tower.surface_conditions = {
  {
    property = "gravity",
    min = 0.1  -- Requires gravity (planets have gravity, space platforms don't)
  }
}

-- Create remnants entity
local mission_control_tower_remnants = table.deepcopy(data.raw["corpse"]["radar-remnants"])
mission_control_tower_remnants.name = "mission-control-tower-remnants"
mission_control_tower_remnants.icon = "__base__/graphics/icons/radar.png"
mission_control_tower_remnants.icon_size = 64

-- Extend data
data:extend({
  mission_control_tower,
  mission_control_tower_remnants
})
