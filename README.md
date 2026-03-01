# Astra (अस्त्र)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

I was working on Go microservices and got tired of re-explaining my preferences every session. Then I noticed the same problem everywhere: good workflows scattered across repos, useful techniques buried in random blog posts, patterns that took me months to figure out.

So I pulled together the best stuff I found into one setup. Skills that capture how I actually want to work. Agents for basically every domain. Clone it, run the install script, done.

**New here?** Read the [Getting Started Guide](GETTING-STARTED.md) — a complete walkthrough of using Astra to architect, build, debug, and deploy Go microservices.

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

| Skill                                                                              | Description                                                                         |
| ---------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| [`brainstorming`](skills/brainstorming/SKILL.md)                                   | Explores user intent, requirements and design before implementation                 |
| [`dispatching-parallel-agents`](skills/dispatching-parallel-agents/SKILL.md)       | Dispatch 2+ independent tasks that can be worked on without shared state            |
| [`executing-plans`](skills/executing-plans/SKILL.md)                               | Execute a written implementation plan in a separate session with review checkpoints |
| [`finishing-a-development-branch`](skills/finishing-a-development-branch/SKILL.md) | Structured options for merge, PR, or cleanup when implementation is complete        |
| [`receiving-code-review`](skills/receiving-code-review/SKILL.md)                   | Handle code review feedback with technical rigor, not blind implementation          |
| [`requesting-code-review`](skills/requesting-code-review/SKILL.md)                 | Verify work meets requirements before merging                                       |
| [`security-architect`](skills/security-architect/SKILL.md)                         | Security audits, threat modeling, vulnerability identification                      |
| [`subagent-driven-development`](skills/subagent-driven-development/SKILL.md)       | Execute implementation plans with independent tasks via subagents                   |
| [`systematic-debugging`](skills/systematic-debugging/SKILL.md)                     | Methodical debugging before proposing fixes                                         |
| [`test-driven-development`](skills/test-driven-development/SKILL.md)               | TDD workflow — write tests before implementation                                    |
| [`using-git-worktrees`](skills/using-git-worktrees/SKILL.md)                       | Isolated git worktrees for feature work                                             |
| [`using-astras`](skills/using-astras/SKILL.md)                                     | Establishes how to find and use skills at conversation start                        |
| [`verification-before-completion`](skills/verification-before-completion/SKILL.md) | Evidence-based verification before claiming work is done                            |
| [`writing-plans`](skills/writing-plans/SKILL.md)                                   | Multi-step task planning before touching code                                       |
| [`writing-skills`](skills/writing-skills/SKILL.md)                                 | Create, edit, and verify skills before deployment                                   |

### Agents (130 across 10 categories)

| Category                  | Count | Examples                                                                                                                                                                                                                                                     |
| ------------------------- | ----: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `01-core-development`     |    10 | [api-designer](agents/01-core-development/api-designer.md), [fullstack-developer](agents/01-core-development/fullstack-developer.md), [ui-designer](agents/01-core-development/ui-designer.md)                                                               |
| `02-language-specialists` |    26 | [python-pro](agents/02-language-specialists/python-pro.md), [typescript-pro](agents/02-language-specialists/typescript-pro.md), [rust-engineer](agents/02-language-specialists/rust-engineer.md), [golang-pro](agents/02-language-specialists/golang-pro.md) |
| `03-infrastructure`       |    16 | [kubernetes-specialist](agents/03-infrastructure/kubernetes-specialist.md), [terraform-engineer](agents/03-infrastructure/terraform-engineer.md), [docker-expert](agents/03-infrastructure/docker-expert.md)                                                 |
| `04-quality-security`     |    14 | [code-reviewer](agents/04-quality-security/code-reviewer.md), [security-auditor](agents/04-quality-security/security-auditor.md), [penetration-tester](agents/04-quality-security/penetration-tester.md)                                                     |
| `05-data-ai`              |    12 | [ai-engineer](agents/05-data-ai/ai-engineer.md), [llm-architect](agents/05-data-ai/llm-architect.md), [data-scientist](agents/05-data-ai/data-scientist.md)                                                                                                  |
| `06-developer-experience` |    13 | [cli-developer](agents/06-developer-experience/cli-developer.md), [refactoring-specialist](agents/06-developer-experience/refactoring-specialist.md), [mcp-developer](agents/06-developer-experience/mcp-developer.md)                                       |
| `07-specialized-domains`  |    12 | [fintech-engineer](agents/07-specialized-domains/fintech-engineer.md), [game-developer](agents/07-specialized-domains/game-developer.md), [blockchain-developer](agents/07-specialized-domains/blockchain-developer.md)                                      |
| `08-business-product`     |    11 | [product-manager](agents/08-business-product/product-manager.md), [technical-writer](agents/08-business-product/technical-writer.md), [ux-researcher](agents/08-business-product/ux-researcher.md)                                                           |
| `09-meta-orchestration`   |    10 | [workflow-orchestrator](agents/09-meta-orchestration/workflow-orchestrator.md), [multi-agent-coordinator](agents/09-meta-orchestration/multi-agent-coordinator.md)                                                                                           |
| `10-research-analysis`    |     6 | [research-analyst](agents/10-research-analysis/research-analyst.md), [competitive-analyst](agents/10-research-analysis/competitive-analyst.md), [trend-analyst](agents/10-research-analysis/trend-analyst.md)                                                |

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

## Contributing

Found a bug? Have an idea for a new skill or agent? PRs welcome.

- **Adding skills** — Create `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`, optionally `user-invocable`, `allowed-tools`, `model`)
- **Adding agents** — Create `agents/<category>/<name>.md` with YAML frontmatter (`name`, `description`, `tools`, `model`)
- **Docs improvements** — Broken links, missing hyperlinks, clarity fixes

Run `./install.sh` after adding new content to create symlinks. Test with `claude` before submitting.

## Acknowledgements

This repo stands on the shoulders of two amazing open-source projects:

- **[obra/superpowers](https://github.com/obra/superpowers)** by [Jesse Vincent](https://github.com/obra) — The original agentic skills framework and software development methodology that this repo is forked from. The skill architecture, workflow orchestration, and development philosophy all originate here. Jesse's work on making Claude Code genuinely productive is outstanding.

- **[VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)** by [VoltAgent](https://github.com/VoltAgent) — The incredible collection of 100+ specialized Claude Code subagents that powers the agents in this repo. A massive effort to cover every development use case imaginable.

Both projects are released under the **MIT license**, which made it possible to fork, customize, and combine them into a single unified setup tailored to my workflow. Huge thanks to the authors for their generosity in open-sourcing this work.
