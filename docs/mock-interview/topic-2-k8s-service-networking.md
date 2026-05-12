# Topic 2 — K8s Service & Networking (D2, 2026-05-12)

> **Mục đích**: 5 câu Q&A căn bản về Service, ClusterIP, NodePort, LoadBalancer, kube-proxy, EndpointSlice, DNS, Headless. Ôn phỏng vấn DevOps/SRE Senior 5+.
> **Cách ôn**: đọc câu hỏi → tự trả lời → so "Senior answer" → đọc "Anchor" để khắc sâu.
> **Tiến độ**: 5/5 DONE (2026-05-12)

---

## Q6 [MID] — ClusterIP / NodePort / LoadBalancer khác gì?

### Câu hỏi
3 type Service `ClusterIP`, `NodePort`, `LoadBalancer` khác nhau như nào? Mỗi cái dùng khi nào? Pod bên ngoài cluster có gọi được `ClusterIP` không?

### Senior answer

| Type | Có ClusterIP? | Có NodePort? | Cổng vào | Use case |
|---|---|---|---|---|
| **ClusterIP** (default) | ✓ | ✗ | Pod nội bộ gọi VIP | East-West pod-to-pod microservice |
| **NodePort** | ✓ | ✓ mở port 30000-32767 trên MỌI node | Client gõ `<NodeIP>:<NodePort>` | Dev/test, target cho LB Instance mode |
| **LoadBalancer** | ✓ | ✓ | Cloud LB managed (NLB/CLB) `<lb-dns>:port` | Prod expose ra Internet |
| **ExternalName** | ✗ | ✗ | DNS CNAME alias ngoài (RDS, S3) | Trỏ tên service nội bộ → service ngoài |
| **Headless** (`clusterIP: None`) | ✗ | ✗ | DNS trả thẳng N Pod IP | StatefulSet, gRPC client-side LB |

**Stack quan hệ**: `LoadBalancer ⊃ NodePort ⊃ ClusterIP` (LB type tạo luôn NodePort + ClusterIP bên dưới).

### Cơ chế ClusterIP

ClusterIP là **VIP ảo** — không nằm trên interface nào của node. Chỉ tồn tại dưới dạng **rule trong iptables/IPVS** của kube-proxy trên mỗi node. Khi pod gửi packet đến ClusterIP, kernel match rule → **DNAT** (Destination NAT) → rewrite đích thành Pod IP thật.

```
Pod A ──curl 10.96.10.5:80──> kernel node A match iptables rule
                              DNAT: 10.96.10.5:80 → 10.0.1.45:80
                              packet đi thẳng tới Pod B (không qua trung gian)
```

### Flow tạo Deployment + Service

1. Tạo Deployment 3 replica nginx → kubelet gọi CNI cấp Pod IP từ VPC subnet (vd 10.0.1.23, 10.0.2.45, 10.0.3.67).
2. Tạo Service `nginx-svc` selector `app=nginx` → API server cấp ClusterIP (vd 10.96.10.5).
3. **endpoints-controller** quét pod match label → tạo **EndpointSlice** liệt kê 3 Pod IP.
4. **kube-proxy** watch EndpointSlice → viết iptables rule trên mỗi node.
5. Pod client gọi `10.96.10.5:80` → kernel DNAT về 1 Pod IP.

### 2 đường data path (Lab A++ pattern)

```
              Internet
                  │
                  ▼
                ALB (IP mode, LBC quản)
                  │ round-robin TRỰC TIẾP Pod IP
        ┌─────────┼─────────┐
        ▼         ▼         ▼
    nginx-pod1 nginx-pod2 nginx-pod3
        ▲         ▲         ▲
        └─────────┼─────────┘
                  │ round-robin
          ClusterIP 10.96.20.5     ← Pod nội bộ gọi (East-West)
                  ▲
                  │ curl http://nginx-svc
            Pod khác trong cluster
```

- **External (North-South)**: Internet → ALB → Pod IP trực tiếp (bypass ClusterIP). ALB tự LB.
- **Internal (East-West)**: pod → ClusterIP → round-robin Pod IP. kube-proxy LB.

### Anchor để nhớ

> **ClusterIP = VIP ảo, không nằm trên dây mạng, chỉ là entry trong bảng rule iptables/IPVS**
> **Pod IP ≠ ClusterIP**: Pod IP do CNI cấp (thật trên ENI VPC), ClusterIP do API server cấp (ảo)
> **ALB IP mode bypass ClusterIP**: data path North-South không qua kube-proxy iptables
> **Service ↔ Pod nối qua LABEL SELECTOR, không phải reference trực tiếp**

### Bẫy phỏng vấn thường gặp

- "Pod ngoài cluster có gọi được ClusterIP không?" → **Không** (ClusterIP chỉ pod-to-pod trong cluster).
- "LoadBalancer round-robin bằng cách nào?" → ALB **tự LB** trực tiếp Pod IP (IP mode), KHÔNG qua ClusterIP. Đừng confuse "ALB gọi ClusterIP rồi ClusterIP LB".
- "NodePort mở port trên Pod hay trên Node?" → **Trên Node host** (kube-proxy mở), Pod chỉ listen container port của nó. Pod không biết NodePort tồn tại.
- "Service `type: LoadBalancer` không có annotation thì AWS tạo NLB hay CLB?" → **CLB** (Classic, qua in-tree CCM legacy). Muốn NLB qua LBC phải thêm `service.beta.kubernetes.io/aws-load-balancer-type: external`.

### AWS LBC — 2 mode TargetType

| | Instance mode | IP mode |
|---|---|---|
| **Target** | EC2 Node IP : NodePort | Pod IP trực tiếp |
| **Path** | LB → Node:NodePort → kube-proxy → Pod | LB → Pod (1 hop) |
| **Source IP** | Mất (SNAT bởi kube-proxy) | Giữ nguyên client IP |
| **CNI yêu cầu** | Bất kỳ | Pod IP routable từ VPC (vpc-cni OK, Calico overlay KHÔNG) |
| **Service type** | NodePort hoặc LoadBalancer | ClusterIP đủ |
| **Use case** | Legacy, CNI overlay | EKS prod default |

### STAR hook Lab A++

**Sub-comp 8 LBC IP mode (Lab A)**: ALB `shopxpress-public` (internet-facing) target type=IP, listener 80→443 redirect, listener 443 forward Pod IP của 3 service `gateway/products/orders` (qua EndpointSlice của Service ClusterIP). Smoke test `curl -I https://shopxpress.do2602.click` → HTTP 200, ~70ms latency. Bypass kube-proxy → giữ client IP nguyên (real_ip field log nginx).

**Vì sao chọn Ingress + ALB qua LBC thay Service `type: LoadBalancer`**: 1 ALB share nhiều service (argocd + grafana + sample-app) qua host routing → tiết kiệm chi phí ($20/tháng/LB → 1 LB cho cả Lab A). Nếu mỗi service 1 NLB → 10 service = $200/tháng nonprd.

---

## Q7 [MID+] — kube-proxy iptables mode vs IPVS mode khác gì?

### Câu hỏi
kube-proxy có 2 mode: **iptables** và **IPVS**. Khác nhau cốt lõi (cơ chế, performance, scale limit)? Khi nào nên chuyển từ iptables sang IPVS?

### Senior answer

**kube-proxy là gì**: DaemonSet chạy trên mỗi node, nhiệm vụ dịch **EndpointSlice** thành **rule trong kernel** để khi pod gọi ClusterIP thì kernel biết DNAT về Pod IP. kube-proxy **không nằm trên data path** — chỉ viết rule, kernel tự rewrite packet.

**Trigger**: kube-proxy watch **EndpointSlice**, KHÔNG phải Pod trực tiếp. Chuỗi:
1. Pod Ready (readiness probe PASS).
2. endpoints-controller thấy Pod match selector → cập nhật EndpointSlice.
3. kube-proxy watch EndpointSlice → viết rule.

→ Pod **có IP** nhưng **chưa Ready** → rule chưa được viết. Đây là cơ chế **health-gating** quan trọng.

### iptables mode (default)

Viết rule vào Netfilter (chain `KUBE-SERVICES` → `KUBE-SVC-XXX` → `KUBE-SEP-XXX`):

```
Packet đến ClusterIP 10.96.10.5
    ▼  Chain KUBE-SERVICES (match đích)
       → if dest=10.96.10.5 → jump KUBE-SVC-NGINX
    ▼  Chain KUBE-SVC-NGINX (chọn pod)
       → probability 33% → jump KUBE-SEP-POD1
       → probability 50% → jump KUBE-SEP-POD2  (50% của 67% còn lại)
       → else            → jump KUBE-SEP-POD3
    ▼  DNAT về 10.0.1.45:80
```

**Cách "load balance"**: dùng **xác suất statistic** trên rule. 3 pod → mỗi pod 1/3.

**Vấn đề scale**:
- Match **linear O(N)** — packet phải scan rule từ trên xuống.
- 5000 Service × 5 pod = 25,000 rule → kernel duyệt chậm.
- Update endpoint = rewrite cả chain (không append-only) → kube-proxy CPU spike khi cluster lớn deploy nhiều.

### IPVS mode

**IPVS = IP Virtual Server**, kernel module có sẵn Linux từ 2.x (dòng họ Netfilter, hook khác).

| | iptables | IPVS |
|---|---|---|
| Cấu trúc | Chuỗi linear list | **Hash table** |
| Lookup | **O(N)** | **O(1)** |
| Thuật toán LB | Random (probability) | rr, wrr, lc, sh, dh (chọn được) |
| CLI debug | `iptables -t nat -L` | `ipvsadm -Ln` |
| Update khi endpoint đổi | Rewrite chain (chậm) | Insert/delete entry nhanh |

**Thuật toán IPVS**:
- `rr` — round-robin (default)
- `wrr` — weighted round-robin (pod khoẻ nhận nhiều hơn)
- `lc` — least connection (tốt cho **gRPC long-lived**)
- `sh` — source hash (sticky theo client IP)
- `dh` — destination hash

**Lưu ý**: IPVS **không thay 100% iptables**. IPVS lo đường chính LB, iptables vẫn lo SNAT masquerade + NodePort hijack + drop rule.

### Khi nào chuyển iptables → IPVS

1. **Cluster lớn**: > 1000 Service hoặc > 5000 endpoint, CPU kube-proxy spike, latency tăng.
2. **Cần thuật toán LB khác round-robin**: gRPC long-lived cần `lc`, session affinity cần `sh`.
3. **Update endpoint quá thường xuyên** (CI/CD deploy liên tục) → iptables rewrite không kịp.

**KHÔNG cần chuyển** nếu cluster < 1000 Service (Lab A anh ~30 service → iptables thừa sức).

### Cách check + switch

```bash
# Check mode
kubectl get cm -n kube-system kube-proxy -o yaml | grep -A1 mode
# mode: ""    → iptables (default)
# mode: "ipvs" → IPVS

# Switch sang IPVS
kubectl edit cm -n kube-system kube-proxy
# Sửa: mode: "ipvs"
kubectl rollout restart ds -n kube-system kube-proxy

# Verify trên node
sudo ipvsadm -Ln
```

### Pattern 2026 — Cilium eBPF

Thay vì iptables/IPVS, prod lớn dùng **Cilium replace kube-proxy** — viết logic LB trong **eBPF program** chạy thẳng kernel hook. Bypass cả Netfilter. Performance cao hơn nữa + có observability (Hubble). Lab A chưa cần.

### Anchor để nhớ

> **kube-proxy = "thư ký viết rule", KHÔNG cầm packet**
> **iptables = chuỗi if-else linear O(N), random LB**
> **IPVS = hash table O(1), thuật toán LB chọn được (rr, lc, sh)**
> **Trigger là EndpointSlice (Pod Ready), KHÔNG phải Pod IP**
> **Pattern 2026 = Cilium eBPF replace kube-proxy hoàn toàn**

### Bẫy phỏng vấn thường gặp

- "kube-proxy có cầm packet không?" → **Không**. Chỉ viết rule, kernel tự xử lý packet trên data path.
- "iptables load balance bằng thuật toán gì?" → **Random qua probability statistic**, KHÔNG có thuật toán chuyên (như round-robin "thật"). Probability statistic mỗi rule đảm bảo phân bố đều.
- "Switch sang IPVS có downtime không?" → **Có**, kube-proxy DaemonSet rollout restart từng node → trong lúc rolling, node đang restart không có rule → traffic mới gãy ngắn. Cluster lớn nên schedule ngoài giờ.
- "Pod có IP rồi mà ClusterIP gọi vẫn time-out, vì sao?" → Pod **chưa Ready** (readiness probe fail) → endpoints-controller chưa thêm vào EndpointSlice → kube-proxy chưa viết rule cho pod đó. Check `kubectl get endpointslice` xem có Pod IP không.

### STAR hook Lab A++

**Sub-comp 5 EKS cluster mode default = iptables**: anh không switch IPVS vì cluster nhỏ (3 node, ~30 service shopxpress-pro). Verify qua `kubectl get cm -n kube-system kube-proxy -o yaml | grep mode` → trống = iptables. Decision: giữ default, không over-engineer.

**Nếu phỏng vấn hỏi**: "Bạn từng dùng IPVS mode chưa?" → trả lời thật: "Tôi đọc kiến trúc IPVS qua tài liệu (O(1) hash, lc cho gRPC), nhưng Lab thực tế chỉ đến quy mô iptables là phù hợp. Sẵn sàng triển khai IPVS nếu công ty có cluster > 1000 Service hoặc workload gRPC long-lived."

---

## Q8 [MID] — Endpoints vs EndpointSlice khác gì?

### Câu hỏi
1. Cả 2 đều chứa gì? Nội dung khác nhau không?
2. Vì sao K8s đẻ ra EndpointSlice thay Endpoints? Endpoints cũ có vấn đề gì?
3. Anh check 2 cái này bằng lệnh `kubectl` nào?

### Senior answer

Cả 2 đều là **danh bạ Pod IP của 1 Service**. Khác nhau cốt lõi ở **cách tổ chức**:

| | Endpoints (legacy) | EndpointSlice (mới, K8s 1.21+ GA) |
|---|---|---|
| Cấu trúc | **1 object** chứa TẤT CẢ pod | **Nhiều slice**, mỗi slice ≤ 100 endpoint |
| Scale | O(N) — mọi pod nhồi 1 object | O(slice) — update cục bộ |
| etcd limit 1.5 MB | Vướng khi > 5000 pod | Không vướng |
| Topology hint | Không có | Có `zone` field cho Topology Aware Routing |
| Pod state | Chỉ `notReadyAddresses` | `ready` + `serving` + `terminating` riêng |
| Watcher hiện tại | Backward compat | kube-proxy 1.19+, LBC, CoreDNS 1.7+ |

### Vấn đề Endpoints cũ — 3 lý do đẻ EndpointSlice

**1. Update tốn băng thông kinh khủng**

1 Service `payment-svc` 1000 pod → Endpoints object chứa 1000 IP. Mỗi pod thay đổi → kube-controller update **TOÀN BỘ Endpoints object** → API server push full object 1000 IP xuống **mỗi node** (kube-proxy watch). 999 IP không đổi vẫn bị push lại từ đầu.

**2. etcd object size limit**

K8s object giới hạn **1.5 MB** (etcd request limit). Service > 5000 pod → Endpoints vượt limit → update **fail luôn**. Cluster lớn vướng giới hạn này thực sự (Spotify, Lyft reported).

**3. API server bottleneck**

CI/CD deploy liên tục, pod recreate 50 lần/giây × 1000 IP = full object push qua API server → CPU control plane spike 80%, latency API tăng.

### Cơ chế EndpointSlice giải quyết

Chia nhỏ: mỗi slice ≤ 100 endpoint (default `--endpointslice.max-endpoints-per-slice=100`).

```
1 Service payment-svc có 1000 pod
       │
       ▼  endpointslice-controller chia:
   payment-svc-abc12 (100 pod)
   payment-svc-def34 (100 pod)
   payment-svc-ghi56 (100 pod)
   ... 10 slice tổng cộng
```

Update 1 pod thuộc slice `abc12` → chỉ update slice `abc12` (100 IP), KHÔNG đụng 9 slice còn lại → **băng thông giảm 10x**.

### Tính năng mới EndpointSlice

1. **Topology hint** (Topology Aware Routing): mỗi endpoint có `zone: ap-southeast-1a`. kube-proxy chọn pod **cùng AZ** với client → giảm cross-AZ traffic ($0.01/GB AWS) + latency thấp.

2. **Pod state phân biệt rõ**:
   - `ready: true` — pod sẵn sàng nhận traffic
   - `serving: true` — pod đang serve (có thể chưa ready khi terminating)
   - `terminating: true` — pod đang shutdown, graceful drain

3. **Multi-protocol stack**: IPv4 + IPv6 + FQDN trong cùng Service.

### Backward compatibility

`kube-controller-manager` vẫn tạo **Endpoints LEGACY object** song song (cùng tên Service) cho controller cũ. Đó là lý do `kubectl get endpoints` vẫn thấy, dù backend đã chuyển EndpointSlice.

### Lệnh check

```bash
# Endpoints legacy
kubectl get endpoints -n dev
kubectl describe endpoints nginx-svc -n dev

# EndpointSlice (mới)
kubectl get endpointslice -n dev
kubectl get endpointslice -n dev -l kubernetes.io/service-name=nginx-svc
kubectl describe endpointslice nginx-svc-abc12 -n dev
# Endpoints:
#   - Addresses: 10.0.1.23
#     Conditions: { Ready: true, Serving: true, Terminating: false }
#     NodeName:   ip-10-0-1-10.ec2.internal
#     Zone:       ap-southeast-1a              ← topology hint
```

### Anchor để nhớ

> **Endpoints = 1 object monolithic O(N). EndpointSlice = chia ≤100 endpoint/slice O(slice).**
> **3 vấn đề Endpoints cũ: băng thông push, etcd 1.5MB, API server bottleneck.**
> **EndpointSlice có topology hint (zone) → Topology Aware Routing giảm cross-AZ cost.**
> **kube-proxy + LBC + CoreDNS đều watch EndpointSlice từ K8s 1.21+. Endpoints chỉ còn cho backward compat.**

### Bẫy phỏng vấn thường gặp

- "Endpoints với Service có giống nhau không?" → **Không**. Service = "tôi muốn route tới label X". Endpoints = "đây là danh sách Pod IP thật của label X". Service là declarative, Endpoints là kết quả runtime.
- "Pod chưa Ready có vào Endpoints không?" → Vào trong `notReadyAddresses` (Endpoints legacy) hoặc `ready: false` (EndpointSlice). kube-proxy không route tới pod chưa ready.
- "Vì sao 1 Service có nhiều EndpointSlice cùng tên prefix?" → Vì K8s tự chia khi > 100 endpoint, hoặc khi endpoint có nhiều port khác nhau.

### STAR hook Lab A++

**Sub-comp 8 LBC IP mode**: LBC controller watch **EndpointSlice** (không phải Endpoints) của Service `gateway/products/orders` → đăng ký Pod IP vào ALB TargetGroup. Khi pod recreate (CI/CD rolling), EndpointSlice update → LBC nhận event → update TargetGroup health check → ALB drain old target + register new target. Lab anh ~3 pod/service × 30 service = 90 endpoint, không bao giờ chạm 100 limit → mỗi service vẫn 1 slice duy nhất.

---

## Q9 [MID] — DNS resolution trong cluster ra sao?

### Câu hỏi
Pod gõ `curl http://nginx-svc.dev.svc.cluster.local` → flow resolve DNS ra sao?
1. Pod hỏi DNS server nào? Sao biết hỏi server đó?
2. CoreDNS xử lý query này thế nào? Tra ở đâu?
3. Format FQDN `<svc>.<ns>.svc.cluster.local` — mỗi phần ý nghĩa gì?
4. Pod gõ tên ngắn `curl http://nginx-svc` có resolve được không?

### Senior answer — Flow đầy đủ

**Bước 1: Pod query DNS server nào**

Pod có file `/etc/resolv.conf` do **kubelet inject** lúc tạo pod:
```
nameserver 10.96.0.10
search dev.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

- `nameserver 10.96.0.10` = **ClusterIP của Service `kube-dns`** (CoreDNS đứng sau). Kubelet đọc từ `--cluster-dns` flag/config khi launch pod.
- ClusterIP `kube-dns` cố định suốt vòng đời cluster, không đổi (thường là `<service-cidr>.10`).

**Bước 2: CoreDNS xử lý**

CoreDNS = Deployment trong `kube-system` (thường 2 replica), config qua ConfigMap `coredns` (file Corefile):
```
.:53 {
    kubernetes cluster.local {              # plugin xử lý *.cluster.local
        pods insecure
    }
    forward . /etc/resolv.conf              # mọi domain khác → upstream
    cache 30
}
```

CoreDNS **watch K8s API server** (Service + EndpointSlice) → giữ bản đồ memory `svc-name + namespace → ClusterIP / Pod IP`. Không truy etcd mỗi query.

Khi query `nginx-svc.dev.svc.cluster.local`:
1. Plugin `kubernetes` match suffix `cluster.local` → xử lý.
2. Parse: service=`nginx-svc`, namespace=`dev`.
3. Lookup memory:
   - Service thường → A record = ClusterIP `10.96.10.5`.
   - Headless → A records = N Pod IP.
   - ExternalName → CNAME → tên ngoài.

Domain ngoài (vd `google.com`) → plugin `forward` → upstream `/etc/resolv.conf` của CoreDNS pod → trên EKS là VPC DNS resolver `10.0.0.2` → Route 53 → public DNS.

### FQDN format ý nghĩa từng phần

```
nginx-svc . dev . svc . cluster.local
    │       │     │         │
    │       │     │         └─ cluster domain (default cluster.local, config được)
    │       │     └─ record type "svc" = Service record
    │       └─ namespace
    └─ tên Service
```

**Schema record K8s DNS**:

| Suffix | Loại record | Dùng để |
|---|---|---|
| `<svc>.<ns>.svc.cluster.local` | A record Service | Resolve ClusterIP (hoặc N Pod IP nếu Headless) |
| `<pod-hostname>.<svc>.<ns>.svc.cluster.local` | A record Pod-trong-Headless | Pod IP cụ thể của StatefulSet (vd `postgres-0.postgres-hl.dev.svc.cluster.local`) |
| `_<port>._<proto>.<svc>.<ns>.svc.cluster.local` | SRV record | Port info |
| `<pod-ip-dash>.<ns>.pod.cluster.local` | A record Pod-IP | Resolve Pod IP ngược (deprecated) |

**Cross-namespace**: Pod ns `dev` gõ `nginx-svc` chỉ resolve service cùng ns. Muốn sang `prod` → gõ `nginx-svc.prod` hoặc full FQDN. → DNS-based namespace isolation.

### Short name + ndots + search domain

`/etc/resolv.conf`:
```
search dev.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

**Quy tắc**: tên có **< 5 dấu chấm** → resolver thử **search domain** trước (append suffix). ≥ 5 chấm → resolve trực tiếp.

Pod gõ `curl http://nginx-svc` (0 dot):
```
1. Thử: nginx-svc.dev.svc.cluster.local         → ✓ hit, dừng
2. Thử: nginx-svc.svc.cluster.local             → fail
3. Thử: nginx-svc.cluster.local                 → fail
4. Thử: nginx-svc (direct)                      → fail
```

→ Pod gõ tên ngắn vẫn resolve được nếu cùng namespace.

**Vấn đề performance external domain**:

Pod gõ `curl https://api.stripe.com` (2 dot, < 5):
```
1. Thử: api.stripe.com.dev.svc.cluster.local    → NXDOMAIN
2. Thử: api.stripe.com.svc.cluster.local        → NXDOMAIN
3. Thử: api.stripe.com.cluster.local            → NXDOMAIN
4. Thử: api.stripe.com (direct upstream)        → ✓ hit
```

→ **4 DNS query** cho 1 lần gọi API ngoài. CI/CD nặng external (S3, GitHub, npm) → CoreDNS quá tải.

**Best practice prod**:
1. **Trailing dot**: gõ `api.stripe.com.` → resolver coi là absolute FQDN, bỏ qua search → 1 query.
2. **Giảm ndots**: pod manifest `dnsConfig.options: [{name: ndots, value: "2"}]` → resolve direct sớm hơn.
3. **NodeLocal DNSCache** (DaemonSet) cache DNS ở chính node, giảm round-trip tới CoreDNS pod.

### Anchor để nhớ

> **Pod query DNS đi tới ClusterIP `kube-dns` 10.96.0.10 (CoreDNS đứng sau).**
> **CoreDNS = memory cache + plugin chain. Plugin `kubernetes` lo cluster.local, plugin `forward` lo Internet.**
> **FQDN schema: `<svc>.<ns>.svc.cluster.local`. StatefulSet thêm prefix `<pod-hostname>.<headless>.<ns>`.**
> **ndots:5 + search list → short name tiện cho internal, đắt 4 query cho external. Fix: trailing dot hoặc giảm ndots.**

### Bẫy phỏng vấn thường gặp

- "Pod gõ `google.com` mà chậm, CoreDNS log thấy 4 NXDOMAIN, vì sao?" → ndots:5 + search list. Fix bằng trailing dot.
- "Service đổi tên có ảnh hưởng DNS không?" → Có. Tên Service = phần đầu FQDN. Đổi tên Service = phải đổi mọi app reference qua DNS.
- "CoreDNS pod chết, cluster sao?" → Pod cũ vẫn chạy (đã resolve DNS xong cache), pod mới không resolve được service mới. CoreDNS HA = 2 replica + PodDisruptionBudget bắt buộc prod.
- "Pod hỏi `kubectl exec ... nslookup nginx-svc.dev` trả ClusterIP, nhưng app trong pod resolve fail, vì sao?" → App có thể đang dùng DNS resolver khác (vd Java cache forever, không respect TTL).

### STAR hook Lab A++

**Sub-comp 8 Add-ons CoreDNS managed addon** (Lab A++): cài qua `aws eks create-addon --addon-name coredns --addon-version v1.x.x`. AWS managed update version. 2 replica trong kube-system + topology spread `kubernetes.io/hostname` để 2 pod ở 2 node khác nhau (HA).

**External DNS pattern (ExternalDNS controller)** anh cài Sub-comp 11: ExternalDNS watch Ingress object → tự cập nhật **Route 53** public zone `shopxpress-pro.do2602.click`. App gọi `argocd.shopxpress-pro.do2602.click` không qua CoreDNS — đây là DNS public Route 53 → ALB DNS → ALB IP → Pod (IP mode). Hai layer DNS khác nhau: CoreDNS lo internal `*.svc.cluster.local`, Route 53 lo public `*.shopxpress-pro.do2602.click`.

---

## Q10 [MID] — Headless Service dùng khi nào?

### Câu hỏi
1. Headless Service là gì (`clusterIP: None`)?
2. **3 use case chính**?
3. Khác Service ClusterIP thường ở điểm nào về DNS?
4. Vì sao **StatefulSet luôn cần Headless Service kèm theo**?

### Senior answer

**Headless = Service có `clusterIP: None`**. Không có ClusterIP, không có kube-proxy rule, không có VIP. Client gọi qua **DNS thẳng**.

```yaml
spec:
  clusterIP: None              # ⬅ key
  selector: { app: postgres }
  ports:
  - port: 5432
```

**Khác cốt lõi ở response DNS**:

| | Service thường (ClusterIP) | Headless |
|---|---|---|
| DNS query | Trả **1 A record = ClusterIP ảo** (`10.96.10.5`) | Trả **N A records = N Pod IP thật** (`10.0.1.23`, `10.0.2.45`, ...) |
| LB | kube-proxy DNAT về 1 Pod | **Client tự pick** trong N |
| VIP | Có | Không |
| iptables rule | Có | Không |

→ Anchor: Headless = K8s **bỏ trung gian**, đẩy responsibility LB / pick pod xuống cho **client**.

### Use case 1 (chính): StatefulSet — stable per-pod address

**Vấn đề**: PostgreSQL HA: 1 primary (write) + 2 replica (read). Pod IP đổi sau recreate. App cần biết **chính xác đâu là primary** để gửi write — không LB ngẫu nhiên.

**Giải pháp**: StatefulSet đẻ pod đánh số `postgres-0`, `postgres-1`, `postgres-2` (hostname = tên pod). Kèm Headless Service → K8s sinh DNS records per-pod:

```
postgres-0.postgres-hl.dev.svc.cluster.local  → 10.0.1.23 (postgres-0)
postgres-1.postgres-hl.dev.svc.cluster.local  → 10.0.2.45
postgres-2.postgres-hl.dev.svc.cluster.local  → 10.0.3.67
```

Pod IP đổi (recreate), **hostname stable không đổi**. App config:
```yaml
DATABASE_WRITE_URL: postgres://postgres-0.postgres-hl.dev:5432/shop
DATABASE_READ_URL:  postgres://postgres-1.postgres-hl.dev:5432/shop
```

**StatefulSet `spec.serviceName` BẮT BUỘC trỏ Headless** — thiếu là pod có hostname nhưng không có DNS record.

**Workload điển hình**: PostgreSQL/MongoDB replica set, Kafka broker (advertised listener), Elasticsearch cluster discovery, Cassandra seed.

**Lab A++ Bitnami PostgreSQL** đẻ 2 Service:
- `db-postgresql` (ClusterIP thường) — client read/write LB tự động
- `db-postgresql-hl` (Headless) — cluster internal discovery + replica sync

### Use case 2: gRPC client-side LB

**Vấn đề gRPC + ClusterIP**: gRPC dùng HTTP/2 long-lived connection. kube-proxy iptables/IPVS chỉ LB lúc thiết lập TCP. Sau đó mọi RPC dồn vào **1 pod** → load lệch.

**Giải pháp Headless + gRPC round_robin**:

```go
conn, _ := grpc.Dial(
    "dns:///grpc-server-hl.dev.svc.cluster.local:50051",
    grpc.WithDefaultServiceConfig(`{"loadBalancingConfig": [{"round_robin":{}}]}`),
)
```

gRPC client:
1. Query DNS → N Pod IP.
2. Mở **N connection** song song.
3. Mỗi RPC round-robin pick 1 connection.
4. DNS refresh 30s → cập nhật pool khi pod scale.

**Alternative**: Service Mesh (Istio, Linkerd) inject sidecar Envoy lo LB layer 7.

### Use case 3: Custom service discovery

App phân tán cần biết **tất cả peer** trong cluster (không LB tới 1 thằng):
- **Cassandra**: seed list, node join cluster phải biết IP seed.
- **Hazelcast / Apache Ignite**: in-memory grid replicate data.
- **Redis Cluster**: client cần list master/slave để route key.
- **Operator pattern**: backup operator quét từng pod database snapshot riêng.

```python
import socket
peers = socket.gethostbyname_ex('cassandra-hl.dev.svc.cluster.local')[2]
# ['10.0.1.23', '10.0.2.45', '10.0.3.67']
```

→ Headless = **DNS-based service registry** miễn phí.

### Anchor để nhớ

> **Headless `clusterIP: None` → DNS trả N Pod IP thẳng, không VIP, không iptables. Client tự pick pod.**
> **Use case 1 (chính): StatefulSet — stable per-pod hostname cho PostgreSQL/MongoDB/Kafka/Cassandra.**
> **Use case 2: gRPC client-side LB — tránh long-lived connection dồn 1 pod.**
> **Use case 3: Custom service discovery — Cassandra/Hazelcast/operator quét từng peer.**
> **StatefulSet `spec.serviceName` BẮT BUỘC trỏ Headless → thiếu = stateful gãy.**

### Bẫy phỏng vấn thường gặp

- "Headless không có ClusterIP thì pod gọi sao?" → Qua DNS. Client tự pick IP trong N record.
- "StatefulSet không có Headless được không?" → Deploy được nhưng không có stable per-pod DNS → mất ý nghĩa StatefulSet.
- "gRPC dùng Service ClusterIP thường gặp vấn đề gì?" → Long-lived HTTP/2 dồn vào 1 pod, load lệch. Fix Headless + client round_robin hoặc service mesh.
- "Headless còn có thể tạo bằng kiểu nào khác?" → Service không có selector (manual Endpoints) cũng là Headless implicit — admin tự maintain danh sách IP.

### STAR hook Lab A++

**Sub-comp 9 ESO Lab A++ (UI Console mode)**: External Secrets Operator cài qua Helm; tạo `ExternalSecret` + `SecretStore` CRD. ESO controller không cần Headless (nó là controller xử lý CRD, không phải data plane).

**Lab A cũ Bitnami PostgreSQL** (đã chạy trước SCP block RDS): Helm chart Bitnami auto đẻ Headless `db-postgresql-hl` + Service thường `db-postgresql`. Anh không phải config thủ công — Bitnami template đã đúng pattern StatefulSet+Headless.

**Senior câu hỏi đào sâu**: "Vì sao Bitnami đẻ cả 2 Service?" → Service thường cho **app client** (load balance request), Headless cho **cluster internal** (replica sync với primary qua hostname stable). Tách 2 vai trò tránh app client query phải đụng DNS records N pod khi chỉ cần 1 entry point.

---

## Tổng kết D2 (2026-05-12)

| Q | Level | Chủ đề | Khởi đầu | Sau giảng |
|---|---|---|---|---|
| Q6 | MID | ClusterIP/NodePort/LoadBalancer | Junior (confuse ClusterIP=Pod IP) | Mid |
| Q7 | MID+ | kube-proxy iptables vs IPVS | Junior (chưa học) | Mid |
| Q8 | MID | Endpoints vs EndpointSlice | Junior (chưa học) | Mid |
| Q9 | MID | DNS resolution + ndots | Junior (chưa học) | Mid |
| Q10 | MID | Headless service | Junior (chưa học) | Mid |

**Điểm tổng D2**: **Junior → Mid**.

**Anchor cốt lõi cần khắc sâu (sẽ test retention D3-D7)**:
1. **Pod IP (CNI cấp, thật trên ENI) ≠ ClusterIP (VIP ảo, chỉ tồn tại trong rule iptables)**.
2. **kube-proxy = thư ký viết rule, KHÔNG cầm packet**. Trigger là EndpointSlice (Pod Ready), không phải Pod IP.
3. **ALB IP mode bypass ClusterIP**: external traffic North-South không qua kube-proxy. ClusterIP chỉ phục vụ East-West.
4. **EndpointSlice chia ≤100 endpoint/slice**, scale O(slice). Endpoints legacy O(N) vướng etcd 1.5MB.
5. **DNS schema `<svc>.<ns>.svc.cluster.local`**. ndots:5 → short name tiện internal, đắt external.
6. **Headless = bỏ VIP, đẩy LB xuống client**. StatefulSet bắt buộc Headless cho stable per-pod hostname.
