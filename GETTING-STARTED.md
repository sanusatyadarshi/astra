# Getting Started with astra

A complete walkthrough of using astra to architect, build, debug, and deploy Go microservices from the Claude Code terminal.

---

## 1. Prerequisites & Install

**You need:**
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Go toolchain (1.21+)
- git

**Setup (3 commands):**

```bash
git clone git@github.com:sanusatyadarshi/astra.git
cd astra
./install.sh
```

On first install, copy and configure your settings:

```bash
cp global/settings.json.example ~/.claude/settings.json
# Edit ~/.claude/settings.json with your API token and endpoint
```

**Verify it works:**

```bash
claude
```

You should see skills listed when Claude starts. Try asking Claude to list its available skills — it should report 15 skills and 130 agents.

**How symlinks work:** `install.sh` symlinks everything from `astra/` into `~/.claude/`. This means any edit you make to files in `astra/skills/` or `astra/agents/` is live immediately — no reinstall needed.

---

## 2. Mental Model: How This Works

astra adds three layers on top of vanilla Claude Code:

### Skills — automatic behaviors

Skills are instructions Claude loads based on what you're doing. You don't invoke most of them — Claude reads each skill's trigger description and activates the right one automatically.

**Example:** You say "tests are failing intermittently." Claude sees this matches the `systematic-debugging` skill's trigger ("any bug, test failure, or unexpected behavior") and follows its methodology: trace the error, reproduce it, form a hypothesis, fix at source, verify.

- 15 skills covering planning, development, debugging, review, and deployment
- One skill (`/security-architect`) is user-invocable as a slash command
- Skills live in `skills/<name>/SKILL.md`
- Multiple skills can be active simultaneously (e.g., `test-driven-development` + `verification-before-completion`)

### Agents — specialized subagents

Agents are focused subprocesses Claude dispatches for specific tasks. You can ask for a specific agent, or Claude picks one based on context.

**Example:** You say "design the API contracts for this service." Claude dispatches the `api-designer` agent — it runs as an isolated subagent with its own context window, focused entirely on API design.

- 130 agents across 10 categories (from `golang-pro` to `kubernetes-specialist`)
- Each agent has a defined role, toolset, and model (opus/sonnet/haiku)
- Agents run isolated — they don't pollute your main conversation context
- Claude can dispatch multiple agents in parallel for independent tasks

### Global CLAUDE.md — workflow rules

The global `CLAUDE.md` file (`~/.claude/CLAUDE.md`) defines workflow rules that apply to every conversation:

- Plan before building, verify before claiming done
- Track progress in `tasks/todo.md`, capture lessons in `tasks/lessons.md`
- Simplicity first — minimal changes, no over-engineering

---

## 3. The Journey: Building a Go Microservice

Let's walk through building an order-processing microservice for an e-commerce platform. Each phase shows what you'd say to Claude, which skills and agents activate, and what Claude does differently because of astra.

### Phase 1: Architect

Start a conversation with Claude:

```
You: I need to design an order processing microservice for our e-commerce
platform. It handles order creation, payment orchestration, inventory
reservation, and fulfillment tracking. We use Go, gRPC between services,
PostgreSQL, and deploy to Kubernetes.
```

**What activates:** The `brainstorming` skill triggers because you're describing new functionality. Instead of jumping straight to code, Claude:

1. Explores your requirements — asks clarifying questions one at a time (event-driven vs synchronous? saga pattern for payments? idempotency requirements?)
2. Proposes 2-3 architectural approaches with trade-offs
3. Presents the design incrementally, getting your approval on each section

For deeper system design work, Claude dispatches specialized agents:

```
You: Design the service boundaries and communication patterns.
```

Claude dispatches the `microservices-architect` agent (runs on opus for deep reasoning). It returns with:
- Service boundary recommendations
- Communication patterns (sync gRPC for queries, async events for state changes)
- Data ownership boundaries
- Failure mode analysis

```
You: Now design the API contracts for the order service.
```

Claude dispatches the `api-designer` agent, which produces:
- gRPC service definitions with protobuf schemas
- REST gateway mappings (if needed)
- Error codes and pagination patterns
- Versioning strategy

### Phase 2: Design & Plan

Once the architecture is settled:

```
You: Write an implementation plan for the order service.
```

**What activates:** The `writing-plans` skill takes over. Claude writes a structured plan to `tasks/todo.md` with:

- Bite-sized tasks (2-5 minutes each)
- Each task follows red-green-refactor: write failing test, verify it fails, implement, verify it passes, commit
- Exact file paths, complete code snippets, exact commands with expected output
- Clear verification steps for each task

**Example plan output** (in `tasks/todo.md`):

```markdown
## Order Service Implementation

### Task 1: Project scaffold
- [ ] Create Go module: `go mod init github.com/yourorg/order-service`
- [ ] Create directory structure: `cmd/`, `internal/`, `proto/`, `migrations/`
- [ ] Write `cmd/server/main.go` with basic gRPC server startup
- [ ] Verify: `go build ./cmd/server` exits 0

### Task 2: Order creation endpoint — RED
- [ ] Write `internal/order/handler_test.go` with `TestCreateOrder`
- [ ] Test expects: valid request returns order with generated ID and PENDING status
- [ ] Verify: `go test ./internal/order/...` FAILS (handler doesn't exist yet)

### Task 3: Order creation endpoint — GREEN
- [ ] Implement `internal/order/handler.go` CreateOrder method
- [ ] Minimal implementation to pass the test
- [ ] Verify: `go test ./internal/order/...` PASSES
...
```

**Run a threat model** before building:

```
You: /security-architect
```

This is the one user-invocable slash command. The `security-architect` skill activates and Claude:
- Maps the attack surface (gRPC endpoints, database access, inter-service communication)
- Traces trust boundaries
- Audits authentication, authorization, data security, API security
- Produces findings organized by severity with remediation recommendations

After the plan is written, Claude offers execution options:
- **Subagent-driven**: Fresh agent per task (via `subagent-driven-development`)
- **Parallel session**: Execute in a separate session with review checkpoints (via `executing-plans`)

### Phase 3: Develop

```
You: Implement the order handler with TDD.
```

**What activates:** The `test-driven-development` skill enforces the RED-GREEN-REFACTOR cycle. Claude won't write implementation code before tests.

**RED** — Claude writes the test first:

```go
func TestCreateOrder(t *testing.T) {
    tests := []struct {
        name    string
        req     *pb.CreateOrderRequest
        wantErr bool
    }{
        {
            name: "valid order",
            req: &pb.CreateOrderRequest{
                CustomerId: "cust-123",
                Items: []*pb.OrderItem{
                    {ProductId: "prod-456", Quantity: 2, PricePerUnit: 1999},
                },
            },
        },
        {
            name:    "empty customer ID",
            req:     &pb.CreateOrderRequest{},
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            h := order.NewHandler(newTestStore())
            resp, err := h.CreateOrder(context.Background(), tt.req)
            if tt.wantErr {
                require.Error(t, err)
                return
            }
            require.NoError(t, err)
            assert.NotEmpty(t, resp.OrderId)
            assert.Equal(t, pb.OrderStatus_PENDING, resp.Status)
        })
    }
}
```

Claude runs the test and verifies it fails:

```
$ go test ./internal/order/...
--- FAIL: TestCreateOrder (0.00s)
    # handler.go doesn't exist
FAIL
```

**GREEN** — Now Claude implements the minimal handler to pass:

```go
type Handler struct {
    store Store
}

func NewHandler(store Store) *Handler {
    return &Handler{store: store}
}

func (h *Handler) CreateOrder(ctx context.Context, req *pb.CreateOrderRequest) (*pb.CreateOrderResponse, error) {
    if req.CustomerId == "" {
        return nil, status.Error(codes.InvalidArgument, "customer_id required")
    }

    order := &Order{
        ID:         uuid.New().String(),
        CustomerID: req.CustomerId,
        Items:      fromProtoItems(req.Items),
        Status:     StatusPending,
        CreatedAt:  time.Now(),
    }

    if err := h.store.Create(ctx, order); err != nil {
        return nil, status.Error(codes.Internal, "failed to create order")
    }

    return toProtoResponse(order), nil
}
```

Claude runs the test again and verifies it passes:

```
$ go test ./internal/order/...
ok      github.com/yourorg/order-service/internal/order    0.003s
```

**REFACTOR** — Only after green. Clean up duplication, improve names, extract helpers.

For Go-specific patterns, Claude dispatches the `golang-pro` agent. This agent knows:
- Table-driven tests (as shown above)
- Functional options pattern for configuration
- Error wrapping with `fmt.Errorf("create order: %w", err)`
- Interface-driven design for testability
- Go module layout conventions

**Worktree isolation:** The `using-git-worktrees` skill creates an isolated git worktree for this feature, so your main branch stays clean while you develop.

### Phase 4: Debug

```
You: Tests are failing intermittently in CI. TestCreateOrder passes
locally but fails about 30% of the time in CI with "context deadline
exceeded".
```

**What activates:** The `systematic-debugging` skill. Claude follows a structured methodology instead of guessing:

**Phase 1 — Gather evidence:**
- Read the full error output carefully
- Check what changed recently (`git log --oneline -10`)
- Reproduce: is it timing-related? Resource-related?
- Trace data flow backward from the error

**Phase 2 — Analyze:**
- Find a working example (local) and compare differences (CI)
- Form a single hypothesis: "CI has lower resources, so the database connection pool exhausts under parallel test runs"
- Test minimally: check if running tests with `-count=1 -parallel=1` eliminates the failure

**Parallel investigation:** The `dispatching-parallel-agents` skill triggers if there are multiple test files failing. Claude dispatches separate agents to investigate each file concurrently:

```
You: Three test files are failing intermittently: handler_test.go,
store_test.go, and integration_test.go.
```

Claude dispatches 3 agents in parallel — one per file — each investigating independently. When they return, Claude synthesizes findings and checks for conflicts.

**Phase 3 — Fix at source:**
- Create a failing test case that reproduces the intermittent failure
- Implement the fix (e.g., add proper test cleanup, use `t.Cleanup()` for database connections)
- Verify the fix

**Phase 4 — Prove it:** The `verification-before-completion` skill requires Claude to run verification fresh and show evidence before claiming the fix works:

```
$ go test -race -count=10 ./internal/order/...
ok      github.com/yourorg/order-service/internal/order    2.341s
```

No "should be fixed" or "probably works" — evidence or nothing.

### Phase 5: Review

```
You: Review the order service before merging.
```

**What activates:** The `requesting-code-review` skill. Claude:

1. Gets the base and head SHAs for the diff
2. Dispatches a `code-reviewer` subagent with full context: what was implemented, requirements, the diff
3. The reviewer evaluates: correctness, Go idioms, security, performance, test coverage

**Example review output:**

```
## Code Review: Order Service

### Critical
- None

### Important
- handler.go:47 — CreateOrder doesn't validate item quantities (could be 0 or negative)
- store.go:23 — Missing index on customer_id column, will be slow for GetOrdersByCustomer

### Minor
- handler.go:12 — Consider using constants for status strings instead of raw strings
- handler_test.go:35 — Test helper newTestStore() could use t.Helper()

### Positive
- Clean separation between handler and store layers
- Good use of table-driven tests
- Error wrapping follows Go conventions
```

**Handling feedback:** The `receiving-code-review` skill ensures Claude doesn't blindly agree with every suggestion. For each review item, Claude:
- Reads the feedback and restates the requirement
- Verifies against the actual codebase
- Evaluates technical soundness
- Pushes back with reasoning if the suggestion is wrong

Critical items get fixed immediately. Important items get fixed before proceeding. Minor items are noted for later.

### Phase 6: Deploy

```
You: Prepare this for production deployment.
```

Claude dispatches multiple specialized agents:

**`kubernetes-specialist`** — Produces K8s manifests:
- Deployment with resource limits, health checks, rolling update strategy
- Service and Ingress configuration
- ConfigMap and Secret references
- HorizontalPodAutoscaler

**`docker-expert`** — Produces a multi-stage Dockerfile:
```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /order-service ./cmd/server

FROM alpine:3.19
RUN apk add --no-cache ca-certificates
COPY --from=builder /order-service /order-service
EXPOSE 8080
ENTRYPOINT ["/order-service"]
```

**`devops-engineer`** — CI/CD pipeline configuration (GitHub Actions / GitLab CI):
- Build, test, lint stages
- Container image build and push
- Deployment to staging then production

**`security-engineer`** — Production hardening:
- Network policies
- Pod security standards
- Secret management review
- TLS configuration

**Branch integration:** The `finishing-a-development-branch` skill presents four options:
1. **Merge locally** — pull, merge, verify tests, cleanup branch
2. **Push & create PR** — push, `gh pr create`, keep branch
3. **Keep as-is** — leave the branch for later
4. **Discard** — requires typed confirmation

---

## 4. Key Agents for Go Architects

Quick reference of the most relevant agents and when to use each:

| Agent | Category | When to Use |
|-------|----------|-------------|
| `golang-pro` | Language Specialists | Everyday Go development — idioms, patterns, stdlib usage |
| `microservices-architect` | Core Development | System design, service boundaries, communication patterns |
| `api-designer` | Core Development | REST/gRPC contract design, protobuf schemas, versioning |
| `kubernetes-specialist` | Infrastructure | K8s manifests, operators, cluster configuration |
| `docker-expert` | Infrastructure | Containerization, multi-stage builds, optimization |
| `devops-engineer` | Infrastructure | CI/CD pipelines, deployment automation |
| `terraform-engineer` | Infrastructure | Infrastructure as code, cloud resource management |
| `security-engineer` | Infrastructure | Production hardening, network policies, TLS |
| `security-auditor` | Quality & Security | Security review, vulnerability scanning |
| `code-reviewer` | Quality & Security | Code review — correctness, idioms, coverage |
| `architect-reviewer` | Quality & Security | Architecture review — design decisions, trade-offs |
| `performance-engineer` | Quality & Security | Profiling, optimization, benchmarking |
| `database-administrator` | Infrastructure | Schema design, query optimization, migrations |
| `sql-pro` | Language Specialists | SQL queries, indexing strategy, database patterns |
| `sre-engineer` | Infrastructure | Reliability, SLOs, incident response, observability |

**Model routing:** Agents run on different models based on task complexity:
- **opus** — Architecture decisions, complex reasoning, threat modeling
- **sonnet** — Everyday coding, implementation, testing
- **haiku** — Quick lookups, simple transformations, formatting

---

## 5. Tips & Patterns

### Parallel agents for faster work
When you have independent tasks, Claude dispatches multiple agents simultaneously:
```
You: Investigate these 3 failing test files: handler_test.go, store_test.go,
and integration_test.go.
```
Claude creates one agent per file, all running in parallel. Results are synthesized when all agents complete.

### Skills stack
Multiple skills can be active at the same time. Writing implementation code might activate both `test-driven-development` (write tests first) and `verification-before-completion` (prove it works before claiming done).

### Slash commands
Only `/security-architect` is user-invocable as a slash command. All other skills activate automatically based on context. You don't need to memorize triggers — just describe what you need and the right skill activates.

### Live editing
Skills and agents are symlinked from `astra/` into `~/.claude/`. Edit a file in `astra/skills/` or `astra/agents/` and it's immediately active in your next Claude conversation. No reinstall needed.

### Adding your own
See the [Adding Your Own](README.md#adding-your-own) section in the README for the skill and agent file format. After adding new content, run `./install.sh` to create symlinks.

### Workflow orchestration
The global `CLAUDE.md` enforces a plan-verify-learn loop:
1. **Plan** — Write tasks to `tasks/todo.md` before building
2. **Execute** — Track progress, mark items complete
3. **Verify** — Run tests, check output, prove correctness
4. **Learn** — Capture lessons in `tasks/lessons.md` after corrections

### Getting the most from agents
- Be specific about what you want: "Design the gRPC API for order creation with idempotency support" beats "design the API"
- Mention technologies explicitly: "using Go, PostgreSQL, and Kubernetes" gives agents the right context
- For architecture work, ask Claude to use opus-level agents for deeper reasoning

---

## 6. Quick Reference Card

### Common prompts
```
"Design a microservice for [domain]"          → brainstorming + microservices-architect
"Write an implementation plan for [feature]"   → writing-plans
"Implement [feature] with TDD"                 → test-driven-development + golang-pro
"Tests are failing: [error]"                   → systematic-debugging
"Review [component] before merging"            → requesting-code-review
"Prepare this for production"                  → kubernetes-specialist + docker-expert + devops-engineer
"/security-architect"                          → security audit and threat model
```

### Most-used agents for Go microservices
```
golang-pro              — Go code, idioms, patterns
microservices-architect — service design, boundaries
api-designer            — gRPC/REST contracts
kubernetes-specialist   — K8s manifests, deployment
docker-expert           — Dockerfiles, image optimization
devops-engineer         — CI/CD pipelines
security-engineer       — production hardening
code-reviewer           — pre-merge review
```

### Skill activation triggers
```
New feature/component   → brainstorming (automatic)
Multi-step task         → writing-plans (automatic)
Writing code            → test-driven-development (automatic)
Bug/test failure        → systematic-debugging (automatic)
Multiple independent    → dispatching-parallel-agents (automatic)
Claiming "done"         → verification-before-completion (automatic)
Security review         → /security-architect (manual slash command)
```

### Where things live
```
~/.claude/skills/       — Skill definitions (symlinked from astra/skills/)
~/.claude/agents/       — Agent definitions (symlinked from astra/agents/)
~/.claude/CLAUDE.md     — Global workflow rules (symlinked from astra/global/CLAUDE.md)
~/.claude/settings.json — Your personal settings (not symlinked, contains secrets)
```
