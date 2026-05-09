# Lab A++ ShopXpress-Pro — Roadmap 22 buổi (18 single-account + 4 multi-account extension)

**Chốt 2026-05-08, extend 2-account 2026-05-09.** Build từ scratch trên 2 AWS account:
- Account A `527055790396` apse1 (Singapore) — primary nonprd, 18 buổi original
- Account B `418553863580` apse2 (Sydney) — standby DR + cross-account demo, +4 buổi extension

**Mục tiêu**: phỏng vấn Senior DevOps $1500-2500 VN. Cover Security Deep + SRE/Observability đủ 3 trụ + FinOps + Bash just-in-time.

**Kế thừa pattern**: Lab A (CLOSED 2026-05-04) + Lab muoidv (DESTROYED 2026-05-08). Lần thứ 3 dựng infra → batch nhanh, KHÔNG dạy lại lý thuyết VPC/EKS/IRSA.

---

## Tổng quan 5 phase / 22 buổi

| Phase | Buổi | Account | Topic | Status |
|---|---|---|---|---|
| 0. Infra base | 3 | A | VPC + EKS + MNG + Controllers + CI/CD baseline | Buổi 0+0.5 ✅ DONE 2026-05-09 (Sub-comp 0..8) / Buổi 0.7 CI/CD pending |
| 1. Security Deep | 9 | A | Supply chain → Pod Security → RBAC → Runtime → AppSec → Secret → IR | Buổi 9 ESO ✅ 25% DONE 2026-05-09 (Sub-comp 9, còn KMS envelope+SIEM+IR) / Buổi 1-8 pending |
| 2. SRE / Observability | 5 | A | Velero DR + 3 trụ (Metric/Log/Trace) + DORA/SLO/Postmortem | Pending |
| 3. FinOps + Wrap-up | 1 | A | Spot + kubecost + cron + Cheatsheet + STAR + Cleanup | Pending |
| **4. Multi-account / DR** *(new 2026-05-09)* | **4** | **A+B** | Cross-account IAM + ECR replication + Standby cluster B + Velero cross-region + R53 failover + CloudTrail org | **Pending** |

---

## PHASE 0 — INFRA BASE (3 buổi, batch TF nhanh)

### Buổi 0 — VPC + EKS + MNG (TF replay)

- **Mục tiêu**: cluster `shopxpress-pro-dev-eks` LIVE, kubectl get nodes 3 Ready
- **Hands-on**:
  - Sub-comp 0 bootstrap: S3 backend bucket + DDB lock table
  - TF batch VPC 9 subnet (3 public + 3 private-app + 3 private-data) + 1 NAT Regional (UI 2026)
  - EKS cluster v1.34 + 3 addon đúng order (vpc-cni Prefix Delegation → kube-proxy → coredns SAU MNG)
  - MNG 3 node t3.medium spread 3 AZ, max-pods 110 verify
  - OIDC IdP IRSA tự tạo
- **Output**: cluster LIVE, TF state S3, max-pods 110 PASS

### Buổi 0.5 — Controller stack + DNS + Cert

- **Mục tiêu**: ingress chain HTTPS xanh end-to-end
- **Hands-on**:
  - LBC Helm v3.2.2 IRSA scope đúng IAM policy
  - ExternalDNS Helm 1.21.1 IRSA scope sub-zone only
  - R53 sub-zone `shopxpress-pro.do2602.click` delegated từ apex `do2602.click`
  - ACM wildcard `*.shopxpress-pro.do2602.click` + apex SAN, DNS validation auto
  - Smoke test: nginx Deployment + Ingress IngressGroup `shopxpress-pro-public` → curl HTTPS 200
- **Output**: ALB internet-facing + record auto-create, chuông xanh PASS

### Buổi 0.7 — CI/CD baseline (Helm CLI, không TF replay)

- **Mục tiêu**: push code → 5-7 phút sau pod live qua HTTPS
- **Hands-on**:
  - 3 service Go distroless (gateway BFF + products + orders)
  - 3 ECR repo Immutable + AES-256, registry scan rule filter `*`
  - GHA OIDC IdP + IAM Role + workflow `build-push.yml` (Trivy gate add Buổi 1)
  - ArgoCD chart non-HA + IngressGroup `shopxpress-pro-public`
  - ApplicationSet matrix 3 svc × 3 NS = 9 App
  - Bot bump tag SSH deploy key e2e test PASS
- **Output**: 9 App green ArgoCD, push commit → tag mới deploy auto

---

## PHASE 1 — SECURITY DEEP (9 buổi)

### Buổi 1 — Distroless + Multi-stage + Trivy baseline

- **Mục tiêu**: image nhỏ nhất + 0 CVE HIGH+
- **Hands-on**:
  - Refactor Dockerfile 3 service Go thành multi-stage (builder Alpine → runtime `gcr.io/distroless/static`)
  - Compare size before/after (~200MB → 14MB)
  - Trivy scan local + add scan job vào GHA `build-push.yml` (gate fail nếu CVE HIGH+)
  - Bash `scripts/security/scan-local.sh` wrap trivy
  - Pre-commit hook gitleaks secret scan
- **Output**: 3 image distroless arm64 lên ECR + GHA Trivy gate
- **STAR**: giảm attack surface 95%, block deploy khi CVE-2025-XXXX

### Buổi 2 — Cosign keyless OIDC + SLSA L3 + Kyverno verify signature

- **Mục tiêu**: pod chỉ chạy nếu image có signature hợp lệ
- **Hands-on**:
  - Cosign install vào GHA workflow, keyless OIDC sign sau khi push ECR
  - SLSA provenance generator (slsa-github-generator) attest build
  - Kyverno Helm install vào cluster
  - ClusterPolicy `verify-image-signatures` ép NS `prd` phải có Cosign sign
  - Test: deploy 1 image không sign → admission deny
  - Bash `scripts/security/cosign-verify.sh` local check
- **Output**: chain "GHA build → Cosign sign → ECR → ArgoCD sync → Kyverno verify → pod run"
- **STAR**: block supply chain attack — image bị thay tag fail signature verify

### Buổi 3 — PodSecurity Standards + NetworkPolicy default-deny

- **Mục tiêu**: pod nonRoot + traffic whitelist
- **Hands-on**:
  - Label NS `prd`: `pod-security.kubernetes.io/enforce=restricted`
  - Test: deploy pod runAsRoot → deny
  - Refactor Helm chart 3 service: `securityContext` (nonRoot, readOnlyRootFs, drop ALL caps, allowPrivilegeEscalation=false)
  - Cài Calico (hoặc dùng VPC CNI NetworkPolicy)
  - NetworkPolicy default-deny ingress+egress trong NS `prd`
  - Allow rule: gateway → products + orders only, all pod → kube-dns
  - Test: `kubectl exec gateway curl orders` → OK; `curl 8.8.8.8` → block
- **Output**: 3 service nonRoot + NetworkPolicy whitelist rõ
- **STAR**: pod compromise không exec binary lạ + không exfil ra ngoài

### Buổi 4 — RBAC least-privilege + ServiceAccount audit

- **Mục tiêu**: mỗi service permission tối thiểu
- **Hands-on**:
  - 3 SA riêng (gateway-sa, products-sa, orders-sa), KHÔNG dùng default SA
  - Role per SA: chỉ `get` configmap riêng của service
  - Audit cluster bằng `kubectl-who-can` + `rbac-tool` plugin
  - Detect+fix ClusterRoleBinding nguy hiểm (cluster-admin wildcard)
  - IRSA per service riêng (separate IAM role, separate AWS permission)
  - Bash `scripts/security/audit-rbac.sh` list mọi SA + permission
- **Output**: 0 ClusterRoleBinding wildcard, mỗi SA <10 action
- **STAR**: audit catch 5 over-privileged SA → downgrade

### Buổi 5 — Falco runtime + GuardDuty EKS Protection

- **Mục tiêu**: detect threat realtime trong cluster
- **Hands-on**:
  - Falco Helm chart DaemonSet eBPF mode trên AL2023
  - Default rules + custom: alert khi `kubectl exec` vào pod prd
  - Falcosidekick → Slack webhook
  - Bật GuardDuty EKS Protection (EKS Audit Logs + Runtime Monitoring agent)
  - Test trigger: `kubectl exec -it gateway-pod -- sh` → alert Slack <30s
  - Test: shell trong container `apk add curl` → Falco detect
- **Output**: Slack alert realtime + GuardDuty finding cho 3 test scenario
- **STAR**: detect lateral movement trong 30s khi attacker có shell vào pod

### Buổi 6 — STRIDE threat modeling + OWASP Top 10 code review

- **Mục tiêu**: tư duy bảo mật từ design phase
- **Hands-on**:
  - Vẽ DFD (Data Flow Diagram) gateway+products+orders trong drawio
  - STRIDE workshop per trust boundary list threat (Spoofing/Tampering/Repudiation/Info Disclosure/DoS/Elevation)
  - Per threat: mitigation đã có / cần thêm
  - Code review 1 service Go theo OWASP Top 10 2021 (A01-A10)
  - Mỗi mục: ví dụ code vulnerable + fix + test
  - Doc `docs/phase-1-security/buoi-06-stride-owasp/threat-model-shopxpress-pro.md`
- **Output**: threat model 1 trang + 10 vulnerability fix có test
- **STAR**: threat model phát hiện missing rate-limit gateway → thêm WAF rule trước prd

### Buổi 7 — DAST OWASP ZAP + SAST Semgrep CI gate

- **Mục tiêu**: automated security testing trong CI
- **Hands-on**:
  - Add Semgrep job vào GHA: scan code Go (`p/golang` + `p/owasp-top-ten`)
  - Add ZAP baseline scan job: chạy gateway lên ephemeral env trong GHA, ZAP crawl + active scan
  - Gate: fail PR nếu HIGH severity finding
  - Customize ZAP rules để skip false positive
  - Bash `scripts/security/security-test.sh` run cả Semgrep + ZAP local
- **Output**: PR template có Semgrep + ZAP report comment, gate hoạt động
- **STAR**: block PR SQL injection (Semgrep) + XSS (ZAP)

### Buổi 8 — Vault HA + dynamic DB secret + Vault PKI

- **Mục tiêu**: short-lived secret thay static
- **Hands-on**:
  - Vault Helm HA 3 replica + Raft storage backend
  - Init + auto-unseal qua KMS
  - Auth method: Kubernetes auth (SA token JWT)
  - Database secrets engine: dynamic Postgres credential TTL 1h (pod-level Postgres trong cluster cho lab)
  - PKI engine: issue cert internal cho service-to-service mTLS
  - Refactor orders service đọc DB password từ Vault qua Vault Agent injector
  - Bash `scripts/vault/vault-unseal.sh`
- **Output**: orders pod restart → DB password mới, rotate auto 1h
- **STAR**: eliminate hardcoded credential, full audit log secret access

### Buổi 9 — ESO + KMS envelope + SIEM + IR tabletop

- **Mục tiêu**: defense-in-depth secret + IR ready
- **Hands-on**:
  - ESO sync AWS Secrets Manager → K8s Secret
  - KMS envelope encrypt etcd secret (cluster-level)
  - AWS Secrets Manager auto-rotate Lambda
  - Fluent Bit → CloudWatch Logs Container Insights
  - Logs Insights query detect anomaly (failed login spike, unauthorized API)
  - Security Hub bật + standards (AWS Foundational, CIS)
  - **IR tabletop scenario**: "IRSA token leak qua container env exposed". Role-play 5 phase NIST: detect → contain → eradicate → recover → lessons
  - Bash `scripts/ir/collect-logs.sh` (kubectl logs + describe + events bundle)
- **Output**: runbook IR + collect-logs.sh + SIEM dashboard
- **STAR**: tabletop discover thiếu IRSA rotation → add CloudTrail alert + 1h rotate

---

## PHASE 2 — SRE / OBSERVABILITY 3 trụ (5 buổi)

### Buổi 10 — Velero DR backup + restore drill

- **Mục tiêu**: RTO <30 phút, RPO <24h
- **Hands-on**:
  - Velero Helm + AWS plugin + S3 backup bucket + KMS encrypt
  - Schedule daily backup full cluster + PVC snapshot
  - Hourly backup namespace `prd` only
  - **Disaster drill**: xoá toàn bộ NS `prd` (3 service + secret + PVC)
  - Restore từ Velero → verify HTTP 200 trở lại
  - Bash `scripts/velero/velero-rotate.sh` cleanup backup >30 ngày
  - Document Jenkins `$JENKINS_HOME` PVC backup pattern (deferred từ muoidv)
- **Output**: restore drill PASS <15 phút + retention policy
- **STAR**: DR drill quarterly, RTO measured 12 phút, runbook board approve

### Buổi 11 — Trụ Metric: Prometheus + Alertmanager + Synthetic

- **Mục tiêu**: 1/3 trụ observability — METRIC
- **Hands-on**:
  - kube-prometheus-stack 84.5.0 Helm + EBS CSI addon + SC gp3
  - 30 dashboard built-in (cluster, node, pod, deployment)
  - Alertmanager + Slack webhook receiver
  - Custom alert rule: pod CrashLoop, node NotReady, PVC >80%
  - Blackbox Exporter (synthetic curl gateway / 30s)
  - Grafana HTTPS qua ALB IngressGroup
- **Output**: Grafana `https://grafana.shopxpress-pro.do2602.click` + 30 dashboard + 6 alert rule
- **STAR**: alert pod CrashLoop trong 1 phút, MTTD giảm từ 30min → 1min

### Buổi 12 — Trụ Log: Loki + Promtail + LogQL

- **Mục tiêu**: 2/3 trụ — LOG aggregation centralized
- **Hands-on**:
  - Loki Helm chart + S3 backend store + retention 30 ngày
  - Promtail DaemonSet ship log từ all node → Loki
  - Add Loki datasource Grafana
  - LogQL deep dive: `{namespace="prd"} |= "ERROR"` filter, parse JSON, rate calculation
  - Custom dashboard: log volume per service, error rate, top error message
  - Correlate log với metric (Grafana derived field)
- **Output**: Grafana log explore, query 1 service 30 phút < 2s
- **STAR**: debug 5xx incident orders xuống 5 phút thay vì kubectl logs từng pod

### Buổi 13 — Trụ Trace: OpenTelemetry + Jaeger + Tempo

- **Mục tiêu**: 3/3 trụ — TRACE distributed cross-service
- **Hands-on**:
  - Inject OpenTelemetry SDK Go vào 3 service (auto-instrumentation HTTP)
  - OTel Collector DaemonSet receive traces
  - Tempo Helm backend store traces (S3 long-term)
  - Jaeger UI + Grafana Tempo datasource
  - Trace request gateway → products → orders, view dependency graph
  - **Killer feature**: correlate metric ↔ log ↔ trace trong 1 Grafana
    - Click metric anomaly → drill xuống Loki log → drill xuống Jaeger trace
    - Thấy ngay query SQL nào ngốn 500ms
- **Output**: 1 trace dashboard + dependency graph + correlate UI
- **STAR**: identify slow query trong 30s thay vì grep log 1h

### Buổi 14 — DORA + SLO/SLI + Burn rate alert + Postmortem giả

- **Mục tiêu**: build trên 3 trụ — measure delivery + practice IR review
- **Hands-on**:
  - Instrument GHA + ArgoCD emit 4 DORA metric Prometheus pushgateway:
    - Deploy frequency (deploys/day)
    - Lead time for change (commit → prd)
    - Change failure rate (% deploy rollback)
    - MTTR (incident detect → resolve)
  - Grafana SLO dashboard 1 trang:
    - SLI: HTTP 5xx rate, latency p99, availability
    - SLO target: 99.9% availability monthly
    - Error budget remaining
  - Multi-window multi-burn-rate alert (5min 14.4× page + 1h 6× ticket)
  - PromQL deep 30 phút
  - **Postmortem giả**: simulated incident "orders 5xx 30 phút lúc peak"
    - Writeup blameless template (Timeline + 5 Whys + Action items preventive/detective/corrective)
    - Doc `docs/phase-2-sre-obs/buoi-14-.../postmortem-2026-XX-orders-5xx.md`
- **Output**: 1 SLO dashboard + 4 alert rule + DORA track + 1 postmortem chuẩn Google
- **STAR**: convince team chấp nhận deploy nhanh khi budget healthy, freeze khi burn

---

## PHASE 3 — FINOPS + WRAP-UP (1 buổi)

### Buổi 15 — Spot + kubecost + MNG cron + Cheatsheet + STAR + Cleanup

- **Mục tiêu**: cost optimization + portfolio prep
- **Hands-on sáng (FinOps)**:
  - Karpenter Spot pool 70% Spot + 30% On-Demand fallback (lưu ý SCP `p-fkxu87ng` block ở Lab A cũ — verify account hiện tại)
  - Savings Plans calculator estimate
  - kubecost Helm install: dashboard $/namespace, $/deployment
  - **MNG nightly auto-scale**: Bash cron `scripts/finops/scale-mng.sh` (EventBridge + Lambda)
    - 23:00 SGT scale 3→1
    - 07:00 SGT scale 1→3
- **Hands-on chiều (Wrap-up)**:
  - Cheatsheet `docs/sre-vs-devops.md` 1 trang (3 pillar SRE riêng + overlap DevOps)
  - Cheatsheet `docs/devsecops-vs-devops.md` 1 trang (5 lớp security DevSecOps thêm)
  - Gom 10-15 STAR scenario phỏng vấn từ 14 buổi trước
  - Bash `scripts/cleanup-all.sh` 10 bước dependency-aware (theo `project_lab_a_cleanup_lessons.md`)
- **Output**: cluster cost -60% + 2 cheatsheet + STAR doc + cleanup script
- **STAR**: FinOps reduce $/tháng 60% cho dev/stg, vẫn 99.9% SLO prd

---

## ⭐ PHASE 4 — MULTI-ACCOUNT / CROSS-REGION DR (4 buổi, extension 2026-05-09)

**Why thêm Phase 4**: VTI cấp account B `vti-aws-45 / 418553863580` ngày 2026-05-09 — sau khi roadmap original chốt cho 1-account. Phỏng vấn Senior $1500-2500 thường hỏi *"đã làm 2-account chưa? cross-region DR thế nào?"* — extend 4 buổi để cover, KHÔNG đến mức Lab B fintech full active-active.

**Decision senior — KHÔNG replicate Sub-comp 0..15 sang account B**:
- Duplicate effort 18 buổi = lãng phí cho mục đích phỏng vấn
- Account B đóng vai trò **DR target + cross-account demo zone**, không cần full app stack thường trực
- Cluster B "standby" (scale 0 thường, scale up khi drill) → cost ~$0/tháng khi không drill

**Account split (chốt 2026-05-09)**:

| | Account A `527055790396` apse1 (Singapore) | Account B `418553863580` apse2 (Sydney) |
|---|---|---|
| Vai trò | Primary cluster nonprd | Standby DR target + cross-account demo |
| Cluster | `shopxpress-pro-nonprd-eks` LIVE 24/7 | `shopxpress-pro-prd-dr-eks` scale 0 thường |
| Traffic ratio | 100% bình thường | 0% (standby) → 100% khi failover |
| Stack | 18 buổi roadmap original | ECR replica + S3 Velero target + mini cluster ondemand |
| AWS CLI profile | `default` | `prd` |

### Buổi 16 — Cross-account IAM + ECR replication

- **Mục tiêu**: cross-account boundary clear + image flow A → B tự động
- **Hands-on**:
  - IAM cross-account AssumeRole: tạo role ở B trust account A principal (test bằng `aws sts assume-role --profile default --role-arn <B-role-arn>`)
  - ECR replication rule (registry-level): A push image → B auto-replicate apse1 → apse2
  - Cross-account S3 bucket policy: B bucket allow A account `s3:PutObject` (chuẩn bị cho Velero target Buổi 17)
  - GHA OIDC update: 1 IAM Role per account, workflow ma trận deploy đến cả A+B
  - Bash `scripts/multi-account/aws-switch.sh` quick switch profile + verify caller identity (RPROMPT cảnh báo profile sai)
- **Output**: 3 image ECR auto-replicate sang account B + IAM AssumeRole verify PASS
- **STAR**: nếu account A bị compromise, attacker không đụng được tài nguyên B (hard separation)

### Buổi 17 — Standby cluster B + Velero cross-region backup/restore

- **Mục tiêu**: RTO <30 phút khi region apse1 sập
- **Hands-on**:
  - TF folder mới `terraform-account-b/` (state file riêng S3 ở apse2)
  - Mini cluster: 1 MNG t3.medium **min=0 max=3 desired=0** (scale 0 thường, scale up khi drill)
  - Velero schedule cross-region: backup từ cluster A → S3 **ở account B apse2** (cross-account write)
  - **Drill scenario**: 
    1. Scale up cluster B 0→3 node
    2. Velero restore namespace `prd` từ S3 B vào cluster B
    3. R53 record `gateway.shopxpress-pro.do2602.click` chuyển sang ALB B
    4. curl HTTPS 200 — RTO measure
    5. Sau drill: scale B back 0, traffic về A
  - Bash `scripts/multi-account/dr-drill.sh` automate full flow
- **Output**: drill PASS RTO <20 phút + cost B ~$0/tháng khi không drill
- **STAR**: quarterly DR drill, RTO measured 18 phút, board sign-off

### Buổi 18 — R53 health check failover apse1 → apse2

- **Mục tiêu**: tự động failover khi A health check fail
- **Hands-on**:
  - R53 health check: HTTPS endpoint `gateway.shopxpress-pro.do2602.click` từ A
  - Failover routing policy: primary record → ALB A apse1, secondary record → ALB B apse2
  - Mock disaster: scale Deployment gateway A → 0 → health check fail 3 lần liên tiếp (30s)
  - R53 detect → traffic auto chuyển sang ALB B (resolve sang IP B)
  - Recovery: scale A back → R53 trả về primary
  - Test browser: trong drill thấy uptime 99% (mất ~30s window)
- **Output**: R53 failover PASS, demo browser thấy auto-recovery
- **STAR**: customer experience ~30s downtime trong DR scenario regional outage

### Buổi 19 — CloudTrail organization trail + Security Hub cross-account aggregation

- **Mục tiêu**: 1 nơi nhìn toàn bộ activity 2 account
- **Hands-on**:
  - CloudTrail organization trail ở A (delegated administrator) — capture event toàn 2 account
  - S3 bucket A nhận log từ cả A+B (bucket policy cross-account)
  - Athena query: `SELECT * FROM cloudtrail WHERE eventName='AssumeRole' AND userIdentity.accountId='418553863580'` — track ai assume role B
  - Security Hub: A là delegated admin, B member → 1 dashboard finding cả 2 account
  - GuardDuty cross-account: B finding tự push lên A
  - IR runbook update: scenario "incident ở B detect qua A aggregate"
  - Bash `scripts/security/multi-account-audit.sh` query Athena CloudTrail + dump finding Security Hub
- **Output**: 1 Security Hub dashboard 2-account + Athena query mẫu + IR runbook v2
- **STAR**: catch lateral movement A → B trong 1 incident giả, 5 phút thay 1 ngày grep CloudTrail từng account

---

## Skip vĩnh viễn (chốt Plan v5 2026-05-06)

- Lab B GlobalPay (multi-region + PCI-DSS) — đợi business case fintech
- Lab C LogiViet (on-prem kubeadm) — đợi business case enterprise legacy
- Python dedicated buổi — Bash đủ 80% case
- Chaos engineering — 20% phỏng vấn hỏi, "đã đọc" đủ
- Istio Service Mesh — over-engineering 1 cluster managed AWS

---

## Naming convention (chốt Lab A)

`<project>-<env>-<service>` lowercase + dash, DNS-1123 compliant.

Ví dụ:
- Cluster: `shopxpress-pro-dev-eks`
- VPC: `shopxpress-pro-dev-vpc`
- ALB: `k8s-shopxpressproppublic-...` (auto)
- ECR: `shopxpress-pro/gateway`, `shopxpress-pro/products`, `shopxpress-pro/orders`
- Sub-zone: `shopxpress-pro.do2602.click`

## Domain pattern

- Apex zone: `do2602.click` (account hiện tại, Z05295483ECCOOG0L2IDK)
- Sub-zone Lab A++: `shopxpress-pro.do2602.click` delegated cùng account
- Wildcard cert: `*.shopxpress-pro.do2602.click` + apex SAN
- Service URL: `<svc>.shopxpress-pro.do2602.click` (vd: argocd, grafana, jaeger)

## Folder structure

```
shopxpress-pro/
├── docs/
│   ├── 00-roadmap.md (file này)
│   ├── phase-0-infra/ (3 buổi)
│   ├── phase-1-security/ (9 buổi)
│   ├── phase-2-sre-obs/ (5 buổi)
│   ├── phase-3-finops/ (1 buổi)
│   └── diagrams/ (.drawio)
├── terraform/
│   ├── 00-bootstrap/ (S3 backend + DDB)
│   ├── 10-vpc/
│   ├── 20-eks/
│   ├── 30-mng/
│   ├── 40-irsa/
│   └── modules/
├── helm/
│   ├── umbrella/
│   └── services/{gateway,products,orders}/
├── k8s/
│   ├── kyverno-policies/
│   ├── network-policies/
│   ├── pod-security/
│   ├── falco/
│   └── rbac/
├── scripts/
│   ├── ci/
│   ├── security/ (scan, cosign, audit-rbac, security-test)
│   ├── velero/
│   ├── vault/
│   ├── ir/ (collect-logs)
│   └── finops/ (scale-mng)
└── source/
    ├── gateway/
    ├── products/
    └── orders/
```

---

## Reference architecture sau Buổi 15 — production-grade

| # | Layer | Component |
|---|---|---|
| 1 | Network/Compute | VPC private + EKS managed v1.34 + MNG + Karpenter Spot |
| 2 | Ingress | ALB IngressGroup `shopxpress-pro-public` + ACM HTTPS wildcard + ExternalDNS |
| 3 | CI | GHA OIDC + Trivy + Semgrep + ZAP + Cosign sign + SLSA L3 |
| 4 | CD | ArgoCD Pull-based GitOps + ApplicationSet 3×3 + bot bump tag |
| 5 | Admission | Kyverno verify signature + PSS restricted + NetworkPolicy default-deny |
| 6 | Runtime Sec | Falco eBPF + GuardDuty EKS Protection + RBAC least-privilege |
| 7 | Secret | Vault HA dynamic DB + PKI mTLS + ESO + KMS envelope + Secrets Manager auto-rotate |
| 8 | Observability | Prometheus (metric) + Loki (log) + Jaeger/Tempo (trace) + Grafana correlate |
| 9 | SRE | DORA 4 metric + SLO 99.9% + multi-burn-rate alert + Postmortem blameless |
| 10 | DR | Velero S3 backup + restore drill RTO <15min |
| 11 | FinOps | Spot 70% + kubecost + MNG cron 3→1 đêm |
| 12 | SIEM/IR | CloudWatch Logs Insights + Security Hub + IR runbook |

→ Cover ~80-90% job market Senior DevOps/SRE/DevSecOps tier $1500-2500 VN.

---

## How to apply

- Mỗi session em theo đúng thứ tự bảng trên, KHÔNG nhảy buổi
- Pattern dạy: sub-comp 6 step (Theory → UI hands-on → confirm → TF → giải thích → ghi docs `.md` + `.docx`)
- Folder per buổi có riêng `kien-thuc.md`, `lab-handson.md`, `pitfall.md`, file artifact (TF/Helm/k8s)
- Cluster `shopxpress-pro-dev-eks` giữ LIVE xuyên suốt 18 buổi, cleanup ở Buổi 15
- Mỗi resource expose internet → dùng IngressGroup `shopxpress-pro-public` share ALB
- File `.md` mới → convert `.docx` cùng tên bằng `pandoc` ngay (theo `feedback_docx_output.md`)
