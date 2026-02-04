#!/bin/bash

# 🧪 Domain Connection Testing Script
# Tests both Railway backend and frontend domain connections

set -e

echo "🌐 Domain Connection Testing Suite"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get domain from user
read -p "Enter your custom domain (e.g., yourdomain.com): " DOMAIN
read -p "Enter your backend subdomain (e.g., api.yourdomain.com): " BACKEND_DOMAIN

echo ""
echo "Testing domains:"
echo "Frontend: https://$DOMAIN"
echo "Backend:  https://$BACKEND_DOMAIN"
echo ""

# Test 1: DNS Resolution
echo "📡 Test 1: DNS Resolution"
echo "========================="

echo -n "Checking frontend DNS... "
if nslookup $DOMAIN > /dev/null 2>&1; then
    echo -e "${GREEN}✓ DNS resolved${NC}"
else
    echo -e "${RED}✗ DNS not resolved${NC}"
    echo "   Wait for DNS propagation or check DNS records"
fi

echo -n "Checking backend DNS... "
if nslookup $BACKEND_DOMAIN > /dev/null 2>&1; then
    echo -e "${GREEN}✓ DNS resolved${NC}"
else
    echo -e "${RED}✗ DNS not resolved${NC}"
    echo "   Wait for DNS propagation or check DNS records"
fi

echo ""

# Test 2: SSL Certificate
echo "🔒 Test 2: SSL Certificate"
echo "=========================="

echo -n "Checking frontend SSL... "
if curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✓ SSL certificate valid${NC}"
else
    echo -e "${YELLOW}⚠ SSL might not be ready yet${NC}"
fi

echo -n "Checking backend SSL... "
if curl -s -o /dev/null -w "%{http_code}" https://$BACKEND_DOMAIN/health | grep -q "200"; then
    echo -e "${GREEN}✓ SSL certificate valid${NC}"
else
    echo -e "${YELLOW}⚠ SSL might not be ready yet${NC}"
fi

echo ""

# Test 3: Backend Health Check
echo "❤️  Test 3: Backend Health Check"
echo "================================"

echo "Testing backend health endpoint..."
HEALTH_RESPONSE=$(curl -s https://$BACKEND_DOMAIN/health)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://$BACKEND_DOMAIN/health)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Backend is healthy${NC}"
    echo "Response: $HEALTH_RESPONSE"
else
    echo -e "${RED}✗ Backend health check failed (HTTP $HTTP_CODE)${NC}"
    echo "Response: $HEALTH_RESPONSE"
fi

echo ""

# Test 4: Backend Metrics
echo "📊 Test 4: Backend Metrics"
echo "========================="

echo "Fetching backend metrics..."
METRICS_RESPONSE=$(curl -s https://$BACKEND_DOMAIN/metrics)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://$BACKEND_DOMAIN/metrics)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Metrics endpoint working${NC}"
    echo "$METRICS_RESPONSE" | jq '.' 2>/dev/null || echo "$METRICS_RESPONSE"
else
    echo -e "${RED}✗ Metrics endpoint failed (HTTP $HTTP_CODE)${NC}"
fi

echo ""

# Test 5: Frontend Connectivity
echo "🎨 Test 5: Frontend Connectivity"
echo "================================"

echo -n "Testing frontend... "
FRONTEND_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN)

if [ "$FRONTEND_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Frontend is accessible (HTTP 200)${NC}"
elif [ "$FRONTEND_CODE" = "301" ] || [ "$FRONTEND_CODE" = "302" ]; then
    echo -e "${GREEN}✓ Frontend is redirecting (HTTP $FRONTEND_CODE)${NC}"
else
    echo -e "${RED}✗ Frontend not accessible (HTTP $FRONTEND_CODE)${NC}"
fi

echo ""

# Test 6: CORS Configuration
echo "🔗 Test 6: CORS Configuration"
echo "============================="

echo "Testing CORS from frontend to backend..."
CORS_RESPONSE=$(curl -s -H "Origin: https://$DOMAIN" -H "Access-Control-Request-Method: POST" -X OPTIONS https://$BACKEND_DOMAIN/api/ai/generate-content)

if echo "$CORS_RESPONSE" | grep -qi "access-control-allow-origin"; then
    echo -e "${GREEN}✓ CORS is configured correctly${NC}"
else
    echo -e "${YELLOW}⚠ CORS might need configuration${NC}"
    echo "   Check ALLOWED_ORIGINS in Railway backend environment"
fi

echo ""

# Summary
echo "📝 Summary"
echo "=========="
echo ""
echo "Next steps:"
echo "1. If DNS not resolved: Wait 5-30 minutes for propagation"
echo "2. If SSL not ready: Wait 10-15 minutes after DNS propagates"
echo "3. If CORS issues: Update ALLOWED_ORIGINS in Railway backend variables"
echo "4. Check Railway dashboard for deployment logs if any errors"
echo ""
echo "Full guides:"
echo "- Quick Start: docs/DOMAIN_QUICK_START.md"
echo "- Detailed Guide: docs/DOMAIN_CONNECTION_GUIDE.md"
echo "- Backend Docs: railway-backend/README.md"
