#!/bin/bash

# Helm Chart Demo Script for Job Assessment
# Demonstrates all required capabilities in sequence

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

NAMESPACE="demo"

echo -e "${GREEN}🎯 Helm Chart Job Assessment Demo${NC}"
echo -e "${BLUE}This script demonstrates all required capabilities:${NC}"
echo -e "  ✅ Reusable Helm chart for microservices"
echo -e "  ✅ Deploy multiple services from one chart"
echo -e "  ✅ ConfigMap changes trigger rolling updates"
echo -e "  ✅ Helm history and rollback functionality"
echo ""

# Function to wait for user input
wait_for_user() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# Function to run command and show output
run_and_show() {
    echo -e "${BLUE}💻 Running: $1${NC}"
    eval "$1"
    echo ""
}

echo -e "${GREEN}📋 Step 1: Setup and Install Services${NC}"
echo "Setting up namespace and installing both services from the same chart..."
wait_for_user

run_and_show "kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -"
run_and_show "helm install service-a ./chart -n $NAMESPACE -f values/values-service-a.yaml"
run_and_show "helm install service-b ./chart -n $NAMESPACE -f values/values-service-b.yaml"

echo -e "${GREEN}📊 Step 2: Verify Deployments${NC}"
echo "Checking that all Kubernetes objects are created..."
wait_for_user

run_and_show "kubectl get deploy,rs,pods,svc,hpa,pdb,sa,configmap,secret -n $NAMESPACE"
run_and_show "helm list -n $NAMESPACE"

echo -e "${GREEN}🧪 Step 3: Test Services${NC}"
echo "Testing both services to ensure they're working..."
wait_for_user

echo -e "${BLUE}Testing Service A:${NC}"
kubectl port-forward service/service-a 8080:8080 -n $NAMESPACE &
PID_A=$!
sleep 3
echo -e "Response: $(curl -s http://localhost:8080)"
kill $PID_A 2>/dev/null || true
echo ""

echo -e "${BLUE}Testing Service B:${NC}"
kubectl port-forward service/service-b 8081:8080 -n $NAMESPACE &
PID_B=$!
sleep 3
echo -e "Response: $(curl -s http://localhost:8081)"
kill $PID_B 2>/dev/null || true
echo ""

echo -e "${GREEN}🔄 Step 4: ConfigMap Change → Rolling Update${NC}"
echo "Updating Service A's ConfigMap to trigger automatic rolling restart..."
wait_for_user

echo -e "${BLUE}Current pods before update:${NC}"
kubectl get pods -l app.kubernetes.io/instance=service-a -n $NAMESPACE

echo -e "${BLUE}Updating Service A configuration...${NC}"
cat > /tmp/service-a-updated.yaml << 'EOF'
nameOverride: "service-a"
args:
  - "-text=UPDATED: Hello from Service A!"
  - "-listen=:8080"
configMap:
  enabled: true
  data:
    MESSAGE: "UPDATED: Welcome to Service A!"
    VERSION: "v1.1.0"
    UPDATE_TIME: "$(date)"
EOF

run_and_show "helm upgrade service-a ./chart -n $NAMESPACE -f values/values-service-a.yaml -f /tmp/service-a-updated.yaml"

echo -e "${BLUE}Monitoring rolling update...${NC}"
kubectl rollout status deployment/service-a -n $NAMESPACE

echo -e "${BLUE}New pods after update (note new AGE):${NC}"
kubectl get pods -l app.kubernetes.io/instance=service-a -n $NAMESPACE

echo -e "${GREEN}✅ Step 5: Verify Rolling Update${NC}"
echo "Testing updated service to confirm new configuration..."
wait_for_user

echo -e "${BLUE}Testing updated Service A:${NC}"
kubectl port-forward service/service-a 8080:8080 -n $NAMESPACE &
PID_A=$!
sleep 3
echo -e "Updated Response: $(curl -s http://localhost:8080)"
kill $PID_A 2>/dev/null || true
echo ""

echo -e "${BLUE}Checking checksum annotation (rolling update mechanism):${NC}"
kubectl get pod -l app.kubernetes.io/instance=service-a -n $NAMESPACE -o yaml | grep "checksum/config" | head -1

echo -e "${GREEN}📚 Step 6: Helm History${NC}"
echo "Viewing release history..."
wait_for_user

run_and_show "helm history service-a -n $NAMESPACE"

echo -e "${GREEN}⏪ Step 7: Helm Rollback${NC}"
echo "Rolling back to previous version..."
wait_for_user

run_and_show "helm rollback service-a 1 -n $NAMESPACE"
run_and_show "kubectl rollout status deployment/service-a -n $NAMESPACE"

echo -e "${GREEN}🔍 Step 8: Verify Rollback${NC}"
echo "Testing service after rollback..."
wait_for_user

echo -e "${BLUE}Testing Service A after rollback:${NC}"
kubectl port-forward service/service-a 8080:8080 -n $NAMESPACE &
PID_A=$!
sleep 3
echo -e "Rollback Response: $(curl -s http://localhost:8080)"
kill $PID_A 2>/dev/null || true
echo ""

run_and_show "helm history service-a -n $NAMESPACE"

echo -e "${GREEN}🎉 Demo Complete!${NC}"
echo ""
echo -e "${BLUE}Summary of demonstrated capabilities:${NC}"
echo -e "  ✅ Single reusable Helm chart deployed two different services"
echo -e "  ✅ All required K8s objects: Deployment, Service, ConfigMap, Secret, HPA, ServiceAccount, PDB"
echo -e "  ✅ ConfigMap change automatically triggered rolling pod restart"
echo -e "  ✅ Helm history tracking and safe rollback functionality"
echo -e "  ✅ Services tested and verified at each step"
echo ""

echo -e "${YELLOW}Cleanup? (y/n)${NC}"
read -r cleanup
if [[ $cleanup == "y" || $cleanup == "Y" ]]; then
    echo -e "${BLUE}Cleaning up...${NC}"
    helm uninstall service-a -n $NAMESPACE || true
    helm uninstall service-b -n $NAMESPACE || true
    kubectl delete namespace $NAMESPACE || true
    echo -e "${GREEN}✅ Cleanup complete${NC}"
fi

rm -f /tmp/service-a-updated.yaml

echo -e "${GREEN}Thank you for watching the demo!${NC}"
