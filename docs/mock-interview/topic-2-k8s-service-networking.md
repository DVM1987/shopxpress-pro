# Topic 2 — K8s Service & Networking (D2, 2026-05-12)

> **Mục đích**: 5 câu Q&A căn bản về Service, ClusterIP, NodePort, LoadBalancer, kube-proxy, EndpointSlice, DNS, Headless. Ôn phỏng vấn DevOps/SRE Senior 5+.
> **Cách ôn**: đọc câu hỏi → tự trả lời → so "Senior answer" → đọc "Anchor" để khắc sâu.
> **Tiến độ**: 2/5 (Q6+Q7 DONE, Q8+Q9+Q10 PENDING)

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

## Q8 [PENDING]

(Sẽ ghi sau khi học)

---

## Q9 [PENDING]

(Sẽ ghi sau khi học)

---

## Q10 [PENDING]

(Sẽ ghi sau khi học)
