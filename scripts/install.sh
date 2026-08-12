#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install.sh --global [--force] [--link] [SKILL ...]
  install.sh --project PATH [--force] [--link] [SKILL ...]

With no SKILL arguments, installs every top-level directory containing SKILL.md.

Options:
  --global        Install to ~/.config/opencode/skills.
  --project PATH  Install to PATH/.opencode/skills.
  --force         Replace an existing skill installation.
  --link          Create symbolic links instead of copying directories.
  -h, --help      Show this help.
EOF
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/.." && pwd)"
destination=""
force=false
link=false
skills=()

while (($#)); do
  case "$1" in
    --global)
      [[ -z "$destination" ]] || { printf 'Choose exactly one installation scope.\n' >&2; exit 2; }
      destination="${HOME:?HOME is not set}/.config/opencode/skills"
      shift
      ;;
    --project)
      [[ -z "$destination" ]] || { printf 'Choose exactly one installation scope.\n' >&2; exit 2; }
      (($# >= 2)) || { printf '%s requires a path.\n' "$1" >&2; exit 2; }
      destination="$(cd -- "$2" && pwd)/.opencode/skills"
      shift 2
      ;;
    --force)
      force=true
      shift
      ;;
    --link)
      link=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      skills+=("$1")
      shift
      ;;
  esac
done

[[ -n "$destination" ]] || { usage >&2; exit 2; }

if ((${#skills[@]} == 0)); then
  while IFS= read -r skill_file; do
    skills+=("$(basename -- "$(dirname -- "$skill_file")")")
  done < <(printf '%s\n' "$repo_dir"/*/SKILL.md 2>/dev/null)
fi

((${#skills[@]} > 0)) || { printf 'No skills found in %s.\n' "$repo_dir" >&2; exit 1; }

mkdir -p -- "$destination"

for skill in "${skills[@]}"; do
  [[ "$skill" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || {
    printf 'Invalid skill name: %s\n' "$skill" >&2
    exit 1
  }

  source_path="$repo_dir/$skill"
  target_path="$destination/$skill"
  [[ -f "$source_path/SKILL.md" ]] || {
    printf 'Skill not found: %s\n' "$skill" >&2
    exit 1
  }

  if [[ -e "$target_path" || -L "$target_path" ]]; then
    if [[ "$force" != true ]]; then
      printf 'Already installed: %s (use --force to replace)\n' "$target_path" >&2
      exit 1
    fi
    rm -rf -- "$target_path"
  fi

  if [[ "$link" == true ]]; then
    ln -s -- "$source_path" "$target_path"
    printf 'Linked %s -> %s\n' "$skill" "$target_path"
  else
    cp -R -- "$source_path" "$target_path"
    printf 'Installed %s -> %s\n' "$skill" "$target_path"
  fi
done

printf 'Restart OpenCode to load the installed skills.\n'
