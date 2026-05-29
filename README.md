# GitOps EKS Platform

A production-pattern GitOps platform built on AWS using Terraform, Kubernetes, and ArgoCD. This project provisions a fully automated infrastructure pipeline where code changes flow from GitHub to a live EKS cluster without manual intervention.

---

## Architecture

```
Developer (local)
      │
      ▼
GitHub (source of truth)
      │
      ├── GitHub Actions CI/CD
      │         │
      │         ├── Builds Docker image
      │         ├── Pushes to ECR
      │         └── Triggers rollout on EKS
      │
      └── ArgoCD (GitOps controller)
                │
                └── Watches k8s/base/
                    └── Auto-syncs to EKS cluster

AWS Infrastructure (Terraform)
├── VPC (public + private subnets, 2 AZs)
├── EKS Cluster (Kubernetes 1.32)
├── Managed Node Group (t3.small x2)
└── ECR Repository (Docker image registry)
```

---

## Tech Stack

| Tool | Purpose |
|------|---------|
| Terraform | Infrastructure as Code — provisions all AWS resources |
| AWS EKS | Managed Kubernetes cluster |
| AWS ECR | Private Docker image registry |
| AWS VPC | Isolated network with public/private subnets |
| kubectl | Kubernetes CLI for cluster management |
| Helm | Kubernetes package manager |
| GitHub Actions | CI/CD pipeline — build, push, deploy on every commit |
| ArgoCD | GitOps controller — syncs GitHub repo to cluster |
| Docker/nginx | Sample containerized application |

---

## Project Structure

```
gitops-eks-platform/
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions CI/CD pipeline
├── k8s/
│   ├── base/
│   │   ├── deployment.yaml     # Kubernetes Deployment manifest
│   │   └── service.yaml        # LoadBalancer Service manifest
│   ├── overlays/
│   │   └── dev/                # Environment-specific overrides
│   └── argocd-app.yaml         # ArgoCD Application manifest
├── terraform/
│   ├── environments/
│   │   └── dev/
│   │       ├── main.tf         # Root module — wires all modules together
│   │       ├── variables.tf    # Environment variables
│   │       └── outputs.tf      # Cluster endpoint, ECR URL, VPC ID
│   └── modules/
│       ├── eks/                # EKS cluster + node group + IAM roles
│       ├── ecr/                # ECR repository
│       └── vpc/                # VPC, subnets, route tables, IGW, NAT
├── Dockerfile                  # Container image definition
└── README.md
```

---

## How It Works

### 1. Infrastructure Provisioning (Terraform)
All AWS infrastructure is defined as code and provisioned with a single command:

```bash
cd terraform/environments/dev
terraform init
terraform apply
```

This creates:
- A VPC with public and private subnets across 2 availability zones
- An EKS control plane and managed node group
- An ECR repository for Docker images
- All required IAM roles and policies

### 2. Application Deployment (kubectl + Kubernetes manifests)
The sample app is deployed to the cluster using Kubernetes manifests:

```bash
kubectl apply -f k8s/base/
```

A LoadBalancer service automatically provisions an AWS ELB to expose the app publicly.

### 3. CI/CD Pipeline (GitHub Actions)
Every push to `main` triggers the pipeline:

1. Authenticates to AWS using repository secrets
2. Logs into ECR
3. Builds a Docker image tagged with the commit SHA
4. Pushes the image to ECR
5. Updates the EKS deployment with the new image
6. Monitors rollout until complete

### 4. GitOps (ArgoCD)
ArgoCD is installed on the cluster and configured to watch the `k8s/base/` directory. Any change merged to `main` is automatically detected and synced to the cluster — no manual deployment steps required.

```bash
# ArgoCD installed via
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side --force-conflicts

# Application registered via
kubectl apply -f k8s/argocd-app.yaml
```

---

## Prerequisites

- AWS CLI (arm64) configured with appropriate IAM permissions
- Terraform >= 1.0
- kubectl >= 1.32
- Helm >= 3.0
- Docker

---

## Deployment Guide

### Step 1 — Clone and configure
```bash
git clone https://github.com/tyruffin96-maker/Gitops-eks-platform
cd Gitops-eks-platform
```

### Step 2 — Add GitHub repository secrets
In your GitHub repo settings, add:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### Step 3 — Provision infrastructure
```bash
cd terraform/environments/dev
terraform init
terraform apply
```

### Step 4 — Connect kubectl
```bash
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster
kubectl get nodes
```

### Step 5 — Deploy the application
```bash
kubectl apply -f k8s/base/
kubectl get svc sample-app  # grab the LoadBalancer external IP
```

### Step 6 — Access ArgoCD UI
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Visit https://localhost:8080
# Username: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Teardown
```bash
cd terraform/environments/dev
terraform destroy
```

---

## Challenges & Lessons Learned

**AMI deprecation:** Kubernetes 1.29 AMIs were deprecated in us-east-1. Resolved by upgrading to 1.32 and ensuring the version was consistently set across both the Terraform variable default and the environment-level module call — a reminder that hardcoded values in module calls override variable defaults.

**Architecture mismatch (arm64 vs x86):** The AWS CLI installer initially deployed an x86 binary on an Apple Silicon Mac, causing `exec format error` when kubectl tried to use it for credentials. Resolved by reinstalling with the universal macOS package.

**HCL syntax:** Terraform variables written with semicolons (`{ type = string; default = "value" }`) are invalid HCL — each argument must be on its own line. A project-wide grep caught all instances.

**Node resource constraints:** Running ArgoCD (7 pods) alongside application workloads on t3.micro nodes (1GB RAM each) caused scheduling failures. Upgraded to t3.small (2GB RAM) to provide sufficient headroom for both the GitOps controller and application pods.

**Rolling update strategy:** Default Kubernetes rolling updates create a new pod before terminating the old one (`maxSurge: 1`). With only 2 nodes fully utilized, there was no capacity for the surge pod. Fixed by setting `maxSurge: 0, maxUnavailable: 1` to terminate first, then replace.

---

## Future Improvements

- **Monitoring** — Add Prometheus + Grafana for cluster and application metrics
- **HTTPS** — Configure AWS Load Balancer Controller with ACM certificate for TLS termination
- **Multi-environment** — Extend Terraform and ArgoCD to manage staging and production environments using Kustomize overlays
- **Secrets management** — Integrate AWS Secrets Manager or HashiCorp Vault for secret injection
- **Policy enforcement** — Add OPA Gatekeeper for Kubernetes admission control
- **Remote Terraform state** — Migrate to S3 backend with DynamoDB state locking for team collaboration

---

## Author

Tyrrell Ruffin — [LinkedIn](https://linkedin.com/in/tyrrell-ruffin) | [GitHub](https://github.com/tyruffin96-maker)

Cloud Engineer | AWS | DevSecOps | Active Top Secret Clearance