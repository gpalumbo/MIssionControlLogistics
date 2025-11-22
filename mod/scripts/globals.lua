--- Global storage management for Mission Control mod
-- Handles initialization and migration of persistent data structures

local globals = {}

--- Initialize storage on first load or after reset
function globals.init()
  -- Mission Control networks indexed by surface index
  -- Each surface (planet) has its own MC network
  storage.mc_networks = storage.mc_networks or {}

  -- Receiver combinators indexed by entity unit_number
  -- Tracks all receiver combinators on space platforms
  storage.receivers = storage.receivers or {}

  -- Platform location cache indexed by platform index
  -- Helps avoid repeated API calls for platform position
  storage.platform_locations = storage.platform_locations or {}

  -- Player GUI states indexed by player_index
  -- Tracks which entity GUI each player has open
  storage.player_gui_states = storage.player_gui_states or {}
end

--- Initialize or get MC network for a surface
--- @param surface_index uint Surface index
--- @return table Network data structure
function globals.get_or_create_network(surface_index)
  if not storage.mc_networks[surface_index] then
    storage.mc_networks[surface_index] = {
      -- Mission Control tower entities (unit_number -> entity data)
      tower_entities = {},

      -- Hidden constant combinators for space->ground output (separate red/green to prevent duplication)
      output_combinators_red = {},   -- unit_number -> entity
      output_combinators_green = {}, -- unit_number -> entity

      -- Cached input signals from ground circuits (updated every 15 ticks)
      cached_input_signals = {
        red = {},   -- Array of Signal objects
        green = {} -- Array of Signal objects
      },

      -- Last tick this network was updated
      last_update = 0
    }
  end
  return storage.mc_networks[surface_index]
end

--- Register a Mission Control tower in the network
--- @param surface_index uint Surface index
--- @param entity LuaEntity The tower entity (radar)
function globals.register_tower(surface_index, entity)
  if not entity or not entity.valid then
    log("[Globals] ERROR: Attempted to register invalid tower entity")
    return
  end

  local network = globals.get_or_create_network(surface_index)

  -- Store the entity reference directly (Factorio handles serialization)
  network.tower_entities[entity.unit_number] = entity

  log(string.format("[Globals] Registered tower #%d on surface %d", entity.unit_number, surface_index))

  -- Count towers for debug
  local count = 0
  for _ in pairs(network.tower_entities) do count = count + 1 end
  log(string.format("[Globals] Total towers on surface %d: %d", surface_index, count))
end

--- Register hidden output combinators for a tower
--- @param surface_index uint Surface index
--- @param combinator_red LuaEntity The red constant combinator entity
--- @param combinator_green LuaEntity The green constant combinator entity
function globals.register_output_combinator(surface_index, combinator_red, combinator_green)
  if not combinator_red or not combinator_red.valid or not combinator_green or not combinator_green.valid then
    log("[Globals] ERROR: Attempted to register invalid output combinators")
    return
  end

  local network = globals.get_or_create_network(surface_index)

  -- Store entity references in separate red/green tables
  network.output_combinators_red[combinator_red.unit_number] = combinator_red
  network.output_combinators_green[combinator_green.unit_number] = combinator_green

  -- Debug: verify what we stored
  log(string.format("[Globals] Stored RED output combinator #%d", combinator_red.unit_number))
  log(string.format("[Globals] Stored GREEN output combinator #%d", combinator_green.unit_number))
end

--- Unregister a tower from the network
--- @param surface_index uint Surface index
--- @param unit_number uint Entity unit number
function globals.unregister_tower(surface_index, unit_number)
  if storage.mc_networks[surface_index] then
    storage.mc_networks[surface_index].tower_entities[unit_number] = nil
    log(string.format("[Globals] Removed tower #%d from surface %d network", unit_number, surface_index))

    -- Debug: count remaining towers
    local count = 0
    for _ in pairs(storage.mc_networks[surface_index].tower_entities) do count = count + 1 end
    log(string.format("[Globals] Remaining towers on surface %d: %d", surface_index, count))
  else
    log(string.format("[Globals] WARNING: No network found for surface %d when unregistering tower #%d", surface_index, unit_number))
  end
end

--- Unregister an output combinator from the network
--- @param surface_index uint Surface index
--- @param unit_number uint Entity unit number
function globals.unregister_output_combinator(surface_index, unit_number)
  if storage.mc_networks[surface_index] then
    -- Remove from both red and green tables (it will only be in one)
    storage.mc_networks[surface_index].output_combinators_red[unit_number] = nil
    storage.mc_networks[surface_index].output_combinators_green[unit_number] = nil
    log(string.format("[Globals] Removed output combinator #%d from surface %d network", unit_number, surface_index))

    -- Debug: count remaining combinators
    local red_count = 0
    local green_count = 0
    for _ in pairs(storage.mc_networks[surface_index].output_combinators_red) do red_count = red_count + 1 end
    for _ in pairs(storage.mc_networks[surface_index].output_combinators_green) do green_count = green_count + 1 end
    log(string.format("[Globals] Remaining output combinators on surface %d: %d red, %d green", surface_index, red_count, green_count))
  else
    log(string.format("[Globals] WARNING: No network found for surface %d when unregistering combinator #%d", surface_index, unit_number))
  end
end

--- Register a receiver combinator
--- @param receiver_entity LuaEntity The receiver entity
--- @param output_entity_red LuaEntity The red output combinator entity
--- @param output_entity_green LuaEntity The green output combinator entity
--- @param platform LuaSpacePlatform The parent platform
function globals.register_receiver(receiver_entity, output_entity_red, output_entity_green, platform)
  if not receiver_entity or not receiver_entity.valid then
    log("[Globals] ERROR: Attempted to register invalid receiver entity")
    return
  end

  -- Ensure storage.receivers exists
  if not storage.receivers then
    storage.receivers = {}
    log("[Globals] WARNING: storage.receivers was nil, initializing")
  end

  -- Auto-configure all discovered planets by default
  local default_surfaces = {}
  for _, planet in pairs(game.planets) do
    if planet.surface then
      table.insert(default_surfaces, planet.surface.index)
    end
  end

  log(string.format("[Globals] Auto-configuring receiver for %d planets", #default_surfaces))

  -- Store entity references directly (Factorio handles serialization)
  storage.receivers[receiver_entity.unit_number] = {
    entity = receiver_entity,
    output_entity_red = output_entity_red,
    output_entity_green = output_entity_green,
    platform_index = platform.index,

    -- Surface configuration: which surfaces this receiver communicates with
    -- Default to all known planets for convenience
    configured_surfaces = default_surfaces,  -- Array of surface indices

    -- Signal behavior when in transit
    -- Default to true: maintain last signal during transit (more useful default)
    hold_signal_in_transit = true,  -- If true, hold last signal; if false, clear signals

    -- Cached signals from ground (for hold signal feature)
    last_received_signals = {
      red = {},   -- Last signals received from ground (red wire)
      green = {}  -- Last signals received from ground (green wire)
    },

    -- Cached input signals from platform circuits (updated every 15 ticks)
    cached_input_signals = {
      red = {},
      green = {}
    },

    -- Last tick this receiver was updated
    last_update = 0
  }

  log(string.format("[Globals] Registered receiver #%d (platform %d) with %d configured surfaces",
    receiver_entity.unit_number, platform.index, #default_surfaces))

  -- Count receivers for debug
  local count = 0
  for _ in pairs(storage.receivers) do count = count + 1 end
  log(string.format("[Globals] Total receivers: %d", count))
end

--- Unregister a receiver combinator
--- @param unit_number uint Entity unit number
function globals.unregister_receiver(unit_number)
  storage.receivers[unit_number] = nil
end

--- Update receiver's configured surfaces
--- @param unit_number uint Receiver entity unit number
--- @param surface_indices table Array of surface indices
function globals.set_receiver_surfaces(unit_number, surface_indices)
  local receiver_data = storage.receivers[unit_number]
  if receiver_data then
    receiver_data.configured_surfaces = surface_indices or {}
  end
end

--- Add a surface to receiver's configuration
--- @param unit_number uint Receiver entity unit number
--- @param surface_index uint Surface index to add
function globals.add_receiver_surface(unit_number, surface_index)
  local receiver_data = storage.receivers[unit_number]
  if receiver_data then
    -- Check if already configured
    for _, idx in ipairs(receiver_data.configured_surfaces) do
      if idx == surface_index then
        return  -- Already configured
      end
    end
    table.insert(receiver_data.configured_surfaces, surface_index)
  end
end

--- Remove a surface from receiver's configuration
--- @param unit_number uint Receiver entity unit number
--- @param surface_index uint Surface index to remove
function globals.remove_receiver_surface(unit_number, surface_index)
  local receiver_data = storage.receivers[unit_number]
  if receiver_data then
    for i, idx in ipairs(receiver_data.configured_surfaces) do
      if idx == surface_index then
        table.remove(receiver_data.configured_surfaces, i)
        return
      end
    end
  end
end

--- Set receiver's hold signal in transit flag
--- @param unit_number uint Receiver entity unit number
--- @param hold_signal boolean True to hold signals in transit, false to clear
function globals.set_receiver_hold_signal(unit_number, hold_signal)
  local receiver_data = storage.receivers[unit_number]
  if receiver_data then
    receiver_data.hold_signal_in_transit = hold_signal
  end
end

--- Update platform location cache
--- @param platform_index uint Platform index
--- @param surface_index uint|nil Current surface index or nil if in transit
function globals.update_platform_location(platform_index, surface_index)
  storage.platform_locations[platform_index] = {
    surface_index = surface_index,
    last_check = game.tick
  }
end

--- Get cached platform location
--- @param platform_index uint Platform index
--- @return uint|nil surface_index or nil if unknown/in transit
function globals.get_platform_location(platform_index)
  local cache = storage.platform_locations[platform_index]
  if cache then
    return cache.surface_index
  end
  return nil
end

--- Clean up invalid entities from storage
--- Called periodically to remove references to destroyed entities
function globals.cleanup_invalid_entities()
  -- Clean up tower entities
  for surface_index, network in pairs(storage.mc_networks) do
    for unit_number, data in pairs(network.tower_entities) do
      -- Mark for removal if entity doesn't exist
      -- (Will be cleaned up by on_entity_destroyed handler normally)
      if not data.valid then
        network.tower_entities[unit_number] = nil
      end
    end

    for unit_number, data in pairs(network.output_combinators_red or {}) do
      if not data.valid then
        network.output_combinators_red[unit_number] = nil
      end
    end

    for unit_number, data in pairs(network.output_combinators_green or {}) do
      if not data.valid then
        network.output_combinators_green[unit_number] = nil
      end
    end
  end

  -- Clean up receivers
  for unit_number, data in pairs(storage.receivers) do
    -- Receiver cleanup handled by on_entity_destroyed
  end
end

--- Set player GUI state (which entity GUI is open)
--- @param player_index uint Player index
--- @param entity LuaEntity The entity being viewed
--- @param gui_type string Type of GUI ("receiver_combinator", "mission_control_tower", etc.)
function globals.set_player_gui_entity(player_index, entity, gui_type)
  if not storage.player_gui_states then
    storage.player_gui_states = {}
  end

  storage.player_gui_states[player_index] = {
    open_entity = entity.unit_number,
    gui_type = gui_type
  }
end

--- Clear player GUI state
--- @param player_index uint Player index
function globals.clear_player_gui_entity(player_index)
  if not storage.player_gui_states then
    storage.player_gui_states = {}
    return
  end

  storage.player_gui_states[player_index] = nil
end

--- Get player GUI state
--- @param player_index uint Player index
--- @return table|nil GUI state {open_entity=uint, gui_type=string}
function globals.get_player_gui_state(player_index)
  if not storage.player_gui_states then
    return nil
  end

  return storage.player_gui_states[player_index]
end

return globals
