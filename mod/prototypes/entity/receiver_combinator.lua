-- Receiver Combinator Entity Prototype
-- Based on arithmetic combinator with platform-only placement
-- Arithmetic combinator has both input and output connections for bidirectional communication

local receiver_combinator = table.deepcopy(data.raw["arithmetic-combinator"]["arithmetic-combinator"])

-- Basic properties
receiver_combinator.name = "receiver-combinator"
receiver_combinator.minable.result = "receiver-combinator"
receiver_combinator.icon = "__mission-control__/graphics/icons/receiver-combinator.png"
receiver_combinator.icon_size = 64

-- Health (same as arithmetic combinator spec: 150, scales with quality)
receiver_combinator.max_health = 150
receiver_combinator.corpse = "receiver-combinator-remnants"
receiver_combinator.dying_explosion = "arithmetic-combinator-explosion"

-- Energy consumption (50kW base, scales with quality)
-- Quality scaling: uncommon:40kW, rare:30kW, epic:15kW, legendary:5kW
receiver_combinator.energy_source = {
  type = "electric",
  usage_priority = "secondary-input"
}
receiver_combinator.active_energy_usage = "50kW"

-- Size: 2x1 combinator (same as constant combinator)
receiver_combinator.collision_box = {{-0.35, -0.9}, {0.35, 0.9}}
receiver_combinator.selection_box = {{-0.5, -1}, {0.5, 1}}

-- Circuit connector specifications
receiver_combinator.circuit_wire_max_distance = default_circuit_wire_max_distance

-- Graphics: Use arithmetic combinator sprites as fallback since no entity sprites exist yet
-- Custom icon is used from mod graphics
-- TODO: Create custom entity sprites (combinator with dish antenna on top)
receiver_combinator.sprites = data.raw["arithmetic-combinator"]["arithmetic-combinator"].sprites

-- Activity LED configuration
receiver_combinator.activity_led_sprites = data.raw["arithmetic-combinator"]["arithmetic-combinator"].activity_led_sprites
receiver_combinator.activity_led_light_offsets = data.raw["arithmetic-combinator"]["arithmetic-combinator"].activity_led_light_offsets

-- Screen light configuration (for display)
receiver_combinator.screen_light = data.raw["arithmetic-combinator"]["arithmetic-combinator"].screen_light
receiver_combinator.screen_light_offsets = data.raw["arithmetic-combinator"]["arithmetic-combinator"].screen_light_offsets

-- Placement restrictions: space platforms only (opposite of mission control tower)
receiver_combinator.surface_conditions = {
  {
    property = "gravity",
    max = 0.05  -- Requires low/no gravity (space platforms have no gravity)
  }
}

-- Flags to ensure proper behavior
-- Add get-by-unit-number flag so the entity can be retrieved globally
receiver_combinator.flags = {"placeable-player", "player-creation", "get-by-unit-number"}

-- Create remnants entity
local receiver_combinator_remnants = table.deepcopy(data.raw["corpse"]["arithmetic-combinator-remnants"])
receiver_combinator_remnants.name = "receiver-combinator-remnants"
receiver_combinator_remnants.icon = "__mission-control__/graphics/icons/receiver-combinator.png"
receiver_combinator_remnants.icon_size = 64

-- Extend data
data:extend({
  receiver_combinator,
  receiver_combinator_remnants
})
