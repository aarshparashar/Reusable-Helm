# Microservice Helm Chart for EKS - Job Assessment

A production-ready Helm chart that demonstrates deployment of multiple microservices on AWS EKS with ConfigMap rolling updates, HPA, PDB, and proper CI/CD pipelines.

> **Repository**: Ready for deployment to [@aarshparashar](https://github.com/aarshparashar) GitHub account  
> **Target Platform**: AWS EKS Auto cluster with managed node groups  
> **Image Strategy**: Uses public `hashicorp/http-echo` image (simple and reliable)

## 📋 Requirements Fulfilled

✅ **Reusable Helm Chart** - Single chart deploys multiple services  
✅ **Required K8s Objects** - Deployment, Service, ConfigMap, Secret, HPA, ServiceAccount, PDB  
✅ **ConfigMap Rolling Updates** - Automatic pod restart on config changes  
✅ **Multiple Service Deployment** - Two services from same chart  
✅ **Helm History & Rollback** - Version control and safe rollbacks  
✅ **EKS Integration** - LoadBalancer services, AWS annotations, optimized for EKS  
✅ **CI/CD Pipeline** - GitHub Actions with security scanning and automated deployment  

## 🎯 GitHub Repository Setup

### 1. Repository Structure
```bash
# Clone to your GitHub account
git clone <this-repo> microservice-helm-chart
cd microservice-helm-chart
git remote set-url origin https://github.com/aarshparashar/microservice-helm-chart.git
git push -u origin main
```

### 2. GitHub Secrets Configuration
Add these secrets to your GitHub repository (`Settings > Secrets and variables > Actions`):

```bash
AWS_ACCESS_KEY_ID       # Your AWS access key
AWS_SECRET_ACCESS_KEY   # Your AWS secret key  
AWS_REGION              # e.g., us-west-2
EKS_CLUSTER_NAME        # Your EKS cluster name
```

### 3. Branches Setup
```bash
# Create develop branch for staging deployments
git checkout -b develop
git push -u origin develop

# Main branch automatically deploys to production
# Develop branch deploys to staging environment
```

## 🚀 EKS Deployment Guide

### Prerequisites

**AWS Setup:**
```bash
# Install AWS CLI and configure
aws configure
aws eks update-kubeconfig --region us-west-2 --name your-cluster-name

# Verify EKS connection
kubectl get nodes
kubectl cluster-info
```

**Required Tools:**
- AWS CLI v2+
- kubectl v1.20+
- Helm v3.8+
- Docker (for local testing)

### Quick EKS Deployment

```bash
# 1. Configure EKS connection
make eks-configure EKS_CLUSTER_NAME=your-cluster AWS_REGION=us-west-2

# 2. View cluster information
make eks-info

# 3. Deploy both services to EKS
make eks-install

# 4. Check deployment status
make status

# 5. Test services (via LoadBalancer)
make eks-test-external
```

### Deployment Options

#### Option 1: ClusterIP Services (Internal)
```bash
# Deploy with internal access only
make install
make test  # Uses port-forward
```

#### Option 2: LoadBalancer Services (External)
```bash
# Deploy with external LoadBalancer access
helm install service-a ./chart -n demo -f values/values-service-a-eks.yaml
helm install service-b ./chart -n demo -f values/values-service-b-eks.yaml

# Get external endpoints
kubectl get svc -n demo
```

## 📁 Project Structure

```
.
├── .github/workflows/          # CI/CD pipelines
│   └── helm-chart-ci.yml      # GitHub Actions workflow
├── chart/                      # Reusable Helm chart
│   ├── Chart.yaml             # Chart metadata
│   ├── values.yaml            # Default values
│   └── templates/             # K8s manifests (7 objects)
├── values/                     # Environment-specific configs
│   ├── values-service-a.yaml  # Service A (local/minikube)
│   ├── values-service-b.yaml  # Service B (local/minikube)
│   ├── values-service-a-eks.yaml # Service A (EKS with LoadBalancer)
│   └── values-service-b-eks.yaml # Service B (EKS with LoadBalancer)
├── demo.sh                    # Interactive demonstration
├── Makefile                   # Automation (local + EKS commands)
└── README.md                  # This documentation
```

## 🔄 ConfigMap Rolling Update Demo

### Demonstration on EKS

```bash
# 1. Deploy initial configuration
make eks-install

# 2. Verify initial deployment
kubectl get pods -n demo -w

# 3. Update Service A configuration
make update

# 4. Watch rolling update in real-time
kubectl rollout status deployment/service-a -n demo

# 5. Verify new configuration
curl http://$(kubectl get svc service-a -n demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):8080

# 6. Rollback demonstration
make rollback

# 7. Verify rollback
curl http://$(kubectl get svc service-a -n demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):8080
```

## 🏗️ CI/CD Pipeline

### GitHub Actions Workflow

**Validation** (All branches):
- Helm chart linting
- Template generation testing
- Kubernetes manifest validation
- Security scanning with Checkov

**Staging Deployment** (develop branch):
- Deploys to `demo-staging` namespace
- Uses staging-specific configurations
- Automated smoke testing

**Production Deployment** (main branch):
- Requires manual approval
- Deploys to `demo` namespace
- Full smoke test suite
- LoadBalancer endpoint verification

### Triggering Deployments

```bash
# Deploy to staging
git checkout develop
git add .
git commit -m "feat: update service configuration"
git push origin develop

# Deploy to production
git checkout main
git merge develop
git push origin main
```

## 🎯 EKS-Specific Features

### AWS Load Balancer Integration
```yaml
# In values-service-a-eks.yaml
service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
```

### Horizontal Pod Autoscaler
```yaml
# Configured for EKS metrics-server
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

### Pod Disruption Budget
```yaml
# High availability for EKS node updates
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

## 🔍 Monitoring & Troubleshooting

### EKS-Specific Commands

```bash
# View cluster information
make eks-info

# Check service LoadBalancer status
kubectl get svc -n demo

# View pod logs
make logs-a
make logs-b

# Describe resources for troubleshooting
make describe-a
make describe-b

# Check HPA metrics
kubectl get hpa -n demo
kubectl describe hpa service-a -n demo
```

### Common EKS Issues

**LoadBalancer Pending:**
```bash
# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Verify service annotations
kubectl describe svc service-a -n demo
```

**HPA Not Scaling:**
```bash
# Check metrics-server
kubectl get pods -n kube-system | grep metrics-server

# View HPA events
kubectl describe hpa service-a -n demo
```

## 🧹 Cleanup

### Remove Services
```bash
# Remove from specific namespace
make clean

# Remove staging deployment
helm uninstall service-a-staging service-b-staging -n demo-staging
kubectl delete namespace demo-staging
```

### EKS Cluster Cleanup
```bash
# Remove all deployments
make clean-all

# Note: EKS cluster deletion should be done via AWS Console/CLI
# aws eks delete-cluster --name your-cluster-name --region us-west-2
```

## 📊 Resource Usage

### Service A (EKS Configuration)
- **Replicas**: 2-10 (HPA managed)
- **CPU**: 250m-500m per pod
- **Memory**: 256Mi-512Mi per pod
- **Service**: LoadBalancer (external access)

### Service B (EKS Configuration)
- **Replicas**: 2-8 (HPA managed)
- **CPU**: 500m-1000m per pod
- **Memory**: 512Mi-1Gi per pod
- **Service**: LoadBalancer (external access)

## 🎯 Job Assessment Demo Script

```bash
# Complete demonstration for interview
./demo.sh

# Or manual step-by-step
make eks-configure EKS_CLUSTER_NAME=your-cluster
make eks-install
make status
make update
make rollback
make clean
```

## 📝 Key Design Decisions

**Public Image Strategy**: Uses `hashicorp/http-echo` - simple, reliable, no registry dependencies

**EKS Optimization**: LoadBalancer services, AWS-specific annotations, proper resource allocation

**CI/CD Integration**: GitHub Actions with staging/production environments, security scanning

**Rolling Updates**: Checksum-based mechanism ensures reliable configuration propagation

**High Availability**: PDB, multiple replicas, and anti-affinity rules for production readiness

---

**🎯 Perfect for EKS deployment with minimal complexity and maximum demonstration value!**

> **Next Steps**: Push to [@aarshparashar/microservice-helm-chart](https://github.com/aarshparashar) and configure GitHub secrets for automated EKS deployment.