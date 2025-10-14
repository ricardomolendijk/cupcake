.PHONY: help build test install clean lint helm-package helm-lint

# Configuration
REGISTRY ?= localhost:5000
OPERATOR_IMAGE ?= kube-update-operator
AGENT_IMAGE ?= kube-update-agent
TAG ?= latest
NAMESPACE ?= kube-system
CHART_VERSION ?= 0.1.0

help:
	@echo "Kubernetes Update Operator - Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make build            - Build operator and agent Docker images"
	@echo "  make push             - Push images to registry"
	@echo "  make test             - Run unit tests"
	@echo "  make test-e2e         - Run end-to-end tests"
	@echo "  make helm-lint        - Lint Helm chart"
	@echo "  make helm-package     - Package Helm chart"
	@echo "  make helm-push        - Push Helm chart to OCI registry"
	@echo "  make install          - Install operator via Helm"
	@echo "  make uninstall        - Uninstall operator"
	@echo "  make lint             - Run linters"
	@echo "  make clean            - Clean up generated files"
	@echo ""
	@echo "Variables:"
	@echo "  REGISTRY=$(REGISTRY)"
	@echo "  TAG=$(TAG)"
	@echo "  NAMESPACE=$(NAMESPACE)"
	@echo "  CHART_VERSION=$(CHART_VERSION)"

build:
	@echo "Building images..."
	docker build -t $(REGISTRY)/$(OPERATOR_IMAGE):$(TAG) -f operator/Dockerfile operator/
	docker build -t $(REGISTRY)/$(AGENT_IMAGE):$(TAG) -f agent/Dockerfile agent/

push: build
	@echo "Pushing images..."
	docker push $(REGISTRY)/$(OPERATOR_IMAGE):$(TAG)
	docker push $(REGISTRY)/$(AGENT_IMAGE):$(TAG)

test:
	@echo "Running unit tests..."
	cd tests && python -m pytest -v

test-e2e:
	@echo "Running integration tests..."
	./test.sh all

helm-lint:
	@echo "Linting Helm chart..."
	helm lint ./helm

helm-package: helm-lint
	@echo "Packaging Helm chart..."
	helm package ./helm --version $(CHART_VERSION) --app-version $(TAG)
	@echo "Chart packaged: kube-update-operator-$(CHART_VERSION).tgz"

helm-push: helm-package
	@echo "Pushing Helm chart to OCI registry..."
	helm push kube-update-operator-$(CHART_VERSION).tgz oci://$(REGISTRY)

helm-template:
	@echo "Rendering Helm templates..."
	helm template kube-update-operator ./helm --namespace $(NAMESPACE)

lint:
	@echo "Running linters..."
	cd operator && pylint *.py lib/ handlers/ || true
	cd agent && pylint *.py || true
	yamllint crds/ helm/ examples/ || true

install: helm-lint
	@echo "Installing operator..."
	helm install kube-update-operator ./helm \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--set operator.image.repository=$(REGISTRY)/$(OPERATOR_IMAGE) \
		--set operator.image.tag=$(TAG) \
		--set agent.image.repository=$(REGISTRY)/$(AGENT_IMAGE) \
		--set agent.image.tag=$(TAG) \
		--wait

upgrade:
	@echo "Upgrading operator..."
	helm upgrade kube-update-operator ./helm \
		--namespace $(NAMESPACE) \
		--set operator.image.repository=$(REGISTRY)/$(OPERATOR_IMAGE) \
		--set operator.image.tag=$(TAG) \
		--set agent.image.repository=$(REGISTRY)/$(AGENT_IMAGE) \
		--set agent.image.tag=$(TAG) \
		--wait

uninstall:
	@echo "Uninstalling operator..."
	helm uninstall kube-update-operator -n $(NAMESPACE) || true

clean:
	@echo "Cleaning up..."
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	rm -f kube-update-operator-*.tgz

deps-operator:
	@echo "Installing operator dependencies..."
	cd operator && pip install -r requirements.txt

deps-agent:
	@echo "Installing agent dependencies..."
	cd agent && pip install -r requirements.txt

deps: deps-operator deps-agent

dev-setup: deps helm-lint
	@echo "Development environment ready!"

# Examples
example-basic:
	kubectl apply -f examples/directupdate-basic.yaml

example-canary:
	kubectl apply -f examples/directupdate-canary.yaml

example-scheduled:
	kubectl apply -f examples/scheduledupdate-basic.yaml

watch:
	kubectl get directupdate,scheduledupdate,updateschedule -A -w

logs-operator:
	kubectl logs -n $(NAMESPACE) deployment/kube-update-operator -f

logs-agent:
	kubectl logs -n $(NAMESPACE) daemonset/kube-update-operator-agent --all-containers -f

describe:
	kubectl describe directupdate -A

status:
	kubectl get directupdate -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.status.summary}{"\n"}{end}'

# Full workflow
all: clean build push helm-package
	@echo "Build complete!"

release: all helm-push
	@echo "Release complete!"
