#!/bin/bash
# Runs the unit tests. With full Xcode this is just `swift test`. With only the Command Line
# Tools, swift-testing lives in a framework directory SwiftPM does not search, so pass it explicitly.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
CLT=/Library/Developer/CommandLineTools/Library/Developer
if [[ ! -d /Applications/Xcode.app && -d "$CLT/Frameworks/Testing.framework" ]]; then
  exec swift test \
    -Xswiftc -F -Xswiftc "$CLT/Frameworks" \
    -Xlinker -F -Xlinker "$CLT/Frameworks" \
    -Xlinker -rpath -Xlinker "$CLT/Frameworks" \
    -Xlinker -rpath -Xlinker "$CLT/usr/lib" "$@"
fi
exec swift test "$@"
