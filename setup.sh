#!/bin/bash

# Automated failover test script

echo "🧪 Blue/Green Failover Test"
echo "============================="

# Test 1: Initial state (should be Blue)
echo ""
echo "Test 1: Checking initial state..."
response=$(curl -s http://localhost:8080/version)
pool=$(curl -s -I http://localhost:8080/version | grep -i "x-app-pool" | cut -d' ' -f2 | tr -d '\r')
echo "✓ Current pool: $pool"
echo "Response: $response"

# Test 2: Trigger chaos on Blue
echo ""
echo "Test 2: Triggering chaos on Blue..."
chaos_response=$(curl -s -X POST http://localhost:8081/chaos/start?mode=error)
echo "✓ Chaos started: $chaos_response"

# Wait a moment
sleep 2

# Test 3: Verify failover to Green
echo ""
echo "Test 3: Testing failover (should now be Green)..."
for i in {1..5}; do
    pool=$(curl -s -I http://localhost:8080/version | grep -i "x-app-pool" | cut -d' ' -f2 | tr -d '\r')
    http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/version)
    echo "  Request $i: HTTP $http_code, Pool: $pool"
    sleep 1
done

# Test 4: Stop chaos
echo ""
echo "Test 4: Stopping chaos..."
stop_response=$(curl -s -X POST http://localhost:8081/chaos/stop)
echo "✓ Chaos stopped: $stop_response"

# Wait for Blue to recover
sleep 6

# Test 5: Verify Blue is back
echo ""
echo "Test 5: Testing after recovery..."
for i in {1..3}; do
    pool=$(curl -s -I http://localhost:8080/version | grep -i "x-app-pool" | cut -d' ' -f2 | tr -d '\r')
    http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/version)
    echo "  Request $i: HTTP $http_code, Pool: $pool"
    sleep 1
done

echo ""
echo "✨ Test complete!"
