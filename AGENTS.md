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
- **Sparkle** (2.6.0+) — auto-update framework

## Creating a New Version

1. **Retrieve the latest commits** since the last version:
   ```bash
   git log v<last-version>..HEAD --oneline
   ```

2. **Determine release type**:
   - **Patch** (`0.x.1`): Bug fixes only
   - **Minor** (`0.x.0`): New features (no breaking changes)
   - **Major** (`0.0.0`): Breaking changes

3. **Build and generate the DMG** with icon and Applications symlink:
    ```bash
    swift build --configuration release
    mkdir -p /tmp/Codnia-v<version>/Codnia.app/Contents/{MacOS,Resources,Frameworks}
    cp .build/release/Codnia /tmp/Codnia-v<version>/Codnia.app/Contents/MacOS/
    cp .build/release/Codnia_Codnia.bundle/icon.icns /tmp/Codnia-v<version>/Codnia.app/Contents/Resources/
    cp Info.plist /tmp/Codnia-v<version>/Codnia.app/Contents/

    # Add rpath so Sparkle is found in Contents/Frameworks/ at runtime
    install_name_tool -add_rpath @loader_path/../Frameworks /tmp/Codnia-v<version>/Codnia.app/Contents/MacOS/Codnia

    # Copy Sparkle framework from xcframework to app bundle
    # xcframework is a wrapper; we need the actual framework inside
    SPARKLE_XCF=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework"
    cp -R "$SPARKLE_XCF/macos-arm64_x86_64/Sparkle.framework" /tmp/Codnia-v<version>/Codnia.app/Contents/Frameworks/
    codesign --force --sign - /tmp/Codnia-v<version>/Codnia.app/Contents/Frameworks/Sparkle.framework

    codesign --force --deep --entitlements Codnia.entitlements --sign - /tmp/Codnia-v<version>/Codnia.app
    ln -s /Applications /tmp/Codnia-v<version>/Applications
    hdiutil create -volname "Codnia v<version>" -srcfolder /tmp/Codnia-v<version> -format UDZO Codnia-v<version>.dmg
    ```

4. **Update README and CHANGELOG**:
   - Update version badge in README.md
   - Add new version section in CHANGELOG.md with commit descriptions

5. **Generate signature and update appcast**:
   ```bash
   .build/artifacts/sparkle/Sparkle/bin/sign_update Codnia-v<version>.dmg
   # Output: sparkle:edSignature="..." length="..."
   # Add a new <item> to appcast.xml with the signature and length
   ```

6. **Commit appcast update**:
   ```bash
   git add appcast.xml
   git commit -m "chore: add v<version> to appcast"
   git push origin main
   ```

7. **Create tag and release**:
   ```bash
   git tag -a v<version> -m "Release v<version>"
   git push origin v<version>
   gh release create v<version> --title "v<version>" --notes "<changelog内容>"
   gh release upload v<version> Codnia-v<version>.dmg --clobber
   ```

## Testing

- `swift test` — runs `CodniaTests` (currently minimal)