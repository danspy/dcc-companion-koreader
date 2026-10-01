#!/bin/sh
# Zip the plugin folder for a release: unzip it into KOReader's plugins/ directory.
set -e
here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here"
rm -f crawlerscompanion.koplugin.zip
zip -qr crawlerscompanion.koplugin.zip crawlerscompanion.koplugin -x '*.DS_Store'
ls -la crawlerscompanion.koplugin.zip
