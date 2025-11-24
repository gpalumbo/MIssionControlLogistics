--- Receiver Combinator entity management
-- Handles creation, destruction, and lifecycle of receiver combinators on space platforms
-- Receivers transmit signals bidirectionally between space and ground

local globals = require("scripts.globals")
local network_manager = require("scripts.network_manager")
local receiver_combinator = {}

--- Get a platform by its index (searches all forces)
--- @param platform_index uint Platform index
--- @return LuaSpacePlatform|nil The platform or nil if not found
local function get_platform_by_index(platform_index)
  for _, force in pairs(game.forces) do
    local platform = force.platforms[platform_index]
    if platform then
      return platform
    end
  end
  return nil
end

--- Find the platform that an entity belongs to
--- @param entity LuaEntity The entity to check
--- @return LuaSpacePlatform|nil The platform, or nil if not on a platform
local function get_entity_platform(entity)
  if not entity or not entity.valid then
    return nil
  end

  local surface = entity.surface

  -- Check if this surface belongs to a space platform
  -- In Factorio 2.0, platform surfaces have a platform property
  if surface.platform then
    return surface.platform
  end

  -- Alternative: search through all platforms
  for _, force in pairs(game.forces) do
    for _, platform in pairs(force.platforms) do
      if platform.surface == surface then
        return platform
      end
    end
  end

  return nil
end

--- Create a receiver combinator on a space platform
--- @param entity LuaEntity The receiver combinator entity just built
--- @param player_index uint|nil The player who built it (for undo support)
--- @param tags table|nil Blueprint tags (from event.tags in Factorio 2.0+)
function receiver_combinator.on_built(entity, player_index, tags)
  if not entity or not entity.valid then
    return
  end

  -- Verify this is a receiver combinator (handle ghosts)
  local entity_name = entity.name
  if entity.type == "entity-ghost" then
    entity_name = entity.ghost_name

    -- Try to get config from event.tags first, then from entity.tags (blueprint placement)
    local config = nil
    if tags and tags.receiver_config then
      config = tags.receiver_config
    elseif entity.tags and entity.tags.receiver_config then
      config = entity.tags.receiver_config
    end

    if config then
      globals.save_ghost_receiver_config(entity, config)
    end
    return  -- Don't register ghosts
  end

  if entity_name ~= "receiver-combinator" then
    return
  end

  -- Find the parent platform
  local platform = get_entity_platform(entity)

  if not platform then
    -- Not on a space platform - this shouldn't happen due to placement restrictions
    game.print("[Mission Control] Warning: Receiver combinator must be placed on a space platform")
    entity.destroy()
    return
  end

  local surface = entity.surface
  local position = entity.position
  local force = entity.force

  -- Create TWO hidden constant combinators for ground->space signal output
  -- Need separate combinators for red and green to prevent signal duplication
  local output_combinator_red = surface.create_entity({
    name = "receiver-combinator-output",  -- Hidden constant combinator
    position = position,
    force = force,
    create_build_effect_smoke = false,
    raise_built = false  -- Don't trigger build events for hidden entity
  })

  local output_combinator_green = surface.create_entity({
    name = "receiver-combinator-output",  -- Hidden constant combinator
    position = position,
    force = force,
    create_build_effect_smoke = false,
    raise_built = false  -- Don't trigger build events for hidden entity
  })

  if not output_combinator_red or not output_combinator_green then
    game.print("[Mission Control] Warning: Failed to create output combinators for receiver")
    if output_combinator_red and output_combinator_red.valid then output_combinator_red.destroy() end
    if output_combinator_green and output_combinator_green.valid then output_combinator_green.destroy() end
    return
  end

  -- Make the combinators indestructible and hidden
  output_combinator_red.destructible = false
  output_combinator_red.minable = false
  output_combinator_red.rotatable = false

  output_combinator_green.destructible = false
  output_combinator_green.minable = false
  output_combinator_green.rotatable = false

  -- Connect red output combinator ONLY to red wire (prevents duplication)
  local receiver_output_red = entity.get_wire_connector(defines.wire_connector_id.combinator_output_red, false)
  local output_red = output_combinator_red.get_wire_connector(defines.wire_connector_id.circuit_red, false)

  if receiver_output_red and output_red then
    output_red.connect_to(receiver_output_red, false, defines.wire_origin.script)
  end

  -- Connect green output combinator ONLY to green wire (prevents duplication)
  local receiver_output_green = entity.get_wire_connector(defines.wire_connector_id.combinator_output_green, false)
  local output_green = output_combinator_green.get_wire_connector(defines.wire_connector_id.circuit_green, false)

  if receiver_output_green and output_green then
    output_green.connect_to(receiver_output_green, false, defines.wire_origin.script)
  end

  -- Register the receiver in global storage (stores entity references directly)
  globals.register_receiver(entity, output_combinator_red, output_combinator_green, platform)

  -- Apply configuration from blueprint tags if present
  if tags and tags.receiver_config then
    globals.restore_receiver_config(entity, tags.receiver_config)
  end

  -- Update platform location cache immediately for this platform
  -- This handles the case where a receiver is built while platform is already stationary
  local surface_index = nil
  if platform.space_location then
    local planet = game.planets[platform.space_location.name]
    if planet and planet.surface then
      surface_index = planet.surface.index
    end
  end
  globals.update_platform_location(platform.index, surface_index)

  -- Trigger an immediate signal update to connect to any towers on the current planet
  network_manager.on_tick_update()
end

--- Destroy a receiver combinator
--- @param entity LuaEntity The receiver combinator being destroyed
function receiver_combinator.on_destroyed(entity)
  if not entity or not entity.valid then
    return
  end

  if entity.name ~= "receiver-combinator" then
    return
  end

  local unit_number = entity.unit_number

  -- Find and destroy the linked output combinators using stored references
  local receiver_data = storage.receivers and storage.receivers[unit_number]
  if receiver_data then
    if receiver_data.output_entity_red and receiver_data.output_entity_red.valid then
      receiver_data.output_entity_red.destroy({raise_destroy = false})
    end
    if receiver_data.output_entity_green and receiver_data.output_entity_green.valid then
      receiver_data.output_entity_green.destroy({raise_destroy = false})
    end
  end

  -- Unregister from global storage
  globals.unregister_receiver(unit_number)
end

--- Handle receiver mined by player (for item return)
--- @param entity LuaEntity The receiver entity being mined
--- @param player_index uint The player mining it
function receiver_combinator.on_mined(entity, player_index)
  -- Call regular destroy handler
  receiver_combinator.on_destroyed(entity)

  -- Note: Item return is handled automatically by Factorio
end

--- Handle blueprint/copy-paste operations
--- @param entity LuaEntity The receiver entity (source)
--- @return table|nil Settings to copy
function receiver_combinator.on_copy_settings(entity)
  if not entity or not entity.valid then
    return nil
  end
  return globals.serialize_receiver_config(entity)
end

--- Handle paste settings from blueprint/copy-paste
--- @param entity LuaEntity The target entity (destination)
--- @param settings table The settings to paste
function receiver_combinator.on_paste_settings(entity, settings)
  if not entity or not entity.valid or not settings then
    return
  end

  -- Use universal restore function (handles both ghost and real entities)
  globals.restore_receiver_config(entity, settings)
end

--- Update receiver status (for debugging/diagnostics)
--- @param entity LuaEntity The receiver entity
--- @return table Status information
function receiver_combinator.get_status(entity)
  if not entity or not entity.valid then
    return {error = "Invalid entity"}
  end

  local unit_number = entity.unit_number
  local receiver_data = storage.receivers[unit_number]

  if not receiver_data then
    return {error = "Not registered"}
  end

  local platform = get_platform_by_index(receiver_data.platform_index)

  if not platform then
    return {error = "Platform not found"}
  end

  local status = {
    platform_index = receiver_data.platform_index,
    location = "In transit",
    receiving = false
  }

  if platform.space_location then
    status.location = platform.space_location.name or "Unknown"

    -- Get the surface index from the planet
    local planet = game.planets[platform.space_location.name]
    if planet and planet.surface then
      status.surface_index = planet.surface.index
    end

    status.receiving = true
  end

  return status
end

--- Validate all receivers and clean up orphaned entries
--- Called during migration or diagnostics
function receiver_combinator.validate_all()
  local orphaned = 0

  for unit_number, receiver_data in pairs(storage.receivers) do
    -- Use cached entity reference
    local entity = receiver_data.entity

    if not entity or not entity.valid then
      -- Receiver destroyed but storage entry remains
      storage.receivers[unit_number] = nil
      orphaned = orphaned + 1
    else
      -- Verify platform still exists
      local platform = get_platform_by_index(receiver_data.platform_index)
      if not platform then
        -- Platform destroyed but receiver remains (shouldn't happen)
        game.print("[Mission Control] Warning: Receiver combinator has invalid platform reference")
      end
    end
  end

  if orphaned > 0 then
    game.print(string.format("[Mission Control] Cleaned up %d orphaned receivers", orphaned))
  end
end

return receiver_combinator
