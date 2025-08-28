#!/bin/bash

# EKS Deployment Script for Job Assessment
# Demonstrates complete Helm chart deployment on AWS EKS

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Default configuration (can be overridden via environment variables)
AWS_REGION=${AWS_REGION:-us-west-2}
EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME:-my-eks-cluster}
NAMESPACE=${NAMESPACE:-demo}
USE_LOADBALANCER=${USE_LOADBALANCER:-true}

echo -e "${GREEN}🚀 EKS Deployment Demo for Job Assessment${NC}"
echo -e "${BLUE}Configuration:${NC}"
echo -e "  AWS Region: ${AWS_REGION}"
echo -e "  EKS Cluster: ${EKS_CLUSTER_NAME}"
echo -e "  Namespace: ${NAMESPACE}"
echo -e "  LoadBalancer: ${USE_LOADBALANCER}"
echo ""

# Function to wait for user input
wait_for_user() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI not found. Please install AWS CLI.${NC}"
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ kubectl not found. Please install kubectl.${NC}"
        exit 1
    fi
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}❌ Helm not found. Please install Helm.${NC}"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}❌ AWS credentials not configured. Run 'aws configure'.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites met${NC}"
}

# Function to configure EKS
configure_eks() {
    echo -e "${BLUE}⚙️  Configuring EKS cluster access...${NC}"
    
    # Update kubeconfig
    aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}
    
    # Verify connection
    echo -e "${BLUE}Cluster information:${NC}"
    kubectl cluster-info
    
    echo -e "${BLUE}Available nodes:${NC}"
    kubectl get nodes -o wide
    
    echo -e "${GREEN}✅ EKS cluster configured${NC}"
}

# Function to deploy services
deploy_services() {
    echo -e "${BLUE}🚀 Deploying microservices to EKS...${NC}"
    
    # Create namespace
    kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    
    if [ "${USE_LOADBALANCER}" = "true" ]; then
        echo -e "${BLUE}Deploying with LoadBalancer services...${NC}"
        
        # Deploy Service A with LoadBalancer
        helm upgrade --install service-a ./chart \
            --namespace ${NAMESPACE} \
            --values values/values-service-a-eks.yaml \
            --wait --timeout=300s
            
        # Deploy Service B with LoadBalancer
        helm upgrade --install service-b ./chart \
            --namespace ${NAMESPACE} \
            --values values/values-service-b-eks.yaml \
            --wait --timeout=300s
    else
        echo -e "${BLUE}Deploying with ClusterIP services...${NC}"
        
        # Deploy Service A with ClusterIP
        helm upgrade --install service-a ./chart \
            --namespace ${NAMESPACE} \
            --values values/values-service-a.yaml \
            --wait --timeout=300s
            
        # Deploy Service B with ClusterIP
        helm upgrade --install service-b ./chart \
            --namespace ${NAMESPACE} \
            --values values/values-service-b.yaml \
            --wait --timeout=300s
    fi
    
    echo -e "${GREEN}✅ Services deployed successfully${NC}"
}

# Function to verify deployment
verify_deployment() {
    echo -e "${BLUE}🔍 Verifying deployment...${NC}"
    
    # Show all resources
    kubectl get deploy,rs,pods,svc,hpa,pdb -n ${NAMESPACE}
    
    # Check rollout status
    kubectl rollout status deployment/service-a -n ${NAMESPACE}
    kubectl rollout status deployment/service-b -n ${NAMESPACE}
    
    # Show Helm releases
    echo -e "${BLUE}Helm releases:${NC}"
    helm list -n ${NAMESPACE}
    
    echo -e "${GREEN}✅ Deployment verification complete${NC}"
}

# Function to test services
test_services() {
    echo -e "${BLUE}🧪 Testing deployed services...${NC}"
    
    if [ "${USE_LOADBALANCER}" = "true" ]; then
        echo -e "${BLUE}Testing via LoadBalancer endpoints...${NC}"
        
        # Get LoadBalancer endpoints
        echo -e "${YELLOW}Waiting for LoadBalancer endpoints to be ready...${NC}"
        sleep 30
        
        SERVICE_A_LB=$(kubectl get svc service-a -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        SERVICE_B_LB=$(kubectl get svc service-b -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        
        if [ -n "${SERVICE_A_LB}" ]; then
            echo -e "${BLUE}Testing Service A at: http://${SERVICE_A_LB}:8080${NC}"
            response_a=$(curl -s --max-time 10 http://${SERVICE_A_LB}:8080 || echo "Connection failed")
            echo -e "Response: ${response_a}"
        else
            echo -e "${YELLOW}Service A LoadBalancer not ready yet${NC}"
        fi
        
        if [ -n "${SERVICE_B_LB}" ]; then
            echo -e "${BLUE}Testing Service B at: http://${SERVICE_B_LB}:8080${NC}"
            response_b=$(curl -s --max-time 10 http://${SERVICE_B_LB}:8080 || echo "Connection failed")
            echo -e "Response: ${response_b}"
        else
            echo -e "${YELLOW}Service B LoadBalancer not ready yet${NC}"
        fi
    else
        echo -e "${BLUE}Testing via port-forward...${NC}"
        
        # Test Service A
        kubectl port-forward service/service-a 8080:8080 -n ${NAMESPACE} &
        PID_A=$!
        sleep 3
        response_a=$(curl -s --max-time 10 http://localhost:8080 || echo "Connection failed")
        kill $PID_A 2>/dev/null || true
        echo -e "Service A response: ${response_a}"
        
        # Test Service B
        kubectl port-forward service/service-b 8081:8080 -n ${NAMESPACE} &
        PID_B=$!
        sleep 3
        response_b=$(curl -s --max-time 10 http://localhost:8081 || echo "Connection failed")
        kill $PID_B 2>/dev/null || true
        echo -e "Service B response: ${response_b}"
    fi
    
    echo -e "${GREEN}✅ Service testing complete${NC}"
}

# Function to demonstrate rolling update
demo_rolling_update() {
    echo -e "${BLUE}🔄 Demonstrating ConfigMap rolling update...${NC}"
    
    echo -e "${YELLOW}Current Service A pods:${NC}"
    kubectl get pods -l app.kubernetes.io/instance=service-a -n ${NAMESPACE}
    
    echo -e "${BLUE}Updating Service A configuration...${NC}"
    
    # Create temporary updated values
    cat > /tmp/service-a-updated.yaml << 'EOF'
nameOverride: "service-a"
args:
  - "-text=UPDATED: Hello from Service A on EKS!"
  - "-listen=:8080"
configMap:
  enabled: true
  data:
    MESSAGE: "UPDATED: Welcome to Service A on EKS!"
    UPDATE_TIME: "$(date)"
    VERSION: "v1.1.0"
EOF

    # Apply update
    if [ "${USE_LOADBALANCER}" = "true" ]; then
        helm upgrade service-a ./chart \
            --namespace ${NAMESPACE} \
            --values values/values-service-a-eks.yaml \
            --values /tmp/service-a-updated.yaml \
            --wait --timeout=300s
    else
        helm upgrade service-a ./chart \
            --namespace ${NAMESPACE} \
            --values values/values-service-a.yaml \
            --values /tmp/service-a-updated.yaml \
            --wait --timeout=300s
    fi
    
    # Monitor rollout
    kubectl rollout status deployment/service-a -n ${NAMESPACE}
    
    echo -e "${YELLOW}Updated Service A pods:${NC}"
    kubectl get pods -l app.kubernetes.io/instance=service-a -n ${NAMESPACE}
    
    # Clean up temp file
    rm -f /tmp/service-a-updated.yaml
    
    echo -e "${GREEN}✅ Rolling update demonstration complete${NC}"
}

# Function to demonstrate rollback
demo_rollback() {
    echo -e "${BLUE}⏪ Demonstrating Helm rollback...${NC}"
    
    # Show history
    echo -e "${BLUE}Release history:${NC}"
    helm history service-a -n ${NAMESPACE}
    
    # Rollback
    echo -e "${BLUE}Rolling back to previous version...${NC}"
    helm rollback service-a 1 -n ${NAMESPACE}
    kubectl rollout status deployment/service-a -n ${NAMESPACE}
    
    # Show updated history
    echo -e "${BLUE}Updated release history:${NC}"
    helm history service-a -n ${NAMESPACE}
    
    echo -e "${GREEN}✅ Rollback demonstration complete${NC}"
}

# Function to cleanup
cleanup() {
    echo -e "${YELLOW}🧹 Would you like to clean up the deployment? (y/N)${NC}"
    read -r cleanup_response
    
    if [[ "$cleanup_response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Cleaning up deployment...${NC}"
        helm uninstall service-a -n ${NAMESPACE} || true
        helm uninstall service-b -n ${NAMESPACE} || true
        kubectl delete namespace ${NAMESPACE} || true
        echo -e "${GREEN}✅ Cleanup complete${NC}"
    else
        echo -e "${BLUE}Deployment left running. Manual cleanup:${NC}"
        echo -e "  helm uninstall service-a service-b -n ${NAMESPACE}"
        echo -e "  kubectl delete namespace ${NAMESPACE}"
    fi
}

# Main execution
main() {
    echo -e "${GREEN}Starting EKS deployment demonstration...${NC}"
    echo ""
    
    check_prerequisites
    wait_for_user
    
    configure_eks
    wait_for_user
    
    deploy_services
    wait_for_user
    
    verify_deployment
    wait_for_user
    
    test_services
    wait_for_user
    
    demo_rolling_update
    wait_for_user
    
    test_services
    wait_for_user
    
    demo_rollback
    wait_for_user
    
    test_services
    wait_for_user
    
    cleanup
    
    echo -e "${GREEN}🎉 EKS deployment demonstration complete!${NC}"
    echo ""
    echo -e "${BLUE}Summary of demonstrated capabilities:${NC}"
    echo -e "  ✅ EKS cluster connection and configuration"
    echo -e "  ✅ Helm chart deployment of multiple microservices"
    echo -e "  ✅ LoadBalancer services for external access"
    echo -e "  ✅ ConfigMap rolling update mechanism"
    echo -e "  ✅ Helm history and rollback functionality"
    echo -e "  ✅ All required Kubernetes objects (Deployment, Service, ConfigMap, Secret, HPA, ServiceAccount, PDB)"
}

# Handle script arguments
case "${1:-}" in
    --loadbalancer)
        USE_LOADBALANCER=true
        ;;
    --clusterip)
        USE_LOADBALANCER=false
        ;;
    --help)
        echo "Usage: $0 [--loadbalancer|--clusterip] [--help]"
        echo ""
        echo "Environment variables:"
        echo "  AWS_REGION          AWS region (default: us-west-2)"
        echo "  EKS_CLUSTER_NAME    EKS cluster name (default: my-eks-cluster)"
        echo "  NAMESPACE           Kubernetes namespace (default: demo)"
        echo "  USE_LOADBALANCER    Use LoadBalancer services (default: true)"
        exit 0
        ;;
esac

# Run main function
main
