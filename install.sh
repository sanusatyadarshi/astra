#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${HOME}/.claude"

echo "Setting up Claude Code from astra..."

# Create directory structure
mkdir -p "${CLAUDE_HOME}/skills" "${CLAUDE_HOME}/plugins"

# Symlink global CLAUDE.md
ln -sfn "${SCRIPT_DIR}/global/CLAUDE.md" "${CLAUDE_HOME}/CLAUDE.md"
echo "  Linked CLAUDE.md"

# Symlink plugins
ln -sfn "${SCRIPT_DIR}/global/plugins/blocklist.json" "${CLAUDE_HOME}/plugins/blocklist.json"
echo "  Linked plugins/blocklist.json"

# Symlink all skills (auto-discovers new ones)
for skill_dir in "${SCRIPT_DIR}/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "${skill_dir}")"
    mkdir -p "${CLAUDE_HOME}/skills/${skill_name}"
    ln -sfn "${skill_dir}SKILL.md" "${CLAUDE_HOME}/skills/${skill_name}/SKILL.md"
    echo "  Linked skill: ${skill_name}"
done

# Symlink all agents
for agent_file in "${SCRIPT_DIR}/agents"/*.md; do
    [ -f "$agent_file" ] || continue
    mkdir -p "${CLAUDE_HOME}/agents"
    ln -sfn "${agent_file}" "${CLAUDE_HOME}/agents/$(basename "${agent_file}")"
    echo "  Linked agent: $(basename "${agent_file}")"
done

# Handle settings.json
if [ ! -f "${CLAUDE_HOME}/settings.json" ]; then
    echo ""
    echo "  No settings.json found. Copy the example and fill in your values:"
    echo "    cp ${SCRIPT_DIR}/global/settings.json.example ${CLAUDE_HOME}/settings.json"
    echo "    Then edit ~/.claude/settings.json with your API token and endpoint."
else
    echo "  settings.json already exists (skipped)"
fi

echo ""
echo "Done. Claude Code is ready."
