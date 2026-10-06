#!/bin/sh
# Re-export the plugin's data from the companion site's repo. Run after the site's
# content changes, then commit the result here.
#
#   scripts/sync-data.sh [path-to-dcc-companion]      default: ../dcc-companion
set -e
here="$(cd "$(dirname "$0")/.." && pwd)"
site="${1:-$here/../dcc-companion}"
node "$site/scripts/export-koreader.mjs" --out "$here/crawlerscompanion.koplugin/data"
# The site's storySoFar() at a set of positions, for the Lua copy's test to replay.
node --disable-warning=ExperimentalWarning --experimental-strip-types "$site/scripts/story-fixtures.mjs" --out "$here/tests/fixtures/story-fixtures.json"
