# Codnia

## Build

- **No Xcode project** — use SPM exclusively: `swift build`, `swift run`, `swift test`
- Release build: `swift build --configuration release` → `.build/release/Codnia`
- `Package.swift` enables `.experimentalFeature("StrictConcurrency")` — be aware of strictconc warnings

## Structure

- Single Swift package, single executable target `Codnia`
- Entry point: `Sources/Codnia/CodniaApp.swift`
- Views, ViewModels, Services, Models, Components, Extensions

## Dependencies

- **SwiftTerm** (1.2.0+) — native terminal
- **PostgresNIO** (1.18.0+) — async PostgreSQL client

## Testing

- `swift test` — runs `CodniaTests` (currently minimal)