# Mock Interview — DevOps/SRE Senior 5+

> **Mục tiêu**: luyện phỏng vấn vị trí DevOps/SRE Senior 5+ ($1500-2500 range), dùng Lab A++ ShopXpress-Pro làm STAR portfolio.
>
> **Pivot**: 2026-05-10 — sau khi đóng Buổi 0.7.9 DORA, chuyển sang khai thác sâu Sub-comp 0..9 + 0.7.x đã build thay vì tiếp Phase 1 Security.
>
> **Update 2026-05-11**: thêm **roadmap 2 tháng** (56 ngày) — xem [`roadmap-2-month.md`](./roadmap-2-month.md). File này (README) ghi 4 câu đã demo + tiến độ session ngắn. File roadmap ghi plan từng ngày D1-D56.

---

## 📋 Plan tuần — 17 câu, mix level

Tỷ lệ **5 [MID] : 7 [MID+] : 5 [SENIOR]** — warm-up Mid trước, không pure Senior.

| Ngày | Câu | Level | Chủ đề |
|---|---|---|---|
| Mon | 1 | [MID] | **Pod CrashLoopBackOff** debug 5 bước ✅ |
| Mon | 2 | [MID] | **Service không reach** (Endpoints layer) ✅ |
| Tue | 3 | [MID+] | **HTTP 404 vs 502** phân biệt tầng (ALB) ✅ |
| Tue | 4 | [MID+] | Pod **OOMKilled** — tăng limits hay tìm leak? |
| Wed | 5 | [MID] | `kubectl logs` vs `describe` vs `events` — khi nào cái nào |
| Wed | 6 | [MID+] | **IRSA pod** gọi AWS API bị `AccessDenied` — debug |
| Thu | 7 | [MID+] | Deploy mới latency tăng 3x — **rollback hay forward fix**? |
| Thu | 8 | [SENIOR] | **ALB 502** — 2/3 target Unhealthy + pod Ready (case mock đầu session) |
| Fri | 9 | [SENIOR] | **RTO/RPO** cho cluster crash mất etcd |
| Fri | 10 | [SENIOR] | **System design**: e-commerce 10K rps multi-AZ vs multi-region ✅ DEMO (Step 1-2) |
| ... | 11-17 | mix | rải các trục HA / CI-CD speed / trade-off |

**Quy tắc đánh giá**:
- Mid = thao tác cụ thể, không yêu cầu trade-off đa chiều
- Mid+ = 1 lớp probe "vì sao không Y", có edge case
- Senior = trade-off đa chiều, scale, business impact, blast radius, escalate

---

## ✅ Tiến độ session 2026-05-10 → 2026-05-11

Đã đi: **4 câu** ([MID]×2 + [MID+]×1 + [SENIOR]×1 demo).

### Tổng chấm điểm baseline

| Câu | Level đề | Level user trả lời | Gap chính |
|---|---|---|---|
| 1 | [MID] | Teaching mode (chưa kinh nghiệm) | Chưa từng debug K8s thực |
| 2 | [MID] | Junior+ | Reflex network OK, **chưa nắm Service ↔ Endpoints** + ClusterIP VIP ảo |
| 3 | [MID+] | Junior | **502 layer sai** (tưởng routing, thật ra target group); chưa biết đọc header `Server:` |
| 10 | [SENIOR] | Teaching mode (chưa từng làm system design) | Cần framework + anchor numbers; bị "ngộp" khi insight nhiều ý — cần ghi xuống đọc lại nhiều lần |

→ **Gap chung**: hiểu fundamental K8s networking (Service VIP ảo, Endpoints, kube-proxy, CoreDNS) + **system design framework** (RESHADED + capacity math + trade-off probe Senior) — tầng này tách biệt với reflex sysadmin truyền thống.

---

## 📚 Câu 1 [MID] — Pod CrashLoopBackOff

### Setup giả lập (đã chạy live trên cluster)

Pod `crash-demo` ở namespace `dev`, image `busybox:1.36`, command in 5 dòng log rồi `exit 1` lặp.

### Methodology 5 bước (vàng)

```
1. kubectl get pod <pod> -n <ns> -o wide       → state cơ bản, IP, node
2. kubectl describe pod <pod> -n <ns>           → Events + Last State + Exit Code
3. kubectl logs <pod> -n <ns> --previous        → log lần crash TRƯỚC (vàng nhất)
4. kubectl logs <pod> -n <ns>                   → log lần thử mới nhất
5. kubectl exec / spawn pod debug               → verify network/DNS từ trong cluster
```

**Quy tắc vàng**: pod CrashLoopBackOff → **luôn `--previous` TRƯỚC**, vì container đang trong back-off thì log hiện tại có thể trống.

### Exit codes phải thuộc

| Code | Nghĩa |
|---|---|
| 0 | OK (Completed) |
| 1 | Lỗi app generic (panic, return error) |
| **137** | SIGKILL — thường = **OOMKilled** |
| 139 | SIGSEGV — segfault |
| 143 | SIGTERM — graceful shutdown |

### Vì sao spawn pod debug riêng

Pod app crash không exec được (container không tồn tại để attach).
Pod app **distroless** không có shell (`exec: "sh": executable file not found`).
→ Spawn 1 pod busybox/netshoot **cùng namespace** → cùng NetworkPolicy + cùng DNS scope → test thay được.

**Pod debug template** (đã verify với PSS `restricted` ns dev):

```yaml
apiVersion: v1
kind: Pod
metadata: {name: net-debug, namespace: dev}
spec:
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile: {type: RuntimeDefault}
  containers:
  - name: net-debug
    image: busybox:1.36
    command: ["sh", "-c", "sleep infinity"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities: {drop: ["ALL"]}
```

### Senior insight

**Log app là *triệu chứng*, không phải *nguyên nhân thật*.**

Lab giả lập: log nói "i/o timeout to orders-db:5432". Verify thực tế:
- `nslookup orders-db.shopxpress-data.svc.cluster.local` → ✅ resolve OK (`172.20.196.204`)
- `nc -zv -w 3 orders-db.shopxpress-data 5432` → ✅ TCP open

→ Mâu thuẫn log vs thực tế → **không tin log mù, luôn verify chéo từ pod debug**. Đây là khác biệt **Mid (tin log)** vs **Senior (verify chéo)**.

5 nguyên nhân thật khi log "timeout" mà network OK:
1. App timeout setting quá ngắn (1s không đủ TLS handshake / cold start)
2. Port/host sai trong env (config `DB_PORT=5433` nhầm)
3. Auth fail → DB drop connection → app coi là timeout
4. TLS mismatch (DB yêu cầu SSL, app không bật)
5. Config drift (dev trỏ nhầm DB stg/prd)

---

## 📚 Câu 2 [MID] — Service không reach

### Câu hỏi

Service `payments` mới deploy ở ns `dev`. Pod Running 1/1, app log `listening on :8080`. Service ClusterIP có. Nhưng `curl http://payments.dev/...` từ pod khác → timeout.

### User trả lời (baseline)

> "Check DNS, check ping"

### Sai logic chính — ClusterIP không reply ICMP

```
ClusterIP 172.20.55.123 = VIP ảo, KHÔNG có interface mạng thật
                          KHÔNG có kernel TCP/IP stack đứng sau
```

`kube-proxy` chỉ lập trình iptables/IPVS rule **DNAT cho TCP/UDP** → packet đi qua bị rewrite về Pod IP thật. **ICMP không có rule** → drop.

→ Pattern senior: dùng `nc -zv <svc> <port>` để probe TCP, **không dùng `ping`** trong K8s.

### Service ↔ Endpoints — khái niệm K8s-specific

```
Service (selector: app=payments)
   ↓ kube-proxy đọc
Endpoints object (list Pod IP đủ điều kiện)
   ↓ DNAT
Pod thật (10.20.x.x:8080)
```

**3 lý do Endpoints trống** (Mid phải thuộc):
1. **Selector mismatch label pod** — typo `app: payment` vs `app: payments`
2. **Pod chưa Ready** (`readinessProbe` fail) → kubelet không add vào Endpoints
3. **Pod không listen `targetPort`** (hoặc app bind `127.0.0.1` thay vì `0.0.0.0`)

### Lệnh debug Senior gõ đầu tiên

```bash
kubectl get endpoints payments -n dev
# bản 1.21+:
kubectl get endpointslice -n dev -l kubernetes.io/service-name=payments
```

- `ENDPOINTS = <none>` → Endpoints trống → đi tìm 1 trong 3 lý do
- `ENDPOINTS = 10.20.34.55:8080` → Endpoints OK → vấn đề ở app/port/NetworkPolicy

### Senior 5+ answer mẫu

> "Đầu tiên `kubectl get endpoints`. Nếu trống → 3 khả năng: (1) selector mismatch (so `kubectl get svc -o yaml | grep selector` vs `kubectl get pod --show-labels`), (2) pod chưa Ready (`describe pod` xem Conditions), (3) container listen sai address. Nếu Endpoints có IP nhưng vẫn timeout → check `targetPort` match `containerPort`. Cuối cùng mới đến NetworkPolicy."

---

## 📚 Câu 3 [MID+] — HTTP 404 vs 502 phân biệt tầng

### Câu hỏi

Cùng host `users.shopxpress-pro.do2602.click`:
- `/healthz` → **HTTP 502 Bad Gateway**
- `/api/v1/users` → **HTTP 404 Not Found**

Phân biệt 2 status do tầng nào sinh + lệnh debug.

### User trả lời (baseline)

> "502 ở tầng routing. 404 do tầng app code."

### Sai — 502 KHÔNG phải tầng routing

```
ALB nhận request → tìm target healthy → forward
   ↓ KHÔNG có target healthy / target chết / response không hợp lệ
ALB tự sinh 502 Bad Gateway
```

**3 nguyên nhân 502** (Mid+ thuộc):
- Target Group **không có target Healthy** (pod chưa Ready, healthcheck fail)
- Target **trả connection RST** (app crash giữa chừng, port mapping sai)
- Target **trả response không phải HTTP hợp lệ** (TLS mismatch — ALB gửi HTTPS, pod listen HTTP)

**Họ hàng**:
- **502** = bad gateway (target trả invalid)
- **503** = service unavailable (ALB busy / no target available)
- **504** = gateway timeout (target không kịp trả)

### 404 — đúng tầng app, NHƯNG 2 lớp có thể trả

Phân biệt qua **header `Server:`**:
- `Server: awselb/2.0` → **ALB** sinh (Listener rules không match → default action 404)
- `Server: nginx`, `Server: gunicorn`, `<empty>` → **App** sinh (route không có)
- `Server: openresty` → **Ingress NGINX** default backend

### Lệnh debug

**Debug 502** (tìm tầng target):

```bash
# 1. Pod Running + Ready?
kubectl get pod -l app=users-api -n dev

# 2. Pod KHÔNG Ready → describe xem readinessProbe
kubectl describe pod -l app=users-api -n dev | grep -A 5 "Conditions\|Events"

# 3. Endpoints có IP?
kubectl get endpoints users-api -n dev

# 4. Target health từ AWS
aws elbv2 describe-target-health \
  --target-group-arn $(kubectl get ingress users-api -n dev -o json \
    | jq -r '.metadata.annotations."alb.ingress.kubernetes.io/target-group-arn"')

# 5. App có chết?
kubectl logs -l app=users-api -n dev --tail=50
```

**Debug 404** (tìm tầng route):

```bash
# 1. Server header — biết ALB hay App trả
curl -v -I https://users.shopxpress-pro.do2602.click/api/v1/users 2>&1 | grep -i "server\|http/"

# 2. Ingress rules có match path?
kubectl get ingress users-api -n dev -o yaml | grep -A 20 "rules:"

# 3. Nếu Ingress OK → app log
kubectl logs -l app=users-api -n dev --tail=20 | grep -i "users\|404"
```

### Senior pattern dễ nhớ

- **502/503/504** = infrastructure layer (ALB ↔ Target ↔ Pod) → debug target group + pod readiness
- **4xx** = application layer (route, auth, validation) → debug Ingress rules + app code
- Header `Server:` = telescope chỉ thẳng tầng sinh response

---

## 📚 Câu 10 [SENIOR] — System Design e-commerce 10K rps (DEMO)

> **Status**: PARTIAL demo — đi hết Step 1 (CLARIFY) + Step 2 (ESTIMATE) đến Tính 3 (DB IOPS + cache insight). Step 3-5 (Design / Deep Dive / Trade-off CEO) **chưa demo**, hẹn session sau khi user vững Step 1-2.

### Câu hỏi gốc

> Em là tech lead. CEO yêu cầu launch site flash sale **12.12** next month. Hiện tại site multi-AZ Singapore, peak 1K rps avg. Đợt 12.12 dự kiến **peak 10K rps** trong 2h. Em design như nào? Multi-AZ scale lên có đủ chưa, hay phải multi-region? Cost vs SLA trade-off thế nào?

### User context

User chưa từng làm system design → yêu cầu em demo + dạy framework "tính toán làm sao".

---

### Framework RESHADED — 5 step cho 45 phút interview

| Step | Tên | Thời gian | Mục tiêu |
|---|---|---|---|
| 1 | **CLARIFY** | 5 min | Hỏi requirements (FR + NFR) — KHÔNG nhảy vào design ngay |
| 2 | **ESTIMATE** | 10 min | Tính capacity: traffic, compute, DB, cache, BW |
| 3 | **DESIGN** | 15 min | Boxes & arrows architecture cấp cao |
| 4 | **DEEP DIVE** | 10 min | Bottleneck + scaling pattern |
| 5 | **TRADE-OFF** | 5 min | Trả lời CEO: multi-AZ vs multi-region |

**Vàng**: Senior fail thường vì **bỏ qua Step 1 CLARIFY** → design dựa trên giả định sai. Hỏi requirements trước = signal cho interviewer "anh có suy nghĩ production".

---

### Step 1 — CLARIFY (5 phút)

**FR (Functional Requirements)** — chức năng PHẢI có:
1. Browse product (catalog read)
2. Add to cart
3. Checkout (payment + order)
4. Order tracking
5. (Optional) review, recommendation

**NFR (Non-Functional Requirements)** — chất lượng:
6. Peak rps + ratio peak/avg
7. Latency P95/P99
8. SLA, RPO, RTO

**Đáp án giả định cho 12.12 flash sale**:

| NFR | Giá trị | Ý nghĩa |
|---|---|---|
| Peak rps | **10K rps** (avg 1K, ratio **10x**) | Flash sale concentrate mua trong 2h |
| Read:Write | **95:5** | Browse > checkout (typical e-commerce) |
| P95 latency | < **300ms** browse, < **1s** checkout | 95% request dưới ngưỡng |
| SLA | **99.95%** toàn site, checkout ưu tiên hơn | Downtime ≤4.38h/năm |
| RPO order | **= 0** | Mất 1 đơn = mất tiền + uy tín |

---

### Step 1.5 — Giải thích thuật ngữ (user push back)

**Peak rps**
> Peak = đỉnh trong khoảng thời gian ngắn (giây/phút). Avg = trung bình cả ngày. Ratio peak/avg quyết định bạn provision theo đâu. Flash sale ratio 10x = phải scale cho 10K dù avg chỉ 1K, nếu không sập.

**P95 latency < 300ms**
> 95% request trả về dưới 300ms. KHÔNG dùng avg vì avg ẩn long-tail. Ví dụ: 95 request 100ms + 5 request 5s → avg 345ms (đẹp), nhưng P95 là 5s → 5% user thấy chậm.
>
> Long-tail nguyên nhân: GC pause Java, DB lock contention, TCP retransmit, cold start.

**SLA "số 9"** (Senior phải thuộc):

| SLA | Downtime/năm |
|---|---|
| 99% | 3.65 ngày |
| 99.9% (three 9) | 8.76 giờ |
| **99.95%** | 4.38 giờ |
| 99.99% (four 9) | 52 phút |
| 99.999% (five 9) | 5.26 phút |

**SLA chuỗi** (weakest link):
```
5 service × SLA 99.9% mỗi cái
Site SLA = 0.999^5 = 0.995 = 99.5%
→ Mất 0.4% chỉ vì có nhiều service nối tiếp
```
→ Decouple critical path: checkout chỉ phụ thuộc 2 service (auth + payment), không 5.

**RPO = Recovery Point Objective**
> Mất tối đa bao nhiêu phút data khi disaster. RPO = 0 = sync replication (Aurora multi-AZ commit cả 2 AZ trước khi return).
> RPO = 5 phút = async backup (snapshot 5 phút/lần).

**RTO = Recovery Time Objective**: bao lâu để khôi phục. RTO 30 phút = chấp nhận sập 30 phút.

**100K SKU**: 100,000 sản phẩm (Stock Keeping Unit) trong catalog.

---

### Step 2 — ESTIMATE (10 phút)

#### Strategy khi không có production number

User push back: *"mấy con số đó chưa làm bao giờ lấy đâu ra mà tính"*.

3 cách defend Senior:

1. **Hỏi interviewer back**: "anh có production metric không, hay em assume?" — signal có suy nghĩ data-driven.
2. **Memorize 5 anchor numbers** (thuộc lòng):

| Resource | Anchor |
|---|---|
| 1 pod Go/Java tuned | **~500 rps** (P95 < 300ms) |
| 1 vCPU general workload | **~1K rps** |
| Aurora MySQL OLTP | **~3K query/s** baseline |
| Redis ElastiCache | **~100K ops/s** per shard |
| Kafka 1 broker | **~100MB/s** throughput |

3. **Defend by approach**: "em sẽ benchmark trong staging với k6/locust, đo P95 tại CPU 60%, chia 1.5 lấy số an toàn".

**Câu nói vàng trong interview**:
> "Em assume X dựa trên Y (Pareto / industry benchmark / anchor number), sẽ verify bằng Z (k6 load test / production metric / Grafana)."

---

#### Tính 1 — Traffic Split

```
Peak = 10,000 rps
Read:Write = 95:5
  → Read  = 9,500 rps
  → Write =   500 rps
```

**Defend "tại sao tính peak chứ không avg?"**:
> Capacity phải gánh peak. Nếu provision theo avg 1K → flash sale peak 10K sập 9 phút đầu tiên. Production = peak × buffer 50%.

**Defend "traffic chỉ Read/Write thôi?"**:
> Đây là **traffic layer** (HTTP request). Số user (DAU) đếm ở **business layer** (DAU/MAU 20-40%, peak concurrent 5-15% DAU, 0.1-0.5 req/s/user). Compute đếm ở **infrastructure layer** (pod, node, IOPS).

---

#### Tính 2 — Compute

```
1 pod Go/Java tuned ~ 500 rps (P95 < 300ms)
Tổng rps = 10,000
Số pod = 10,000 / 500 = 20 pod
+ Buffer 50% HA + scale headroom = 30 pod
```

**Vì sao 500 rps/pod?** — anchor industry: Go binary native + DB pool tuned + sidecar nhẹ. Java Spring Boot thường ~200-300 rps. Python Flask gunicorn ~100 rps.

**Vì sao +50% buffer?**
- Multi-AZ: 1 AZ chết, AZ kia phải gánh full
- HPA scale-out chậm 30-60s, cần headroom
- Pod restart, deploy rolling

```
1 node c6i.large (2 vCPU, 4GB):
  - Net usable: 1800m CPU + 3.5Gi RAM (sau OS + kubelet + system pod)
  - Chứa ~6 pod tuned (requests 250m + 512Mi)
Số node = 30 / 6 = 5 node
× 2 multi-AZ (mỗi AZ tự đủ tải) = 10 node tổng
```

**Vì sao 6 pod/node?** Phụ thuộc requests:

| Pod size | Pod/node | Khi nào |
|---|---|---|
| Nặng (500m + 512Mi) | 3 | Java heap 1Gi |
| **Trung bình (250m + 512Mi)** | **6** ← em dùng | Go tuned |
| Nhẹ (100m + 128Mi) | 15-20 | Microservice nhỏ (limit max-pods ENI: 29 default, 110 prefix delegation) |

**Output Compute**:
```
EKS Managed Nodegroup:
- Instance: c6i.large
- Peak: 10 node (ASG max)
- Baseline: 3-4 node (avg 1K rps)
- HPA pod theo CPU > 60% (KHÔNG 80% — scale delay 30-60s cần headroom)
- Karpenter spawn EC2 60-90s
```

**HPA tại sao 60% không 80%?**
> 80% = đã muộn. Khi HPA detect → tạo pod → schedule → image pull → Ready = 30-60s. Trong 60s đó CPU đã lên 100% → request queue đầy → P95 nổ.
> 60% = sớm 20% biên độ → khi Ready CPU vừa qua 80%, headroom kịp.

**Karpenter vs Cluster Autoscaler**:
- HPA scale **pod** trước (sec)
- Pod pending vì hết node → Karpenter spawn **EC2 mới** (60-90s) — chọn instance type tối ưu theo workload
- CA cũ scale theo ASG fix instance type → đắt hơn 20-30% và chậm hơn

**Defend "tại sao 10 node mà không 5?"**:
> 5 node là math thuần. Production em ×2 multi-AZ — 1 AZ chết phải còn AZ kia tự gánh full peak. ×2 là chi phí HA bắt buộc, không phải over-provision.

---

#### Tính 3 — DB IOPS

**Confuse thường gặp**: Read:Write 95:5 ở traffic layer ≠ DB query.

| Lớp | Đơn vị | Ai gánh |
|---|---|---|
| Traffic 10K rps | HTTP request | Pod app |
| DB IOPS | Query SQL | RDS/Aurora |

Trên đường đi có **cache** (CDN, Redis) chặn lại → cache hit không đụng DB.

**Bước 1 — Cache hit ratio**:
```
Cache hit giả định 80% (Pareto e-commerce, Pareto 80/20 SKU)
  → 9,500 × 0.80 = 7,600 rps cache trả về (KHÔNG đụng DB)
  → 9,500 × 0.20 = 1,900 rps cache MISS → đụng DB
```

**80/20 lấy ở đâu?** — 3 nguồn:
1. **Pareto 80/20**: 20% SKU hot (best-seller, flash sale) sinh 80% read traffic
2. **Industry benchmark**: Shopify/Amazon/Lazada report cache hit browse page 75-90%
3. **Anchor numbers**: e-commerce **80%**, social feed **95%**, search **30-40%**

**Defend khi interviewer probe "sao 80% không 50%?"**:
> "Em assume read-heavy e-commerce với catalog stable, hot SKU sit trong Redis TTL 5-10 phút. Em verify bằng `redis-cli info stats` → `keyspace_hits/(hits+misses)` sau go-live tuần đầu. Nếu chỉ 50% → cache không đủ hot key (tăng RAM) / TTL ngắn (kéo lên) / thundering herd."

**Bước 2 — Query DB thực**:
```
Read miss   = 1,900 query/s
Write       =   500 query/s  (write KHÔNG cache, replicate luôn DB)
─────────────────────────────
Tổng        = 2,400 query/s
```

**Bước 3 — IOPS**:
```
1 query OLTP ~ 2 IOPS (avg: index lookup + row read + WAL)
Peak IOPS = 2,400 × 2 = 4,800
+ 50% buffer (replication lag, vacuum) = ~7,200 IOPS
```

**Bước 4 — Chọn DB**:
```
Aurora MySQL db.r6g.large:
- 2 vCPU, 16GB RAM
- Connection pool: 1,000
- IOPS auto-scale theo storage, baseline 3K burst 12K
- Storage Aurora separate compute (auto-extend 128TB)
→ Peak 7,200 IOPS nằm trong burst ✅

Topology:
- 1 writer + 2 read replica (multi-AZ)
- 2 replica chia 1,900 read miss = 950 query/s mỗi replica
- Failover tự động <30s
- Checkout PHẢI đọc writer (read-after-write consistency)
```

**Defend "tại sao r6g chứ không r5/r6i?"**:
> r6g = Graviton ARM, rẻ hơn x86 ~20%, perf tương đương cho OLTP MySQL. Non-Windows DB em default r6g. Oracle/MSSQL license bắt x86 mới r6i.

**Defend "tại sao 2 read replica?"**:
> 1 replica fail thì replica còn lại gánh đủ 1,900 read. Nếu chỉ 1 → mất là sập tải read.

**Cảnh báo trade-off (Senior khoe)**:
> Cache hit 80% là **giả định**. Nếu thực tế chỉ 50% → DB ăn 5,250 query/s × 2 = 10,500 IOPS → phải lên r6g.xlarge hoặc shard. "Rút dây động rừng": cache hit % → DB instance → cost → SLA.

---

#### Insight Cache hit/miss (vàng nhất Step 2)

**7,600 rps cache hit — insight**:

- Redis trả lời **1-5ms** (RAM lookup). DB **KHÔNG biết** những request này tồn tại.
- Cache là **shock absorber**: Aurora db.r6g.large OLTP chịu **~3K query/s** tối đa. KHÔNG cache → 9,500 query/s đập DB → CPU 100% → timeout → sập site.
- **Money math**: cache đỡ 80% → tiết kiệm **~$4,000-5,000/tháng** (so với scale DB lên 5x).
- 80% user thấy site "nhanh" (2ms), chỉ 20% chịu chậm (30ms DB query).

**1,900 rps cache miss — health metric**:

3 lý do gây miss:
1. **TTL hết hạn** — sản phẩm cache 5 phút (bình thường)
2. **Key chưa từng cache** — long-tail SKU (80% SKU ít người xem)
3. **Cache evict** — Redis hết RAM, đẩy key cũ ra (cảnh báo)

**Health check**:
- Miss rate **15-25%** = healthy
- Miss rate **>40%** = cache too small, hot set không fit
- Miss rate **<5%** = TTL quá dài, data stale risk

**Risk Thundering Herd**:
> Nếu 1 key hot expired đồng thời, 10K request cùng miss → 10K request đập DB cùng lúc → DB sập.
> Mitigation: **singleflight pattern** (1 request đi DB, 9,999 chờ) hoặc **probabilistic early expiration**.

**Câu Senior nói trong interview**:
> "Cache hit ratio không chỉ là performance — **nó quyết định kiến trúc DB**. 80% hit → 1 cluster r6g.large. 50% hit → phải 4 cluster shard. Đây là **đòn bẩy lớn nhất** trong system design e-commerce."

---

### Step 3-5 — chưa demo (hẹn session sau)

| Step | Nội dung kế hoạch |
|---|---|
| **3 DESIGN** | CloudFront → ALB → EKS (3 NS dev/stg/prd) → SQS async checkout → Aurora + ElastiCache Redis. Vẽ boxes & arrows numbered |
| **4 DEEP DIVE** | Idempotency key checkout (mất tiền nếu retry kép), SQS DLQ, sharding khi >50K rps, circuit breaker, rate limit |
| **5 TRADE-OFF** | Multi-AZ Singapore ($X/month, SLA 99.95%, RTO 30min) vs Multi-region Sin+Tokyo ($3X, SLA 99.99%, RTO 5min). Trả lời CEO: "12.12 dùng multi-AZ + pre-warm 30 phút, multi-region để sau quý sau khi traffic 30K rps" |

---

### Insight session (cho user đọc lại)

User chưa làm system design bao giờ → cần học **4 thứ**:

1. **Framework có sẵn** (RESHADED) — không nghĩ random, đi theo step
2. **Anchor numbers** — thuộc 5 số để self-defend khi probe
3. **Pattern interview**: "em assume X dựa Y, verify bằng Z" — signal data-driven
4. **Rút dây động rừng**: 1 con số đổi → cascade nhiều thứ
   - Cache hit % → DB instance → cost → SLA chuỗi
   - Pod rps → node count → multi-AZ → instance family
   - SLA × số service = SLA chuỗi (weakest link)

**Câu nói vàng kết Step 2**:
> "Capacity estimate là **hypothesis**, không phải fact. Em assume dựa anchor industry, sẽ verify bằng staging benchmark + production metric tuần đầu. Nếu sai → recalculate cascade ngay."

---

## 🎯 Câu sắp tới (NEXT)

### Câu 4 [MID+] — Pod OOMKilled

> Pod app `orders-prd` đang chạy ổn 2 tuần. Đêm qua deploy version mới, sáng anh thấy pod restart 12 lần, `RESTARTS=12`. `kubectl describe` thấy `Last State: Terminated, Reason: OOMKilled, Exit Code: 137`. Anh:
>
> 1. Tăng `resources.limits.memory` cho qua, hay tìm memory leak?
> 2. Trade-off mỗi cách?
> 3. Lệnh anh gõ trong 5 phút đầu để quyết định?

→ Câu này test trade-off senior + tooling profiling (`kubectl top`, container metrics, heap dump).

---

## 🧹 Cleanup pending

Pod giả lập còn live trên cluster (đến khi user delete):

```bash
kubectl delete pod crash-demo net-debug -n dev
```

---

## 🔁 Resume protocol

Khi Claude (em) đọc lại file này ở session sau:
1. Đọc tới Câu nào DONE ở section "Tiến độ session" → tiếp Câu kế.
2. Áp đúng level label `[MID]` / `[MID+]` / `[SENIOR]` ở mỗi câu mới.
3. Pattern: em đưa câu hỏi → user trả lời → em probe → chấm + ref Senior 5+ answer.
4. KHÔNG em tự chạy `kubectl` thay user trong context teaching debug — đưa lệnh, user gõ, paste output.
5. File update sau mỗi 2-3 câu mới (commit + push).
