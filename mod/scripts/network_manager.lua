--- Network Manager for Mission Control
-- Handles signal transmission between ground Mission Control towers and space Receiver combinators

local globals = require("scripts.globals")
local network_manager = {}

--- Validate entity can be used for circuit operations
--- @param entity LuaEntity Entity to validate
--- @return boolean True if valid and has circuit connectors
local function is_valid_circuit_entity(entity)
  if not entity then return false end
  if not entity.valid then return false end
  -- Check if entity supports circuit connections
  return entity.get_circuit_network ~= nil
end

--- Count signals in a lookup table
--- @param signals table Signal lookup table {[signal_id] = count}
--- @return number Count of signals
local function count_signals(signals)
  if not signals then return 0 end
  local count = 0
  for _ in pairs(signals) do
    count = count + 1
  end
  return count
end

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

--- Get surface index from a space location prototype
--- @param space_location LuaSpaceLocationPrototype The space location prototype
--- @return uint|nil The surface index or nil if not found
local function get_surface_index_from_location(space_location)
  if not space_location then
    return nil
  end

  -- Look up the planet by the space location's name
  local planet = game.planets[space_location.name]
  if planet and planet.surface then
    return planet.surface.index
  end

  return nil
end

--- Read circuit signals from an entity's wire connector (Factorio 2.0 API)
--- @param entity LuaEntity The entity to read from
--- @param wire_connector_id defines.wire_connector_id Wire connector to read
--- @return table Signal lookup table {[signal_id] = count} or empty table
local function read_signals(entity, wire_connector_id)
  if not is_valid_circuit_entity(entity) then
    return {}
  end

  -- Get the circuit network for this wire connector (Factorio 2.0 API)
  local circuit_network = entity.get_circuit_network(wire_connector_id)

  if not circuit_network then
    return {}  -- No network connected
  end

  -- Get signals from the network
  local signals = circuit_network.signals

  if not signals then
    return {}  -- Network exists but no signals
  end

  -- Convert signals array to lookup table
  -- Factorio API returns: {{signal={type="item", name="..."}, count=N}, ...}
  -- We convert to: {[signal_id] = count}
  local signal_table = {}
  for _, signal_data in pairs(signals) do
    if signal_data.signal and signal_data.count then
      signal_table[signal_data.signal] = signal_data.count
    end
  end

  return signal_table
end

--- Write signals to a constant combinator using Factorio 2.0 sections API
--- @param combinator LuaEntity The constant combinator entity
--- @param signals table Signal lookup table {[signal_id] = count}
--- @param wire_color string "red" or "green" for section identification
local function write_signals_to_combinator(combinator, signals, wire_color)
  if not combinator or not combinator.valid then
    return
  end

  local behavior = combinator.get_or_create_control_behavior()
  if not behavior then
    return
  end

  -- Ensure we have at least one section
  if behavior.sections_count == 0 then
    behavior.add_section()
  end

  -- Get the first section
  local section = behavior.get_section(1)
  if not section then
    return
  end

  -- Clear existing filters
  for i = 1, section.filters_count do
    section.clear_slot(i)
  end

  -- Write new signals (signals is now a lookup table {[signal_id] = count})
  if signals and next(signals) then
    local slot_index = 1
    for signal_id, count in pairs(signals) do
      if slot_index <= 1000 then  -- Max slots in a constant combinator section
        -- Ensure SignalID has all required fields with proper defaults
        local complete_signal = {
          type = signal_id.type or "item",  -- Default to "item" if not specified
          name = signal_id.name,
          quality = signal_id.quality or "normal"  -- Default to "normal" if not specified
        }

        section.set_slot(slot_index, {
          value = complete_signal,
          min = count,
          max = count  -- Set max = min for constant output
        })
        slot_index = slot_index + 1
      else
        break  -- Too many signals, truncate
      end
    end
  end
end

--- Aggregate signals from multiple sources
--- @param signal_tables table Array of signal lookup tables to aggregate
--- @return table Aggregated signal lookup table {[signal_id] = count}
local function aggregate_signals(signal_tables)
  local aggregated = {}

  -- Sum all signals with the same signal ID
  for _, signals in ipairs(signal_tables) do
    if signals then
      for signal_id, count in pairs(signals) do
        aggregated[signal_id] = (aggregated[signal_id] or 0) + count
      end
    end
  end

  return aggregated
end

--- Check if a surface is in the receiver's configured surfaces list
--- @param receiver_data table Receiver data
--- @param surface_index uint Surface index to check
--- @return boolean True if surface is configured
local function is_surface_configured(receiver_data, surface_index)
  if not receiver_data or not receiver_data.configured_surfaces then
    return false
  end

  for _, idx in ipairs(receiver_data.configured_surfaces) do
    if idx == surface_index then
      return true
    end
  end

  return false
end

--- Update ground-to-space signal transmission
--- Reads signals from Mission Control towers and writes to receiver combinators
--- Implements hold signal logic: receivers hold last signal when enabled and not at configured surface
function network_manager.update_ground_to_space()
  local surfaces_processed = 0
  local receivers_updated = 0

  -- For each surface with MC towers
  for surface_index, network in pairs(storage.mc_networks) do
    -- Skip if no towers on this surface
    if next(network.tower_entities) then
      surfaces_processed = surfaces_processed + 1

      -- Manual aggregation: read from ALL towers and sum their inputs
      -- (Combinators don't auto-share signals like radars do)
      local red_signal_tables = {}
      local green_signal_tables = {}
      local towers_read = 0

      for unit_number, entity in pairs(network.tower_entities) do
        if entity and entity.valid then
          -- Read from combinator INPUT connectors (prevents feedback from outputs)
          local red_signals = read_signals(entity, defines.wire_connector_id.combinator_input_red)
          local green_signals = read_signals(entity, defines.wire_connector_id.combinator_input_green)

          table.insert(red_signal_tables, red_signals)
          table.insert(green_signal_tables, green_signals)
          towers_read = towers_read + 1
        end
      end

      if towers_read > 0 then
        -- Aggregate signals from all towers
        local red_signals = aggregate_signals(red_signal_tables)
        local green_signals = aggregate_signals(green_signal_tables)

        local red_count = count_signals(red_signals)
        local green_count = count_signals(green_signals)

        -- Cache the aggregated signals
        network.cached_input_signals.red = red_signals or {}
        network.cached_input_signals.green = green_signals or {}
        network.last_update = game.tick

        -- Write to all receivers configured for this surface
        for receiver_unit_number, receiver_data in pairs(storage.receivers) do
          local platform = get_platform_by_index(receiver_data.platform_index)

          -- Check if platform is at this surface
          local platform_surface_index = get_surface_index_from_location(platform and platform.space_location)

          -- Check if this receiver is configured for this surface
          if is_surface_configured(receiver_data, surface_index) then
            -- Receiver is configured for this surface
            if platform_surface_index == surface_index then
              -- Platform is orbiting this configured surface - update and cache signals
              if receiver_data.output_entity_red and receiver_data.output_entity_red.valid and
                 receiver_data.output_entity_green and receiver_data.output_entity_green.valid then
                -- Write ground signals to receiver output combinators
                write_signals_to_combinator(receiver_data.output_entity_red, red_signals, "red")
                write_signals_to_combinator(receiver_data.output_entity_green, green_signals, "green")

                -- Cache the signals for hold signal feature
                receiver_data.last_received_signals.red = red_signals
                receiver_data.last_received_signals.green = green_signals

                receivers_updated = receivers_updated + 1
              end
            end
          end
        end
      end  -- Close "if towers_read > 0" block
    end
  end

  -- Handle receivers that are NOT at configured surfaces (hold signal logic)
  for receiver_unit_number, receiver_data in pairs(storage.receivers) do
    local platform = get_platform_by_index(receiver_data.platform_index)
    local platform_surface_index = get_surface_index_from_location(platform and platform.space_location)

    -- Check if receiver is at a configured surface
    local at_configured_surface = platform_surface_index and is_surface_configured(receiver_data, platform_surface_index)

    if not at_configured_surface then
      -- Not at a configured surface (in transit or at unconfigured planet)
      if receiver_data.hold_signal_in_transit then
        -- Hold last signal - output cached signals
        if receiver_data.output_entity_red and receiver_data.output_entity_red.valid and
           receiver_data.output_entity_green and receiver_data.output_entity_green.valid then
          write_signals_to_combinator(receiver_data.output_entity_red, receiver_data.last_received_signals.red or {}, "red")
          write_signals_to_combinator(receiver_data.output_entity_green, receiver_data.last_received_signals.green or {}, "green")
        end
      else
        -- Clear signals when not at configured surface
        if receiver_data.output_entity_red and receiver_data.output_entity_red.valid and
           receiver_data.output_entity_green and receiver_data.output_entity_green.valid then
          write_signals_to_combinator(receiver_data.output_entity_red, {}, "red")
          write_signals_to_combinator(receiver_data.output_entity_green, {}, "green")
        end
      end
    end
  end
end

--- Update space-to-ground signal transmission
--- Reads signals from receiver combinators and writes to Mission Control towers
function network_manager.update_space_to_ground()
  local receivers_read = 0
  local towers_updated = 0

  -- Aggregate signals by destination surface
  local surface_signals = {}  -- [surface_index] = {red = {signals}, green = {signals}}

  -- Read signals from all receivers and aggregate by their platform's location
  for receiver_unit_number, receiver_data in pairs(storage.receivers) do
    -- Use cached entity reference directly (no lookup needed)
    local receiver_entity = receiver_data.entity

    if not receiver_entity or not receiver_entity.valid then
      -- Clean up invalid receiver
      storage.receivers[receiver_unit_number] = nil
      goto continue
    end

    if receiver_entity and receiver_entity.valid then
      local platform = get_platform_by_index(receiver_data.platform_index)
      if platform and platform.space_location then
        local surface_index = get_surface_index_from_location(platform.space_location)
        if surface_index then

        -- Initialize surface signals if needed
        if not surface_signals[surface_index] then
          surface_signals[surface_index] = {
            red = {},
            green = {}
          }
        end

        -- Read signals from receiver inputs
        local red_signals = read_signals(receiver_entity, defines.wire_connector_id.combinator_input_red)
        local green_signals = read_signals(receiver_entity, defines.wire_connector_id.combinator_input_green)

        local red_count = count_signals(red_signals)
        local green_count = count_signals(green_signals)

        -- Add to aggregation arrays
        if red_signals then
          table.insert(surface_signals[surface_index].red, red_signals)
        end
        if green_signals then
          table.insert(surface_signals[surface_index].green, green_signals)
        end
        receivers_read = receivers_read + 1
        end
      end
    end

    ::continue::
  end

  -- Write aggregated signals to output combinators on each surface
  for surface_index, signals in pairs(surface_signals) do
    local network = storage.mc_networks[surface_index]
    if network then
      -- Aggregate all signals from platforms
      local aggregated_red = aggregate_signals(signals.red)
      local aggregated_green = aggregate_signals(signals.green)

      local agg_red_count = count_signals(aggregated_red)
      local agg_green_count = count_signals(aggregated_green)

      -- Write red signals to red combinators
      for unit_number, combinator in pairs(network.output_combinators_red or {}) do
        if combinator and combinator.valid and combinator.get_or_create_control_behavior then
          write_signals_to_combinator(combinator, aggregated_red, "red")
        end
      end

      -- Write green signals to green combinators
      for unit_number, combinator in pairs(network.output_combinators_green or {}) do
        if combinator and combinator.valid and combinator.get_or_create_control_behavior then
          write_signals_to_combinator(combinator, aggregated_green, "green")
          towers_updated = towers_updated + 1
        end
      end
    end
  end
end

--- Main update function called every 15 ticks
--- Handles bidirectional signal transmission
function network_manager.on_tick_update()
  network_manager.update_ground_to_space()
  network_manager.update_space_to_ground()
end

--- Update platform location cache
--- Called when platform state changes or periodically
function network_manager.update_platform_locations()
  -- Iterate through all known platforms (from receivers)
  local seen_platforms = {}

  for receiver_unit_number, receiver_data in pairs(storage.receivers) do
    local platform_index = receiver_data.platform_index
    if not seen_platforms[platform_index] then
      seen_platforms[platform_index] = true

      local platform = get_platform_by_index(platform_index)
      if platform and platform.valid then
        local surface_index = get_surface_index_from_location(platform.space_location)

        -- Update cache in globals
        globals.update_platform_location(platform_index, surface_index)
      end
    end
  end
end

return network_manager
