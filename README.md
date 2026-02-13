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
    │   ├── HitboxConfig.luau    # Config (buffer, raycast, input, debug)
    │   ├── HitboxAPI.luau       # Public API for developer customization
    │   ├── Checksum.luau        # Payload integrity hash (anti-exploit)
    │   └── Types.luau           # HitRequest, HitResult types
    ├── server/
    │   ├── init.server.luau     # Entry point, wires modules
    │   ├── TemporalBuffer.luau  # Position history buffer
    │   ├── PositionTracker.luau # Records positions every Heartbeat
    │   ├── RequestIntegrity.luau # Session tokens, replay protection
    │   ├── HitboxValidator.luau # Server raycast + rewind validation
    │   └── HitRequestHandler.luau # RemoteEvent, rate limiting, validation
    └── client/
        ├── init.client.luau     # Entry point
        ├── HitboxClient.luau    # Raycast + hit request emission
        ├── DebugVisualizer.luau # Real-time hurt/hit box display
        ├── PositionPredictor.luau # Client-side position extrapolation
        └── LagLogger.luau      # Developer console lag warnings
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
| Hitbox API | `src/shared/HitboxAPI.luau` |
| Checksum | `src/shared/Checksum.luau` |
| Request integrity | `src/server/RequestIntegrity.luau` |
| Server entry | `src/server/init.server.luau` |
| Temporal buffer | `src/server/TemporalBuffer.luau` |
| Position tracker | `src/server/PositionTracker.luau` |
| Hitbox validator | `src/server/HitboxValidator.luau` |
| Hit request handler | `src/server/HitRequestHandler.luau` |
| Client entry | `src/client/init.client.luau` |
| Hitbox client | `src/client/HitboxClient.luau` |
| Debug visualizer | `src/client/DebugVisualizer.luau` |
| Position predictor | `src/client/PositionPredictor.luau` |
| Lag logger | `src/client/LagLogger.luau` |
| Request integrity | `src/server/RequestIntegrity.luau` |
| Checksum (shared) | `src/shared/Checksum.luau` |

## Anti-Exploit Protection

The system includes multiple layers to prevent exploiters from abusing the hitbox:

| Layer | Description |
|-------|-------------|
| **Session tokens** | Server-issued tokens that must be included in every request. Prevents external bots and replay from other sessions. |
| **Replay protection** | Tracks recent request IDs; rejects duplicate requests (replay attacks). |
| **Checksum validation** | Payload integrity hash — detects tampering with timestamp, target, origin, direction, or distance. |
| **Position validation** | Server verifies client origin is within `maxPositionDelta` (5 studs) of server's stored position. |
| **Distance validation** | Rejects hits if attacker and target are farther than `maxAttackerTargetDistance` (50 studs). |
| **Rate limiting** | 10 hits/second per player to prevent spam. |

Configure in `HitboxConfig`:
- `enableSessionTokens` — Require server-issued tokens (default: true)
- `enableReplayProtection` — Reject duplicate request IDs (default: true)
- `maxPositionDelta` — Max allowed client/server position mismatch (studs)
- `maxAttackerTargetDistance` — Max allowed attacker-target distance (studs)

## Implemented Modules

### Shared

- **Types** — `HitRequest`, `HitResult` types for the hit request payload
- **HitboxConfig** — Buffer window, raycast distance, rate limits, input bindings, debug options
- **HitboxAPI** — Public API for developers to customize config before the client starts

### Server

- **TemporalBuffer** — Circular buffer for player position history (500ms, 60 entries)
- **PositionTracker** — Records all player positions every Heartbeat
- **HitboxValidator** — Rewinds positions and performs server raycast for hit confirmation
- **HitRequestHandler** — Creates RemoteEvents, rate limits (10/sec), validates args, delegates to HitboxValidator

### Client

- **HitboxClient** — Raycast from camera look direction, fires hit request to server
- **DebugVisualizer** — Renders **hurt box** (target) and **hit box** (attacker ray) in real-time
- **PositionPredictor** — Extrapolates player positions when server lags for smoother gameplay
- **LagLogger** — Logs to developer console when round-trip latency exceeds threshold

## Developer Integration

### Configurable Input

Choose **any button** to trigger hits:

```lua
local HitboxAPI = require(ReplicatedStorage.Shared.HitboxAPI)
HitboxAPI.setConfig({
    hitInputTypes = { "MouseButton1", "MouseButton2", "Touch" },  -- Left/right click, touch
    hitKeyCodes = { "Q", "F", "E", "R" },                         -- Keyboard keys
})
```

### Debug Mode: Hurt Box & Hit Box

Show hitbox size in real-time:

```lua
HitboxAPI.setConfig({
    debugMode = true,
    hurtBoxColor = Color3.fromRGB(255, 100, 100),   -- Red = damage receiver
    hitBoxColor = Color3.fromRGB(100, 255, 100),    -- Green = attack ray
})
```

- **Hurt box** — Red overlay on each player's character (where damage is received)
- **Hit box** — Green beam showing the attack ray/range

### Lag Logging

See in the developer console when the system is lagging:

```lua
HitboxAPI.setConfig({
    lagWarningThresholdMs = 150,  -- Warn when round-trip exceeds 150ms
})
```

Output: `[Hitbox] Lag detected: 200ms round-trip (threshold: 150ms) | Timestamp out of buffer window`

### Prediction System

When the server lags, the client predicts player movement so both sides feel smooth:

```lua
HitboxAPI.setConfig({
    predictionEnabled = true,
    predictionExtrapolationMs = 100,  -- How far ahead to predict (based on latency)
})
```

The client extrapolates target positions using velocity, allowing hits to register more reliably under lag.

### Usage

1. Set your preferred input and options via `HitboxAPI.setConfig()` before the client starts.
2. Use the configured button to attempt a hit. The client raycasts toward the camera look direction (or predicted target position when prediction is enabled).
3. The server validates, rewinds, and performs its own raycast.
4. If valid, the server fires `HitboxHitResult` back with `{ valid = true }` or `{ valid = false, reason = "..." }`.

## Requirements

- Roblox Studio or Rojo for syncing
- Luau (Roblox Lua)
- `FilteringEnabled: true` (already configured in `default.project.json`)

## License

See [LICENSE](LICENSE).
