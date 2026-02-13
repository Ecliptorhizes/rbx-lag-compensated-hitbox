# rbx-lag-compensated-hitbox

A **server-authoritative lag-compensated hitbox system** for Roblox (Luau). This is a modular engineering showcase project—not a full game—designed to demonstrate best practices for lag compensation in networked combat.

## Core Goals

- **Raycast-based hit detection** (not `.Touched`)
- **Historical position storage** (temporal buffering for 300–500ms)
- **Server rewind validation** during hit confirmation
- **Client hit requests** validated server-side
- **Exploit mitigation** (rate limiting + argument validation)
- **Modular, scalable architecture** with clear separation of concerns

## Architecture

### Server-Authoritative Flow

1. **Client** performs a raycast and fires a hit request to the server.
2. **Server** validates the request (rate limit, timestamps, target validity).
3. **Server** rewinds both attacker and target positions to the request timestamp.
4. **Server** performs its own raycast from the rewound attacker position.
5. **Server** confirms or rejects the hit based on the raycast result.

### Module Separation

| Layer | Responsibility |
|-------|----------------|
| **Hitbox logic** | Raycast detection, hit geometry |
| **Buffer logic** | Position history storage and retrieval |
| **Validation layer** | Server-side hit verification |
| **Networking layer** | RemoteEvent handling, rate limiting |

### Roblox Services

- **RunService** — Position tracking (Heartbeat), client raycasts (RenderStepped)
- **Players** — Character access, player iteration
- **ReplicatedStorage** — Shared modules, RemoteEvents
- **ServerScriptService** — Server scripts
- **MemoryStoreService** — Optional, for future extension
- **CollectionService** — Optional, for tagging hitbox/damageable entities

## Project Structure

```
src/
├── shared/           # Shared logic (types, constants)
│   └── Hello.luau
├── server/
│   ├── init.server.luau
│   └── TemporalBuffer.luau    # Position history buffer
└── client/
    └── init.client.luau
```

## Implemented Modules

### TemporalBuffer (`src/server/TemporalBuffer.luau`)

Circular buffer that stores player position history for server-side rewind validation.

- **Window**: 500ms (configurable)
- **Capacity**: 60 entries per player (~120Hz)
- **Interpolation**: Linear interpolation between snapshots for smooth rewinds

**API:**

```lua
local TemporalBuffer = require(path.to.TemporalBuffer)

local buffer = TemporalBuffer.new(500, 60)  -- maxAgeMs, maxEntriesPerPlayer

-- Add position each frame (from PositionTracker)
buffer:add(player, character.HumanoidRootPart.CFrame)

-- Rewind during hit validation
local position = buffer:getPositionAt(targetPlayer, requestTimestamp)

-- Cleanup old entries periodically
buffer:prune()

-- Teardown
buffer:destroy()
```

## Planned Components

- **PositionTracker** — Records all player positions into the buffer every Heartbeat
- **HitboxValidator** — Server raycast + rewind logic
- **HitRequestHandler** — RemoteEvent handling, rate limiting, argument validation
- **HitboxClient** — Client raycast + hit request emission
- **Shared types** — HitRequest payload, constants

## Requirements

- Roblox Studio or Rojo for syncing
- Luau (Roblox Lua)
- `FilteringEnabled: true` (already configured in `default.project.json`)

## License

See [LICENSE](LICENSE).
