-- Receiver Combinator Entity Prototype
-- Based on arithmetic combinator with platform-only placement
-- Arithmetic combinator has both input and output connections for bidirectional communication

-- Constants
local default_circuit_wire_max_distance = 9  -- Standard Factorio circuit wire reach

local receiver_combinator = table.deepcopy(data.raw["arithmetic-combinator"]["arithmetic-combinator"])

-- Basic properties
receiver_combinator.name = "receiver-combinator"
receiver_combinator.minable.result = "receiver-combinator"
receiver_combinator.icon = "__mission-control__/graphics/entities/receiver_icon.png"
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

-- Custom graphics: combinator with dish antenna on top
-- Sprite sheet: 576x124 (4 frames of 144x124 each for N/E/S/W directions)
receiver_combinator.sprites = make_4way_animation_from_spritesheet({
  layers = {
    {
      scale = 0.5,
      filename = "__mission-control__/graphics/entities/receiver-combinator.png",
      width = 144,
      height = 124,
      shift = util.by_pixel(0, 0)
    },
    {
      scale = 0.5,
      filename = "__mission-control__/graphics/entities/receiver-combinator-shadow.png",
      width = 148,
      height = 156,
      shift = util.by_pixel(6, 3),
      draw_as_shadow = true
    }
  }
})

-- Clear arithmetic combinator operation symbol sprites (not needed for receiver)
receiver_combinator.multiply_symbol_sprites = nil
receiver_combinator.plus_symbol_sprites = nil
receiver_combinator.minus_symbol_sprites = nil
receiver_combinator.divide_symbol_sprites = nil
receiver_combinator.modulo_symbol_sprites = nil
receiver_combinator.power_symbol_sprites = nil
receiver_combinator.left_shift_symbol_sprites = nil
receiver_combinator.right_shift_symbol_sprites = nil
receiver_combinator.and_symbol_sprites = nil
receiver_combinator.or_symbol_sprites = nil
receiver_combinator.xor_symbol_sprites = nil

-- LED and screen lights are inherited from arithmetic combinator (required properties)

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
receiver_combinator_remnants.icon = "__mission-control__/graphics/entities/receiver_icon.png"
receiver_combinator_remnants.icon_size = 64

-- Extend data
data:extend({
  receiver_combinator,
  receiver_combinator_remnants
})
