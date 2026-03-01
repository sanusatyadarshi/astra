#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${HOME}/.claude"

# Copy file, handling the case where symlinks resolve to the same path
backup_file() {
    local src="$1" dst="$2"
    if [ ! -f "$src" ]; then
        return 1
    fi
    # If src is a symlink pointing to dst (or same inode), it's already in sync
    local real_src real_dst
    real_src="$(readlink -f "$src" 2>/dev/null || realpath "$src" 2>/dev/null || echo "$src")"
    real_dst="$(readlink -f "$dst" 2>/dev/null || realpath "$dst" 2>/dev/null || echo "$dst")"
    if [ "$real_src" = "$real_dst" ]; then
        return 0  # Already in sync via symlink
    fi
    cp -L "$src" "$dst"
}

echo "Backing up Claude config to astra..."

# Backup CLAUDE.md
if backup_file "${CLAUDE_HOME}/CLAUDE.md" "${SCRIPT_DIR}/global/CLAUDE.md"; then
    echo "  Backed up CLAUDE.md"
else
    echo "  Skipped CLAUDE.md (not found)"
fi

# Backup plugins
if backup_file "${CLAUDE_HOME}/plugins/blocklist.json" "${SCRIPT_DIR}/global/plugins/blocklist.json"; then
    echo "  Backed up plugins/blocklist.json"
else
    echo "  Skipped blocklist.json (not found)"
fi

# Backup all skills
for skill_dir in "${CLAUDE_HOME}/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "${skill_dir}")"
    if [ -f "${skill_dir}/SKILL.md" ]; then
        mkdir -p "${SCRIPT_DIR}/skills/${skill_name}"
        if backup_file "${skill_dir}/SKILL.md" "${SCRIPT_DIR}/skills/${skill_name}/SKILL.md"; then
            echo "  Backed up skill: ${skill_name}"
        fi
    fi
done

# Backup all agents
for agent_file in "${CLAUDE_HOME}/agents"/*.md; do
    [ -f "$agent_file" ] || continue
    mkdir -p "${SCRIPT_DIR}/agents"
    if backup_file "${agent_file}" "${SCRIPT_DIR}/agents/$(basename "${agent_file}")"; then
        echo "  Backed up agent: $(basename "${agent_file}")"
    fi
done

# Update settings example (strip secrets, strip sensitive URLs)
if [ -f "${CLAUDE_HOME}/settings.json" ]; then
    python3 -c "
import json, sys
with open('${CLAUDE_HOME}/settings.json') as f:
    cfg = json.load(f)
env = cfg.get('env', {})
for k, v in env.items():
    if 'TOKEN' in k or 'KEY' in k or 'SECRET' in k or 'PASSWORD' in k:
        env[k] = '<your-' + k.lower().replace('_', '-') + '>'
    elif 'URL' in k:
        env[k] = '<your-api-endpoint>'
print(json.dumps(cfg, indent=2))
" > "${SCRIPT_DIR}/global/settings.json.example"
    echo "  Updated settings.json.example (secrets stripped)"
fi

echo ""
echo "Done. Review changes with: cd ${SCRIPT_DIR} && git diff"
