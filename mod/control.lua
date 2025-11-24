--- Mission Control Mod - Main Control Script
-- Coordinates all mod functionality and event handlers

-- Module imports
local globals = require("scripts.globals")
local network_manager = require("scripts.network_manager")
local mission_control_tower = require("scripts.mission_control.mission_control_tower")
local receiver_combinator = require("scripts.receiver_combinator.receiver_combinator")
local receiver_combinator_gui = require("scripts.receiver_combinator.gui")

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize mod on first load
script.on_init(function()
  globals.init()
end)

--- Handle configuration changes (mod updates, etc.)
script.on_configuration_changed(function(data)
  globals.init()  -- Ensure storage structure exists

  -- Future: Add migration logic here when updating versions
  if data.mod_changes and data.mod_changes["mission-control"] then
    -- Validate all entities after update
    mission_control_tower.validate_all()
    receiver_combinator.validate_all()
  end
end)

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================



-- ============================================================================
-- ENTITY LIFECYCLE EVENTS
-- ============================================================================

--- Filter for built entity events (performance optimization)
local build_filters = {
  {filter = "name", name = "mission-control-tower"},
  {filter = "name", name = "receiver-combinator"},
  {filter = "ghost_name", name = "mission-control-tower"},
  {filter = "ghost_name", name = "receiver-combinator"}
}

--- Handle entity built by player, robot, or script
local function on_entity_built(event)
  local entity = event.created_entity or event.entity or event.destination
  if not entity or not entity.valid then
    return
  end

  local entity_name = globals.get_entity_name(entity)
  if not entity_name then
    return
  end

  -- DEBUG: Log which event fired
  local event_name = "UNKNOWN"
  if event.name == defines.events.on_built_entity then
    event_name = "on_built_entity"
  elseif event.name == defines.events.on_robot_built_entity then
    event_name = "on_robot_built_entity"
  elseif event.name == defines.events.on_space_platform_built_entity then
    event_name = "on_space_platform_built_entity"
  elseif event.name == defines.events.script_raised_built then
    event_name = "script_raised_built"
  elseif event.name == defines.events.script_raised_revive then
    event_name = "script_raised_revive"
  end

  if entity_name == "receiver-combinator" then
    log(string.format("[MC Control] Event: %s, entity_type=%s, event.tags=%s",
      event_name, entity.type, event.tags and "EXISTS" or "NIL"))
  end

  local player_index = event.player_index
  local tags = event.tags  -- Blueprint/ghost tags from Factorio 2.0+

  -- Route to appropriate handler based on entity name (handles ghosts)
  if entity_name == "mission-control-tower" then
    mission_control_tower.on_built(entity, player_index, tags)
  elseif entity_name == "receiver-combinator" then
    receiver_combinator.on_built(entity, player_index, tags)
  end
end

-- Register for all build events
script.on_event(defines.events.on_built_entity, on_entity_built, build_filters)
script.on_event(defines.events.on_robot_built_entity, on_entity_built, build_filters)
script.on_event(defines.events.on_space_platform_built_entity, on_entity_built, build_filters)

-- Script raised events don't support filters, so we handle all entities
local function on_script_built(event)
  on_entity_built(event)
end

script.on_event(defines.events.script_raised_built, on_script_built)
script.on_event(defines.events.script_raised_revive, on_script_built)

--- Handle entity destruction (any cause)
local function on_entity_destroyed(event)
  local entity = event.entity
  if not entity or not entity.valid then
    return
  end

  local entity_name = globals.get_entity_name(entity)
  if not entity_name then
    return
  end

  -- Route to appropriate handler based on entity name (handles ghosts)
  if entity_name == "mission-control-tower" then
    mission_control_tower.on_destroyed(entity)
  elseif entity_name == "receiver-combinator" then
    receiver_combinator.on_destroyed(entity)
  end
end

-- Register for all destruction events
script.on_event(defines.events.on_entity_died, on_entity_destroyed, build_filters)
script.on_event(defines.events.on_robot_mined_entity, on_entity_destroyed, build_filters)
script.on_event(defines.events.on_player_mined_entity, on_entity_destroyed, build_filters)
script.on_event(defines.events.on_space_platform_mined_entity, on_entity_destroyed, build_filters)
script.on_event(defines.events.script_raised_destroy, on_entity_destroyed)

-- ============================================================================
-- BLUEPRINT / COPY-PASTE SUPPORT
-- ============================================================================

--- Handle entity settings copy/paste
script.on_event(defines.events.on_entity_settings_pasted, function(event)
  local source = event.source
  local destination = event.destination

  if not source or not source.valid or not destination or not destination.valid then
    return
  end

  local source_name = globals.get_entity_name(source)
  local dest_name = globals.get_entity_name(destination)

  if not source_name or not dest_name then
    return
  end

  -- Route based on destination entity type (handles ghosts)
  if dest_name == "mission-control-tower" then
    local settings = mission_control_tower.on_copy_settings(source)
    if settings then
      mission_control_tower.on_paste_settings(destination, settings)
    end
  elseif dest_name == "receiver-combinator" then
    local settings = receiver_combinator.on_copy_settings(source)
    if settings then
      receiver_combinator.on_paste_settings(destination, settings)
    end
  end
end)

--- Handle blueprint creation (tag entities with configuration)
script.on_event(defines.events.on_player_setup_blueprint, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  local blueprint = player.blueprint_to_setup
  if not blueprint or not blueprint.valid_for_read then
    blueprint = player.cursor_stack
  end

  if not blueprint or not blueprint.valid_for_read then
    return
  end

  -- Get the mapping (CRITICAL: provides blueprint_index -> real_entity mapping)
  local mapping = event.mapping.get()
  if not mapping then return end

  -- Iterate through mapped entities
  for blueprint_index, real_entity in pairs(mapping) do
    if not real_entity or not real_entity.valid then
      goto continue
    end

    local entity_name = globals.get_entity_name(real_entity)

    -- Tag receiver combinators with their configuration
    if entity_name == "receiver-combinator" then
      log(string.format("[MC Blueprint] Found receiver-combinator at bp_index=%d, is_ghost=%s",
        blueprint_index, real_entity.type == "entity-ghost" and "YES" or "NO"))

      local config = globals.serialize_receiver_config(real_entity)
      if config then
        log(string.format("[MC Blueprint] Serialized config: %d surfaces, hold_signal=%s",
          #(config.configured_surfaces or {}), tostring(config.hold_signal_in_transit)))
        blueprint.set_blueprint_entity_tag(blueprint_index, "receiver_config", config)
        log(string.format("[MC Blueprint] Saved config to blueprint at index %d", blueprint_index))
      else
        log(string.format("[MC Blueprint] WARNING: No config returned for bp_index=%d", blueprint_index))
      end
    end
    -- Mission Control towers don't have configuration yet, so skip tagging

    ::continue::
  end
end)

--- Handle entity cloning (editor or mods)
script.on_event(defines.events.on_entity_cloned, function(event)
  local source = event.source
  local destination = event.destination

  if not source or not source.valid or not destination or not destination.valid then
    return
  end

  local source_name =  globals.get_entity_name(source)
  local dest_name = globals.get_entity_name(destination)

  if not source_name or not dest_name or source_name ~= dest_name then
    return
  end

  -- For receiver combinators, copy configuration
  if dest_name == "receiver-combinator" then
    -- Register the cloned entity first (cloning creates a NEW entity)
    receiver_combinator.on_built(destination, nil, nil)

    -- Then copy settings
    local settings = receiver_combinator.on_copy_settings(source)
    if settings then
      receiver_combinator.on_paste_settings(destination, settings)
    end
  elseif dest_name == "mission-control-tower" then
    -- Register the cloned tower
    mission_control_tower.on_built(destination, nil, nil)

    -- Copy settings if towers ever get configuration
    local settings = mission_control_tower.on_copy_settings(source)
    if settings then
      mission_control_tower.on_paste_settings(destination, settings)
    end
  end
end)

-- ============================================================================
-- SIGNAL TRANSMISSION (PERIODIC UPDATES)
-- ============================================================================

--- Main update tick - handles signal transmission every 15 ticks (~0.25 seconds)
script.on_nth_tick(15, function(event)
  network_manager.on_tick_update()
end)

--- Platform location cache update - every 60 ticks (~1 second)
script.on_nth_tick(60, function(event)
  network_manager.update_platform_locations()
end)

-- ============================================================================
-- SPACE PLATFORM EVENTS
-- ============================================================================

--- Handle platform state changes (arriving at planets, departing, etc.)
script.on_event(defines.events.on_space_platform_changed_state, function(event)
  local platform = event.platform

  if not platform or not platform.valid then
    return
  end

  -- Update platform location cache immediately
  local surface_index = nil
  if platform.space_location then
    -- Look up the planet by space location name and get its surface index
    local planet = game.planets[platform.space_location.name]
    if planet and planet.surface then
      surface_index = planet.surface.index
    end
  end

  globals.update_platform_location(platform.index, surface_index)
end)

-- ============================================================================
-- GUI EVENTS
-- ============================================================================

--- Helper function to determine which GUI module to route to based on context
local function get_gui_module_for_event(event)
    -- For on_gui_opened, check the entity type
    if event.entity and event.entity.valid then
        if event.entity.name == "receiver-combinator" or (event.entity.type == "entity-ghost" and event.entity.ghost_name == "receiver-combinator") then
            return receiver_combinator_gui
        end
        -- Note: Mission Control Towers intentionally have no GUI
        -- They function as simple signal relay stations without configuration
    end

    -- For other events, check player's GUI state
    if event.player_index then
        local gui_state = globals.get_player_gui_state(event.player_index)
        if gui_state and gui_state.gui_type then
            if gui_state.gui_type == "receiver_combinator" then
                return receiver_combinator_gui
            end
            -- Mission Control Towers have no GUI
        end
    end

    return nil
end

-- Override GUI event handlers with dispatchers that route based on entity type or GUI state
-- This is necessary because multiple script.on_event calls for the same event will overwrite each other
script.on_event(defines.events.on_gui_opened, function(event)
    local gui_module = get_gui_module_for_event(event)
    if gui_module and gui_module.on_gui_opened then
        gui_module.on_gui_opened(event)
    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    local gui_module = get_gui_module_for_event(event)
    if gui_module and gui_module.on_gui_closed then
        gui_module.on_gui_closed(event)
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    local gui_module = get_gui_module_for_event(event)
    if gui_module and gui_module.on_gui_click then
        gui_module.on_gui_click(event)
    end
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
    local gui_module = get_gui_module_for_event(event)
    if gui_module and gui_module.on_gui_elem_changed then
        gui_module.on_gui_elem_changed(event)
    end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
    local gui_module = get_gui_module_for_event(event)
    if gui_module and gui_module.on_gui_text_changed then
        gui_module.on_gui_text_changed(event)
    end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    local gui_module = get_gui_module_for_event(event)
    if gui_module and gui_module.on_gui_selection_state_changed then
        gui_module.on_gui_selection_state_changed(event)
    end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    local gui_module = get_gui_module_for_event(event)
    if gui_module and gui_module.on_gui_checked_state_changed then
        gui_module.on_gui_checked_state_changed(event)
    end
end)

script.on_event(defines.events.on_gui_switch_state_changed, function(event)
    local gui_module = get_gui_module_for_event(event)
    if gui_module and gui_module.on_gui_switch_state_changed then
        gui_module.on_gui_switch_state_changed(event)
    end
end)

-- ============================================================================
-- DEBUG / REMOTE INTERFACE
-- ============================================================================

  --- Get status of a receiver combinator
  --- @param unit_number uint The receiver's unit number
  --- @return table Status information
  local function get_receiver_status(unit_number)
    local entity = game.get_entity_by_unit_number(unit_number)
    if entity and entity.valid and entity.name == "receiver-combinator" then
      return receiver_combinator.get_status(entity)
    end
    return {error = "Not a receiver combinator"}
  end

  --- Validate all entities and clean up orphaned data
  local function validate_all()
    mission_control_tower.validate_all()
    receiver_combinator.validate_all()
    globals.cleanup_invalid_entities()
    return {success = true}
  end

    --- Validate all entities and clean up orphaned data
  local function clear_all()
    storage.tower_to_output = {}
    storage.receivers = {}
    storage.platform_locations = {}
    storage.mc_networks = {}
    return {success = true}
  end

  --- Get network statistics
  local function get_stats()
    local stats = {
      surfaces = 0,
      towers = 0,
      receivers = 0,
      platforms = 0
    }

    for _, network in pairs(storage.mc_networks or {}) do
      stats.surfaces = stats.surfaces + 1
      for _ in pairs(network.tower_entities or {}) do
        stats.towers = stats.towers + 1
      end
    end

    for _ in pairs(storage.receivers or {}) do
      stats.receivers = stats.receivers + 1
    end

    for _ in pairs(storage.platform_locations or {}) do
      stats.platforms = stats.platforms + 1
    end

    return stats
  end

-- ============================================================================
-- DEBUG COMMANDS (optional, can be removed in release)
-- ============================================================================

commands.add_command("mc-stats", "Show Mission Control network statistics", function(event)
  -- Check if interface exists
  if not remote.interfaces["mission_control"] then
    game.players[event.player_index].print("[Mission Control] ERROR: Remote interface not registered!")
    return
  end

  local stats = get_stats()

  game.players[event.player_index].print(string.format(
    "[Mission Control] Stats:\n" ..
    "  Surfaces: %d\n" ..
    "  Towers: %d\n" ..
    "  Receivers: %d\n" ..
    "  Platforms: %d",
    stats.surfaces, stats.towers, stats.receivers, stats.platforms
  ))
end)

commands.add_command("mc-validate", "Validate and clean up Mission Control entities", function(event)
  validate_all()
  game.players[event.player_index].print("[Mission Control] Validation complete")
end)

commands.add_command("mc-clear", "Validate and clean up Mission Control entities", function(event)
  clear_all()
  game.players[event.player_index].print("[Mission Control] Validation complete")
end)

commands.add_command("mc-debug", "Trigger an immediate signal update with debug output", function(event)
  network_manager.on_tick_update(true)
end)

commands.add_command("mc-dump-receivers", "Dump all receiver data for debugging", function(event)
  local player = game.players[event.player_index]

  player.print("[Mission Control] Receiver Storage Dump:")
  for unit_number, receiver_data in pairs(storage.receivers or {}) do
    local entity = receiver_data.entity

    player.print(string.format("  Receiver #%d:", unit_number))
    player.print(string.format("    Entity exists: %s", entity and "YES" or "NO"))
    if entity then
      player.print(string.format("    Entity valid: %s", entity.valid and "YES" or "NO"))
      player.print(string.format("    Entity name: %s", entity.name))
      player.print(string.format("    Entity surface: %s", entity.surface.name))
    end
    player.print(string.format("    Platform index: %d", receiver_data.platform_index))

    -- Show configured surfaces
    if receiver_data.configured_surfaces and #receiver_data.configured_surfaces > 0 then
      player.print(string.format("    Configured surfaces: %d", #receiver_data.configured_surfaces))
      for _, surf_idx in ipairs(receiver_data.configured_surfaces) do
        local surf = game.surfaces[surf_idx]
        player.print(string.format("      - Surface %d (%s)", surf_idx, surf and surf.name or "INVALID"))
      end
    else
      player.print("    Configured surfaces: NONE (receiver will not communicate!)")
    end

    player.print(string.format("    Hold signal in transit: %s", receiver_data.hold_signal_in_transit and "YES" or "NO"))
  end
end)
