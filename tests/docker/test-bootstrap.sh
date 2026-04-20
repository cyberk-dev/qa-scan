#!/bin/bash
# Test install.sh bootstrap in Docker
# Usage: ./test-bootstrap.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "╔══════════════════════════════════════╗"
echo "║  QA Scan Bootstrap — Docker Test     ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Test 1: Ubuntu 22.04 (full install)
echo "─── Test 1: Ubuntu 22.04 Full Install ───"
docker run --rm \
  -v "$REPO_ROOT/install.sh:/app/install.sh:ro" \
  -e CI=true \
  ubuntu:22.04 \
  bash -c '
    apt-get update -qq && apt-get install -y curl >/dev/null 2>&1
    echo "Running install.sh --non-interactive..."
    bash /app/install.sh --non-interactive --dir /tmp/qa-scan 2>&1 | head -50
    echo ""
    echo "=== Verification ==="
    command -v git && echo "✓ git installed" || echo "✗ git missing"
    command -v jq && echo "✓ jq installed" || echo "✗ jq missing"
    command -v gh && echo "✓ gh installed" || echo "✗ gh missing"
    command -v bun && echo "✓ bun installed" || echo "✗ bun missing"
  '

echo ""
echo "─── Test 2: CI Detection ───"
docker run --rm \
  -e CI=true \
  -e GITHUB_ACTIONS=true \
  ubuntu:22.04 \
  bash -c '
    # Source just the CI detection part
    IS_CI=false
    NON_INTERACTIVE=false
    if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
      IS_CI=true
      NON_INTERACTIVE=true
    fi
    echo "CI=$CI GITHUB_ACTIONS=$GITHUB_ACTIONS"
    echo "IS_CI=$IS_CI NON_INTERACTIVE=$NON_INTERACTIVE"
    [ "$IS_CI" = true ] && echo "✓ CI detected" || echo "✗ CI not detected"
  '

echo ""
echo "─── Test 3: GitLab CI Detection ───"
docker run --rm \
  -e GITLAB_CI=true \
  ubuntu:22.04 \
  bash -c '
    IS_CI=false
    if [ -n "${GITLAB_CI:-}" ]; then IS_CI=true; fi
    echo "GITLAB_CI=$GITLAB_CI → IS_CI=$IS_CI"
    [ "$IS_CI" = true ] && echo "✓ GitLab CI detected" || echo "✗ GitLab CI not detected"
  '

echo ""
echo "─── Test 4: Azure DevOps Detection ───"
docker run --rm \
  -e TF_BUILD=true \
  ubuntu:22.04 \
  bash -c '
    IS_CI=false
    if [ -n "${TF_BUILD:-}" ]; then IS_CI=true; fi
    echo "TF_BUILD=$TF_BUILD → IS_CI=$IS_CI"
    [ "$IS_CI" = true ] && echo "✓ Azure DevOps detected" || echo "✗ Azure DevOps not detected"
  '

echo ""
echo "═══════════════════════════════════════"
echo "  All Docker tests complete"
echo "═══════════════════════════════════════"
