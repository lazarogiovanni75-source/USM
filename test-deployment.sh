#!/bin/bash

echo "======================================"
echo "Railway Deployment Status Checker"
echo "======================================"
echo ""
echo "Domain: www.ultimatesocialmedia01.com"
echo "Time: $(date)"
echo ""

echo "Testing health endpoint..."
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' https://www.ultimatesocialmedia01.com/up)

if [ "$HTTP_CODE" == "200" ]; then
    echo "✅ SUCCESS! Health check returned HTTP $HTTP_CODE"
    echo ""
    echo "Testing main page..."
    MAIN_CODE=$(curl -s -o /dev/null -w '%{http_code}' https://www.ultimatesocialmedia01.com)
    echo "Main page returned HTTP $MAIN_CODE"
    echo ""
    echo "🎉 YOUR DOMAIN IS LIVE!"
    echo "Visit: https://www.ultimatesocialmedia01.com"
elif [ "$HTTP_CODE" == "502" ]; then
    echo "⏳ Still getting HTTP 502 - Railway deployment in progress"
    echo ""
    echo "This means:"
    echo "  - Railway is building/deploying your app"
    echo "  - Or the app hasn't started yet"
    echo ""
    echo "Please wait 1-2 more minutes and run this script again:"
    echo "  bash test-deployment.sh"
elif [ "$HTTP_CODE" == "000" ]; then
    echo "❌ Connection failed - HTTP $HTTP_CODE"
    echo "Check your internet connection"
else
    echo "⚠️  Unexpected HTTP status: $HTTP_CODE"
    echo "Check Railway deployment logs"
fi

echo ""
echo "======================================"
