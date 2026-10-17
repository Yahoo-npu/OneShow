#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
for test in Tests/*.test.cjs; do node "$test"; done
mkdir -p .build/module-cache
SDK="${ONESHOW_SDK_PATH:-$(xcrun --sdk macosx --show-sdk-path)}"
xcrun swiftc -sdk "$SDK" -module-cache-path "$PWD/.build/module-cache" Sources/Services/PrivacyRedactor.swift Tests/PrivacyTests.swift -o .build/privacy-tests
.build/privacy-tests
