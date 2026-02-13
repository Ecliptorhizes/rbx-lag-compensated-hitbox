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
rbx-lag-compensated-hitbox/
├── .gitignore
├── default.project.json
├── LICENSE
├── README.md
├── sourcemap.json
└── src/
    ├── shared/
    │   ├── HitboxConfig.luau     # Config (buffer, raycast, rate limits)
    │   └── Types.luau            # HitRequest, HitResult types
    ├── server/
    │   ├── init.server.luau      # Entry point, wires modules
    │   ├── TemporalBuffer.luau   # Position history buffer
    │   ├── PositionTracker.luau  # Records positions every Heartbeat
    │   ├── HitboxValidator.luau  # Server raycast + rewind validation
    │   └── HitRequestHandler.luau # RemoteEvent, rate limiting, validation
    └── client/
        ├── init.client.luau      # Entry point
        └── HitboxClient.luau     # Raycast + hit request emission
```

**File locations:**

| File | Path |
|------|------|
| Project config | `default.project.json` |
| Git ignore | `.gitignore` |
| License | `LICENSE` |
| Rojo sourcemap | `sourcemap.json` |
| Shared types | `src/shared/Types.luau` |
| Shared config | `src/shared/HitboxConfig.luau` |
| Server entry | `src/server/init.server.luau` |
| Temporal buffer | `src/server/TemporalBuffer.luau` |
| Position tracker | `src/server/PositionTracker.luau` |
| Hitbox validator | `src/server/HitboxValidator.luau` |
| Hit request handler | `src/server/HitRequestHandler.luau` |
| Client entry | `src/client/init.client.luau` |
| Hitbox client | `src/client/HitboxClient.luau` |

## Implemented Modules

### Shared

- **Types** — `HitRequest`, `HitResult` types for the hit request payload
- **HitboxConfig** — Buffer window, raycast distance, rate limits, validation bounds

### Server

- **TemporalBuffer** — Circular buffer for player position history (500ms, 60 entries)
- **PositionTracker** — Records all player positions every Heartbeat
- **HitboxValidator** — Rewinds positions and performs server raycast for hit confirmation
- **HitRequestHandler** — Creates RemoteEvents, rate limits (10/sec), validates args, delegates to HitboxValidator

### Client

- **HitboxClient** — Raycast from camera look direction on left-click/tap, fires hit request to server

### Usage

1. **Left-click** (or tap on mobile) to attempt a hit. The client raycasts from your character toward the camera look direction.
2. The server validates the request, rewinds both players to the hit timestamp, and performs its own raycast.
3. If valid, the server fires `HitboxHitResult` back to the client with `{ valid = true }` or `{ valid = false, reason = "..." }`.

## Requirements

- Roblox Studio or Rojo for syncing
- Luau (Roblox Lua)
- `FilteringEnabled: true` (already configured in `default.project.json`)

## License

See [LICENSE](LICENSE).
