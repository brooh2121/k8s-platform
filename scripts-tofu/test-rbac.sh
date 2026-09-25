#!/bin/bash
# ============================================
# Проверка RBAC через kubectl auth can-i
# ============================================
# Выполняется на master. Падает, если роль не совпала с ожиданием.
# ============================================

set -e

DEV_SA="system:serviceaccount:dev:developer"
USER_SA="system:serviceaccount:user-space:user"
DEVOPS_SA="system:serviceaccount:default:devops"

assert_can() {
    local as="$1"
    shift
    if kubectl auth can-i "$@" --as="$as" >/dev/null 2>&1; then
        echo "[PASS] $as CAN $*"
    else
        echo "[FAIL] expected allow: $as $*"
        exit 1
    fi
}

assert_cannot() {
    local as="$1"
    shift
    if kubectl auth can-i "$@" --as="$as" >/dev/null 2>&1; then
        echo "[FAIL] expected deny: $as $*"
        exit 1
    else
        echo "[PASS] $as CANNOT $*"
    fi
}

echo "[RBAC-TEST] Checking developer in namespace dev..."
assert_can "$DEV_SA" create deployments -n dev
assert_can "$DEV_SA" get pods -n dev
assert_can "$DEV_SA" delete services -n dev
assert_cannot "$DEV_SA" get pods -n user-space
assert_cannot "$DEV_SA" get nodes

echo "[RBAC-TEST] Checking user in namespace user-space..."
assert_can "$USER_SA" get pods -n user-space
assert_can "$USER_SA" list configmaps -n user-space
assert_cannot "$USER_SA" create deployments -n user-space
assert_cannot "$USER_SA" get pods -n dev
assert_cannot "$USER_SA" delete nodes

echo "[RBAC-TEST] Checking devops cluster-wide..."
assert_can "$DEVOPS_SA" get nodes
assert_can "$DEVOPS_SA" create deployments -n default
assert_can "$DEVOPS_SA" get pods -n dev
assert_can "$DEVOPS_SA" get pods -n user-space

echo "[RBAC-TEST] All RBAC checks passed."
