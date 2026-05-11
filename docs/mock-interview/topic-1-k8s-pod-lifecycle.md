# Topic 1 — K8s Pod Lifecycle (D1, 2026-05-11)

> **Mục đích**: 5 câu Q&A căn bản về vòng đời Pod, dùng để ôn phỏng vấn DevOps/SRE Senior 5+.
> **Cách ôn**: đọc câu hỏi → tự trả lời ra giấy/miệng → so với "Senior answer" → đọc "Anchor" để khắc sâu.

---

## Q1 [MID] — 5 phase của Pod khác nhau như nào?

### Câu hỏi
Pod trong K8s có **5 phase**: `Pending` / `Running` / `Succeeded` / `Failed` / `Unknown`.
Mỗi phase nghĩa là gì? **State transition** giữa chúng ra sao?

### Senior answer

| Phase | Nghĩa |
|---|---|
| **Pending** | Pod đã được API server accept nhưng **chưa chạy được**: chưa bind node, hoặc đang pull image, hoặc chưa init xong. |
| **Running** | Pod đã bind node, **ít nhất 1 container đang chạy** (hoặc đang start/restart). |
| **Succeeded** | **TẤT CẢ container đã terminate với exit 0**, không restart nữa. Chỉ áp Job/CronJob/batch. Web app `nginx` không bao giờ vào phase này. |
| **Failed** | Tất cả container đã terminate, **≥1 cái exit non-zero** hoặc bị system kill. App đã CHẠY rồi chết, KHÔNG phải "tạo không được". |
| **Unknown** | Kubelet **mất liên lạc** control plane (node NotReady, network partition). Lỗi infra/node, không phải lỗi Pod. |

### State transition đúng

```
Pending  → Running  → Succeeded   (Job xong, exit 0)
Pending  → Running  → Failed      (Job chết, exit ≠ 0, restartPolicy=Never)
Pending  → Failed   (rare: container chạy được nhưng exit ngay, Never)
Running  → Unknown  (PHỔ BIẾN: node die khi pod đang chạy)
```

### Anchor để nhớ

> **Succeeded / Failed = về VIỆC CONTAINER CHẠY (exit code)**
> **KHÔNG phải về VIỆC PULL IMAGE**
> Pull image lỗi → vẫn **Pending** (status `ImagePullBackOff`), KHÔNG phải Failed.

### Bẫy phỏng vấn thường gặp

- "Image pull lỗi mãi không được, Pod ở phase nào?" → **Pending** với reason `ImagePullBackOff`/`ErrImagePull`, KHÔNG phải Failed.
- "Container OOM, exit 137, restartPolicy=Always, Pod ở phase nào?" → **Running** (vì K8s restart liên tục), reason `CrashLoopBackOff`.
- "Node mất điện, pod đang chạy trên node đó, Pod ở phase nào?" → **Unknown** sau ~40s, sau đó controller có thể delete và tạo pod mới ở node khác.

### STAR hook Lab A++

Vụ **muoidv MNG nightly scaledown 1/1/1** (2026-05-08): khi MNG về 1 node, pod `sample-app` ở AZ-b stuck **Pending** vì PVC bind ở AZ khác → scheduler không bind được node phù hợp. Đây là Pending vì **failed scheduling**, không phải "đang starting".

---

## Q2 [MID] — Init container vs Sidecar container khác gì?

### Câu hỏi
1. **Chạy lúc nào** mỗi cái?
2. **Sống bao lâu** mỗi cái?
3. **Dùng để làm gì** (1-2 ví dụ cụ thể)?
4. Nếu **init fail** thì Pod thế nào? Nếu **sidecar chết** thì main app có chết không?

### Senior answer

#### Init container

- Chạy **TRƯỚC** main container, **TUẦN TỰ** từng cái (init-1 → init-2 → ... → main).
- Mỗi init phải `exit 0` thì cái kế tiếp + main mới chạy.
- Xong là **biến mất** (terminate), KHÔNG sống cùng main.
- **Dùng để**: chờ DB ready, chạy migration DB, download cert/secret/config, chown volume.

**Analogy khách sạn**:
> Anh đặt phòng (main = anh). Trước khi anh vào: init-1 dọn phòng → init-2 trải drap → init-3 đặt nước → mỗi nhân viên xong việc rồi đi ra → sau đó anh (main) mới vào ở.

**Ví dụ YAML**:
```yaml
spec:
  initContainers:
    - name: wait-for-db
      image: busybox
      command: ['sh','-c','until nc -z mysql 3306; do sleep 2; done']
    - name: download-config
      image: amazon/aws-cli
      command: ['aws','s3','cp','s3://bucket/cfg','/etc/app/']
  containers:
    - name: api
      image: my-api:v1
```

#### Sidecar container

- Chạy **SONG SONG** main, **SUỐT ĐỜI Pod** (cùng start, cùng stop).
- **Share network** với main → gọi nhau qua `localhost:port` (cùng IP Pod).
- **Share volume** nếu mount cùng → main ghi file, sidecar đọc file đó.
- **Dùng để**: log shipper (Fluent-bit), service mesh proxy (Envoy Istio/Linkerd), secret refresher (Vault agent), monitoring agent (DataDog APM).

**Analogy khách sạn**:
> Sidecar = nhân viên đứng trong phòng SUỐT đêm. Anh ngủ (main running) → sidecar pha cà phê sẵn (log shipper). Anh check-out → sidecar cũng nghỉ cùng lúc.

**Native sidecar K8s 1.28+** (cluster `shopxpress-pro-nonprd-eks` v1.34 có): là **init container với `restartPolicy: Always`** → start TRƯỚC main, chạy SONG SONG, stop SAU main → fix bug cũ "Istio Envoy chết trước main → main không gửi log/trace được khi shutdown".

### So sánh

| | Init | Sidecar |
|---|---|---|
| Chạy lúc nào | **Trước** main | **Cùng** main |
| Sống bao lâu | Xong là **biến mất** | **Suốt đời** Pod |
| Pod chết thì sao | Đã chết từ lâu | Chết cùng main |
| Dùng để | **Chuẩn bị** (dọn phòng) | **Phục vụ liên tục** (pha cà phê) |
| Ví dụ | DB migration, download cert | Log shipper, Envoy proxy |

### Init fail → Pod ra sao?

- Init exit ≠ 0 → K8s **restart init** theo `restartPolicy` (default `Always`) → Pod kẹt ở phase **`Init:CrashLoopBackOff`** hoặc **`Init:Error`**, KHÔNG phải Pod `Failed` luôn.
- Chỉ khi `restartPolicy=Never` → init fail mới đẩy Pod sang `Failed`.

### Sidecar chết → main có chết không?

❌ **SAI lầm phổ biến**: "Sidecar chết → main chết theo".
✅ **Đúng**: Sidecar chết → K8s **restart sidecar** thôi, main **VẪN CHẠY** bình thường.
✅ Hậu quả: chỉ mất **chức năng phụ trợ tạm thời** trong lúc sidecar đang restart (log không ship → mất log; Envoy chết → traffic không qua mTLS).
✅ Exception: nếu main **gọi sidecar qua `localhost`** (như Envoy) và sidecar chết → request main fail → main có thể fail readiness probe → bị remove khỏi Service Endpoint, **nhưng main process VẪN CHẠY**.

### Anchor để nhớ

> **Init = chuẩn bị TRƯỚC** (dọn phòng), xong là **biến mất**.
> **Sidecar = phục vụ SUỐT ĐỜI** (pha cà phê), chết cùng main.
> **Sidecar chết KHÔNG kéo main chết.** K8s restart sidecar độc lập.

### STAR hook Lab A++

- **Init container thật**: `kube-prometheus-stack` Grafana có init `init-chown-data` chown PVC trước khi Grafana start (Buổi 10 Observability).
- **Sidecar mindset**: ESO ExternalSecret controller + cert-manager sống cùng workload, sync state liên tục.

---

## Q3 [MID+] — `terminationGracePeriodSeconds` default 30s, khi nào tăng/giảm?

### Câu hỏi
Khi `kubectl delete pod` hoặc Pod bị evict, K8s cho Pod 1 khoảng "shutdown êm" = `terminationGracePeriodSeconds`, default 30s.
1. Trong 30s đó K8s làm gì?
2. Khi nào TĂNG (60s, 120s, 300s)?
3. Khi nào GIẢM (< 30s)?

### Senior answer

#### Flow 30s grace period

```
0s  [kubectl delete pod / rolling update / eviction]
    ├─ API server set deletionTimestamp
    ├─ Pod bị xoá khỏi Service Endpoint
    │   → load balancer NGỪNG gửi request mới vào pod  ⚠️ quan trọng
    └─ K8s gửi SIGTERM vào PID 1 container
         (signal "tự chết êm đi")

0s → 30s  [grace period]
    Container có 30s để TỰ DỌN DẸP:
    - Stop nhận request mới
    - Hoàn tất in-flight request (drain TCP connection)
    - Close DB connection, flush log buffer
    - Save state, ack pending message queue
    - exit 0 (chết êm)

30s [hết grace]
    Nếu container CHƯA chết → K8s gửi SIGKILL
    → kill tức thì, KHÔNG refuse được → MẤT DATA trong RAM
```

#### Khi nào TĂNG

1. **Long-running request** — upload file lớn, video processing, batch report → tăng **300-600s**.
2. **Stateful workload** — PostgreSQL flush WAL, Redis save dump, Kafka commit offset → **120-300s**.
3. **Message queue consumer** — cần ack message đang xử lý trước khi chết → **60-120s**.
4. **gRPC streaming** — long-lived stream cần đóng êm.

#### Khi nào GIẢM

1. **Stateless API ngắn** (request < 1s) → giảm **5-10s** để rolling update nhanh.
2. **Pod đã hang/deadlock** → không đợi, kill nhanh.
3. **CI runner tạm thời** — chạy xong xoá ngay.

### Anchor để nhớ

> Grace period **KHÔNG phải để cứu pod hay tăng tốc replacement**.
> Mà là **để pod tự dọn dẹp êm** trước khi chết: đóng connection, flush buffer, ack pending tasks → tránh **mất data + request rớt giữa chừng**.

### 2 chi tiết senior thường hỏi

- **`preStop` hook** = script chạy TRƯỚC SIGTERM. Pattern phổ biến: `sleep 10` để chờ load balancer hoàn toàn drain endpoint, sau đó app mới shutdown → tránh request 502.
- **PID 1 trap signal**: nhiều image dùng `node app.js` làm PID 1 nhưng Node KHÔNG handle SIGTERM mặc định → SIGTERM bị **ignore** → đợi 30s → SIGKILL. Fix: dùng `tini`/`dumb-init` làm PID 1, hoặc app code phải `process.on('SIGTERM', ...)`. Go thì dùng `signal.Notify(SIGTERM)`.

### STAR hook Lab A++

Buổi 0.7.6 ArgoCD rolling update `hello-shopxpress` v3 → pod cũ nhận SIGTERM → drain 30s pending HTTP request → bot bump-tag curl liên tục **không gặp 502 nào** → user không thấy downtime. Đó là **grace period đang hoạt động** thật trong lab.

---

## Q4 [MID] — `restartPolicy` Always / OnFailure / Never apply khi nào?

### Câu hỏi
1. Mỗi giá trị nghĩa là gì?
2. Workload nào dùng cái nào (ví dụ cụ thể)?
3. Controller K8s (Deployment, Job, CronJob) ép buộc `restartPolicy` nào?

### Senior answer

#### 3 giá trị

**1. `Always` (default)**
- Container chết → K8s restart **LUÔN**, bất kể exit 0 hay exit ≠ 0.
- Dùng cho: **web/API/frontend long-running** (nginx, Node, Java, Go) — chạy mãi mãi, chết = bất thường → restart.
- Restart fail liên tục → phase **`CrashLoopBackOff`** (K8s delay 10s → 20s → 40s → ... max 5 phút).

**2. `OnFailure`**
- Exit 0 → KHÔNG restart (coi như xong việc thành công).
- Exit ≠ 0 → restart.
- Dùng cho: **Job/CronJob batch task** — migration DB, backup, daily report, ETL.

**3. `Never`**
- Container chết bất kể exit code → **KHÔNG restart**.
- Pod vào phase `Succeeded` (exit 0) hoặc `Failed` (exit ≠ 0).
- Dùng cho: **debug Pod** (kubectl run -it), **one-shot không retry**, **batch fail = stop để xem log**.

#### Controller ÉP BUỘC `restartPolicy` nào?

| Controller | Cho phép | Mặc định |
|---|---|---|
| **Deployment / StatefulSet / DaemonSet / ReplicaSet** | **CHỈ** `Always` | `Always` |
| **Job** | `OnFailure` hoặc `Never` (KHÔNG `Always`) | `Never` |
| **CronJob** | `OnFailure` hoặc `Never` | `Never` |
| **Bare Pod** (kubectl run) | Cả 3 | `Always` |

⚠️ Viết `Deployment` với `restartPolicy: Never` → K8s **reject** YAML:
```
Unsupported value: "Never": supported values: "Always"
```

### Anchor để nhớ

> **Always** = chạy mãi (web/API)
> **OnFailure** = retry khi lỗi (batch Job)
> **Never** = chạy 1 lần thôi (debug, one-shot)

### STAR hook Lab A++

- **Deployment `hello-shopxpress`** (Buổi 0.7.6) — `restartPolicy: Always` mặc định → khi pod OOM, K8s tự restart, anh không can thiệp tay.
- **GitHub Actions `build-push.yml`** (Buổi 0.7.4) — bản chất giống `Never`: chạy 1 lần, fail thì show red badge để dev xem log.
- **CronJob ECR cleanup** — nếu chuyển thành K8s Job thật, đặt `OnFailure` vì network blip thì retry là ổn.

---

## Q5 [MID] — Exit code 0 / 1 / 137 / 139 / 143 đọc ra sao?

### Câu hỏi
Khi container chết, `kubectl describe pod` ghi exit code. Đọc exit code = **chẩn đoán nguyên nhân chết** mà không cần đọc log dài.
5 exit code quan trọng nhất, mỗi cái nghĩa là gì, ai gây ra (app tự exit / K8s kill / kernel kill)?

### Senior answer

#### Quy tắc đọc exit code (Linux convention)

```
0       → App TỰ exit thành công
1-127   → App TỰ exit với lỗi (do code)
128+N   → Process bị KILL bởi SIGNAL N

→ 128 + 9  = 137  (SIGKILL)
→ 128 + 11 = 139  (SIGSEGV)
→ 128 + 15 = 143  (SIGTERM)
```

#### 5 exit code quan trọng nhất

| Code | Tên | Ai gây | Nghĩa thực tế | Cách fix |
|---|---|---|---|---|
| **0** | Success | App tự | Chạy xong OK. Job → `Succeeded`. Web app exit 0 → bất thường. | Check entrypoint nếu web app exit 0. |
| **1** | Generic error | App tự | Code lỗi không xử lý: config missing, env var thiếu, DB không connect, panic. | `kubectl logs <pod>` để xem log app. |
| **137** | SIGKILL | **OOM killer** (kernel) hoặc K8s force kill | **PHỔ BIẾN NHẤT** = pod xài quá `resources.limits.memory` → kernel OOM kill. | Tăng memory limits, fix memory leak, tune JVM `-Xmx`. |
| **139** | SIGSEGV | Kernel | Segfault — process truy cập memory không hợp lệ. Bug C/C++/Go cgo/Java JNI/native lib. | Core dump + GDB. Hiếm gặp app pure Go/Java/Python/Node. |
| **143** | SIGTERM | **K8s** | K8s gửi SIGTERM lúc `kubectl delete` / rolling update / eviction. App KHÔNG trap signal → Linux default → exit 143. | Thường KHÔNG cần fix. Nên trap SIGTERM trong app để cleanup → exit 0. |

### Workflow debug khi thấy exit code

```bash
kubectl describe pod <pod>
# Last State: Terminated
#   Reason: OOMKilled       ← chìa khoá vàng
#   Exit Code: 137
```

- Thấy `OOMKilled` → 100% là exit 137 vì memory.
- `Reason: Error` + Exit Code 1 → app tự fail → xem log.
- `Reason: Completed` + Exit Code 0 → bình thường (Job xong).

### Anchor để nhớ

> **0** = OK ✅
> **1** = code lỗi → xem log
> **137** = bị kill cứng → **OOM** 99% lần
> **139** = segfault → bug nặng (hiếm)
> **143** = K8s shutdown êm

### STAR hook Lab A++

- **Buổi 0.7.6** — nếu `hello-shopxpress` Go app đặt `limits.memory: 64Mi` quá thấp khi tải lớn → **OOMKilled exit 137** → `kubectl describe` thấy reason → tăng lên 128Mi.
- **Buổi 0.7.7 ApplicationSet rolling update** — pod cũ nhận SIGTERM trong grace 30s → nếu app trap (Go `signal.Notify`) → exit 0; nếu không → exit 143.
- **muoidv MNG nightly scaledown** — pod bị evict → SIGTERM → nếu pod hang → SIGKILL sau 30s → exit 137 (do K8s force, không phải OOM).

---

## Tổng kết D1 — Self-check checklist

- [ ] Tôi đọc được 5 phase Pod và state transition cơ bản.
- [ ] Tôi phân biệt được Init container vs Sidecar (chạy lúc nào, sống bao lâu, dùng để gì).
- [ ] Tôi nhớ `Succeeded/Failed = về exit code, KHÔNG phải image pull`.
- [ ] Tôi giải thích được flow 30s grace period (SIGTERM → drain → SIGKILL).
- [ ] Tôi biết controller nào ép `restartPolicy` nào (Deployment=Always, Job=OnFailure/Never).
- [ ] Tôi đọc exit code 137 = OOMKilled, 143 = SIGTERM, 1 = code error.
- [ ] Tôi có ít nhất 1 STAR hook Lab A++ cho mỗi câu trên.

**Next**: D2 — Service & Networking (Q6-Q10): ClusterIP/NodePort/LoadBalancer, kube-proxy iptables vs IPVS, Endpoint vs EndpointSlice, DNS resolution, headless service.
