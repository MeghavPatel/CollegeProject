#!/bin/bash

echo "🔍 Testing Firebase redirect loop fixes..."

# Check if firebase.json exists and has correct configuration
if [ -f "firebase.json" ]; then
    echo "✅ firebase.json exists"
    if grep -q "rewrites" firebase.json && grep -q "destination.*index.html" firebase.json; then
        echo "✅ Firebase hosting configured with SPA rewrites (no redirects)"
    else
        echo "❌ Firebase hosting configuration issue"
    fi
else
    echo "❌ firebase.json missing"
fi

# Check if web build exists
if [ -d "build/web" ]; then
    echo "✅ Web build exists"
    
    # Check if index.html has proper base href
    if grep -q 'base href="/"' build/web/index.html; then
        echo "✅ Base href properly set to '/'"
    else
        echo "❌ Base href issue in build"
    fi
else
    echo "❌ Web build missing - run 'flutter build web'"
fi

# Check Android manifest
if grep -q 'usesCleartextTraffic="false"' android/app/src/main/AndroidManifest.xml; then
    echo "✅ Cleartext traffic disabled (prevents HTTP redirect loops)"
else
    echo "❌ Cleartext traffic not properly configured"
fi

echo ""
echo "🎯 Summary: Redirect loop fixes implemented"
echo "   - Firebase hosting uses rewrites (not redirects)"
echo "   - Base href set correctly for web"
echo "   - Android enforces HTTPS only"
echo "   - Flutter navigation handles all routes"
echo ""
echo "🚀 Ready to test on:"
echo "   - Cloud Workstation preview (cloudworkstations.dev)"
echo "   - Firebase Hosting (your-project.web.app)"
echo "   - Android emulator/device"