#!/bin/bash

# Quick LoadBalancer status checker for EKS
# Helps troubleshoot pending LoadBalancer issues

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

NAMESPACE="default"

echo -e "${GREEN}🔍 EKS LoadBalancer Status Checker${NC}"
echo ""

# Check LoadBalancer services
echo -e "${BLUE}📊 LoadBalancer Services:${NC}"
kubectl get svc -n ${NAMESPACE} --field-selector spec.type=LoadBalancer

echo ""

# Check service details
for service in service-a service-b; do
    if kubectl get svc ${service} -n ${NAMESPACE} >/dev/null 2>&1; then
        echo -e "${BLUE}🔍 ${service} LoadBalancer details:${NC}"
        
        # Get external IP
        EXTERNAL_IP=$(kubectl get svc ${service} -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        
        if [ -n "${EXTERNAL_IP}" ]; then
            echo -e "${GREEN}✅ External endpoint: http://${EXTERNAL_IP}:8080${NC}"
            echo "Testing connectivity..."
            curl -s --max-time 5 http://${EXTERNAL_IP}:8080 || echo "Connection test failed"
        else
            echo -e "${YELLOW}⚠️  External IP still pending...${NC}"
            
            # Show service events
            echo "Recent events:"
            kubectl describe svc ${service} -n ${NAMESPACE} | grep -A 5 Events: || echo "No events found"
        fi
        echo ""
    fi
done

# Check AWS Load Balancer Controller
echo -e "${BLUE}🔍 AWS Load Balancer Controller Status:${NC}"
if kubectl get pods -n kube-system | grep -q aws-load-balancer-controller; then
    echo -e "${GREEN}✅ AWS Load Balancer Controller is running${NC}"
    kubectl get pods -n kube-system | grep aws-load-balancer-controller
else
    echo -e "${YELLOW}⚠️  AWS Load Balancer Controller not found${NC}"
    echo ""
    echo -e "${BLUE}To install AWS Load Balancer Controller:${NC}"
    echo "1. curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.4/docs/install/iam_policy.json"
    echo "2. aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json"
    echo "3. Follow AWS documentation for complete setup"
fi

echo ""

# Alternative access methods
echo -e "${BLUE}🔄 Alternative Access Methods:${NC}"

# NodePort access
echo -e "${YELLOW}Method 1: NodePort Access${NC}"
for service in service-a service-b; do
    if kubectl get svc ${service} -n ${NAMESPACE} >/dev/null 2>&1; then
        NODEPORT=$(kubectl get svc ${service} -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
        
        if [ -n "${NODE_IP}" ]; then
            echo "${service}: http://${NODE_IP}:${NODEPORT}"
        else
            echo "${service}: NodePort ${NODEPORT} (no external node IP available)"
        fi
    fi
done

echo ""

# Port forwarding method
echo -e "${YELLOW}Method 2: Port Forwarding (for testing)${NC}"
echo "kubectl port-forward service/service-a 8080:8080 -n ${NAMESPACE}"
echo "kubectl port-forward service/service-b 8081:8080 -n ${NAMESPACE}"

echo ""

# Real-time monitoring
echo -e "${BLUE}💡 Monitor LoadBalancer in real-time:${NC}"
echo "watch kubectl get svc -n ${NAMESPACE}"

echo ""
echo -e "${YELLOW}⏰ LoadBalancer IP typically takes 2-3 minutes to provision${NC}"
