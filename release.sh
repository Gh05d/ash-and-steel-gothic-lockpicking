#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

REPO=Gh05d/ash-and-steel-gothic-lockpicking
VERSION=$(grep -oP 'local VERSION = "\K[^"]+' mod/GothicLockpicking/Scripts/main.lua)
TAG="v${VERSION}"
ZIP="dist/GothicLockpicking-${VERSION}.zip"

echo "Preparing release: Gothic Lockpicking ${TAG}"

if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "ERROR: Tag ${TAG} already exists. Bump VERSION in mod/GothicLockpicking/Scripts/main.lua first."
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "ERROR: Working tree is dirty. Commit or stash changes first."
    exit 1
fi

echo "Pushing to origin..."
git push origin master

echo "Building zip..."
python3 scripts/package.py

if [ ! -f "$ZIP" ]; then
    echo "ERROR: Expected zip not found at ${ZIP}"
    exit 1
fi
echo "Release artifact: ${ZIP} ($(du -h "$ZIP" | cut -f1))"

git tag -a "$TAG" -m "Release ${TAG}"
git push origin "$TAG"

echo "Creating GitHub release..."
gh release create "$TAG" "$ZIP" \
    --repo "$REPO" \
    --title "Gothic Lockpicking ${TAG}" \
    --notes "$(cat <<NOTES
## Gothic Lockpicking ${TAG}

Lockpicking as in Gothic 2 for Of Ash and Steel: every lock has a fixed left/right combination, a wrong turn starts over and may break your lockpick. Master Lockpickers see the correct turns of their best attempt.

### Installation
1. Install [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest) (experimental build) into \`ofAshAndSteelGame/Binaries/Win64/\`
2. Extract \`GothicLockpicking-${VERSION}.zip\` into the game folder \`ofAshAndSteel/\`
3. Steam Deck / Linux: launch option \`WINEDLLOVERRIDES="dwmapi=n,b" %command%\`
NOTES
)"

echo ""
echo "Release ${TAG} published!"
echo "  GitHub: https://github.com/${REPO}/releases/tag/${TAG}"
echo "Nexus Mods upload will be triggered automatically via GitHub Actions."
