#!/usr/bin/env bash
# Build web (HTML5) and push to itch.io via butler.
# Optionally push an APK to channel "android" (set ITCH_APK_PATH or put APK at default path).
# Requires: butler (https://itch.io/docs/butler/) and one-time: butler login
# Env: ITCH_PROJECT (e.g. youruser/toktokgames), optional BUTLER_API_KEY for CI, optional ITCH_APK_PATH

set -e
cd "$(dirname "$0")/.."

PROJECT="${ITCH_PROJECT:-}"
WEB_CHANNEL="${ITCH_CHANNEL:-html5}"
VERSION="$(date +%Y%m%d-%H%M%S)"

# Default APK path (e.g. after building in this repo or in a worktree you symlink/copy from)
APK_PATH="${ITCH_APK_PATH:-android/app/build/outputs/apk/debug/app-debug.apk}"

if [ -z "$PROJECT" ]; then
  echo "Error: set ITCH_PROJECT (e.g. youruser/toktokgames)"
  echo "Example: ITCH_PROJECT=leonidasmaciel/toktokgames ./scripts/push-itch.sh"
  exit 1
fi

if ! command -v butler >/dev/null 2>&1; then
  echo "Error: butler not found. Install from https://itch.io/docs/butler/"
  exit 1
fi

# ----- Web (HTML5) -----
echo "Building web..."
npm run build

echo "Preparing dist/..."
rm -rf dist
mkdir -p dist
cp index.html hello.js dist/
[ -f hello.js.map ] && cp hello.js.map dist/

echo "Pushing web to itch.io ($PROJECT:$WEB_CHANNEL)..."
butler push dist/ "$PROJECT:$WEB_CHANNEL" --userversion "$VERSION"

# ----- Android (APK) -----
if [ -f "$APK_PATH" ]; then
  echo "Pushing APK to itch.io ($PROJECT:android)..."
  APK_DIR=$(mktemp -d)
  cp "$APK_PATH" "$APK_DIR/app-debug.apk"
  butler push "$APK_DIR" "$PROJECT:android" --userversion "$VERSION"
  rm -rf "$APK_DIR"
  echo "APK pushed from: $APK_PATH"
else
  echo "No APK at $APK_PATH (set ITCH_APK_PATH to push an APK from elsewhere). Skipping android channel."
fi

echo "Done. Check https://$PROJECT/"
