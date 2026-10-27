#!/usr/bin/env bash
set -e

BASE_URL="${BASE_URL:-git@github.com:p2p-energy-trading-platform}"

if [ -n "$REPOS" ]; then
  read -r -a REPOS <<< "$REPOS"
fi

RESULTS_FILE=$(mktemp)
trap "rm -f $RESULTS_FILE" EXIT

add_result() {
  local repo="$1"
  local action="$2"
  local branch="$3"
  local status="$4"
  echo "$repo | $action | $branch | $status" >> "$RESULTS_FILE"
}

switch_repo() {
  local repo="$1"
  local display_name="$2"

  if [ ! -d "$repo" ]; then
    add_result "$display_name" "Skipped" "N/A" "Repository directory missing"
    return
  fi

  cd "$repo" || return
  if [ ! -d ".git" ]; then
    add_result "$display_name" "Skipped" "N/A" "Not a git repository"
    cd - >/dev/null
    return
  fi

  local current_branch
  current_branch=$(git branch --show-current)
  if [ -z "$current_branch" ]; then
    add_result "$display_name" "Skipped" "HEAD" "Detached HEAD state"
    cd - >/dev/null
    return
  fi

  if [ "$current_branch" = "main" ]; then
    add_result "$display_name" "Skipped" "main" "Already on main"
    cd - >/dev/null
    return
  fi

  # Check for uncommitted changes
  if [ -n "$(git status --porcelain)" ]; then
    add_result "$display_name" "Skipped" "$current_branch" "Uncommitted changes (dirty)"
    cd - >/dev/null
    return
  fi

  # Check for unpushed commits (pending pushes) if upstream exists
  if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    local ahead
    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
    if [ "$ahead" -gt 0 ]; then
      add_result "$display_name" "Skipped" "$current_branch" "Has $ahead unpushed commit(s)"
      cd - >/dev/null
      return
    fi
  fi

  # Check if 'main' branch exists locally
  if ! git show-ref --verify --quiet refs/heads/main; then
    add_result "$display_name" "Skipped" "$current_branch" "Local 'main' branch not found"
    cd - >/dev/null
    return
  fi

  # Perform switch to main
  if git checkout main >/dev/null 2>&1; then
    add_result "$display_name" "Switched" "main" "Switched from $current_branch"
  else
    add_result "$display_name" "Error" "$current_branch" "Failed to checkout main"
  fi

  cd - >/dev/null
}

echo "🔄 Evaluating repositories to safely switch to 'main'..."

# Check root workspace
if [ -d ".git" ]; then
  switch_repo "." "gridx-workspace (root)"
else
  add_result "gridx-workspace (root)" "Skipped" "N/A" "Not a git repository"
fi

# Check all microservices
for repo in "${REPOS[@]}"; do
  switch_repo "$repo" "$repo"
done

# Print Summary Table
echo ""
echo "=========================================================================================="
echo "📊 SWITCH TO MAIN SUMMARY REPORT"
echo "=========================================================================================="
printf "%-25s | %-12s | %-20s | %-35s\n" "Repository" "Action" "Branch" "Status Details"
printf "%-25s-|-%-12s-|-%-20s-|-%-35s\n" "-------------------------" "------------" "--------------------" "-----------------------------------"
while IFS='|' read -r r a b s; do
  r=$(echo "$r" | xargs)
  a=$(echo "$a" | xargs)
  b=$(echo "$b" | xargs)
  s=$(echo "$s" | xargs)
  printf "%-25s | %-12s | %-20s | %-35s\n" "$r" "$a" "$b" "$s"
done < "$RESULTS_FILE"
echo "=========================================================================================="