# Mission Control Mod - Complete Requirements Document

## Vision Statement
The Mission Control mod extends Factorio 2.0+ space platform automation by enabling circuit network communication between planetary surfaces and orbiting platforms. It introduces Mission Control buildings that act as planetary communication hubs, Receiver Combinators for platform-side data exchange, and Logistics Combinators that dynamically inject/remove logistics groups based on circuit conditions. This creates a seamless ground-to-space automation layer that feels native to Factorio's design philosophy while opening new strategic possibilities for cross-surface logistics control.

## Core Components

### 1. Technologies

#### Mission Control Technology
- **Name:** `mission-control`
- **Cost:** 1000x each science pack (automation, logistic, military, chemical, production, utility, space)
- **Prerequisites:** Space platform, Radar, Space Science, Logistic system
- **Unlocks:** Mission Control Tower, Receiver Combinator
- **Icon:** Radar with satellite dish overlay

### 2. Mission Control Tower

**Entity Specifications:**
- **Size:** 5x5 (radar-sized)
- **Recipe:** 5 radars + 100 processing units
- **Placement:** Planets only (not space platforms)
- **Health:** 250 (same as radar, scales with quality)
- **Power:** 300kW constant draw (same as radar, scales with quality)
- **Circuit Connections:** 4 terminals (red in, red out, green in, green out)
- **Graphics:** Modified radar with enhanced antenna array
- **Stack Size:** 1
- **Rocket Capacity:** 1

**Networking Behavior:**
- All MC buildings on the same surface share circuit data (like radars share circuit inputs)
- Signal aggregation: SUM all inputs from same-surface MCs
- Broadcasts summed signals to all orbiting platforms
- Outputs only signals received from orbiting platforms (not from other MCs)
- Red and green wire networks remain separated throughout

**Implementation Critical:**
```lua
-- Use entity input/output connectors for signal flow
-- Network state stored in global table indexed by surface
-- Update on_nth_tick(15) for transmission delay. If more preformant to hook into existing circuit update infrastructure ignore this requirement, however be very careful about performance crossing circuit data across surfaces which is not normally the case.

-- Example global structure:
storage.mc_networks[surface.index] = {
  red_signals = {},
  green_signals = {},
  connected_mcs = {}, -- unit_numbers
  orbiting_platforms = {} -- platform unit_numbers
}
```

### 3. Receiver Combinator

**Entity Specifications:**
- **Size:** 2x1 combinator
- **Recipe:** 10 red circuits + 5 radars + 1 arithmetic combinator
- **Placement:** Space platforms only
- **Health:** 150 (same as arithmetic combinator, scales with quality)
- **Power:** 50kW (quality uncommon:40KW rare 30:Kw epic:15KW legendary:5Kw)
- **Circuit Connections:** 4 terminals (red in, red out, green in, green out)
- **Mode:** Always bidirectional (send and receive simultaneously)
- **Graphics:** Combinator with dish antenna on top
- **Stack Size:** 25
- **Rocket Capacity:** 25

**Surface Configuration UI:**
- Title: "Surface Communication Settings"
- Multi-select checkbox list of all discovered planets
- "Select All" / "Clear All" buttons
- Only active when platform.space_location exists AND platform is stationary
- Configuration changes take effect immediately upon arrival
- Shows connection status: "Connected to: [Planet Name]" or "In Transit"

**Signal Behavior:**
- Receives broadcast signals from planet when orbiting configured surface
- Sends input signals to planet's MC network  
- Outputs nothing when in transit or orbiting non-configured planet
- Preserves red/green wire separation
- 15-tick transmission delay (or instant if performance allows)

**Implementation Critical:**
```lua
-- Use defines.events.on_space_platform_built/destroyed for lifecycle
-- Check platform.space_location every 60 ticks for orbit status
-- Platform stationary = not traveling (check velocity or position delta)

-- Example connection check:
local function is_platform_orbiting_and_stationary(platform)
  return platform.space_location ~= nil and 
         platform.speed == 0 -- or check position history
end
```
**Implementation Critical:**
```lua
-- Use standard combinator prototype as base
-- Hook into on_wire_added/removed events to track connected entities
-- Cache connected entity list, update on wire changes only
-- Groups injected by combinator tagged with source combinator unit_number for cleanup
-- On combinator removal, remove all injected groups

-- Condition storage structure (per rule):
-- rule.conditions = {
--   {signal_id, operator, value, and_or = nil},  -- First condition (no AND/OR)
--   {signal_id, operator, value, and_or = "AND"}, -- Subsequent conditions
--   {signal_id, operator, value, and_or = "OR"},
--   ...
-- }
-- and_or field: nil (first), "AND", or "OR"
-- Persist and_or state across save/load
-- Update GUI layout dynamically when and_or toggled
```

## Data Flow Architecture

### Signal Flow Pattern
```
Ground → Space:
MC Building 1 (red: iron=10) ──┐
MC Building 2 (red: iron=5)  ──┼──→ SUM → All Platforms (red: iron=15)
MC Building 3 (green: copper=20)──→ SUM → All Platforms (green: copper=20)

Space → Ground:
Platform A (red: steel=100) ──┐
Platform B (red: steel=50)  ──┼──→ SUM → All MCs output (red: steel=150)
Platform C (green: circuits=25)──→ SUM → All MCs output (green: circuits=25)
```

### Key Principles
1. **Preserve wire separation** - Red and green networks never mix
2. **Sum aggregation** - Multiple sources sum their signals
3. **Broadcast pattern** - Planet broadcasts to all platforms, platforms broadcast to all MCs
4. **15-tick delay** - Simulate transmission time (optional for performance)
5. **Differentiation via signals** - Players create unique signal combinations to identify platforms

## Critical Implementation Warnings

### DO NOT Attempt:
1. **Creating real interrupts** - Logistics combinator replaces this need
2. **Modifying vanilla logistics groups** - Only inject/remove
3. **Direct circuit network manipulation** - Use entity connectors
4. **GUI replacement** - Use companion windows/overlays
5. **Cross-surface entity references** - Use signal passing only
6. **Store entity references in global** - Store unit_numbers only

### MUST Handle:
1. **Entity lifecycle events** - Cleanup when entities destroyed
2. **Platform movement** - Update connections when platforms move
3. **Wire changes** - Recache connections when wires added/removed
4. **Save/Load** - Properly serialize global state
5. **Multiplayer** - Ensure signal sync across players
6. **Quality scaling** - Apply quality bonuses to health/power

## Architecture Notes

### Global State Structure
```lua
global = {
  -- MC Networks indexed by surface
  mc_networks = {
    [surface_index] = {
      red_signals = {},
      green_signals = {},
      mc_entities = {}, -- unit_numbers
      last_update = game.tick
    }
  },
  
  -- Platform receivers
  platform_receivers = {
    [platform_unit_number] = {
      configured_surfaces = {}, -- surface indices
      entity_unit_number = unit_number,
      last_connection = nil -- surface_index or nil
    }
  },
  
```

### Performance Optimizations
1. Use `on_nth_tick(15)` for non-critical updates
2. Cache entity connections, only update on wire events
3. Batch signal processing per surface
4. Use edge-triggered conditions to reduce processing
5. Limit GUI updates to when GUI is open

## Edge Cases & Solutions

| Edge Case | Solution |
|-----------|----------|
| Platform destroyed mid-transmission | Clear from storage.platform_receivers immediately |
| MC destroyed while sending | Recalculate surface network, exclude destroyed MC |
| Multiple platforms same signal | Sum at MC (intended behavior) |
| Config change during flight | Apply when platform arrives at next planet |
| Wire disconnected | Update connection cache, stop controlling orphaned entities |
| Save during transmission | Store pending signals in global for restoration |
| Platform docking/undocking | Treat as movement event, recheck connections |
| Quality upgrade of entity | Preserve configuration, update health/power values |

## Validation Checklist

### Core Functionality
- [ ] MC buildings sum signals from all same-surface MCs
- [ ] Receiver combinators only work when orbiting AND stationary
- [ ] Red/green wire separation preserved through transmission  
- [ ] Logistics combinator injects/removes groups, never modifies
- [ ] All entities require appropriate tech unlock
- [ ] 15-tick transmission delay implemented (or instant if simpler)

### Entity Behavior
- [ ] Health values scale with quality
- [ ] Power consumption scales with quality
- [ ] Entities can be blueprinted and copy/pasted
- [ ] Rotation works correctly for all entities
- [ ] Circuit connections preserved in blueprints

### UI/UX
- [ ] Surface selector shows all discovered planets
- [ ] LED indicators show active state
- [ ] Connection status clearly displayed
- [ ] GUI responsive to changes

### Events & Lifecycle
- [ ] Platform lifecycle events handled
- [ ] Entity destroyed events cleanup global state
- [ ] Wire added/removed updates connections
- [ ] Save/load preserves all state
- [ ] Multiplayer synchronized properly

## Success Criteria

Players can successfully:
1. Build MC network on planet surface for communication infrastructure
2. Configure receiver combinators to connect to specific planets
3. Send unique platform identifiers for ground-side differentiation
5. See clear visual feedback (LEDs, status text) of system state
6. Create blueprints incorporating the new entities
7. Scale up to multiple planets and platforms without issues
8. Use familiar Factorio UI patterns throughout

## Implementation Order

1. **Phase 1: Technologies & Recipes**
   - Create technology definitions
   - Define recipes for all entities
   - Set up item/entity prototypes

2. **Phase 2: Mission Control Building**
   - Entity with circuit connections
   - Surface networking logic
   - Signal aggregation system

3. **Phase 3: Receiver Combinator**
   - Platform-only placement
   - Surface configuration UI
   - Orbit detection logic

4. **Phase 4: Signal Transmission**
   - Cross-surface signal passing
   - Delay implementation
   - Wire separation preservation

6. **Phase 6: Polish**
   - LED indicators and visuals
   - Performance optimization
   - Edge case handling

## Final Notes

- This mod extends vanilla without replacing functionality
- All vanilla platform behaviors remain intact
- Circuit control is optional - players can ignore it entirely
- Focus on intuitive, Factorio-like user experience
- Prioritize stability over feature complexity
- When in doubt, follow vanilla patterns
