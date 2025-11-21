# Mission Control Logistics

Circuit network communication between planetary surfaces and space platforms.

## Quick Start

### On Planets
1. Place **Mission Control Towers** on any planet
2. Connect circuit networks (red/green wires) to tower inputs
3. All towers on same surface share and aggregate their input signals
4. Signals broadcast to configured space platforms

### On Space Platforms
1. Place **Receiver Combinators** on your platform
2. Open the combinator GUI (click on it)
3. Select which planets this receiver communicates with (checkboxes)
4. Toggle "Hold signal in transit" to keep signals while traveling

### Signal Flow
- **Ground → Space**: Receivers output signals from configured planets when orbiting them
- **Space → Ground**: Towers output signals from all platforms at that planet
- **In Transit**: If hold enabled, receivers keep last signal. If disabled, signals clear.

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
