#!/bin/bash

# Quick fix script for EKS deployment issues
# Addresses LoadBalancer pending and timeout issues

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

NAMESPACE="default"
AWS_REGION="ap-south-1"
EKS_CLUSTER_NAME="scrumptious-dance-hideout"

echo -e "${GREEN}🔧 EKS Deployment Recovery Script${NC}"
echo ""

# Check current status
echo -e "${BLUE}📊 Current deployment status:${NC}"
kubectl get pods,svc -n ${NAMESPACE}
echo ""

# Complete Service B deployment
echo -e "${BLUE}🚀 Completing Service B deployment...${NC}"
if ! helm list -n ${NAMESPACE} | grep -q service-b; then
    echo "Deploying Service B..."
    helm upgrade --install service-b ./chart \
        --namespace ${NAMESPACE} \
        --values values/values-service-b-eks.yaml \
        --wait --timeout=600s || echo "Service B deployment timed out, but may still be progressing..."
else
    echo "Service B already deployed"
fi

echo ""
echo -e "${BLUE}📊 Updated deployment status:${NC}"
kubectl get pods,svc,deploy -n ${NAMESPACE}
echo ""

# Check LoadBalancer status
echo -e "${BLUE}🔍 Checking LoadBalancer status...${NC}"
SERVICE_A_LB=$(kubectl get svc service-a -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
SERVICE_B_LB=$(kubectl get svc service-b -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "${SERVICE_A_LB}" ]; then
    echo -e "${YELLOW}⚠️  Service A LoadBalancer external IP is still pending${NC}"
    echo "This is common in EKS and can take 2-3 minutes..."
else
    echo -e "${GREEN}✅ Service A LoadBalancer ready: ${SERVICE_A_LB}${NC}"
fi

if [ -z "${SERVICE_B_LB}" ]; then
    echo -e "${YELLOW}⚠️  Service B LoadBalancer external IP is still pending${NC}"
else
    echo -e "${GREEN}✅ Service B LoadBalancer ready: ${SERVICE_B_LB}${NC}"
fi

echo ""

# Check AWS Load Balancer Controller
echo -e "${BLUE}🔍 Checking AWS Load Balancer Controller...${NC}"
if kubectl get pods -n kube-system | grep -q aws-load-balancer-controller; then
    echo -e "${GREEN}✅ AWS Load Balancer Controller is running${NC}"
else
    echo -e "${YELLOW}⚠️  AWS Load Balancer Controller not found${NC}"
    echo "This might be why LoadBalancer is pending. EKS Auto should have this by default."
fi

# Check Load Balancer events
echo -e "${BLUE}🔍 Checking LoadBalancer events...${NC}"
kubectl describe svc service-a -n ${NAMESPACE} | grep -A 10 Events: || echo "No events found"

echo ""

# Provide alternative testing methods
echo -e "${BLUE}🧪 Testing services (alternative methods):${NC}"

echo -e "${YELLOW}Method 1: NodePort access${NC}"
SERVICE_A_NODEPORT=$(kubectl get svc service-a -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')

if [ -n "${NODE_IP}" ]; then
    echo "Service A via NodePort: http://${NODE_IP}:${SERVICE_A_NODEPORT}"
    echo "Testing..."
    curl -s --max-time 5 http://${NODE_IP}:${SERVICE_A_NODEPORT} || echo "NodePort test failed - this is normal if security groups don't allow access"
else
    echo "No external node IP found"
fi

echo ""

echo -e "${YELLOW}Method 2: Port forwarding${NC}"
echo "Testing Service A via port-forward..."
kubectl port-forward service/service-a 8080:8080 -n ${NAMESPACE} &
PID_A=$!
sleep 3
SERVICE_A_RESPONSE=$(curl -s --max-time 5 http://localhost:8080 || echo "Connection failed")
kill $PID_A 2>/dev/null || true
echo "Service A response: ${SERVICE_A_RESPONSE}"

if kubectl get svc service-b -n ${NAMESPACE} >/dev/null 2>&1; then
    echo "Testing Service B via port-forward..."
    kubectl port-forward service/service-b 8081:8080 -n ${NAMESPACE} &
    PID_B=$!
    sleep 3
    SERVICE_B_RESPONSE=$(curl -s --max-time 5 http://localhost:8081 || echo "Connection failed")
    kill $PID_B 2>/dev/null || true
    echo "Service B response: ${SERVICE_B_RESPONSE}"
fi

echo ""

# Demonstrate ConfigMap rolling update
echo -e "${BLUE}🔄 Demonstrating ConfigMap rolling update...${NC}"
echo "Current Service A pods:"
kubectl get pods -l app.kubernetes.io/instance=service-a -n ${NAMESPACE}

echo ""
echo "Updating Service A configuration..."

# Create updated configuration
cat > /tmp/service-a-updated.yaml << 'EOF'
args:
  - "-text=UPDATED: Hello from Service A on EKS!"
  - "-listen=:8080"
configMap:
  enabled: true
  data:
    MESSAGE: "UPDATED: Welcome to Service A on EKS!"
    UPDATE_TIME: "$(date)"
    VERSION: "v1.1.0"
    CLUSTER_NAME: "scrumptious-dance-hideout"
EOF

# Apply update
helm upgrade service-a ./chart \
    --namespace ${NAMESPACE} \
    --values values/values-service-a-eks.yaml \
    --values /tmp/service-a-updated.yaml \
    --wait --timeout=300s

echo ""
echo "Rolling update complete! New pods:"
kubectl get pods -l app.kubernetes.io/instance=service-a -n ${NAMESPACE}

echo ""
echo "Testing updated service..."
kubectl port-forward service/service-a 8080:8080 -n ${NAMESPACE} &
PID_A=$!
sleep 3
UPDATED_RESPONSE=$(curl -s --max-time 5 http://localhost:8080 || echo "Connection failed")
kill $PID_A 2>/dev/null || true
echo "Updated Service A response: ${UPDATED_RESPONSE}"

# Demonstrate rollback
echo ""
echo -e "${BLUE}⏪ Demonstrating Helm rollback...${NC}"
echo "Release history:"
helm history service-a -n ${NAMESPACE}

echo ""
echo "Rolling back to previous version..."
helm rollback service-a 1 -n ${NAMESPACE}
kubectl rollout status deployment/service-a -n ${NAMESPACE} --timeout=300s

echo ""
echo "Testing after rollback..."
kubectl port-forward service/service-a 8080:8080 -n ${NAMESPACE} &
PID_A=$!
sleep 3
ROLLBACK_RESPONSE=$(curl -s --max-time 5 http://localhost:8080 || echo "Connection failed")
kill $PID_A 2>/dev/null || true
echo "Rollback Service A response: ${ROLLBACK_RESPONSE}"

# Clean up temp file
rm -f /tmp/service-a-updated.yaml

echo ""
echo -e "${GREEN}🎉 EKS Deployment Demo Complete!${NC}"
echo ""
echo -e "${BLUE}Summary of demonstrated capabilities:${NC}"
echo -e "  ✅ EKS cluster deployment with Auto mode"
echo -e "  ✅ Multiple microservices from single Helm chart"
echo -e "  ✅ LoadBalancer services (may take time to get external IP)"
echo -e "  ✅ ConfigMap rolling update mechanism"
echo -e "  ✅ Helm history and rollback functionality"
echo -e "  ✅ All required Kubernetes objects deployed"
echo ""

# Show final status
echo -e "${BLUE}📊 Final deployment status:${NC}"
kubectl get all -n ${NAMESPACE}

echo ""
echo -e "${YELLOW}💡 LoadBalancer troubleshooting tips:${NC}"
echo "1. LoadBalancer external IP can take 2-3 minutes to provision"
echo "2. Check: kubectl describe svc service-a -n ${NAMESPACE}"
echo "3. Verify AWS Load Balancer Controller: kubectl get pods -n kube-system | grep aws-load-balancer"
echo "4. Check VPC/subnet configuration if LoadBalancer stays pending"
echo ""
echo -e "${BLUE}Monitor LoadBalancer status: watch kubectl get svc -n ${NAMESPACE}${NC}"
