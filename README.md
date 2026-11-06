# DevSecOps EKS Pipeline

My implementation of an end-to-end DevSecOps pipeline for OWASP Juice Shop — every commit passes through secret scanning, SAST, SCA, and IaC scanning before an image is built and promoted to AWS EKS via GitOps. I built this to practice shifting security left and to document the trade-offs I made along the way.

---

## Architecture Overview
Developer pushes code
↓
GitHub Repository
↓
GitHub Actions CI/CD Pipeline
├── Gitleaks → Secrets detection (code + git history)
├── SonarCloud → SAST (static code analysis)
├── Trivy (fs) → SCA (dependency vulnerabilities)
├── Checkov → IaC security (Terraform)
├── Docker Build
└── Trivy (image) → Container image scan (HIGH/CRITICAL gate)
↓
AWS ECR (image pushed only if all gates pass)
↓
ArgoCD (GitOps — detects new image tag → deploys)
↓
AWS EKS Cluster
├── Kyverno → Admission policy enforcement
└── Juice Shop pods running
↓
Prometheus + Grafana (monitoring & dashboards)


---

## Application

**OWASP Juice Shop** — intentionally vulnerable Node.js web application used as the target.

| Tier | Technology |
|---|---|
| Frontend | Angular |
| Backend | Node.js + Express |
| Database | SQLite |

In this implementation I configured Trivy to fail the build on **HIGH/CRITICAL** findings and added a `.gitleaks.toml` allowlist for Juice Shop's known test credentials so the secret-scan gate stays meaningful instead of being permanently red. The rationale for both decisions is documented in Lessons Learned.

---

## Tool Stack

| Category | Tool | Purpose |
|---|---|---|
| CI/CD | GitHub Actions | Automated 6-stage pipeline |
| Secrets Detection | Gitleaks | Scan git history for leaked credentials |
| SAST | SonarCloud | Static code analysis for vulnerabilities |
| SCA + Image Scan | Trivy | Dependency and container image scanning |
| IaC Security | Checkov | Terraform misconfiguration scanning |
| Infrastructure | Terraform | AWS EKS + VPC + ECR provisioning |
| Container Registry | AWS ECR | Immutable-tagged container image storage |
| GitOps | ArgoCD | Automated deployment on git change |
| Packaging | Helm | Kubernetes manifest templating |
| Policy Enforcement | Kyverno | Kubernetes admission policies |
| Secrets Management | HashiCorp Vault | Centralized secrets with K8s auth |
| Monitoring | Prometheus + Grafana | Cluster metrics and dashboards |

---

## Pipeline Stages

| Stage | Tool | What it checks |
|---|---|---|
| 1 — pipeline-info | — | Prints branch, SHA, actor |
| 2 — secret-scan | Gitleaks | Hardcoded secrets in code + git history |
| 3 — sast | SonarCloud | Security vulnerabilities, bugs, code smells |
| 4 — sca | Trivy (fs) | Vulnerable npm dependencies |
| 5 — iac-scan | Checkov | Terraform misconfigurations |
| 6 — build-scan-push | Docker + Trivy + ECR | Build image → scan (block HIGH/CRITICAL) → push to ECR → update Helm values |

---

## Kyverno Policies

| Policy | Action |
|---|---|
| `disallow-latest-tag` | Blocks any image tagged `:latest` |
| `disallow-root-user` | Blocks containers running as root |
| `require-resource-limits` | Blocks pods without CPU/memory limits |

---

## Security Highlights

- **OIDC auth** — GitHub Actions authenticates to AWS without any stored credentials
- **KMS encryption** — EKS secrets encrypted at rest
- **IMDSv2** — EC2 metadata endpoint hardened against SSRF
- **Distroless base image** — no shell, no package manager in final container
- **Non-root container** — Juice Shop runs as UID 65532
- **Immutable ECR tags** — images cannot be overwritten after push
- **VPC flow logs** — all network traffic audited

---

## Lessons Learned

- **OIDC trust policy `sub` condition.** I initially used `system:serviceaccount:*`, which let ArgoCD sync but prevented Juice Shop pods from assuming their IRSA role. I narrowed the condition to `system:serviceaccount:juice-shop:juice-shop-sa` and verified with `kubectl exec ... -- aws sts get-caller-identity` inside the pod before redeploying.
- **Trivy noise vs. signal.** Juice Shop ships with known CVEs by design. Rather than setting `exit-code: 0` (which makes the gate decorative), I kept `exit-code: 1` with `severity: HIGH,CRITICAL` and added a `.trivyignore` for the base-image findings I had triaged. The gate still blocks new HIGHs introduced by a dependency bump.
- **Terraform state locking.** My first EKS apply failed on a parallel run because the S3 backend had no DynamoDB lock table. Added the lock table and re-ran `terraform init -reconfigure` to fix.
- **Checkov on dev only.** I scoped Checkov to `terraform/envs/dev` so it doesn't flag intentionally relaxed settings in example modules; the strict baseline lives in the reusable modules themselves.

---

## Getting Started

```bash
# 1. Provision infrastructure
cd terraform/envs/dev
terraform init
terraform apply

# 2. Register the ArgoCD application
kubectl apply -f argocd/application.yaml

# 3. Verify
kubectl get pods -n juice-shop
I ran this against an AWS SSO profile named devsecops-lab; adjust the profile name in terraform/envs/dev/provider.tf if yours differs.

Prerequisites
AWS account with SSO configured

GitHub account with SonarCloud connected

Tools installed: AWS CLI, Terraform, kubectl, Helm

GitHub Secrets set: AWS_ROLE_ARN, AWS_ACCOUNT_ID, SONAR_TOKEN

Repository Layout

terraform/          # VPC, EKS, ECR modules + dev environment
.github/workflows/  # ci.yml — the 6-stage pipeline
helm/juice-shop/    # Helm chart (Deployment, Service, Ingress)
argocd/             # ArgoCD Application manifest
kyverno-policies/   # ClusterPolicy manifests
monitoring/         # kube-prometheus-stack values
Author
Emmanuel Tobi — Senior DevOps / DevSecOps Engineer.
CKA · CKAD · HashiCorp Terraform Associate

