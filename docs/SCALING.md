# Scalability Plan

Concrete thresholds — when each piece of infrastructure actually becomes
necessary, not "eventually." Ordered by how soon they'll realistically be hit.

| Trigger | What to add | Why this threshold |
|---|---|---|
| **>1 backend instance needed at all** (any reason — redundancy, or load) | **Redis** (`REDIS_URL` set) | `bus.js`/`queue.js` already support this — it's a config flag, not new code. This is the first scaling step because every other form of horizontal scaling depends on it. |
| **Postgres CPU/IO consistently >70%, mostly from reads** (admin Dashboard, `GET /orders` on a large table) | **Read replica** | Writes (order creation, status updates) must stay on the primary for correctness (the `FOR UPDATE` locks this session's hardening pass relies on need a single writer); read-only endpoints (`GET /products`, `GET /orders` for an admin dashboard) can point at a replica once they're competing with write throughput for the same connections. |
| **Static asset traffic (admin-web/frontend bundles) becomes a meaningful % of bandwidth**, or users are geographically spread out | **CDN** | nginx's own gzip + long-cache headers (`admin-web/nginx.conf`) handle small scale fine; a CDN (Cloudflare, which also brings the WAF from `security/README.md`) matters once TTFB from a single origin region starts showing up in Core Web Vitals for distant users. |
| **BullMQ queue backlog regularly >1000 waiting jobs**, or job processing time becomes the bottleneck for user-visible latency | **Redis Cluster** | Single-instance Redis handles tens of thousands of ops/sec — this threshold is about queue *volume*, not raw Redis throughput. Cluster mode shards across nodes once one instance's memory or single-threaded processing becomes the ceiling. |
| **>1 distinct backend *service*** (not just replicas of the same one — e.g. a separate courier-matching service, a separate analytics service) | **API Gateway** (Kong, AWS API Gateway) replacing nginx's routing role | nginx handles "route by domain to N replicas of one app" fine forever. A gateway earns its keep when there are multiple *different* backends needing centralized auth, rate limiting, and versioning across them. |
| **Order volume high enough that courier/picker "least busy" SQL COUNT() query shows up in slow-query logs**, or the business wants real geo-based dispatch (nearest courier, not just least-loaded) | **Dedicated matching service** (see `docs/ARCHITECTURE.md`'s automation flow) | The current `leastBusy()` (advisory-lock-protected, see the hardening report) is correct and fast at the order volumes a COUNT-based query can handle — this becomes the bottleneck only when matching needs geolocation, which isn't in the schema today. |
| **Deploys need zero-downtime with health-gated rollout, or replica count needs to auto-scale with traffic** | **Kubernetes** | Docker Compose (`docker-compose.prod.yml`) is genuinely sufficient up to "a handful of VMs, manually scaled." K8s earns its operational overhead once auto-scaling policies or multi-region deploys are actual requirements, not nice-to-haves. |
| **Multiple product teams need independently deployable pieces**, not just independently *scalable* ones | **Microservices** | This is an organizational trigger more than a technical one — the current monolith-with-a-worker-process is the *right* architecture until deployment coordination between teams becomes the actual bottleneck, not request volume. |
| **A feature needs user-uploaded files** (product photos, courier documents) | **Object storage** (S3/R2/Supabase Storage) | Nothing in the schema stores files today (`image_url` is a plain string) — this is a feature-driven trigger, not a load-driven one, and can be added independent of everything else in this table. |
| **>1000 req/sec sustained, well beyond nginx's single-box ceiling** | **Load balancer in front of multiple nginx instances** | nginx itself handles tens of thousands of req/sec on modest hardware — this is a very late-stage trigger, listed for completeness. |

## What NOT to add prematurely

Everything above is listed with its trigger specifically so it *isn't*
added before the trigger. Kubernetes, microservices, and a dedicated API
gateway in particular are common premature-scaling mistakes — each adds
real operational complexity (more failure modes, more to monitor, slower
iteration) that isn't worth paying for until the specific problem it
solves is an actual, measured problem.
