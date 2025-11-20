-- Migration script to clean up invalid storage data
-- Run this when loading a save with corrupted or old data

log("[Mission Control Migration] Starting storage cleanup for version 0.1.1")

-- Clear all MC networks
if storage.mc_networks then
  for surface_index, network in pairs(storage.mc_networks) do
    -- Count entities before cleanup
    local tower_count = 0
    local combinator_count = 0
    for _ in pairs(network.tower_entities or {}) do tower_count = tower_count + 1 end
    for _ in pairs(network.output_combinators or {}) do combinator_count = combinator_count + 1 end

    log(string.format("[Migration] Surface %d had %d towers and %d output combinators",
      surface_index, tower_count, combinator_count))

    -- Validate all entities, remove invalid ones
    for unit_number, entity in pairs(network.tower_entities or {}) do
      if not entity or not entity.valid then
        log(string.format("[Migration] Removing invalid tower #%d from surface %d", unit_number, surface_index))
        network.tower_entities[unit_number] = nil
      end
    end

    for unit_number, combinator in pairs(network.output_combinators or {}) do
      if not combinator or not combinator.valid then
        log(string.format("[Migration] Removing invalid output combinator #%d from surface %d", unit_number, surface_index))
        network.output_combinators[unit_number] = nil
      end
    end
  end
end

-- Clear tower-to-output mapping, rebuild from valid entities
if storage.tower_to_output then
  log("[Migration] Clearing tower_to_output mapping")
  storage.tower_to_output = {}
end

-- Validate all receivers
if storage.receivers then
  local receiver_count = 0
  for unit_number, receiver_data in pairs(storage.receivers) do
    receiver_count = receiver_count + 1
    if not receiver_data.entity or not receiver_data.entity.valid then
      log(string.format("[Migration] Removing invalid receiver #%d", unit_number))
      storage.receivers[unit_number] = nil
    end
  end
  log(string.format("[Migration] Validated %d receivers", receiver_count))
end

log("[Mission Control Migration] Storage cleanup complete")
