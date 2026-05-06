#!/bin/bash
echo "Codnia Installer"
echo "=================="
echo ""
echo "1. Removing quarantine attributes..."
xattr -cr /Applications/Codnia.app 2>/dev/null
echo "2. Installing Codnia.app to Applications folder..."
cp -R "$(dirname "$0")/Codnia.app" /Applications/ 2>/dev/null || sudo cp -R "$(dirname "$0")/Codnia.app" /Applications/
echo "3. Removing quarantine attributes from installed app..."
xattr -cr /Applications/Codnia.app
echo "4. Setting permissions..."
chmod +x /Applications/Codnia.app/Contents/MacOS/Codnia
echo ""
echo "Installation complete! You can now open Codnia from Applications."
echo "If macOS still blocks it, run: xattr -cr /Applications/Codnia.app"
