# Roadmap 2 tháng Mock Interview — DevOps Senior 5+ Remote

> **Mục tiêu**: phỏng vấn DevOps/SRE Senior 5+ remote, salary $1500-2500. 56 ngày, ~165 câu cốt lõi + 4 system design + 5 STAR Lab A++.
>
> **Bắt đầu**: 2026-05-11 (Mon). **Kết thúc**: 2026-07-05 (Sun).

---

## Pattern 1 ngày học

```
🕘 Sáng 60 phút — 5 câu MỚI:
   - Mỗi câu 10 phút: 3 phút anh trả lời (ghi giấy/note) → 7 phút em probe Senior + STAR template
   - Lệnh ngắn: anh đọc câu hỏi → tự nghĩ 3 phút → gõ "tiếp" → em giảng

🕗 Tối 30 phút — ÔN 5 câu HÔM QUA:
   - 3 phút/câu — tự kể lại KHÔNG nhìn note
   - Tự đánh giá: ✅ pass / 🟡 đọc lại / ❌ chưa hiểu (báo em)

📅 Sun cuối tuần:
   - Mock 30-60 phút (em là interviewer)
   - Ôn tổng 25 câu cả tuần (1.5 phút/câu flash)
```

**Pattern ôn**: D ôn D-1 + cuối tuần ôn cả tuần. Tuần kế: 1 câu Mid ngẫu nhiên từ tuần trước được probe trong mock.

---

## 8 tuần × 7 ngày = 56 ngày

### TUẦN 1 — K8s Fundamental + Troubleshoot (25 câu Q1-Q25)

| Ngày | Chủ đề | Học mới | Ôn |
|---|---|---|---|
| **D1** Mon | Pod lifecycle | Q1-Q5: 5 phase Pod / Init vs Sidecar / terminationGracePeriod / restartPolicy / Exit code (0/1/137/139/143) | — |
| **D2** Tue | Service + Networking ⬅ SWAPPED 2026-05-12 | Q6-Q10: ClusterIP/NodePort/LoadBalancer + LBC IP mode / kube-proxy iptables vs IPVS / Endpoints vs EndpointSlice / DNS cluster.local + ndots / Headless StatefulSet | D1 |
| **D3** Wed | Probes ⬅ SWAPPED 2026-05-12 | Q11-Q15: readiness vs liveness vs startup / HTTP/TCP/Exec / failureThreshold math / probe gây CrashLoop / sidecar race | D2 |
| **D4** Thu | Deployment + Rolling | Q16-Q20: maxSurge/maxUnavailable / rollback strategy / revisionHistoryLimit / immutable selector pitfall / Recreate strategy khi nào | D3 |
| **D5** Fri | Debug 5-method | Q21-Q25: CrashLoopBackOff / OOMKilled exit 137 / ImagePullBackOff / Pending (scheduling fail) / Evicted (DiskPressure) | D4 |
| **D6** Sat | Mock 30 phút | 6 câu random Q1-Q25 + em chấm gap | D5 |
| **D7** Sun | NGHỈ + ôn tổng tuần | Flash 25 câu, 90 phút | Tuần 1 |

### TUẦN 2 — K8s Advanced + Network + Linux (25 câu Q26-Q50)

| Ngày | Chủ đề | Học mới | Ôn |
|---|---|---|---|
| **D8** Mon | CNI deep | Q26-Q30: VPC CNI vs Calico vs Cilium / IPAM ENI/Prefix Delegation / max-pods 29 vs 110 / NetworkPolicy enforcement engine / eBPF intro | D1 (spaced) |
| **D9** Tue | kube-proxy + DNAT | Q31-Q35: iptables chain flow / IPVS hash table / conntrack table size / source IP preserve (externalTrafficPolicy) / kube-proxy crash effect | D8 |
| **D10** Wed | Autoscale HPA/VPA/Karpenter | Q36-Q40: HPA CPU 60% vs 80% why / metric-server vs custom metric / VPA recommend mode / Karpenter vs CA / scale lag math | D9 |
| **D11** Thu | NetworkPolicy + RBAC | Q41-Q45: ingress vs egress / podSelector vs namespaceSelector / deny-all default / Role vs ClusterRole / ServiceAccount binding | D10 |
| **D12** Fri | Linux signal + cgroup | Q46-Q50: SIGTERM/SIGKILL/SIGINT flow / cgroup v1 vs v2 / OOM killer score / `ps`+`top`+`pidstat` / strace+lsof khi nào | D11 |
| **D13** Sat | Mock 30 phút | Mix Q1-Q50 (6 câu) + STAR template 2 câu | D12 |
| **D14** Sun | NGHỈ + ôn tổng | Spaced repetition Tuần 1 (35 câu flash 60 phút) + Tuần 2 review | Tuần 1+2 |

### TUẦN 3 — AWS Network + Security (25 câu Q51-Q75)

| Ngày | Chủ đề | Học mới | Ôn |
|---|---|---|---|
| **D15** Mon | VPC fundamentals | Q51-Q55: CIDR planning / public vs private subnet / IGW vs NAT GW / route table priority / VPC Flow Logs đọc gì | D8 (spaced) |
| **D16** Tue | ALB advanced | Q56-Q60: target group health / sticky session cookie / host vs path routing / TLS termination + SNI / IngressGroup pattern | D15 |
| **D17** Wed | TGW + VPN + Direct Connect | Q61-Q65: TGW vs VPC Peering vs PrivateLink / route propagation / BGP basic / Site-to-Site VPN HA / DX vs VPN cost | D16 |
| **D18** Thu | IAM deep | Q66-Q70: principal + action + resource + condition / assume-role flow + STS / IRSA OIDC trust / permission boundary / SCP vs IAM policy precedence | D17 |
| **D19** Fri | KMS + Secrets | Q71-Q75: envelope encryption DEK/KEK / GenerateDataKey vs Decrypt / key policy 4 statement / grant vs policy / Secrets Manager vs SSM Parameter | D18 |
| **D20** Sat | Mock 30 phút | 6 câu AWS Network+Sec + 1 scenario "IRSA pod gọi S3 AccessDenied debug" | D19 |
| **D21** Sun | NGHỈ + ôn tổng | Spaced Tuần 2 + review Tuần 3 | Tuần 2+3 |

### TUẦN 4 — CI/CD + GitOps + Deployment + English start (25 câu Q76-Q100)

| Ngày | Chủ đề | Học mới | Ôn |
|---|---|---|---|
| **D22** Mon | GHA workflow | Q76-Q80: matrix strategy / paths filter 2-layer pitfall / OIDC IdP vs static keys / secret scope / reusable workflow | D15 (spaced) |
| **D23** Tue | ArgoCD architecture | Q81-Q85: App vs AppProject vs ApplicationSet / sync wave + hook PreSync/PostSync / RespectIgnoreDifferences CRD / RBAC ArgoCD / drift detection | D22 |
| **D24** Wed | Image promotion + Registry | Q86-Q90: build-once-deploy-many / ImageUpdater bot SSH deploy key / immutable tag / ECR lifecycle / multi-arch manifest pitfall | D23 |
| **D25** Thu | Blue/Green vs Canary vs Rolling | Q91-Q95: trade-off 3 strategy / PDB minAvailable vs maxUnavailable / traffic shift 10→25→50% / automated rollback metric / dark launch | D24 |
| **D26** Fri | PreStop + readinessProbe pitfall | Q96-Q100: preStop sleep 5s why / readiness vs liveness nhầm lẫn / SIGTERM not propagating in shell / connection draining ALB 30s / pod terminating grace flow | D25 |
| **D27** Sat | **Mock 45 phút FULL English** lần đầu | 3 tech + 1 scenario, em phát hiện gap fluency | D26 |
| **D28** Sun | NGHỈ + **dịch top 30 answer sang English** | 90 phút translate Q1-Q30 sang English script | Tuần 3+4 |

### TUẦN 5 — IaC Terraform + Observability + APPLY JOB START (25 câu Q101-Q125)

| Ngày | Chủ đề | Học mới | Ôn |
|---|---|---|---|
| **D29** Mon | Terraform state | Q101-Q105: S3 + DDB lock / state large (>1000 resource) sharding / workspace vs directory / remote vs local state / state encryption | D22 (spaced) |
| **D30** Tue | Drift + Import + Taint | Q106-Q110: terraform plan cron drift / import existing / taint vs replace / moved block refactor / dependency lock file | D29 |
| **D31** Wed | Prometheus + Federation | Q111-Q115: pull vs push model / federation hierarchy / recording rules / cardinality bomb (label avoid) / remote_write retention | D30 |
| **D32** Thu | **4 Golden Signals** | Q116-Q120: Latency (P50/P95/P99) / Traffic (rps/qps) / Error (rate vs ratio) / Saturation (CPU/RAM/IO) / RED vs USE method khi nào | D31 |
| **D33** Fri | SLO/SLI + Error budget | Q121-Q125: SLI 99.9% math / error budget burn rate / 2-window alert 1h/6h / multi-burn-rate / postmortem trigger threshold | D32 |
| **D34** Sat | Mock 45 phút (English Obs heavy) + **APPLY 3-5 JOB ĐẦU TIÊN** | LinkedIn, RemoteOK, WeWorkRemotely | D33 |
| **D35** Sun | NGHỈ + cập nhật CV LinkedIn | Polish portfolio Lab A++ + thêm DORA Elite | Tuần 4+5 |

### TUẦN 6 — Production Outage Scenarios (25 câu Q126-Q150)

| Ngày | Chủ đề | Học mới | Ôn |
|---|---|---|---|
| **D36** Mon | Outage 1: ALB 5xx spike 3AM | Q126-Q130: 15 phút đầu / dashboard nào mở trước / log query / target group debug / escalate ai | D29 (spaced) |
| **D37** Tue | Outage 2: etcd disk full | Q131-Q135: etcd defrag / WAL size / compaction strategy / quorum loss recover / backup restore | D36 |
| **D38** Wed | Outage 3: Cascading OOM | Q136-Q140: 1 pod OOM → restart → memory leak / HPA quá nhanh kill node / circuit breaker / bulkhead pattern / load shed | D37 |
| **D39** Thu | Outage 4: Certificate expire | Q141-Q145: ACM auto-renew failed / cert-manager Let's Encrypt rate limit / SNI mismatch / nội bộ Vault PKI / cert rotation Karpenter pitfall | D38 |
| **D40** Fri | Outage 5: Deploy fail + DB migration broken | Q146-Q150: forward fix vs rollback / migration backward compat / feature flag kill switch / blue-green DB schema / chaos eng intro | D39 |
| **D41** Sat | Mock 45 phút (chỉ outage scenario) + **APPLY 5-10 JOB nữa** | em đóng vai interviewer khó | D40 |
| **D42** Sun | NGHỈ + ghi **3 postmortem mẫu** | Timeline + 5 whys + action item — dùng làm STAR | Tuần 5+6 |

### TUẦN 7 — System Design 4 classic (8 problem dài)

| Ngày | Chủ đề | Học mới | Ôn |
|---|---|---|---|
| **D43** Mon | **SD1 E-commerce 10K rps** (Step 1-2 đã demo) | Step 3 DESIGN: boxes & arrows CloudFront→ALB→EKS→SQS→Aurora+Redis | D36 (spaced) |
| **D44** Tue | SD1 tiếp Step 4-5 | Deep dive: idempotency, sharding, queue. Trade-off CEO multi-AZ vs multi-region | D43 |
| **D45** Wed | **SD2 URL shortener** | base62 encode, hash collision, read-heavy 100K rps, cache strategy, custom alias | D44 |
| **D46** Thu | SD2 hoàn thiện + STAR write | Polish thành câu chuyện kể 5-7 phút | D45 |
| **D47** Fri | **SD3 Chat real-time** | WebSocket vs long-poll, fan-out (push vs pull), presence indicator, message persistence | D46 |
| **D48** Sat | **Mock 60 phút system design** + **APPLY 5-10 JOB** | Em là interviewer FAANG | D47 |
| **D49** Sun | NGHỈ + skeleton **SD4 News feed** | Pull vs push timeline, ranking algorithm, hot user fan-out problem | Tuần 6+7 |

### TUẦN 8 — Behavioral STAR + Mock Full Loop (12 STAR + 5 mock)

| Ngày | Chủ đề | Học mới | Ôn |
|---|---|---|---|
| **D50** Mon | **STAR 1-2**: Karpenter SCP + MNG nightly scale-down 3AM | Polish thành câu kể 4-5 phút, English version sẵn | D43 (spaced) |
| **D51** Tue | **STAR 3-5**: GHA→ArgoCD bot + DORA Elite + ECR multi-arch | + Mock 60 phút English (Behavioral + Tech) | D50 |
| **D52** Wed | **Mock loop FULL** lần 1: Behavioral 30m + Tech 45m + SD 45m | + **APPLY 5 JOB** | Tuần 6+7 |
| **D53** Thu | Mock loop FULL lần 2 + ghi điểm yếu | Focus topic yếu nhất | D52 |
| **D54** Fri | Mock loop FULL lần 3 + review điểm yếu loop trước | + chốt salary nego script ($1500-2500) | D53 |
| **D55** Sat | Mock loop FULL lần 4 + **APPLY 10 JOB cuối** | Final polish | D54 |
| **D56** Sun | **NGHỈ TỔNG KẾT** | Tự đánh giá: ready? Còn gì gap → patch tuần 9 nếu cần | All |

---

## Đầu ra (Deliverables)

| # | File | Nội dung |
|---|---|---|
| 1 | `README.md` | Index + tiến độ session + 4 câu đã demo (1, 2, 3, 10) |
| 2 | `roadmap-2-month.md` | File này — 56 ngày plan |
| 3 | `topic-1-k8s-fundamental.md` | Q1-Q25 đầy đủ Senior answer + STAR (tạo dần D1-D5) |
| 4 | `topic-2-k8s-advanced.md` | Q26-Q50 |
| 5 | `topic-3-aws-net-sec.md` | Q51-Q75 |
| 6 | `topic-4-cicd-deploy.md` | Q76-Q100 |
| 7 | `topic-5-iac-obs.md` | Q101-Q125 |
| 8 | `topic-6-outage-scenario.md` | Q126-Q150 |
| 9 | `topic-7-system-design.md` | SD1-SD4 full |
| 10 | `star-portfolio.md` | 5 chuyện Lab A++ format Vietnamese + English |
| 11 | `mock-log.md` | 25-30 mock — điểm yếu loop |
| 12 | `apply-job-tracker.md` | Job applied / interview scheduled / offer |

---

## Spaced repetition matrix

Mỗi câu lặp 3 lần tự nhiên qua pattern D ôn D-1:

```
Câu Q1 học D1
   → ôn D2 (lần 2, sau 1 ngày)
   → ôn D8 spaced tuần 2 (lần 3, sau 7 ngày)
   → ôn D29 spaced tuần 5 (lần 4, sau 28 ngày) [nếu cần]
```

→ Sau 8 tuần, 150 câu Mid+Mid+ thuộc lòng, không nhìn note vẫn kể được.

---

## STAR portfolio (rút từ Lab A++)

5 câu chuyện anh đã LIVE — gắn vào interview tự nhiên:

| # | Câu chuyện | Interview prompt mapping |
|---|---|---|
| 1 | **Karpenter SCP block** (v1.12 rút, pivot Bitnami) | "Tell me a time you hit a constraint" |
| 2 | **MNG nightly scale-down 03:00 SGT** ($14K loss avoid) | "Tell me about a 3AM incident" |
| 3 | **Bot bump tag SSH deploy key** (GHA→Argo e2e) | "Tell me about a CI/CD you designed" |
| 4 | **DORA Lead Time 6m36s Elite** (poll bottleneck 53%) | "Tell me a metric you improved" |
| 5 | **ECR multi-arch delete loop pitfall** | "Tell me a subtle bug you found" |

Mỗi câu chuyện format STAR:
- **S**ituation: 30s context
- **T**ask: anh cần gì
- **A**ction: 2-3 phút quyết định + bước cụ thể
- **R**esult: số cụ thể ($14K save / 6m36s / 0 CVE...)

---

## Salary nego script (Tuần 8 D54)

| Range | Ai trả | Cần có |
|---|---|---|
| **$1500-2000** | Vietnamese outsource remote / SEA startup | Lab A++ portfolio + DORA Elite + English B1 |
| **$2000-2500** | EU/AU/SG mid-size company | CKA cert + open source contrib (1-2 PR Argo/Helm) |
| **$2500-3500** | US startup / FAANG-adjacent | AWS SA Pro + system design vững + English B2+ |
| **$3500+** | FAANG / unicorn | + LeetCode 150+ + 2 SD round PASS |

**Mục tiêu realistic**: $1800-2500 sau 2 tháng — đủ để xin việc remote first job.

---

## Cảnh báo

- **English fluency = gating factor**. Tuần 4 D27 mock English đầu tiên — nếu fluency yếu, anh phải add 30 phút/ngày English speaking (shadow YouTube Kubernetes/AWS talk).
- **Apply job sớm** (D34 tuần 5) — không chờ hết roadmap. Phỏng vấn thật là feedback tốt nhất.
- **Đừng skip mock**. Đọc 200 câu mà không mock = thi viết, không phải phỏng vấn. Mock = muscle memory.
- **Lab A++ không xoá**. STAR cần live demo nếu interviewer hỏi "show me your cluster". Giữ chạy đến hết tuần 8.

---

## Resume protocol

Khi em (Claude) đọc lại file này ở session sau:
1. Hỏi anh "hôm nay D mấy?" → đi đúng entry trong table.
2. Ôn 5 câu hôm trước (3 phút/câu, anh tự kể) → em chấm.
3. Học 5 câu mới hôm nay (10 phút/câu, full Senior answer + STAR).
4. Cập nhật **mock-log.md** sau mỗi mock.
5. Update **apply-job-tracker.md** mỗi khi apply / interview / offer.
6. Commit + push sau mỗi 2-3 ngày.
