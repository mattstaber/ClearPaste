#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
TEST_DIR="$PWD/.build/smoke"
mkdir -p "$TEST_DIR"
swiftc -emit-library -emit-module -module-name PasteCore Sources/PasteCore/*.swift -o "$TEST_DIR/libPasteCore.dylib" -emit-module-path "$TEST_DIR/PasteCore.swiftmodule"
swiftc -D STANDALONE_TESTS -parse-as-library -I "$TEST_DIR" -L "$TEST_DIR" -lPasteCore -Xlinker -rpath -Xlinker "$TEST_DIR" Sources/EasyPaste/PasteHotKey.swift Sources/EasyPaste/ClipboardController.swift Tests/PasteCoreTests/TextCleanerTests.swift scripts/SmokeRunner.swift -o "$TEST_DIR/EasyPasteTests"
"$TEST_DIR/EasyPasteTests"
