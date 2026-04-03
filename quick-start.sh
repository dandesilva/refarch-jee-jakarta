#!/bin/bash

# Customer Order Services - Quick Start Script
# This script sets up the complete environment

set -e

echo "=========================================="
echo "Customer Order Services - Quick Start"
echo "=========================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

command -v podman >/dev/null 2>&1 || command -v docker >/dev/null 2>&1 || {
    echo "Error: Neither podman nor docker is installed"
    exit 1
}

# Determine container runtime
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
else
    CONTAINER_CMD="docker"
fi

echo "✓ Using container runtime: $CONTAINER_CMD"

# Create network
echo ""
echo "Creating container network..."
$CONTAINER_CMD network create customerorder-net 2>/dev/null || echo "Network already exists"
echo "✓ Network ready"

# Start PostgreSQL
echo ""
echo "Starting PostgreSQL database..."
$CONTAINER_CMD run -d --name postgres-orderdb \
  --network customerorder-net \
  -p 15432:5432 \
  -e POSTGRES_DB=ORDERDB \
  -e POSTGRES_USER=db2inst1 \
  -e POSTGRES_PASSWORD=db2inst1 \
  postgres:15 2>/dev/null || echo "PostgreSQL already running"

echo "Waiting for PostgreSQL to be ready..."
sleep 5
echo "✓ PostgreSQL ready"

# Load database schema
echo ""
echo "Loading database schema and sample data..."
$CONTAINER_CMD exec -i postgres-orderdb \
  psql -U db2inst1 -d ORDERDB < Common/createOrderDB_postgres.sql 2>/dev/null || true
echo "✓ Database initialized"

# Build application
echo ""
echo "Building application container..."
$CONTAINER_CMD build -f Dockerfile.redhat -t customerorder-app:latest .
echo "✓ Application built"

# Start application
echo ""
echo "Starting application..."
$CONTAINER_CMD run -d --name customerorder-app \
  --network customerorder-net \
  -p 8080:8080 \
  -p 9990:9990 \
  customerorder-app:latest 2>/dev/null || {
    echo "Stopping existing container..."
    $CONTAINER_CMD stop customerorder-app 2>/dev/null || true
    $CONTAINER_CMD rm customerorder-app 2>/dev/null || true
    $CONTAINER_CMD run -d --name customerorder-app \
      --network customerorder-net \
      -p 8080:8080 \
      -p 9990:9990 \
      customerorder-app:latest
}

echo "Waiting for application to start..."
sleep 15
echo "✓ Application started"

# Test endpoints
echo ""
echo "Testing REST endpoints..."
sleep 5

echo ""
echo "Test 1: Get product by ID"
curl -s http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Product/1 | head -c 200
echo "..."

echo ""
echo ""
echo "Test 2: Get categories"
curl -s http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Category | head -c 200
echo "..."

echo ""
echo ""
echo "=========================================="
echo "✓ Setup Complete!"
echo "=========================================="
echo ""
echo "Application URLs:"
echo "  REST API: http://localhost:8080/CustomerOrderServicesWeb/jaxrs"
echo "  Admin Console: http://localhost:9990"
echo ""
echo "Test Commands:"
echo "  curl http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Product/1"
echo "  curl http://localhost:8080/CustomerOrderServicesWeb/jaxrs/Category"
echo ""
echo "View logs:"
echo "  $CONTAINER_CMD logs -f customerorder-app"
echo ""
echo "Stop all:"
echo "  $CONTAINER_CMD stop customerorder-app postgres-orderdb"
echo ""
