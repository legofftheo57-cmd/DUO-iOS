#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Ce contrôle exige macOS, Xcode et un simulateur iPhone.' >&2
  exit 1
fi
mkdir -p TestResults
swift test 2>&1 | tee TestResults/core.log
DUO_SIMULATOR_ID="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for runtime,devices in d["devices"].items() if "iOS" in runtime for x in devices if "iPhone" in x["name"]))')"
xcodebuild -project DUO.xcodeproj -scheme DUO -destination "platform=iOS Simulator,id=$DUO_SIMULATOR_ID" -derivedDataPath TestResults/DerivedData CODE_SIGNING_ALLOWED=NO build 2>&1 | tee TestResults/build.log
if [[ "${DUO_RUN_UI_TESTS:-1}" == "1" ]]; then
  DUO_RESULT_NAME="TestResults/UI-$(date +%Y%m%d-%H%M%S).xcresult"
  xcodebuild -project DUO.xcodeproj -scheme DUO -destination "platform=iOS Simulator,id=$DUO_SIMULATOR_ID" -derivedDataPath TestResults/DerivedData -resultBundlePath "$DUO_RESULT_NAME" -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test 2>&1 | tee TestResults/ui.log
else
  echo "Tests d'interface non lancés : relancez avec include_ui_tests=true pour les exécuter."
fi
