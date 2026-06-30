#!/usr/bin/env bash
#
# Run the sdk-sync unit tests (the WPSync* XCTest classes) on an iOS Simulator.
#
# Usage:
#   Scripts/test-sync.sh                 # run all sync tests on the default simulator
#   Scripts/test-sync.sh -v              # verbose (full xcodebuild output)
#   Scripts/test-sync.sh WPSyncVersionIdTests          # one class
#   Scripts/test-sync.sh WPSyncVersionIdTests/testStringNonAsciiCodeUnitOrder  # one method
#   SIMULATOR="iPhone 16 Pro" Scripts/test-sync.sh     # override the simulator
#
set -euo pipefail
cd "$(dirname "$0")/.."

SIMULATOR="${SIMULATOR:-iPhone 17 Pro}"
SCHEME="WonderPushExampleTests"
PROJECT="WonderPush.xcodeproj"

# All sdk-sync test classes. Add new WPSync*Tests classes here.
SYNC_CLASSES=(
  WPSyncConformanceTests
  WPSyncTypesTests
  WPSyncVersionIdTests
  WPSyncKnobsTests
  WPSyncKnobsProviderTests
  WPSyncFetchPolicyTests
  WPSyncProcessorTests
  WPSyncContactStoreTests
  WPSyncStateStoreTests
  WPSyncMutexTests
  WPSyncOutgoingTests
  WPSyncFetcherTests
  WPSyncTests
  WPSyncContactSourceTests
  WPSyncAPITransportTests
  WPSyncHookTests
  WPSyncIntegrationTests
)

VERBOSE=0
ONLY_TESTING=()
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=1 ;;
    *) ONLY_TESTING+=("-only-testing:${SCHEME}/${arg}") ;;
  esac
done

# Default to the full sync suite when no specific class/method was requested.
if [ ${#ONLY_TESTING[@]} -eq 0 ]; then
  for c in "${SYNC_CLASSES[@]}"; do ONLY_TESTING+=("-only-testing:${SCHEME}/${c}"); done
fi

CMD=(xcodebuild test
  -project "$PROJECT"
  -scheme "$SCHEME"
  -destination "platform=iOS Simulator,name=${SIMULATOR}"
  "${ONLY_TESTING[@]}"
  CODE_SIGNING_ALLOWED=NO)

echo "▶ ${SIMULATOR} · ${#ONLY_TESTING[@]} target(s)"
if [ "$VERBOSE" -eq 1 ]; then
  "${CMD[@]}"
else
  # Show just test results + the final status; fail the script if xcodebuild fails.
  set -o pipefail
  "${CMD[@]}" 2>&1 | grep -E "Test Case .*(passed|failed)|Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)|error:|^.*: error:"
fi
