#!/bin/bash
#
# run-tests.sh
# Runs all LifeAdmin unit tests
#
# Usage: ./scripts/run-tests.sh
#

set -e

# Ensure we're in the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Set Xcode developer directory (for unprivileged users)
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# Configuration
SCHEME="LifeAdmin"
DESTINATION="platform=iOS Simulator,name=iPhone 14 Pro Max"
PROJECT="LifeAdmin.xcodeproj"

echo "🧪 Running LifeAdmin tests..."
echo "   Scheme: $SCHEME"
echo "   Destination: $DESTINATION"
echo ""

# Regenerate project if xcodegen is available
if command -v xcodegen &> /dev/null; then
    echo "📦 Regenerating Xcode project..."
    xcodegen generate --quiet
fi

# Run tests
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -quiet \
    test

echo ""
echo "✅ All tests passed!"
