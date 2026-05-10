# Mock Interview — DevOps/SRE Senior 5+

> **Mục tiêu**: luyện phỏng vấn vị trí DevOps/SRE Senior 5+ ($1500-2500 range), dùng Lab A++ ShopXpress-Pro làm STAR portfolio.
>
> **Pivot**: 2026-05-10 — sau khi đóng Buổi 0.7.9 DORA, chuyển sang khai thác sâu Sub-comp 0..9 + 0.7.x đã build thay vì tiếp Phase 1 Security.

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
| Fri | 10 | [SENIOR] | **System design**: e-commerce 10K rps multi-AZ vs multi-region |
| ... | 11-17 | mix | rải các trục HA / CI-CD speed / trade-off |

**Quy tắc đánh giá**:
- Mid = thao tác cụ thể, không yêu cầu trade-off đa chiều
- Mid+ = 1 lớp probe "vì sao không Y", có edge case
- Senior = trade-off đa chiều, scale, business impact, blast radius, escalate

---

## ✅ Tiến độ session 2026-05-10

Đã đi: **3 câu** ([MID]×2 + [MID+]×1).

### Tổng chấm điểm baseline

| Câu | Level đề | Level user trả lời | Gap chính |
|---|---|---|---|
| 1 | [MID] | Teaching mode (chưa kinh nghiệm) | Chưa từng debug K8s thực |
| 2 | [MID] | Junior+ | Reflex network OK, **chưa nắm Service ↔ Endpoints** + ClusterIP VIP ảo |
| 3 | [MID+] | Junior | **502 layer sai** (tưởng routing, thật ra target group); chưa biết đọc header `Server:` |

→ **Gap chung**: hiểu fundamental K8s networking (Service VIP ảo, Endpoints, kube-proxy, CoreDNS) — tầng này tách biệt với reflex sysadmin truyền thống.

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
