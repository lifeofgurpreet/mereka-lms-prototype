#!/usr/bin/env bash
set -euo pipefail

# Docker cleanup script for mereka.academy
# Removes unused images, containers, volumes, and build cache

echo "=== Docker Cleanup Assessment ==="
echo ""

# Show current disk usage
echo "Current Docker disk usage:"
docker system df
echo ""

# Images currently in use
echo "Images currently in use:"
docker ps --format "{{.Image}}" | sort -u
echo ""

# Show what will be removed
echo "=== Items to be removed ==="
echo ""

# Dangling images
echo "1. Dangling images:"
docker images --filter "dangling=true" --format "  {{.ID}}\t{{.Size}}"
echo ""

# Old Supabase images (keep only latest)
echo "2. Old Supabase images (keeping latest versions):"
docker images "public.ecr.aws/supabase/*" --format "  {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" 2>/dev/null | grep -v "v2.57.3\|v1.69.15\|v0.93.1\|17.6.1.029\|1.23.2\|v1.28.2\|2025.10.27" || echo "  (none)"
echo ""

# Old OpenEdX images from GCP registry
echo "3. Old OpenEdX images from GCP registry (not in use):"
docker images "asia-southeast1-docker.pkg.dev/mereka-lms/openedx/*" --format "  {{.Repository}}:{{.Tag}}\t{{.Size}}" 2>/dev/null || echo "  (none)"
echo ""

# Old MySQL version
echo "4. Old MySQL version:"
docker images "mysql:8.0.40" --format "  {{.Repository}}:{{.Tag}}\t{{.Size}}" 2>/dev/null || echo "  (none)"
echo ""

# Old MongoDB versions
echo "5. Old MongoDB versions:"
docker images "mongo:5.0" --format "  {{.Repository}}:{{.Tag}}\t{{.Size}}" 2>/dev/null || echo "  (none)"
docker images "mongo:4.0.25" --format "  {{.Repository}}:{{.Tag}}\t{{.Size}}" 2>/dev/null || echo "  (none)"
echo ""

# Old Redis version
echo "6. Old Redis version:"
docker images "redis:6.2.1" --format "  {{.Repository}}:{{.Tag}}\t{{.Size}}" 2>/dev/null || echo "  (none)"
echo ""

# Old Caddy version
echo "7. Old Caddy version:"
docker images "caddy:2.3.0" --format "  {{.Repository}}:{{.Tag}}\t{{.Size}}" 2>/dev/null || echo "  (none)"
echo ""

# Old Elasticsearch version
echo "8. Old Elasticsearch version:"
docker images "elasticsearch:7.8.1" --format "  {{.Repository}}:{{.Tag}}\t{{.Size}}" 2>/dev/null || echo "  (none)"
echo ""

# Stopped containers
echo "9. Stopped containers:"
docker ps -a --filter "status=exited" --format "  {{.Names}}\t{{.Image}}\t{{.Status}}"
echo ""

# Build cache size
BUILD_CACHE_SIZE=$(docker system df --format "{{.Size}}" | grep "Build Cache" | awk '{print $3}' || echo "unknown")
echo "10. Build cache: ${BUILD_CACHE_SIZE}"
echo ""

# Dangling volumes
DANGLING_VOLUMES=$(docker volume ls --filter "dangling=true" -q | wc -l | tr -d ' ')
echo "11. Dangling volumes: ${DANGLING_VOLUMES}"
echo ""

# Calculate estimated space to be freed
echo "=== Estimated space to be freed ==="
echo "Run with --execute flag to perform cleanup"
echo ""

if [[ "${1:-}" == "--execute" ]]; then
    echo "=== Executing cleanup ==="
    echo ""
    
    # Remove stopped containers
    echo "Removing stopped containers..."
    docker container prune -f
    echo ""
    
    # Remove dangling images
    echo "Removing dangling images..."
    docker image prune -f
    echo ""
    
    # Remove old Supabase images (keep latest)
    echo "Removing old Supabase images..."
    OLD_SUPABASE=$(docker images "public.ecr.aws/supabase/*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | \
        grep -v "v2.57.3\|v1.69.15\|v0.93.1\|17.6.1.029\|1.23.2\|v1.28.2\|2025.10.27" || true)
    if [[ -n "$OLD_SUPABASE" ]]; then
        echo "$OLD_SUPABASE" | xargs docker rmi 2>/dev/null || true
    fi
    echo ""
    
    # Remove old OpenEdX images from GCP registry
    echo "Removing old OpenEdX images from GCP registry..."
    OLD_OPENEDX=$(docker images "asia-southeast1-docker.pkg.dev/mereka-lms/openedx/*" --format "{{.ID}}" 2>/dev/null || true)
    if [[ -n "$OLD_OPENEDX" ]]; then
        echo "$OLD_OPENEDX" | xargs docker rmi 2>/dev/null || true
    fi
    echo ""
    
    # Remove old MySQL version
    echo "Removing old MySQL version..."
    docker rmi mysql:8.0.40 2>/dev/null || true
    echo ""
    
    # Remove old MongoDB versions
    echo "Removing old MongoDB versions..."
    docker rmi mongo:5.0 2>/dev/null || true
    docker rmi mongo:4.0.25 2>/dev/null || true
    echo ""
    
    # Remove old Redis version
    echo "Removing old Redis version..."
    docker rmi redis:6.2.1 2>/dev/null || true
    echo ""
    
    # Remove old Caddy version
    echo "Removing old Caddy version..."
    docker rmi caddy:2.3.0 2>/dev/null || true
    echo ""
    
    # Remove old Elasticsearch version
    echo "Removing old Elasticsearch version..."
    docker rmi elasticsearch:7.8.1 2>/dev/null || true
    echo ""
    
    # Remove unused images (not tagged and not in use)
    echo "Removing unused images..."
    docker image prune -a -f --filter "until=168h"  # Remove images older than 7 days that are not in use
    echo ""
    
    # Remove build cache
    echo "Removing build cache..."
    docker builder prune -a -f
    echo ""
    
    # Remove dangling volumes
    echo "Removing dangling volumes..."
    docker volume prune -f
    echo ""
    
    echo "=== Cleanup complete ==="
    echo ""
    echo "Final Docker disk usage:"
    docker system df
else
    echo "To execute cleanup, run: $0 --execute"
fi

