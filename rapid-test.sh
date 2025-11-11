#!/bin/bash

# Configuration
CONTAINER_NAME="rapid-test-server"
TEST_PORT="8888"
TEST_SUBDOMAIN="rapidtest"
DOMAIN_NAME=${DOMAIN_NAME:-"maximesainlot.com"}
TEST_URL="https://${TEST_SUBDOMAIN}.${DOMAIN_NAME}"

# Cleanup function
cleanup() {
    echo ""
    echo "🧹 Cleaning up test container..."
    docker stop $CONTAINER_NAME >/dev/null 2>&1
    docker rm $CONTAINER_NAME >/dev/null 2>&1
    echo "✅ Cleanup complete"
}

# Set up trap to ensure cleanup happens even if script is interrupted
trap cleanup EXIT INT TERM

echo "🚀 RAPID FIRE RATE LIMIT TEST 🚀"
echo "Creating temporary test container..."

# Create a simple HTTP server container in the proxy network
docker run -d \
    --name $CONTAINER_NAME \
    --network proxy \
    -p $TEST_PORT:80 \
    --label "traefik.enable=true" \
    --label "traefik.docker.network=proxy" \
    --label "traefik.http.routers.rapidtest.entrypoints=websecure" \
    --label "traefik.http.routers.rapidtest.rule=Host(\`${TEST_SUBDOMAIN}.${DOMAIN_NAME}\`)" \
    --label "traefik.http.routers.rapidtest.tls.certresolver=letsencrypt" \
    --label "traefik.http.services.rapidtest.loadbalancer.server.port=80" \
    --label "traefik.http.routers.rapidtest.middlewares=test-rate-limit@file" \
    nginx:alpine >/dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Failed to start test container"
    exit 1
fi

echo "✅ Test container created: $CONTAINER_NAME"
echo "🌐 Test URL: $TEST_URL"
echo "⏳ Waiting 10 seconds for Traefik to pick up the new service..."
sleep 10

echo "🔍 Testing container accessibility..."
test_response=$(curl -s -o /dev/null -w "%{http_code}" "$TEST_URL" --connect-timeout 5 --max-time 10 2>/dev/null)
if [[ "$test_response" != "200" ]]; then
    echo "⚠️  Warning: Test container may not be accessible yet (got $test_response). Continuing anyway..."
else
    echo "✅ Test container is accessible"
fi

echo ""
echo "🔥 Starting rapid fire test with 200 requests..."

success=0
rate_limited=0
errors=0

# Make 200 very rapid requests (no delay between them)
for i in {1..200}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" "$TEST_URL" --connect-timeout 2 --max-time 5 2>/dev/null)
    
    if [[ "$response" == "200" ]]; then
        ((success++))
        echo -n "✓"
    elif [[ "$response" == "429" ]]; then
        ((rate_limited++))
        echo -n "🚫"
    else
        ((errors++))
        echo -n "❌"
    fi
    
    # Only a tiny delay to make output readable
    if [[ $((i % 50)) -eq 0 ]]; then
        echo " ($i/200)"
    fi
done

echo ""
echo "📊 RESULTS:"
echo "✅ Successful (200): $success"
echo "🚫 Rate Limited (429): $rate_limited" 
echo "❌ Errors: $errors"
echo ""

if [[ $rate_limited -gt 0 ]]; then
    echo "🎉 SUCCESS: Rate limiting is working! Got $rate_limited rate-limited responses"
else
    echo "⚠️  Rate limiting not triggered. This could mean:"
    echo "   - Rate limit is higher than our request rate"
    echo "   - Middleware is not properly configured on this route"
    echo "   - Our requests are spread out enough to not exceed limits"
fi

# Cleanup will be called automatically by the trap