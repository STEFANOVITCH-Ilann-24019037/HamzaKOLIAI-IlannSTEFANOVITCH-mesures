#!/usr/bin/env bash
# Compte les lignes d'un projet, par extension + total.
# Usage : ./count_lines.sh [dossier] [--no-blank]
#   dossier     : racine du projet (défaut : dossier courant)
#   --no-blank  : ignore les lignes vides

set -euo pipefail

DIR="."
SKIP_BLANK=false
for arg in "$@"; do
  case "$arg" in
    --no-blank) SKIP_BLANK=true ;;
    -h|--help)  sed -n '2,5p' "$0"; exit 0 ;;
    *)          DIR="$arg" ;;
  esac
done

[[ -d "$DIR" ]] || { echo "Erreur : '$DIR' n'est pas un dossier" >&2; exit 1; }
cd "$DIR"

# Liste des fichiers : git ls-files si c'est un dépôt (respecte le .gitignore),
# sinon find en excluant les dossiers lourds habituels.
list_files() {
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    git ls-files -z --cached --others --exclude-standard
  else
    find . -type d \( -name .git -o -name node_modules -o -name vendor \
      -o -name dist -o -name build -o -name .next -o -name target \
      -o -name __pycache__ -o -name .venv -o -name venv -o -name .idea \
      -o -name .vscode -o -name coverage \) -prune -o -type f -print0
  fi
}

declare -A lines files
total_lines=0
total_files=0

while IFS= read -r -d '' f; do
  [[ -f "$f" ]] || continue
  # On saute les fichiers binaires
  grep -Iq . "$f" 2>/dev/null || continue
  # On saute les lockfiles, qui gonflent artificiellement le total
  case "$(basename "$f")" in
    package-lock.json|yarn.lock|pnpm-lock.yaml|composer.lock|Cargo.lock|poetry.lock) continue ;;
  esac

  name=$(basename "$f")
  if [[ "$name" == *.* && "$name" != .* ]]; then ext="${name##*.}"; else ext="(sans ext)"; fi

  if $SKIP_BLANK; then
    n=$(grep -cv '^[[:space:]]*$' "$f" || true)
  else
    n=$(wc -l < "$f")
  fi

  lines[$ext]=$(( ${lines[$ext]:-0} + n ))
  files[$ext]=$(( ${files[$ext]:-0} + 1 ))
  total_lines=$(( total_lines + n ))
  total_files=$(( total_files + 1 ))
done < <(list_files)

printf "%-14s %8s %10s\n" "EXTENSION" "FICHIERS" "LIGNES"
printf -- "-%.0s" {1..34}; echo
for ext in "${!lines[@]}"; do
  printf "%-14s %8d %10d\n" "$ext" "${files[$ext]}" "${lines[$ext]}"
done | sort -k3 -nr
printf -- "-%.0s" {1..34}; echo
printf "%-14s %8d %10d\n" "TOTAL" "$total_files" "$total_lines"
