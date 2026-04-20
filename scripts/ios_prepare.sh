#!/bin/bash

echo "🔄 Regenerating iOS project structure..."

# Recreate the iOS project with correct paths for the current machine
flutter create --platforms=ios .

# Ensure the bundle identifier is set correctly
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = .*;/PRODUCT_BUNDLE_IDENTIFIER = com.gigscourt.app;/g' ios/Runner.xcodeproj/project.pbxproj

# Ensure display name is set correctly
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName GigsCourt" ios/Runner/Info.plist 2>/dev/null || true

echo "✅ iOS project prepared successfully"
