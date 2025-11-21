-- Mission Control Tower Entity Prototype
-- Based on arithmetic combinator with separate input/output connectors (prevents feedback loops)
-- Similar to receiver combinator design for consistency

local mission_control_tower = table.deepcopy(data.raw["arithmetic-combinator"]["arithmetic-combinator"])

-- Basic properties
mission_control_tower.name = "mission-control-tower"
mission_control_tower.minable.result = "mission-control-tower"
mission_control_tower.icon = "__mission-control__/graphics/icons/tower_icon.png"
mission_control_tower.icon_size = 120

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

-- Graphics: Custom tower sprites with layered structure
-- Tower sprite is 1568x2032 (likely 7x8 spritesheet or animation frames)
-- Using layered approach similar to radar for proper rendering
mission_control_tower.sprites = {
  layers = {
    -- Main tower sprite
    {
      filename = "__mission-control__/graphics/icons/tower.png",
      width = 224,
      height = 254,
      frame_count = 1,
      shift = {0, 0},
      scale = 1
    },
    -- Shadow layer
    {
      filename = "__mission-control__/graphics/icons/tower-shadow.png",
      width = 224,
      height = 170,
      frame_count = 1,
      shift = {0.75, 0.5},
      draw_as_shadow = true,
      scale = 1
    },
    -- Integration layer (circuit connection visuals)
    {
      filename = "__mission-control__/graphics/icons/tower-integration.png",
      width = 238,
      height = 216,
      frame_count = 1,
      shift = {0, 0},
      scale = 1
    },
    -- Reflection/light layer
    {
      filename = "__mission-control__/graphics/icons/tower-reflection.png",
      width = 28,
      height = 32,
      frame_count = 1,
      shift = {0, -1},
      blend_mode = "additive",
      scale = 1
    }
  }
}

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
mission_control_tower_remnants.icon = "__mission-control__/graphics/icons/tower_icon.png"
mission_control_tower_remnants.icon_size = 120
mission_control_tower_remnants.collision_box = {{-2, -2}, {2, 2}}
mission_control_tower_remnants.selection_box = {{-2.5, -2.5}, {2.5, 2.5}}

-- Extend data
data:extend({
  mission_control_tower,
  mission_control_tower_remnants
})
