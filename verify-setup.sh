#!/bin/bash

# Verification script for Helm chart setup
# This script checks that all files are in place and the chart is valid

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔍 Verifying Helm Chart Setup${NC}"
echo ""

# Check if we're in the right directory
if [[ ! -f "chart/Chart.yaml" ]]; then
    echo -e "${RED}❌ Error: chart/Chart.yaml not found. Please run this script from the project root.${NC}"
    exit 1
fi

echo -e "${YELLOW}📁 Checking file structure...${NC}"

# Required files
REQUIRED_FILES=(
    "chart/Chart.yaml"
    "chart/values.yaml"
    "chart/templates/_helpers.tpl"
    "chart/templates/deployment.yaml"
    "chart/templates/service.yaml"
    "chart/templates/configmap.yaml"
    "chart/templates/secret.yaml"
    "chart/templates/hpa.yaml"
    "chart/templates/serviceaccount.yaml"
    "chart/templates/poddisruptionbudget.yaml"
    "chart/templates/NOTES.txt"
    "values/values-service-a.yaml"
    "values/values-service-b.yaml"
    "README.md"
    "Makefile"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo -e "  ✅ $file"
    else
        echo -e "  ❌ $file ${RED}(missing)${NC}"
        exit 1
    fi
done

echo ""
echo -e "${YELLOW}🔧 Checking for required tools...${NC}"

# Check for required tools
REQUIRED_TOOLS=("helm" "kubectl")

for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$tool" > /dev/null 2>&1; then
        version=$(${tool} version --short 2>/dev/null | head -n 1 || ${tool} version --client --short 2>/dev/null | head -n 1 || echo "unknown")
        echo -e "  ✅ $tool ($version)"
    else
        echo -e "  ❌ $tool ${RED}(not found)${NC}"
        echo -e "     ${YELLOW}Please install $tool to continue${NC}"
    fi
done

echo ""
echo -e "${YELLOW}📊 Validating Helm chart...${NC}"

# Lint the chart
if helm lint chart/ > /dev/null 2>&1; then
    echo -e "  ✅ Helm chart linting passed"
else
    echo -e "  ❌ Helm chart linting failed"
    echo -e "     ${YELLOW}Running helm lint chart/ for details:${NC}"
    helm lint chart/
    exit 1
fi

# Template validation
echo -e "${YELLOW}🎯 Testing template generation...${NC}"

# Test Service A templates
if helm template test-a chart/ -f values/values-service-a.yaml > /dev/null 2>&1; then
    echo -e "  ✅ Service A template generation successful"
else
    echo -e "  ❌ Service A template generation failed"
    exit 1
fi

# Test Service B templates
if helm template test-b chart/ -f values/values-service-b.yaml > /dev/null 2>&1; then
    echo -e "  ✅ Service B template generation successful"
else
    echo -e "  ❌ Service B template generation failed"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 All checks passed! Your Helm chart is ready to use.${NC}"
echo ""
echo -e "${YELLOW}📚 Next steps:${NC}"
echo -e "  1. Start your Kubernetes cluster (minikube start)"
echo -e "  2. Create namespace: kubectl create namespace demo"
echo -e "  3. Install services: make install-all"
echo -e "  4. Test services: make test-services"
echo -e "  5. Try configuration update: make update-service-a-config"
echo ""
echo -e "${YELLOW}📖 For detailed instructions, see README.md${NC}"
