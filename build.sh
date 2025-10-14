#!/bin/bash
set -e

# Build script for CUPCAKE - Kubernetes Cluster Upgrade Automation

# Configuration
REGISTRY="${REGISTRY:-ghcr.io/ricardomolendijk}"
OPERATOR_IMAGE="${OPERATOR_IMAGE:-cupcake}"
AGENT_IMAGE="${AGENT_IMAGE:-cupcake-agent}"
TAG="${TAG:-latest}"
BUILD_ARGS="${BUILD_ARGS:-}"

echo "==============================================="
echo "Building CUPCAKE 🧁"
echo "Control-plane Upgrade Platform for"
echo "Continuous Kubernetes Automation and Evolution"
echo "==============================================="
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
echo ""

# Build operator image
echo "► Building operator image..."
docker build ${BUILD_ARGS} \
  -t "${REGISTRY}/${OPERATOR_IMAGE}:${TAG}" \
  -f operator/Dockerfile \
  operator/

echo "✓ Operator image built: ${REGISTRY}/${OPERATOR_IMAGE}:${TAG}"
echo ""

# Build agent image
echo "► Building agent image..."
docker build ${BUILD_ARGS} \
  -t "${REGISTRY}/${AGENT_IMAGE}:${TAG}" \
  -f agent/Dockerfile \
  agent/

echo "✓ Agent image built: ${REGISTRY}/${AGENT_IMAGE}:${TAG}"
echo ""

# Tag as latest if not already
if [ "$TAG" != "latest" ]; then
  docker tag "${REGISTRY}/${OPERATOR_IMAGE}:${TAG}" "${REGISTRY}/${OPERATOR_IMAGE}:latest"
  docker tag "${REGISTRY}/${AGENT_IMAGE}:${TAG}" "${REGISTRY}/${AGENT_IMAGE}:latest"
  echo "✓ Tagged as :latest"
fi

echo ""
echo "==============================================="
echo "Build Complete!"
echo "==============================================="
echo ""
echo "Images built:"
echo "  • ${REGISTRY}/${OPERATOR_IMAGE}:${TAG}"
echo "  • ${REGISTRY}/${AGENT_IMAGE}:${TAG}"
echo ""

# Optionally push if PUSH=true
if [ "${PUSH}" = "true" ]; then
  echo "► Pushing images..."
  docker push "${REGISTRY}/${OPERATOR_IMAGE}:${TAG}"
  docker push "${REGISTRY}/${AGENT_IMAGE}:${TAG}"
  
  if [ "$TAG" != "latest" ]; then
    docker push "${REGISTRY}/${OPERATOR_IMAGE}:latest"
    docker push "${REGISTRY}/${AGENT_IMAGE}:latest"
  fi
  
  echo "✓ Push complete!"
fi

# Optionally package Helm chart if PACKAGE=true
if [ "${PACKAGE}" = "true" ]; then
  CHART_VERSION="${CHART_VERSION:-0.1.0}"
  echo ""
  echo "► Packaging Helm chart..."
  helm lint ./helm
  helm package ./helm --version "${CHART_VERSION}" --app-version "${TAG}"
  echo "✓ Chart packaged: cupcake-${CHART_VERSION}.tgz"
fi

echo ""
echo "Next steps:"
echo "  • Push images: PUSH=true ./build.sh"
echo "  • Package chart: PACKAGE=true ./build.sh"
echo "  • Install: helm install cupcake ./helm"
echo ""
