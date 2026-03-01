# astra (अस्त्र)

Personal Claude Code configuration repo. Single source of truth for workflow instructions, skills, agents, and plugins.

One script to set up. One script to back up. No secrets committed.

## Setup

```bash
git clone git@github.com:<you>/astra.git
cd astra
./install.sh
```

This creates symlinks from `~/.claude/` into the repo, so edits are live immediately.

On first install, copy and fill in your settings:

```bash
cp global/settings.json.example ~/.claude/settings.json
# Edit with your API token and endpoint
```

## Backup

Sync local `~/.claude/` changes back to the repo (secrets are automatically stripped):

```bash
./backup.sh
git add -A && git commit -m "backup"
git push
```

## Structure

```
astra/
├── global/
│   ├── CLAUDE.md                # Workflow orchestration instructions
│   ├── settings.json.example    # Settings template (no secrets)
│   └── plugins/
│       └── blocklist.json       # Plugin blocklist
├── skills/
│   └── security-architect/
│       └── SKILL.md             # Security review skill
├── agents/                      # Agent definitions
├── hooks/                       # Hook configurations
└── commands/                    # Custom commands
```

## Adding Content

| What | How | Auto-discovered? |
|------|-----|-------------------|
| New skill | Create `skills/<name>/SKILL.md` | Yes |
| New agent | Create `agents/<name>.md` | Yes |
| New hook | Add to `hooks/` | Manual |
| New command | Create `commands/<name>.md` | Manual |
| Update workflow | Edit `global/CLAUDE.md` | Live via symlink |

No script changes needed for skills or agents — `install.sh` auto-discovers them.
