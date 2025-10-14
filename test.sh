#!/bin/bash
set -e

# Test script for Kubernetes Update Operator
# Requires: kind, kubectl, helm, docker

echo "=== Kubernetes Update Operator Integration Test ==="

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-kube-update-test}"
REGISTRY_NAME="${REGISTRY_NAME:-kind-registry}"
REGISTRY_PORT="${REGISTRY_PORT:-5001}"

# Functions
create_kind_cluster() {
  echo ""
  echo "Creating Kind cluster: $CLUSTER_NAME"
  
  cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REGISTRY_PORT}"]
    endpoint = ["http://${REGISTRY_NAME}:5000"]
EOF
}

create_registry() {
  echo ""
  echo "Creating local Docker registry"
  
  if [ "$(docker inspect -f '{{.State.Running}}' ${REGISTRY_NAME} 2>/dev/null || true)" != 'true' ]; then
    docker run -d --restart=always -p "${REGISTRY_PORT}:5000" --name "${REGISTRY_NAME}" registry:2
  fi
  
  # Connect registry to kind network
  docker network connect "kind" "${REGISTRY_NAME}" 2>/dev/null || true
}

build_images() {
  echo ""
  echo "Building images..."
  
  REGISTRY="localhost:${REGISTRY_PORT}" TAG="test" ./build.sh
}

install_operator() {
  echo ""
  echo "Installing CRDs..."
  kubectl apply -f crds/
  
  echo ""
  echo "Installing operator via Helm..."
  helm install cupcake ./helm \
    --namespace kube-system \
    --values values-test.yaml \
    --set operator.image.repository="localhost:${REGISTRY_PORT}/cupcake" \
    --set operator.image.tag="test" \
    --set agent.image.repository="localhost:${REGISTRY_PORT}/cupcake-agent" \
    --set agent.image.tag="test" \
    --wait --timeout=5m
}

wait_for_operator() {
  echo ""
  echo "Waiting for operator to be ready..."
  kubectl wait --for=condition=available --timeout=300s \
    deployment/cupcake -n kube-system
  
  echo "Waiting for agent daemonset..."
  kubectl rollout status daemonset/cupcake-agent -n kube-system --timeout=300s
}

run_tests() {
  echo ""
  echo "Running tests..."
  
  # Test 1: Create DirectUpdate CR
  echo ""
  echo "Test 1: Creating DirectUpdate CR"
  kubectl apply -f examples/directupdate-basic.yaml
  
  # Wait a bit for reconciliation
  sleep 10
  
  # Check status
  echo "Checking DirectUpdate status..."
  kubectl get directupdate upgrade-to-1-27-4 -o yaml
  
  # Verify status is Pending or InProgress
  PHASE=$(kubectl get directupdate upgrade-to-1-27-4 -o jsonpath='{.status.phase}')
  echo "Current phase: $PHASE"
  
  if [ "$PHASE" = "Pending" ] || [ "$PHASE" = "InProgress" ]; then
    echo "✓ Test 1 passed: DirectUpdate CR created and reconciled"
  else
    echo "✗ Test 1 failed: Unexpected phase $PHASE"
    return 1
  fi
  
  # Test 2: Check operator logs
  echo ""
  echo "Test 2: Checking operator logs"
  kubectl logs -n kube-system deployment/cupcake --tail=50
  
  # Test 3: Check agent logs
  echo ""
  echo "Test 3: Checking agent logs"
  kubectl logs -n kube-system daemonset/cupcake-agent --tail=50 --all-containers
  
  # Test 4: Verify metrics endpoint
  echo ""
  echo "Test 4: Checking metrics endpoint"
  kubectl run metrics-test --image=curlimages/curl:latest --rm -i --restart=Never -- \
    curl -s http://cupcake-metrics.kube-system:8080/metrics | head -20
  
  echo ""
  echo "✓ All tests passed!"
}

cleanup() {
  echo ""
  echo "Cleaning up..."
  
  # Delete DirectUpdate CR
  kubectl delete directupdate upgrade-to-1-27-4 --ignore-not-found
  
  # Uninstall operator
  helm uninstall cupcake -n kube-system || true
  
  # Delete CRDs
  kubectl delete -f crds/ --ignore-not-found || true
  
  # Delete cluster
  kind delete cluster --name "$CLUSTER_NAME" || true
  
  # Stop registry
  docker stop "${REGISTRY_NAME}" || true
  docker rm "${REGISTRY_NAME}" || true
}

# Main execution
main() {
  case "${1:-all}" in
    cluster)
      create_kind_cluster
      create_registry
      ;;
    build)
      build_images
      ;;
    install)
      install_operator
      wait_for_operator
      ;;
    test)
      run_tests
      ;;
    cleanup)
      cleanup
      ;;
    all)
      create_registry
      create_kind_cluster
      build_images
      install_operator
      wait_for_operator
      run_tests
      ;;
    *)
      echo "Usage: $0 {cluster|build|install|test|cleanup|all}"
      exit 1
      ;;
  esac
}

# Handle Ctrl+C
trap cleanup EXIT INT TERM

main "$@"
