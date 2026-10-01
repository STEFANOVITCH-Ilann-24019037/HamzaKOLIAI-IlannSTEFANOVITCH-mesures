#!/usr/bin/env bash
# Compte les lignes de chaque fichier d'un projet + total.
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

total_lines=0
total_files=0
results=""

while IFS= read -r -d '' f; do
  [[ -f "$f" ]] || continue
  grep -Iq . "$f" 2>/dev/null || continue   # saute les binaires
  case "$(basename "$f")" in                # saute les lockfiles
    package-lock.json|yarn.lock|pnpm-lock.yaml|composer.lock|Cargo.lock|poetry.lock) continue ;;
  esac

  if $SKIP_BLANK; then
    n=$(grep -cv '^[[:space:]]*$' "$f" || true)
  else
    n=$(wc -l < "$f")
  fi

  results+="$(printf "%8d  %s" "$n" "${f#./}")"$'\n'
  total_lines=$(( total_lines + n ))
  total_files=$(( total_files + 1 ))
done < <(list_files)

printf "%8s  %s\n" "LIGNES" "FICHIER"
printf -- "-%.0s" {1..40}; echo
printf "%s" "$results" | sort -nr
printf -- "-%.0s" {1..40}; echo
printf "%8d  TOTAL (%d fichiers)\n" "$total_lines" "$total_files"
