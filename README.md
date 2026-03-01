# astra (अस्त्र)

Personal Claude Code configuration repo. 15 skills, 130 agents, zero setup friction.

One clone. One script. Immediately productive.

## Setup

```bash
git clone git@github.com:sanusatyadarshi/astra.git
cd astra
./install.sh
```

On first install, copy and fill in your settings:

```bash
cp global/settings.json.example ~/.claude/settings.json
# Edit with your API token and endpoint
```

All skills and agents are symlinked — edits are live immediately.

## What's Included

### Skills (15)

| Skill | Description |
|-------|-------------|
| `brainstorming` | Explores user intent, requirements and design before implementation |
| `dispatching-parallel-agents` | Dispatch 2+ independent tasks that can be worked on without shared state |
| `executing-plans` | Execute a written implementation plan in a separate session with review checkpoints |
| `finishing-a-development-branch` | Structured options for merge, PR, or cleanup when implementation is complete |
| `receiving-code-review` | Handle code review feedback with technical rigor, not blind implementation |
| `requesting-code-review` | Verify work meets requirements before merging |
| `security-architect` | Security audits, threat modeling, vulnerability identification |
| `subagent-driven-development` | Execute implementation plans with independent tasks via subagents |
| `systematic-debugging` | Methodical debugging before proposing fixes |
| `test-driven-development` | TDD workflow — write tests before implementation |
| `using-git-worktrees` | Isolated git worktrees for feature work |
| `using-superpowers` | Establishes how to find and use skills at conversation start |
| `verification-before-completion` | Evidence-based verification before claiming work is done |
| `writing-plans` | Multi-step task planning before touching code |
| `writing-skills` | Create, edit, and verify skills before deployment |

### Agents (130 across 10 categories)

| Category | Count | Examples |
|----------|------:|---------|
| `01-core-development` | 10 | api-designer, fullstack-developer, ui-designer |
| `02-language-specialists` | 26 | python-pro, typescript-pro, rust-engineer, golang-pro |
| `03-infrastructure` | 16 | kubernetes-specialist, terraform-engineer, docker-expert |
| `04-quality-security` | 14 | code-reviewer, security-auditor, penetration-tester |
| `05-data-ai` | 12 | ai-engineer, llm-architect, data-scientist |
| `06-developer-experience` | 13 | cli-developer, refactoring-specialist, mcp-developer |
| `07-specialized-domains` | 12 | fintech-engineer, game-developer, blockchain-developer |
| `08-business-product` | 11 | product-manager, technical-writer, ux-researcher |
| `09-meta-orchestration` | 10 | workflow-orchestrator, multi-agent-coordinator |
| `10-research-analysis` | 6 | research-analyst, competitive-analyst, trend-analyst |

Browse agents: `ls agents/` or `ls agents/<category>/`

## Backup

Sync local `~/.claude/` changes back to the repo (secrets are automatically stripped):

```bash
./backup.sh
git add -A && git commit -m "backup"
git push
```

## Adding Your Own

### New skill

Create `skills/<name>/SKILL.md`:

```yaml
---
name: my-new-skill
description: Use when <specific situation> — <what it checks/produces>
user-invocable: true
allowed-tools: Read, Grep, Glob
model: inherit
---

# My New Skill

Instructions for Claude when this skill is active...
```

### New agent

Create `agents/<category>/<name>.md`:

```yaml
---
name: my-new-agent
description: When to invoke this agent
tools: Read, Grep, Glob, Bash
model: sonnet
---

# My New Agent

Role description, expertise areas, guidelines...
```

**Model routing:** `opus` for deep reasoning, `sonnet` for everyday coding, `haiku` for quick tasks, `inherit` to match conversation model.

Run `./install.sh` after adding new content to create symlinks.

## Structure

```
astra/
├── global/
│   ├── CLAUDE.md                # Workflow orchestration instructions
│   ├── settings.json.example    # Settings template (no secrets)
│   └── plugins/
│       └── blocklist.json       # Plugin blocklist
├── skills/                      # 15 skill directories
│   ├── security-architect/
│   ├── brainstorming/
│   ├── writing-plans/
│   └── ...
├── agents/                      # 130 agents in 10 categories
│   ├── 01-core-development/
│   ├── 02-language-specialists/
│   ├── 03-infrastructure/
│   └── ...
├── hooks/                       # Hook configurations
├── commands/                    # Custom commands
├── install.sh                   # Symlink everything into ~/.claude/
└── backup.sh                    # Sync changes back to repo
```
