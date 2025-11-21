--- Mission Control Tower entity management
-- Handles creation, destruction, and lifecycle of MC towers
-- MC towers are composite entities: combinator (visible) + constant combinator (hidden outputs)
-- Based on combinator design (like receiver) for separate input/output connectors

local globals = require("scripts.globals")
local network_manager = require("scripts.network_manager")
local mission_control_tower = {}

--- Create a Mission Control tower and its hidden output combinator
--- @param entity LuaEntity The tower entity just built
--- @param player_index uint|nil The player who built it (for undo support)
function mission_control_tower.on_built(entity, player_index)
  if not entity or not entity.valid then
    return
  end

  -- Verify this is a Mission Control tower (combinator-based entity)
  if entity.name ~= "mission-control-tower" then
    return
  end

  local surface = entity.surface
  local position = entity.position
  local force = entity.force
  local surface_index = surface.index

  -- Create TWO hidden constant combinators for space->ground signal output
  -- Need separate combinators for red and green to prevent signal duplication
  local output_combinator_red = surface.create_entity({
    name = "mission-control-tower-output",  -- Hidden constant combinator
    position = position,
    force = force,
    create_build_effect_smoke = false,
    raise_built = false  -- Don't trigger build events for hidden entity
  })

  local output_combinator_green = surface.create_entity({
    name = "mission-control-tower-output",  -- Hidden constant combinator
    position = position,
    force = force,
    create_build_effect_smoke = false,
    raise_built = false  -- Don't trigger build events for hidden entity
  })

  if not output_combinator_red or not output_combinator_green then
    game.print("[Mission Control] Warning: Failed to create output combinators for tower")
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
  -- Use combinator OUTPUT connectors (similar to receiver design)
  local tower_output_red = entity.get_wire_connector(defines.wire_connector_id.combinator_output_red, false)
  local output_red = output_combinator_red.get_wire_connector(defines.wire_connector_id.circuit_red, false)

  if tower_output_red and output_red then
    output_red.connect_to(tower_output_red, false, defines.wire_origin.script)
    log(string.format("[MC Tower] Connected RED output combinator to tower #%d", entity.unit_number))
  end

  -- Connect green output combinator ONLY to green wire (prevents duplication)
  local tower_output_green = entity.get_wire_connector(defines.wire_connector_id.combinator_output_green, false)
  local output_green = output_combinator_green.get_wire_connector(defines.wire_connector_id.circuit_green, false)

  if tower_output_green and output_green then
    output_green.connect_to(tower_output_green, false, defines.wire_origin.script)
    log(string.format("[MC Tower] Connected GREEN output combinator to tower #%d", entity.unit_number))
  end

  -- Register entities in global storage (stores entity references directly)
  globals.register_tower(surface_index, entity)
  globals.register_output_combinator(surface_index, output_combinator_red, output_combinator_green)

  -- Store link for cleanup (map tower to both output combinators)
  if not storage.tower_to_output then
    storage.tower_to_output = {}
  end
  storage.tower_to_output[entity.unit_number] = {
    red = output_combinator_red,
    green = output_combinator_green
  }

  log(string.format("[MC Tower] Built tower #%d on surface %d (%s)",
    entity.unit_number, surface_index, surface.name))
  log(string.format("[MC Tower] Output combinators: red=#%d, green=#%d",
    output_combinator_red.unit_number, output_combinator_green.unit_number))

  -- Trigger an immediate signal update to connect to any platforms already orbiting
  -- This handles the case where a tower is built while platforms are stationary
  network_manager.on_tick_update()
  log("[MC Tower] Triggered immediate signal update")
end

--- Destroy a Mission Control tower and its hidden output combinator
--- @param entity LuaEntity The tower entity being destroyed
function mission_control_tower.on_destroyed(entity)
  if not entity or not entity.valid then
    log("[MC Tower] on_destroyed called with invalid entity")
    return
  end

  if entity.name ~= "mission-control-tower" then
    log(string.format("[MC Tower] on_destroyed called for wrong entity type: %s", entity.name))
    return
  end

  local unit_number = entity.unit_number
  local surface_index = entity.surface.index

  log(string.format("[MC Tower] Destroying tower #%d on surface %d", unit_number, surface_index))

  -- Find the linked output combinators using stored references
  local output_combinators = storage.tower_to_output and storage.tower_to_output[unit_number]
  if output_combinators then
    -- Destroy the red output combinator
    if output_combinators.red and output_combinators.red.valid then
      local output_unit_number = output_combinators.red.unit_number
      log(string.format("[MC Tower] Destroying RED output combinator #%d", output_unit_number))
      output_combinators.red.destroy({raise_destroy = false})
      globals.unregister_output_combinator(surface_index, output_unit_number)
    end

    -- Destroy the green output combinator
    if output_combinators.green and output_combinators.green.valid then
      local output_unit_number = output_combinators.green.unit_number
      log(string.format("[MC Tower] Destroying GREEN output combinator #%d", output_unit_number))
      output_combinators.green.destroy({raise_destroy = false})
      globals.unregister_output_combinator(surface_index, output_unit_number)
    end

    storage.tower_to_output[unit_number] = nil
  else
    log(string.format("[MC Tower] No output combinators found for tower #%d", unit_number))
  end

  -- Unregister tower from global storage
  globals.unregister_tower(surface_index, unit_number)
  log(string.format("[MC Tower] Unregistered tower #%d from surface %d", unit_number, surface_index))
end

--- Handle tower mined by player (for item return)
--- @param entity LuaEntity The tower entity being mined
--- @param player_index uint The player mining it
function mission_control_tower.on_mined(entity, player_index)
  -- Call regular destroy handler
  mission_control_tower.on_destroyed(entity)

  -- Note: Item return is handled automatically by Factorio
end

--- Handle blueprint/copy-paste operations
--- @param entity LuaEntity The tower entity
--- @return table|nil Settings to copy
function mission_control_tower.on_copy_settings(entity)
  -- Mission Control towers don't have custom settings yet
  -- (Future: could save channel/frequency settings if we add that feature)
  return nil
end

--- Handle paste settings from blueprint
--- @param entity LuaEntity The target entity
--- @param settings table The settings to paste
function mission_control_tower.on_paste_settings(entity, settings)
  -- Currently no custom settings to paste
  -- (Future: restore channel/frequency settings)
end

--- Validate all towers and clean up orphaned entities
--- Called during migration or diagnostics
function mission_control_tower.validate_all()
  local orphaned_combinators = 0
  local orphaned_towers = 0

  -- Check all tower-to-output links
  if storage.tower_to_output then
    for tower_unit_number, output_combinator in pairs(storage.tower_to_output) do
      -- Check if tower still exists in the network
      local tower_exists = false
      for surface_index, network in pairs(storage.mc_networks or {}) do
        if network.tower_entities[tower_unit_number] then
          local tower = network.tower_entities[tower_unit_number]
          if tower and tower.valid then
            tower_exists = true
          end
          break
        end
      end

      if not tower_exists then
        -- Tower destroyed but link remains - clean up combinator
        if output_combinator and output_combinator.valid then
          output_combinator.destroy({raise_destroy = false})
        end
        storage.tower_to_output[tower_unit_number] = nil
        orphaned_towers = orphaned_towers + 1
      elseif not output_combinator or not output_combinator.valid then
        -- Combinator destroyed but link remains - cleanup
        storage.tower_to_output[tower_unit_number] = nil
        orphaned_combinators = orphaned_combinators + 1
      end
    end
  end

  if orphaned_combinators > 0 or orphaned_towers > 0 then
    game.print(string.format("[Mission Control] Cleaned up %d orphaned towers and %d orphaned combinators",
      orphaned_towers, orphaned_combinators))
  end
end

return mission_control_tower
