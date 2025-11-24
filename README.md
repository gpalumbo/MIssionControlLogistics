# Mission Control Logistics

Circuit network communication between planetary surfaces and space platforms.

## Quick Start

### On Planets
1. Place **Mission Control Towers** on any planet
2. Connect circuit networks (red/green wires) to tower inputs
3. All towers on same surface share and aggregate their input signals
4. Signals broadcast to configured space platforms
5. **Space → Ground**: Towers output signals from all receivers on platforms currently in orbit at that planet

### On Space Platforms
1. Place **Receiver Combinators** on your platform
2. Open the combinator GUI (click on it)
3. Select which planets this receiver communicates with (checkboxes)
4. Toggle "Hold signal in transit" to keep signals while traveling
5. **Ground → Space**: Receivers output signals received from towers on configured planets ONLY when orbiting them

### Signal Flow
- **Ground → Space**: Receivers output signals from configured planets when orbiting them
- **Space → Ground**: Towers output signals from all platforms at that planet
- **In Transit**: If hold enabled, receivers keep last signal while moving. If disabled, signals clear.

### Example Setup
```
Nauvis Mission Control Tower (iron-plate = 100)
    ↓ (platform orbits Nauvis with configured receiver)
Platform Receiver outputs iron-plate = 100
    ↓ (platform travels to Gleba)
Platform Receiver outputs iron-plate = 100 (held) or 0 (if hold disabled)
```

## Research
Unlock via **Mission Control** technology (requires space science).

## Mod Synergy: Logistics Combinator

Combine with [Logistics Combinator](https://mods.factorio.com/mod/logistics-combinator) for automated cross-surface shipping:

**Platform requests items from planet:**
1. Platform reads inventory shortages via circuit network
2. Receiver sends shortage signals to planet's Mission Control Tower
3. Logistics Combinator on planet sets rocket cargo based on received signals
4. Rocket launches with exactly what the platform needs

**Planet monitors platform status:**
1. Platform sends current inventory/production stats via Receiver
2. Mission Control Tower outputs these signals on planet
3. Use signals to control factory production priorities or alert systems
