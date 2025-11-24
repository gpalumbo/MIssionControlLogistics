-- Mission Control Tower Entity Prototype
-- Based on arithmetic combinator with separate input/output connectors (prevents feedback loops)
-- Similar to receiver combinator design for consistency

-- Constants
local default_circuit_wire_max_distance = 9  -- Standard Factorio circuit wire reach

local mission_control_tower = table.deepcopy(data.raw["arithmetic-combinator"]["arithmetic-combinator"])

-- Basic properties
mission_control_tower.name = "mission-control-tower"
mission_control_tower.minable.result = "mission-control-tower"
mission_control_tower.icon = "__base__/graphics/icons/radar.png"
mission_control_tower.icon_size = 64

-- Health (250, scales with quality - same as radar spec)
mission_control_tower.max_health = 250
mission_control_tower.corpse = "mission-control-tower-remnants"
mission_control_tower.dying_explosion = "radar-explosion"

-- Energy consumption (300kW constant, scales with quality)
mission_control_tower.energy_source = {
  type = "electric",
  usage_priority = "secondary-input"
}
mission_control_tower.active_energy_usage = "300kW"

-- Size: 5x5 (radar-sized, much larger than standard combinator)
mission_control_tower.collision_box = {{-2, -2}, {2, 2}}
mission_control_tower.selection_box = {{-2.5, -2.5}, {2.5, 2.5}}

-- Circuit connector specifications
-- Inherits combinator's input/output connectors (prevents signal mixing)
mission_control_tower.circuit_wire_max_distance = default_circuit_wire_max_distance

-- Graphics will use radar graphics for now
-- TODO: Replace with custom graphics later (5x5 tower with antenna)
-- For now, scale up the combinator sprites
mission_control_tower.sprites = data.raw["radar"]["radar"].pictures

-- Activity LED configuration (reuse combinator's LED system)
mission_control_tower.activity_led_sprites = data.raw["arithmetic-combinator"]["arithmetic-combinator"].activity_led_sprites
mission_control_tower.activity_led_light_offsets = data.raw["arithmetic-combinator"]["arithmetic-combinator"].activity_led_light_offsets

-- Screen light configuration
mission_control_tower.screen_light = data.raw["arithmetic-combinator"]["arithmetic-combinator"].screen_light
mission_control_tower.screen_light_offsets = data.raw["arithmetic-combinator"]["arithmetic-combinator"].screen_light_offsets

-- Flags to ensure proper behavior
-- Add get-by-unit-number flag for cross-surface access
mission_control_tower.flags = {"placeable-player", "player-creation", "get-by-unit-number"}

-- Placement restrictions: planets only (not space platforms)
mission_control_tower.surface_conditions = {
  {
    property = "gravity",
    min = 0.1  -- Requires gravity (planets have gravity, space platforms don't)
  }
}

-- Create remnants entity (use radar remnants for 5x5 size)
local mission_control_tower_remnants = table.deepcopy(data.raw["corpse"]["radar-remnants"])
mission_control_tower_remnants.name = "mission-control-tower-remnants"
mission_control_tower_remnants.icon = "__base__/graphics/icons/radar.png"
mission_control_tower_remnants.icon_size = 64
mission_control_tower_remnants.collision_box = {{-2, -2}, {2, 2}}
mission_control_tower_remnants.selection_box = {{-2.5, -2.5}, {2.5, 2.5}}

-- Extend data
data:extend({
  mission_control_tower,
  mission_control_tower_remnants
})
