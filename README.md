# ShopXpress-Pro — Lab A++ Senior DevOps Platform

End-to-end EKS platform trên AWS dùng để học + phỏng vấn DevOps Senior 5+ năm.
Bao phủ Security Deep + SRE/Observability + FinOps + multi-account.

---

## 1. Architecture overview

```
┌─────────────────────── Account A (nonprd, ap-southeast-1) ───────────────────────┐
│                                                                                  │
│  VPC 10.20.0.0/16                                                                │
│  ├── 3× public subnet  /24  (ALB internet-facing)                                │
│  ├── 3× private-app    /19  (EKS worker, ALB internal)                           │
│  └── 3× private-data   /24  (RDS — chưa apply)                                   │
│                                                                                  │
│  EKS cluster: shopxpress-pro-nonprd-eks                                          │
│  ├── NS: dev / stg                                                               │
│  ├── Controllers: AWS LBC, ExternalDNS, ESO, Karpenter (planned)                 │
│  └── Stack: kube-prometheus-stack, Loki, OTel, Vault, Falco (planned)            │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────── Account B (prd, ap-southeast-2) ──────────────────────────┐
│                                                                                  │
│  VPC + EKS cluster: shopxpress-pro-prd-eks (planned, Sub-comp 16+)               │
│  └── NS: prd                                                                     │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘

DNS: do2602.click (account A) → sub-zone shopxpress-pro.do2602.click (TBD)
```

## 2. Repository structure

```
shopxpress-pro/
├── terraform/                  # Infra as Code (sub-component layout)
│   ├── 00-bootstrap/           # S3 backend bucket + DDB lock table
│   ├── 10-vpc/                 # VPC + 9 subnet + NAT + RT
│   ├── 20-eks/                 # EKS control plane (planned)
│   └── ...                     # 1 sub-comp = 1 folder
├── helm/                       # Helm values per env (planned)
├── k8s/                        # Raw manifests, Kustomize overlays
├── source/                     # Sample app source (3 service Go)
├── scripts/                    # Bash helper scripts
├── docs/                       # Documentation, diagrams
├── .github/workflows/          # CI pipelines (planned)
├── Makefile                    # Workflow front door
├── .terraform-version          # Pin TF CLI version (1.9.8)
├── .editorconfig               # Cross-editor code style
└── .gitignore
```

## 3. Prerequisites

| Tool | Version | Install (Mac) |
|---|---|---|
| Terraform | 1.9.8 (pinned) | `brew install tfenv && tfenv install` |
| AWS CLI | 2.x | `brew install awscli` |
| kubectl | 1.30+ | `brew install kubectl` |
| Helm | 3.15+ | `brew install helm` |
| pre-commit | latest | `brew install pre-commit` |
| jq, yq | latest | `brew install jq yq` |

## 4. Quick start

```bash
# 1. Configure AWS profile (one time)
aws configure --profile default      # account A nonprd
aws configure --profile prd          # account B prd
source ~/.zshrc                      # load awsp function

# 2. Switch to nonprd account
awsp default                         # RPROMPT shows [AWS:default:0396]

# 3. Bootstrap state backend (run once per account)
make init     COMPONENT=00-bootstrap BACKEND=local
make plan     COMPONENT=00-bootstrap
make apply    COMPONENT=00-bootstrap

# 4. Apply VPC
make init     COMPONENT=10-vpc       # uses backend.hcl
make plan     COMPONENT=10-vpc
make apply    COMPONENT=10-vpc

# 5. List components / view all targets
make list-components
make help
```

## 5. Sub-components

| ID | Name | Status | Resources | Depends |
|---|---|---|---|---|
| 00 | bootstrap | DONE | S3 + DDB | — |
| 10 | vpc | TF written, not applied | 24 (VPC + 9 subnet + NAT + RT) | 00 |
| 20 | eks | planned | EKS cluster + add-ons | 10 |
| 30 | mng | planned | Managed Node Group | 20 |
| ... | ... | planned | controllers, observability, security, FinOps | ... |

## 6. Conventions

- **Naming**: `<project>-<env>-<resource>` lowercase + dash, DNS-1123 compliant
  - Example: `shopxpress-pro-nonprd-vpc`, `shopxpress-pro-nonprd-eks`
- **Tagging** (default_tags áp mọi resource): Project, Environment, Component, ManagedBy, Owner, CostCenter, Repo, DataClassification, BackupPolicy, CreatedBy
- **Branching**: `main` protected, feature branch `feat/<ticket>-<slug>`, PR required + 1 approval
- **Commit**: Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`)
- **State backend**: S3 partial config via `backend.hcl` per sub-comp (no migration)

## 7. References

- Roadmap: `docs/00-roadmap.md`
- Domain plan: sub-zone `shopxpress-pro.do2602.click` delegated từ apex
- Account A: `527055790396` / IAM `DE000189` / region `ap-southeast-1`
- Account B: `418553863580` / IAM `AWS0582` / region `ap-southeast-2`

## 8. Status

Active. Last updated: 2026-05-09.
