#!/usr/bin/env python3
"""
Render graphviz diagrams from a skill's SKILL.md to SVG files.

Usage:
    ./render-graphs.py <skill-directory>           # Render each diagram separately
    ./render-graphs.py <skill-directory> --combine  # Combine all into one diagram

Extracts all ```dot blocks from SKILL.md and renders to SVG.
Useful for helping your human partner visualize the process flows.

Requires: graphviz (dot) installed on system
"""

import re
import shutil
import subprocess
import sys
from pathlib import Path


def extract_dot_blocks(markdown: str) -> list[dict]:
    blocks = []
    for match in re.finditer(r"```dot\n([\s\S]*?)```", markdown):
        content = match.group(1).strip()
        name_match = re.search(r"digraph\s+(\w+)", content)
        name = name_match.group(1) if name_match else f"graph_{len(blocks) + 1}"
        blocks.append({"name": name, "content": content})
    return blocks


def extract_graph_body(dot_content: str) -> str:
    match = re.search(r"digraph\s+\w+\s*\{([\s\S]*)\}", dot_content)
    if not match:
        return ""
    body = match.group(1)
    # Remove rankdir (we'll set it once at the top level)
    body = re.sub(r"^\s*rankdir\s*=\s*\w+\s*;?\s*$", "", body, flags=re.MULTILINE)
    return body.strip()


def combine_graphs(blocks: list[dict], skill_name: str) -> str:
    subgraphs = []
    for i, block in enumerate(blocks):
        body = extract_graph_body(block["content"])
        indented = "\n".join("    " + line for line in body.splitlines())
        subgraphs.append(
            f'  subgraph cluster_{i} {{\n'
            f'    label="{block["name"]}";\n'
            f'{indented}\n'
            f'  }}'
        )
    joined = "\n\n".join(subgraphs)
    return (
        f"digraph {skill_name}_combined {{\n"
        f"  rankdir=TB;\n"
        f"  compound=true;\n"
        f"  newrank=true;\n\n"
        f"{joined}\n"
        f"}}"
    )


def render_to_svg(dot_content: str) -> str | None:
    try:
        result = subprocess.run(
            ["dot", "-Tsvg"],
            input=dot_content,
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error running dot: {e}", file=sys.stderr)
        if e.stderr:
            print(e.stderr, file=sys.stderr)
        return None
    except FileNotFoundError:
        print("Error: graphviz (dot) not found. Install with:", file=sys.stderr)
        print("  brew install graphviz          # macOS", file=sys.stderr)
        print("  apt install graphviz           # Linux", file=sys.stderr)
        print("  choco install graphviz         # Windows (Chocolatey)", file=sys.stderr)
        print("  winget install Graphviz.Graphviz  # Windows (winget)", file=sys.stderr)
        return None


def main() -> None:
    args = [a for a in sys.argv[1:]]
    combine = "--combine" in args
    positional = [a for a in args if not a.startswith("--")]

    if not positional:
        print("Usage: render-graphs.py <skill-directory> [--combine]", file=sys.stderr)
        print("", file=sys.stderr)
        print("Options:", file=sys.stderr)
        print("  --combine    Combine all diagrams into one SVG", file=sys.stderr)
        print("", file=sys.stderr)
        print("Example:", file=sys.stderr)
        print("  ./render-graphs.py ../subagent-driven-development", file=sys.stderr)
        print("  ./render-graphs.py ../subagent-driven-development --combine", file=sys.stderr)
        sys.exit(1)

    skill_dir = Path(positional[0]).resolve()
    skill_file = skill_dir / "SKILL.md"
    skill_name = skill_dir.name.replace("-", "_")

    if not skill_file.exists():
        print(f"Error: {skill_file} not found", file=sys.stderr)
        sys.exit(1)

    # Check if dot is available
    if shutil.which("dot") is None:
        print("Error: graphviz (dot) not found. Install with:", file=sys.stderr)
        print("  brew install graphviz          # macOS", file=sys.stderr)
        print("  apt install graphviz           # Linux", file=sys.stderr)
        print("  choco install graphviz         # Windows (Chocolatey)", file=sys.stderr)
        print("  winget install Graphviz.Graphviz  # Windows (winget)", file=sys.stderr)
        sys.exit(1)

    markdown = skill_file.read_text()
    blocks = extract_dot_blocks(markdown)

    if not blocks:
        print(f"No ```dot blocks found in {skill_file}")
        sys.exit(0)

    print(f"Found {len(blocks)} diagram(s) in {skill_dir.name}/SKILL.md")

    output_dir = skill_dir / "diagrams"
    output_dir.mkdir(exist_ok=True)

    if combine:
        combined = combine_graphs(blocks, skill_name)
        svg = render_to_svg(combined)
        if svg:
            output_path = output_dir / f"{skill_name}_combined.svg"
            output_path.write_text(svg)
            print(f"  Rendered: {skill_name}_combined.svg")

            dot_path = output_dir / f"{skill_name}_combined.dot"
            dot_path.write_text(combined)
            print(f"  Source: {skill_name}_combined.dot")
        else:
            print("  Failed to render combined diagram", file=sys.stderr)
    else:
        for block in blocks:
            svg = render_to_svg(block["content"])
            if svg:
                output_path = output_dir / f"{block['name']}.svg"
                output_path.write_text(svg)
                print(f"  Rendered: {block['name']}.svg")
            else:
                print(f"  Failed: {block['name']}", file=sys.stderr)

    print(f"\nOutput: {output_dir}/")


if __name__ == "__main__":
    main()
