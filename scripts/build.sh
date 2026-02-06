#!/bin/bash
#
# build.sh
# Builds LifeAdmin for iOS and watchOS
#
# Usage: ./scripts/build.sh [ios|watch|all]
#

set -e

# Ensure we're in the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Set Xcode developer directory (for unprivileged users)
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# Configuration
PROJECT="LifeAdmin.xcodeproj"
IOS_DESTINATION="generic/platform=iOS Simulator"
WATCH_DESTINATION="generic/platform=watchOS Simulator"

build_ios() {
    echo "📱 Building iOS app..."
    xcodebuild \
        -project "$PROJECT" \
        -scheme "LifeAdmin" \
        -destination "$IOS_DESTINATION" \
        -quiet \
        build
    echo "✅ iOS build succeeded"
}

build_watch() {
    echo "⌚ Building watchOS app..."
    xcodebuild \
        -project "$PROJECT" \
        -scheme "LifeAdmin Watch App" \
        -destination "$WATCH_DESTINATION" \
        -quiet \
        CODE_SIGNING_ALLOWED=NO \
        build
    echo "✅ watchOS build succeeded"
}

# Regenerate project if xcodegen is available
if command -v xcodegen &> /dev/null; then
    echo "📦 Regenerating Xcode project..."
    xcodegen generate --quiet
fi

# Parse arguments
case "${1:-all}" in
    ios)
        build_ios
        ;;
    watch)
        build_watch
        ;;
    all)
        build_ios
        build_watch
        ;;
    *)
        echo "Usage: $0 [ios|watch|all]"
        exit 1
        ;;
esac

echo ""
echo "🎉 Build complete!"
