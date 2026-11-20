#!/usr/bin/env bash
# Export the Web build into docs/ (served by GitHub Pages).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/opt/godot/godot}
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
rm -rf docs && mkdir -p docs && cp build/web/* docs/ && touch docs/.nojekyll docs/.gdignore
