#!/bin/bash
cd "$(dirname "$0")/src"
/Applications/Godot.app/Contents/MacOS/Godot --headless --export-release "Web" ../build/index.html
