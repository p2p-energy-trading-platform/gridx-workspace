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

# Check Root Workspace (gridx-workspace)
echo "🏠 Checking root workspace (gridx-workspace)..."
if [ -d ".git" ]; then
  root_branch=$(git branch --show-current)
  if [ -n "$(git status --porcelain)" ]; then
    add_result "gridx-workspace" "Skipped" "${root_branch:-HEAD}" "Dirty (uncommitted changes)"
  elif [ -z "$root_branch" ]; then
    add_result "gridx-workspace" "Skipped" "HEAD" "Detached HEAD state"
  elif ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    add_result "gridx-workspace" "Skipped" "$root_branch" "No upstream tracking branch"
  else
    if git pull --ff-only >/dev/null 2>&1; then
      add_result "gridx-workspace" "Pulled" "$root_branch" "Success (Fast-forward)"
    else
      add_result "gridx-workspace" "Error" "$root_branch" "Fast-forward failed (Diverged)"
    fi
  fi
else
  add_result "gridx-workspace" "N/A" "N/A" "Not a git repository"
fi

# Loop Through All Microservice Repositories
for repo in "${REPOS[@]}"; do
  echo "--------------------------------------------------"
  
  if [ ! -d "$repo" ]; then
    echo "📦 [MISSING] $repo - Cloning repository..."
    if git clone "$BASE_URL/$repo.git" >/dev/null 2>&1; then
      cd "$repo"
      cloned_branch=$(git branch --show-current)
      cd - >/dev/null
      add_result "$repo" "Cloned" "$cloned_branch" "Success"
    else
      add_result "$repo" "Cloned" "N/A" "Clone failed (Check permissions/URL)"
    fi
    continue
  fi

  echo "🔄 [CHECKING] $repo..."
  cd "$repo" || continue

  if [ ! -d ".git" ]; then
    add_result "$repo" "Skipped" "N/A" "Not a valid git repository"
    cd - >/dev/null
    continue
  fi

  if [ -n "$(git status --porcelain)" ]; then
    branch=$(git branch --show-current)
    add_result "$repo" "Skipped" "${branch:-HEAD}" "Dirty (uncommitted changes)"
    cd - >/dev/null
    continue
  fi

  branch=$(git branch --show-current)
  if [ -z "$branch" ]; then
    add_result "$repo" "Skipped" "HEAD" "Detached HEAD state"
    cd - >/dev/null
    continue
  fi

  if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    add_result "$repo" "Skipped" "$branch" "No upstream tracking branch"
    cd - >/dev/null
    continue
  fi

  if git pull --ff-only >/dev/null 2>&1; then
    add_result "$repo" "Pulled" "$branch" "Success (Fast-forward)"
  else
    add_result "$repo" "Error" "$branch" "Fast-forward failed (Diverged)"
  fi
  
  cd - >/dev/null
done

# Print Final Summary Table
echo ""
echo "=========================================================================================="
echo "📊 WORKSPACE SYNC SUMMARY REPORT"
echo "=========================================================================================="
printf "%-25s | %-12s | %-20s | %-32s\n" "Repository" "Action" "Branch" "Status Details"
printf "%-25s-|-%-12s-|-%-20s-|-%-32s\n" "-------------------------" "------------" "--------------------" "--------------------------------"
while IFS='|' read -r r a b s; do
  r=$(echo "$r" | xargs)
  a=$(echo "$a" | xargs)
  b=$(echo "$b" | xargs)
  s=$(echo "$s" | xargs)
  printf "%-25s | %-12s | %-20s | %-32s\n" "$r" "$a" "$b" "$s"
done < "$RESULTS_FILE"
echo "=========================================================================================="