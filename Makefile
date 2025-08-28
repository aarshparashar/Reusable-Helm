# Helm Chart Makefile for EKS Deployment
# Supports both local (minikube) and EKS deployments

NAMESPACE := demo
CHART := ./chart
AWS_REGION := us-west-2
EKS_CLUSTER_NAME := my-eks-cluster

# Detect if running on EKS or local
KUBECTL_CONTEXT := $(shell kubectl config current-context 2>/dev/null || echo "none")
IS_EKS := $(shell echo $(KUBECTL_CONTEXT) | grep -q 'eks' && echo "true" || echo "false")

.PHONY: help setup install test update rollback status clean

help: ## Show available commands
	@echo "Helm Chart Commands for Kubernetes/EKS:"
	@echo "Current context: $(KUBECTL_CONTEXT)"
	@echo "EKS mode: $(IS_EKS)"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: ## Create namespace and verify prerequisites
	@echo "Setting up demo environment..."
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@echo "✓ Namespace ready"

install: setup ## Install both services
	@echo "Installing Service A..."
	helm install service-a $(CHART) -n $(NAMESPACE) -f values/values-service-a.yaml
	@echo "Installing Service B..."
	helm install service-b $(CHART) -n $(NAMESPACE) -f values/values-service-b.yaml
	@echo "✓ Both services installed"

test: ## Test both services
	@echo "Testing Service A:"
	@kubectl port-forward service/service-a 8080:8080 -n $(NAMESPACE) &
	@sleep 2
	@curl -s http://localhost:8080 || echo "Failed"
	@pkill -f "kubectl port-forward service/service-a" || true
	@echo ""
	@echo "Testing Service B:"
	@kubectl port-forward service/service-b 8081:8080 -n $(NAMESPACE) &
	@sleep 2
	@curl -s http://localhost:8081 || echo "Failed"
	@pkill -f "kubectl port-forward service/service-b" || true

update: ## Update Service A config to trigger rolling restart
	@echo "Updating Service A configuration..."
	@echo "nameOverride: \"service-a\"" > /tmp/service-a-updated.yaml
	@echo "args:" >> /tmp/service-a-updated.yaml
	@echo "  - \"-text=UPDATED: Hello from Service A!\"" >> /tmp/service-a-updated.yaml
	@echo "  - \"-listen=:8080\"" >> /tmp/service-a-updated.yaml
	@echo "configMap:" >> /tmp/service-a-updated.yaml
	@echo "  enabled: true" >> /tmp/service-a-updated.yaml
	@echo "  data:" >> /tmp/service-a-updated.yaml
	@echo "    MESSAGE: \"UPDATED: Welcome to Service A!\"" >> /tmp/service-a-updated.yaml
	@echo "    VERSION: \"v1.1.0\"" >> /tmp/service-a-updated.yaml
	helm upgrade service-a $(CHART) -n $(NAMESPACE) -f values/values-service-a.yaml -f /tmp/service-a-updated.yaml
	kubectl rollout status deployment/service-a -n $(NAMESPACE)
	@rm -f /tmp/service-a-updated.yaml
	@echo "✓ Service A updated with rolling restart"

rollback: ## Rollback Service A to previous version
	@echo "Rolling back Service A..."
	helm rollback service-a -n $(NAMESPACE)
	kubectl rollout status deployment/service-a -n $(NAMESPACE)
	@echo "✓ Service A rolled back"

history: ## Show helm release history
	@echo "Service A History:"
	helm history service-a -n $(NAMESPACE)
	@echo ""
	@echo "Service B History:"
	helm history service-b -n $(NAMESPACE)

status: ## Show status of all resources
	@echo "=== Deployments ==="
	kubectl get deploy -n $(NAMESPACE)
	@echo ""
	@echo "=== Pods ==="
	kubectl get pods -n $(NAMESPACE)
	@echo ""
	@echo "=== Services ==="
	kubectl get svc -n $(NAMESPACE)
	@echo ""
	@echo "=== Helm Releases ==="
	helm list -n $(NAMESPACE)

clean: ## Remove both services
	helm uninstall service-a -n $(NAMESPACE) || echo "service-a not found"
	helm uninstall service-b -n $(NAMESPACE) || echo "service-b not found"
	@echo "✓ Services removed"

clean-all: clean ## Remove services and namespace
	kubectl delete namespace $(NAMESPACE) || echo "namespace not found"
	@echo "✓ Complete cleanup done"

# Quick demo sequence
demo: install status test update test rollback test ## Run complete demo sequence

## EKS-specific commands
eks-configure: ## Configure kubectl for EKS cluster
	@echo "Configuring kubectl for EKS cluster..."
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(EKS_CLUSTER_NAME)
	@echo "✓ EKS kubeconfig updated"

eks-info: ## Show EKS cluster information
	@echo "EKS Cluster Information:"
	@echo "Cluster: $(EKS_CLUSTER_NAME)"
	@echo "Region: $(AWS_REGION)"
	@echo "Current context: $(KUBECTL_CONTEXT)"
	@kubectl cluster-info
	@echo ""
	@echo "Node information:"
	@kubectl get nodes -o wide

eks-install: eks-configure install ## Configure EKS and install services

eks-deploy-staging: eks-configure ## Deploy to staging namespace on EKS
	@echo "Deploying to staging environment on EKS..."
	kubectl create namespace $(NAMESPACE)-staging --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install service-a-staging $(CHART) \
		--namespace $(NAMESPACE)-staging \
		--values values/values-service-a.yaml \
		--set nameOverride=service-a-staging \
		--wait --timeout=300s
	helm upgrade --install service-b-staging $(CHART) \
		--namespace $(NAMESPACE)-staging \
		--values values/values-service-b.yaml \
		--set nameOverride=service-b-staging \
		--wait --timeout=300s
	@echo "✓ Staging deployment complete"

eks-test-external: ## Test services via LoadBalancer (if configured)
	@echo "Testing services via external access..."
	@echo "Service A LoadBalancer:"
	@kubectl get svc service-a -n $(NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "No external IP"
	@echo ""
	@echo "Service B LoadBalancer:"
	@kubectl get svc service-b -n $(NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "No external IP"

## Monitoring and troubleshooting
logs-a: ## Show logs for Service A
	kubectl logs -l app.kubernetes.io/instance=service-a -n $(NAMESPACE) --tail=50

logs-b: ## Show logs for Service B
	kubectl logs -l app.kubernetes.io/instance=service-b -n $(NAMESPACE) --tail=50

describe-a: ## Describe Service A resources
	kubectl describe deployment,service,configmap,secret service-a -n $(NAMESPACE)

describe-b: ## Describe Service B resources
	kubectl describe deployment,service,configmap,secret service-b -n $(NAMESPACE)