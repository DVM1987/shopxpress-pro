# Buổi 1 — Image Hardening: Distroless + Multi-stage + Trivy

**Phase 1 Security Deep — Buổi 1/9**
**Lab A++ ShopXpress-Pro**
**Date**: 2026-05-11
**Scope**: Build-time image security — multi-stage build, distroless runtime, static binary, Trivy CVE gate, ECR registry scan, STRIDE threat model cho image pipeline.

---

## TL;DR (1 đoạn cho interviewer non-technical)

Lab A++ ship 3 service Go (`gateway` BFF, `products`, `orders`) lên EKS production qua image **14 MB** (so với 350 MB nếu dùng `golang:alpine` đầy đủ) với **0 CVE HIGH/CRITICAL** sustained. Hai vũ khí chính: (1) **Multi-stage build** tách compile khỏi runtime → source/credentials không leak; (2) **Distroless `static:nonroot`** → không shell/curl/apt → attacker compromise pod cũng không có công cụ để leverage. CI gate qua **Trivy@0.35.0** (HIGH+CRITICAL fail, `ignore-unfixed`) + ECR registry scan continuous (defense-in-depth). ECR `IMMUTABLE` + tag `sha-<7chars>` đảm bảo image không tamper được sau push.

---

## STAR — "Tell me about a time you hardened a container image for production"

### Situation
Đầu Phase 1 Security Deep của Lab A++, sau khi đã build xong CI/CD GitOps end-to-end (Sub-comp 0..0.7, 9/9 ArgoCD App Synced + Healthy, DORA Lead Time ~6m36s). Service Go gồm `gateway/products/orders` cần ship lên EKS nonprd cluster `shopxpress-pro-nonprd-eks` ở account A apse1.

**Constraint**:
- Bộ phận compliance yêu cầu image production không chứa shell/package manager (giảm attack surface)
- CVE gate phải block CI nếu image có HIGH/CRITICAL vulnerability
- Image phải ≤ 50 MB để pull <2s (rolling update nhanh)
- Reproducible build — 2 lần build từ cùng commit ra cùng SHA

### Task
DevOps lead solo (anh), trách nhiệm:
- Thiết kế Dockerfile production-grade cho 3 service Go
- Wire Trivy scan vào GHA workflow `build-push.yml` với gate strict
- Setup ECR registry-level scan + IMMUTABLE tag policy
- Document threat model image pipeline (STRIDE) cho audit team review

### Action (5 bước technical)

**A1. Multi-stage Dockerfile** — 1 file `Dockerfile` chung cho 3 service (parametrize qua `SERVICE` build-arg):
```dockerfile
ARG GO_VERSION=1.25
ARG ALPINE_VERSION=3.22

FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS builder
ENV CGO_ENABLED=0 GOFLAGS=-trimpath GOOS=linux
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download                        # cache layer ÍT đổi
COPY . .                                   # layer ĐỔI mỗi commit
ARG SERVICE
RUN go build -ldflags="-s -w" -o /out/app ./services/${SERVICE}

FROM gcr.io/distroless/static:nonroot
COPY --from=builder /out/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

Decision senior:
- **Multi-stage**: tách compile (cần Go compiler + git + ~340 MB) khỏi runtime (chỉ binary)
- **`CGO_ENABLED=0`**: static link binary → tương thích Distroless `static` (không có libc.so)
- **`GOFLAGS=-trimpath`**: xoá build path `/home/...` khỏi binary → reproducible + không lộ path
- **Distroless `static:nonroot`**: ~2 MB, không shell, USER `nonroot` (uid 65532) pre-defined
- **Layer order `go mod download` trước `COPY . .`**: cache 99% hit khi sửa code, CI nhanh 5x

**A2. Trivy CVE gate trong GHA workflow** (`.github/workflows/build-push.yml`):
```yaml
- name: Build image (load to local for scan)
  uses: docker/build-push-action@v6
  with:
    push: false
    load: true                              # ① image vào docker daemon CỦA runner

- name: Trivy vulnerability scan (gate HIGH+CRITICAL)
  uses: aquasecurity/trivy-action@0.35.0
  with:
    image-ref: ${{ steps.tag.outputs.IMAGE }}
    severity: HIGH,CRITICAL                 # ② chỉ fail CVE quan trọng
    exit-code: '1'                          # ③ FAIL → workflow stop, KHÔNG push
    ignore-unfixed: true                    # ④ skip CVE chưa có patch upstream
    format: table
    vuln-type: 'os,library'                 # ⑤ scan OS package + Go lib

- name: Push image to ECR
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  uses: docker/build-push-action@v6
  with:
    push: true                              # ⑥ chỉ chạy nếu Trivy pass
```

Pattern senior: **build local → scan → push**. Nếu build trực tiếp lên ECR thì image bẩn đã vào registry, scan sau push là quá muộn.

**A3. ECR registry-level scan + IMMUTABLE** (Terraform `terraform/70-ecr/`):
```hcl
resource "aws_ecr_repository" "this" {
  for_each             = toset(local.services)
  name                 = "shopxpress-pro-${each.key}"
  image_tag_mutability = "IMMUTABLE"        # tag sha-abc1234 không overwritten
  encryption_configuration { encryption_type = "AES256" }
}

resource "aws_ecr_registry_scanning_configuration" "this" {
  scan_type = "BASIC"
  rule {
    scan_frequency = "SCAN_ON_PUSH"
    repository_filter {
      filter      = "*"                     # apply tất cả repo trong account
      filter_type = "WILDCARD"
    }
  }
}
```

Defense-in-depth: Trivy CI (lúc build) + ECR scan (continuous rescan khi DB CVE update).

**A4. OIDC trust policy strict** (Sub-comp 0.7.3) — chỉ repo `DVM1987/shopxpress-pro-app` push được:
```hcl
condition {
  test     = "StringLike"
  variable = "token.actions.githubusercontent.com:sub"
  values   = [
    "repo:DVM1987/shopxpress-pro-app:ref:refs/heads/*",
    "repo:DVM1987/shopxpress-pro-app:pull_request"
  ]
}
```

Mitigation **Spoofing** threat: không attacker nào ngoài repo này AssumeRole được.

**A5. Tag scheme + lifecycle**:
- Tag `sha-<7chars>` từ Git commit (immutable, traceable)
- Lifecycle keep 10 tagged + expire untagged >1 day (control DoS qua storage exhaust)

### Result (số đo cụ thể)

| Metric | Số đo |
|---|---|
| **Image size** | 14 MB (vs 350 MB nếu `golang:alpine`) → giảm 25x |
| **CVE HIGH/CRITICAL** | 0 sustained qua 30+ CI run |
| **Pull time** từ ECR (EKS node apse1) | ~1.2s |
| **Build time** CI (cache hit) | 38s (vs 3 phút cache miss) |
| **Attack surface** | Zero shell/curl/apt — verify `kubectl exec` báo "executable not found" |
| **Verify reproducible** | Build 2 lần cùng commit → cùng image SHA256 |

→ Image production đạt **CIS Docker Benchmark 4.1, 4.5, 4.6, 5.3, 5.4** (USER nonroot, read-only rootfs, drop capabilities — Buổi 5 sẽ enforce qua PSS).

---

## 7 ý kiến thức cốt lõi Buổi 1

### 1. Distroless là gì + vì sao dùng

**Distroless** = base image của Google chỉ chứa runtime tối thiểu, KHÔNG có shell/package manager/coreutils/useradd. Chỉ còn: `ca-certificates`, `tzdata`, `/etc/passwd` cho user nonroot, `/tmp` writable.

**3 lý do senior** (xếp ưu tiên):
1. **Attack surface (#1)**: không có shell = attacker RCE pod không leverage được (không download malware, không spawn reverse shell)
2. **CVE count (#2)**: 0-2 CVE/tháng vs Alpine 5-15 vs Ubuntu 30-50
3. **Size (#3, bonus)**: image nhẹ, pull nhanh, ECR cost thấp

**Variant Distroless**:
- `static:nonroot` — Go/Rust static binary (~2 MB, không libc)
- `base:nonroot` — có libc cho binary dynamic (~7 MB)
- `python3`, `nodejs`, `java` — runtime cụ thể

### 2. Multi-stage build — 2 lý do thật sự

**Lý do #1 — Security boundary**: Stage 1 chứa source code, `.git`, build credentials (SSH key clone private module), `go.sum`. Stage 2 chỉ COPY binary → tất cả nguy hiểm trên BỊ VỨT. Không multi-stage = ship cả stage 1 lên production = attacker đọc được hết.

**Lý do #2 — Layer caching**: tách layer theo tần suất đổi.
```dockerfile
COPY go.mod go.sum ./             # Layer 1: ÍT đổi (cache 99% hit)
RUN go mod download
COPY . .                          # Layer 2: ĐỔI mỗi commit
RUN go build ...
```
CI rebuild lần 2 (chỉ sửa code): 30s. Nếu `COPY . .` trước `go mod download`: 3 phút mỗi lần.

### 3. Static binary + `CGO_ENABLED=0`

**CGO** = cầu nối Go gọi thư viện C (`libc.so`, `libpq.so`). Mặc định `CGO_ENABLED=1` → binary dynamic-linked, cần `libc.so` runtime.

**Vấn đề với Distroless `static`**: không có `libc.so`, không có dynamic linker → binary CGO fail "no such file or directory" (dù file `/app` có tồn tại! Kernel không tìm được linker).

**Fix**: `CGO_ENABLED=0` → Go dùng pure Go implementation cho `net`/`crypto/tls`/`os/user` → static binary self-contained.

**Verify**:
```bash
file /out/app
# ELF 64-bit LSB executable, x86-64, statically linked, ...
ldd /out/app
# not a dynamic executable        ← perfect cho distroless static
```

**Lý do Lab A++ chọn pgx/v5 driver**: pure Go (không cần libpq C). Nếu chọn `lib/pq` cũ → cần CGO → không Distroless static được.

**3 env "production-grade Go build flags"**:
- `CGO_ENABLED=0` — static link
- `GOFLAGS=-trimpath` — xoá build path, reproducible
- `GOOS=linux` — cross-compile từ Mac/Windows sang Linux EKS

### 4. Trivy baseline — 4 flag senior

| Flag | Vì sao |
|---|---|
| `severity: HIGH,CRITICAL` | LOW/MEDIUM noise quá, dev tắt scan. Industry baseline |
| `exit-code: '1'` | Mặc định Trivy exit 0 → "scan ghi log cho có". Senior pattern: fail CI block merge |
| `ignore-unfixed: true` | CVE chưa có patch upstream → dev không làm gì được → fail oan |
| `format: sarif` (improvement) | Upload Security tab GitHub → CVE trực quan, history theo time |

Trivy scan 3 thứ: OS package (apk/dpkg), application deps (`go.sum`/`package.json`), misconfig Dockerfile.

### 5. CI scan vs ECR scan — Defense-in-depth

| Lớp | Scanner | Chạy ở đâu | Khi nào |
|---|---|---|---|
| 1. CI gate | Trivy 0.35.0 | GHA runner VM | Trước push (one-shot) |
| 2. Registry continuous | ECR Basic | AWS ECR backend | Sau push + rescan định kỳ |

**Vì sao cần cả 2**:
- CI scan = snapshot tại 1 thời điểm. Trivy DB lúc đó không biết CVE công bố tuần sau.
- ECR scan = continuous, rescan khi DB CVE update → catch CVE retroactive.

**Edge case**: CI pass nhưng ECR fail (timing race + DB khác). Image đã production vẫn chạy (không tự khoá). Senior response:
1. EventBridge → SNS → Slack alert
2. Triage exploitability + scope
3. Bump dep → CI rescan pass → bot bump-tag → ArgoCD deploy (~6-7p)
4. Image cũ ECR auto cleanup qua lifecycle

### 6. STRIDE Threat Model cho Image Pipeline

(Xem section STRIDE table riêng bên dưới)

### 7. Flow CI thực tế

```
Mac dev: git push
   ↓
GHA runner VM (ubuntu-22.04, ephemeral ~5p):
   ├── checkout repo
   ├── docker build → image vào docker daemon CỦA runner
   ├── trivy scan image (tại runner)
   ├── push image từ runner → ECR (account A apse1)
   └── VM bị huỷ
```

Mac dev KHÔNG build, KHÔNG scan — chỉ commit + push code.

---

## STRIDE Threat Model — Image Pipeline

| STRIDE | Threat | Mitigation Lab A++ | File reference |
|---|---|---|---|
| **S**poofing | Attacker push image giả vào ECR | OIDC IdP + trust policy `sub: repo:DVM1987/shopxpress-pro-app:ref:refs/heads/*` (Sub-comp 0.7.3) | `terraform/75-gha-oidc/main.tf` |
| **T**ampering | Sửa image trong ECR sau push | ECR `imageTagMutability=IMMUTABLE` + tag `sha-<7chars>` từ Git commit | `terraform/70-ecr/main.tf` |
| **R**epudiation | "Tôi không push image lỗi đó" | CloudTrail log `ecr:PutImage` + GHA workflow run history + commit SHA nhúng tag | (built-in AWS + GitHub) |
| **I**nformation Disclosure | Source code/secret leak vào production image | Multi-stage drop stage 1 + `.dockerignore` skip `.git, .env` + ESO Secret runtime inject (Sub-comp 9) | `Dockerfile`, `.dockerignore` |
| **D**oS | ECR storage full / image quá to → pull chậm pod crash | Lifecycle policy keep 10 + expire untagged >1d + Distroless 14 MB pull <2s | `terraform/70-ecr/lifecycle.tf` |
| **E**oP | Container escape → host root | `USER nonroot:nonroot` + Pod Security Standard restricted (Buổi 5) + read-only rootfs + drop ALL capabilities | `Dockerfile` + Buổi 5 PSS |

**Tần suất re-check**:
- 1 lần khi design ban đầu (Buổi 1)
- Mỗi khi đổi architecture (add Cosign Buổi 2 → re-check Tampering row)
- Quarterly review (threat landscape update)
- Sau mỗi P1 incident (postmortem map STRIDE)

---

## Q&A Bank — 15 câu interview Senior 5+

### Q1. Vì sao Distroless mà không Alpine?
**A**: Ba lý do xếp ưu tiên:
1. **Attack surface**: Alpine có `busybox sh` + `apk` → attacker RCE pod có thể chạy `wget`/`apk add` để escalate. Distroless không có gì → tấn công dừng ở giai đoạn 1.
2. **CVE count**: Alpine ~5-15 CVE/tháng (busybox + musl libc), Distroless 0-2 CVE/tháng.
3. **Size bonus**: Distroless ~2 MB vs Alpine ~7 MB (chênh ít, không phải lý do chính).

Anchor: Log4Shell 2021 — pod Alpine bị RCE → attacker `wget xmrig` mining ngay. Pod Distroless cùng bug → bí, attacker dừng ở stage 1.

### Q2. Vì sao multi-stage thay vì build trực tiếp?
**A**: Hai lý do:
1. **Security boundary**: Stage 1 chứa source code, build credentials, `.git`. Nếu ship lên production = attacker compromise pod đọc được hết logic + credentials. Multi-stage = hard boundary, chỉ binary đã compile sang stage 2.
2. **Layer caching**: tách `go mod download` (cache) khỏi `go build` (mỗi commit) → CI rebuild lần 2 nhanh 5x.

### Q3. Giải thích `CGO_ENABLED=0`.
**A**: Tắt CGO → Go compile binary **static-linked** (không cần `libc.so` runtime). Cần thiết cho Distroless `static:nonroot` vì image này không có libc. Nếu để `CGO_ENABLED=1` (default) → binary dynamic-linked → pod start fail `"no such file or directory"` ở dynamic linker.

Side effect: Go dùng pure Go DNS resolver (không glibc `getaddrinfo`). Production EKS không ảnh hưởng.

### Q4. Trivy gate level chọn HIGH+CRITICAL vs CRITICAL only — vì sao?
**A**: HIGH+CRITICAL = baseline industry (Aqua, Snyk, Twistlock cùng pattern). CRITICAL only quá lỏng — miss Log4Shell ban đầu chỉ HIGH. ALL severity quá strict — noise → team tắt scan. HIGH+CRITICAL cân bằng signal/noise.

### Q5. Đã có Trivy CI scan, vì sao cần ECR scan nữa?
**A**: Defense-in-depth, 2 layer khác đặc tính:
- **CI Trivy** = snapshot tại thời điểm build, dùng Trivy DB lúc đó. Miss CVE công bố SAU build.
- **ECR scan** = continuous, rescan khi DB CVE update → catch CVE retroactive (image đã production 2 tuần phát hiện CVE mới).

Trivy CI block image bẩn vào ECR. ECR scan flag image cũ trong ECR. 2 lớp bổ sung nhau.

### Q6. Anh phát hiện image production có CVE HIGH mới — 15 phút đầu làm gì?
**A**: 5 bước:
1. **Triage exploitability**: CVE có reachable từ external traffic không? Lib chỉ internal worker → P2. Endpoint public → P1.
2. **Scope**: bao nhiêu service dùng image này (3/3 hay 1/3)? Multi region không?
3. **Mitigation tạm thời**: WAF block exploit pattern, NetworkPolicy hạn chế egress.
4. **Patch**: bump go.mod / base image → PR → CI scan PASS → bot bump-tag → ArgoCD deploy (~6-7 phút như DORA baseline Lab A++).
5. **Document**: postmortem + add detection rule (vd Trivy `.trivyignore` review process).

### Q7. Vì sao tag `sha-<7chars>` thay vì semver `v1.2.3`?
**A**:
- **Immutable + traceable**: SHA từ Git commit → 1-1 mapping image ↔ source. Audit trail rõ ràng.
- **Compliance**: ECR `imageTagMutability=IMMUTABLE` ép unique tag. Semver có thể conflict (rebuild v1.2.3) hoặc overwrite (tag latest).
- **No human error**: developer không cần nghĩ version number, CI tự generate.

Trade-off: kém human-readable. Production thực tế có thể combine: `sha-abc1234` (immutable) + alias `v1.2.3` (mutable, dùng cho release note).

### Q8. Tần suất threat modeling STRIDE?
**A**:
- 1 lần lúc design ban đầu (Buổi 1 Lab A++)
- Re-check **mỗi khi đổi architecture** (add service, integrate 3rd party, đổi auth flow)
- Quarterly review chủ động
- Sau mỗi P1 incident (postmortem map STRIDE)

KHÔNG check mỗi push — đó là nhầm vai trò giữa threat model (strategic) vs vulnerability scan (runtime).

### Q9. ECR `IMMUTABLE` giải quyết threat gì?
**A**: **Tampering** trong STRIDE. Nếu `MUTABLE`:
- Dev push `v1.2.3` lần đầu (clean)
- Attacker compromise CI → push `v1.2.3` lại (malicious)
- ECR overwrite tag → pod kéo "v1.2.3" về chạy malware

IMMUTABLE = tag push 1 lần, không overwrite. Combine với Cosign sign (Buổi 2) = end-to-end integrity.

### Q10. Vì sao build local trên runner rồi mới push, không build push thẳng?
**A**:
- Build `load: true` → image vào docker daemon runner → có image vật lý để Trivy scan ngay
- Build push thẳng ECR → phải pull về scan = 2 lần upload/download + image bẩn đã ở ECR
- Pattern "fail fast, fail local" — bug detect ở runner, không leak ra ECR

### Q11. Reproducible build là gì + cách verify?
**A**:
- **Định nghĩa**: build 2 lần từ cùng commit (cùng source) ra cùng image SHA256 (bit-by-bit identical).
- **Vì sao cần**: supply chain security. Nếu reproducible thì 2 build server khác nhau verify được "binary này có thật từ source ABC".
- **Cách đạt**: `GOFLAGS=-trimpath` xoá build path, pin base image tag chính xác (không `latest`), không embed timestamp/hostname.
- **Verify**: build lần 2 → `docker inspect --format='{{.Id}}' image` → so sánh SHA256.

### Q12. SBOM là gì + Lab A++ có chưa?
**A**: **Software Bill of Materials** = danh sách dependencies + version trong image (như "ingredient list" của sản phẩm). Format chuẩn: SPDX, CycloneDX.

Lab A++ **chưa có** SBOM generate — improvement backlog Buổi 2. Cách add:
```yaml
- name: Generate SBOM
  uses: aquasecurity/trivy-action@0.35.0
  with:
    image-ref: ${{ steps.tag.outputs.IMAGE }}
    format: cyclonedx
    output: sbom-${{ matrix.service }}.cdx.json
- name: Upload SBOM as artifact
  uses: actions/upload-artifact@v4
```

Use case: khi CVE mới công bố (vd CVE-2026-xxx in `golang.org/x/net v0.15.0`), search SBOM của 100 image → biết image nào chứa lib đó → patch targeted.

### Q13. Workflow Trivy fail — dev xử lý sao?
**A**:
1. GHA UI tab Actions → đọc Trivy log → lấy CVE ID + fixed version
2. Sửa local (Mac): bump `go.mod` hoặc base image tag Dockerfile
3. `git commit + push` → workflow chạy lại
4. KHÔNG bypass scan (xoá Trivy step / `exit-code: 0`) — red flag interview

Edge case: CVE chưa có patch upstream → `.trivyignore` + Linear ticket theo dõi + review monthly.

### Q14. Container escape — Distroless có ngăn không?
**A**: Distroless **không trực tiếp** ngăn container escape (CVE runc, kernel exploit). Nhưng:
- **Giảm leverage sau escape**: attacker thoát container → vào host runner → không có shell trong image → không chain attack được tại pod
- **Combine với**:
  - PSS restricted (Buổi 5) — drop ALL capabilities, read-only rootfs
  - SECCOMP profile — limit syscall
  - AppArmor/SELinux — MAC layer
  - gVisor/Kata runtime — sandbox layer

Defense-in-depth: Distroless là 1 trong nhiều lớp, không phải silver bullet.

### Q15. Lab A++ image hardening còn gap nào?
**A**: Admit thẳng (interview Senior thật thà về gap = điểm cộng):
1. **Cosign sign image** — chưa có, Buổi 2 sẽ add. Hiện attacker compromise CI có thể push image bẩn cùng tag mới (không overwrite cũ do IMMUTABLE, nhưng pod kéo về vẫn chạy).
2. **SBOM generate** — chưa có, Buổi 2 add `trivy sbom --format cyclonedx`.
3. **SARIF upload Security tab** — đang `format: table`, log chỉ ở GHA. Senior nâng `format: sarif` + `github/codeql-action/upload-sarif@v3`.
4. **Reproducible build verification** — chưa có script tự động verify 2 build cùng commit ra cùng SHA.
5. **Dependency review GHA** — chưa có check `go.mod` diff cho PR (`actions/dependency-review-action@v4`).
6. **Pin base image by digest** — đang dùng tag `golang:1.25-alpine3.22`, attacker compromise registry có thể push lại tag. Pattern senior: `golang@sha256:abc...` (digest pin).

→ Backlog Buổi 2 sẽ cover 5/6 gap (Cosign + SBOM + SARIF + dependency review + digest pin).

---

## Improvement Backlog (cho Buổi 2)

| Priority | Task | Effort |
|---|---|---|
| P0 | Add Cosign sign + Kyverno verify policy | ~1 buổi |
| P0 | Add SBOM generate (`trivy sbom` cyclonedx) | ~30p |
| P1 | Switch Trivy `format: table` → `sarif` + upload Security tab | ~20p |
| P1 | Pin base image by digest (`golang@sha256:...`) + Renovate bot tự bump | ~1h |
| P2 | Add `actions/dependency-review-action@v4` cho PR | ~15p |
| P2 | Add `.trivyignore` empty file + process review monthly | ~10p |
| P3 | Reproducible build verify script (build 2 lần so SHA) | ~1h |

---

## Reference

- `Dockerfile` (Sub-comp 0.7.1) — multi-stage 6 block
- `.github/workflows/build-push.yml` line 144-180 — Trivy step
- `terraform/70-ecr/` (Sub-comp 0.7.2) — ECR IMMUTABLE + lifecycle + registry scan
- `terraform/75-gha-oidc/` (Sub-comp 0.7.3) — OIDC trust policy strict
- Memory `project_ecr_registry_scan_rule.md` — registry-level scan override pattern
- Memory `project_gha_pitfalls_buoi4.md` — 3 pitfall workflow build-push
- Memory `project_ecr_buildkit_scan_pitfall.md` — BuildKit v24+ multi-arch manifest

## STAR cheat sheet (in nhỏ mang đi phỏng vấn)

> "Lab A++ tôi ship 3 service Go lên EKS production qua image 14 MB, 0 CVE HIGH/CRITICAL sustained. Stack: multi-stage Dockerfile (security boundary + cache), Distroless static:nonroot (zero shell attack surface), CGO_ENABLED=0 (static link tương thích distroless), Trivy@0.35.0 CI gate (HIGH+CRITICAL fail), ECR IMMUTABLE + registry scan continuous (defense-in-depth). STRIDE threat model 6 ô documented. Gap admit: Cosign + SBOM + SARIF — Buổi 2 sẽ cover."
