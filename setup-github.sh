#!/bin/bash

# GitHub Repository Setup Script
# Prepares the repository for push to @aarshparashar GitHub account

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

GITHUB_USERNAME="aarshparashar"
REPO_NAME="microservice-helm-chart"

echo -e "${GREEN}🚀 Setting up repository for GitHub deployment${NC}"
echo -e "${BLUE}Target: https://github.com/${GITHUB_USERNAME}/${REPO_NAME}${NC}"
echo ""

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}Initializing git repository...${NC}"
    git init
    git add .
    git commit -m "feat: initial commit - Helm chart for EKS microservices deployment

- Reusable Helm chart with all required K8s objects
- ConfigMap rolling update mechanism
- EKS-optimized configurations with LoadBalancer
- GitHub Actions CI/CD pipeline
- Multiple deployment environments (staging/production)
- Comprehensive documentation and automation"
else
    echo -e "${GREEN}✓ Git repository already initialized${NC}"
fi

# Set up remote (user needs to create the repo first)
echo -e "${YELLOW}Setting up GitHub remote...${NC}"
if git remote get-url origin 2>/dev/null; then
    echo -e "${BLUE}Current remote:$(git remote get-url origin)${NC}"
    echo -e "${YELLOW}Updating remote URL...${NC}"
    git remote set-url origin https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git
else
    git remote add origin https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git
fi

echo -e "${GREEN}✓ Remote configured: https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git${NC}"

# Create and push develop branch
echo -e "${YELLOW}Setting up branches...${NC}"
git checkout -b develop 2>/dev/null || git checkout develop
git checkout main 2>/dev/null || git checkout -b main

echo -e "${GREEN}✓ Branches configured (main, develop)${NC}"

# Verify setup
echo -e "${YELLOW}Verifying repository structure...${NC}"
./verify-setup.sh || exit 1

echo ""
echo -e "${GREEN}🎉 Repository setup complete!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "1. Create repository on GitHub: https://github.com/new"
echo -e "   Repository name: ${REPO_NAME}"
echo -e "   Description: Helm chart for deploying microservices on EKS with rolling updates"
echo -e ""
echo -e "2. Push to GitHub:"
echo -e "   git push -u origin main"
echo -e "   git push -u origin develop"
echo -e ""
echo -e "3. Configure GitHub Secrets:"
echo -e "   - AWS_ACCESS_KEY_ID"
echo -e "   - AWS_SECRET_ACCESS_KEY"
echo -e "   - AWS_REGION"
echo -e "   - EKS_CLUSTER_NAME"
echo -e ""
echo -e "4. Deploy to EKS:"
echo -e "   make eks-configure EKS_CLUSTER_NAME=your-cluster AWS_REGION=us-west-2"
echo -e "   make eks-install"
echo -e ""
echo -e "${YELLOW}Repository URL: https://github.com/${GITHUB_USERNAME}/${REPO_NAME}${NC}"
