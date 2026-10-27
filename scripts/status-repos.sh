#!/usr/bin/env bash
set -e

BASE_URL="${BASE_URL:-git@github.com:p2p-energy-trading-platform}"

if [ -n "$REPOS" ]; then
  read -r -a REPOS <<< "$REPOS"
fi

STATUS_FILE=$(mktemp)
trap "rm -f $STATUS_FILE" EXIT

inspect_repo() {
  local repo="$1"
  local display_name="$2"
  
  if [ ! -d "$repo" ]; then
    echo "$display_name | Missing | N/A | N/A" >> "$STATUS_FILE"
    return
  fi

  cd "$repo" || return
  if [ ! -d ".git" ]; then
    echo "$display_name | Not a git repo | N/A | N/A" >> "$STATUS_FILE"
    cd - >/dev/null
    return
  fi

  local branch
  branch=$(git branch --show-current)
  if [ -z "$branch" ]; then
    branch="HEAD (detached)"
  fi

  local wt="Clean"
  if [ -n "$(git status --porcelain)" ]; then
    wt="Dirty ⚠️"
  fi

  local tracking="No upstream"
  if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    local upstream
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u})
    
    # Calculate ahead/behind counts relative to upstream
    local counts
    counts=$(git rev-list --left-right --count @{u}...HEAD 2>/dev/null || echo "0 0")
    local behind=$(echo "$counts" | awk '{print $1}')
    local ahead=$(echo "$counts" | awk '{print $2}')
    
    if [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
      tracking="Up to date ($upstream)"
    elif [ "$ahead" -gt 0 ] && [ "$behind" -eq 0 ]; then
      tracking="Ahead by $ahead ($upstream)"
    elif [ "$ahead" -eq 0 ] && [ "$behind" -gt 0 ]; then
      tracking="Behind by $behind ($upstream)"
    else
      tracking="Diverged (Ahead:$ahead, Behind:$behind)"
    fi
  fi

  echo "$display_name | $branch | $tracking | $wt" >> "$STATUS_FILE"
  cd - >/dev/null
}

echo "🔍 Inspecting workspace repositories branch status..."

# Inspect root workspace
if [ -d ".git" ]; then
  inspect_repo "." "gridx-workspace (root)"
else
  echo "gridx-workspace (root) | Not a git repo | N/A | N/A" >> "$STATUS_FILE"
fi

# Inspect all microservices
for repo in "${REPOS[@]}"; do
  inspect_repo "$repo" "$repo"
done

# Print Status Table
echo ""
echo "===================================================================================================="
echo "🌿 WORKSPACE BRANCH STATUS REPORT"
echo "===================================================================================================="
printf "%-25s | %-20s | %-36s | %-12s\n" "Repository" "Branch" "Tracking Status" "Working Tree"
printf "%-25s-|-%-20s-|-%-36s-|-%-12s\n" "-------------------------" "--------------------" "------------------------------------" "------------"
while IFS='|' read -r r b t w; do
  r=$(echo "$r" | xargs)
  b=$(echo "$b" | xargs)
  t=$(echo "$t" | xargs)
  w=$(echo "$w" | xargs)
  printf "%-25s | %-20s | %-36s | %-12s\n" "$r" "$b" "$t" "$w"
done < "$STATUS_FILE"
echo "===================================================================================================="