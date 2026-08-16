#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# GridX Workspace Complexity Analysis
#
# Measures STATIC CODE COMPLEXITY.
#
# It intentionally does NOT claim to measure:
# - production readiness
# - bug probability
# - security
# - architecture quality
# - test quality
# - delivery readiness
#
# Requirements:
#   pip install lizard
#
# Optional files:
#   .analysis-ignore
#   .analysis-maturity
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_DIR="$WORKSPACE_ROOT/complexity-analysis"
IGNORE_FILE="$WORKSPACE_ROOT/.analysis-ignore"
MATURITY_FILE="$WORKSPACE_ROOT/.analysis-maturity"

SUMMARY_FILE="$TARGET_DIR/executive_summary.md"
DETAILED_FILE="$TARGET_DIR/detailed_report.txt"

# Lizard CCN threshold used to identify individual hotspots.
CCN_WARNING_THRESHOLD=15

# ------------------------------------------------------------
# Validate environment
# ------------------------------------------------------------

if ! command -v lizard >/dev/null 2>&1; then
    echo "Error: 'lizard' is not installed or not available in PATH." >&2
    echo "Install it with: pip install lizard" >&2
    exit 1
fi

mkdir -p "$TARGET_DIR"

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

is_ignored() {
    local target="$1"

    [ -f "$IGNORE_FILE" ] || return 1

    # Normalize target
    target="${target#./}"
    target="${target%/}"

    while IFS= read -r line; do
        # Remove comments
        line="${line%%#*}"

        # Trim leading/trailing whitespace
        line="$(echo "$line" | xargs)"

        # Ignore blank lines
        [ -z "$line" ] && continue

        # Normalize ./folder and folder/
        line="${line#./}"
        line="${line%/}"

        if [ "$line" = "$target" ]; then
            return 0
        fi
    done < "$IGNORE_FILE"

    return 1
}


get_maturity() {
    local repo="$1"

    if [ ! -f "$MATURITY_FILE" ]; then
        echo "unknown"
        return
    fi

    local value

    value=$(
        awk -F '=' -v repo="$repo" '
            {
                sub(/#.*/, "")

                key=$1
                val=$2

                gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)

                if (key == repo) {
                    print val
                    exit
                }
            }
        ' "$MATURITY_FILE"
    )

    if [ -n "$value" ]; then
        echo "$value"
    else
        echo "unknown"
    fi
}


maturity_label() {
    case "$1" in
        not-started)
            echo "Not started"
            ;;
        skeleton)
            echo "Skeleton"
            ;;
        early)
            echo "Early implementation"
            ;;
        active)
            echo "Active development"
            ;;
        near-complete)
            echo "Near complete"
            ;;
        complete)
            echo "Complete / mature"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}


confidence_for_maturity() {
    case "$1" in
        not-started)
            echo "⚪ NONE"
            ;;
        skeleton)
            echo "🔵 LOW"
            ;;
        early)
            echo "🔵 LOW"
            ;;
        active)
            echo "🟡 MEDIUM"
            ;;
        near-complete)
            echo "🟢 HIGH"
            ;;
        complete)
            echo "🟢 HIGH"
            ;;
        *)
            echo "⚪ UNKNOWN"
            ;;
    esac
}


# Convert numeric complexity score to human-readable classification.
complexity_rating() {
    local score="$1"

    if (( score >= 70 )); then
        echo "🔴 SEVERE"
    elif (( score >= 45 )); then
        echo "🟠 ELEVATED"
    elif (( score >= 20 )); then
        echo "🟡 MODERATE"
    else
        echo "🟢 LOW"
    fi
}


# ------------------------------------------------------------
# Initialize reports
# ------------------------------------------------------------

cat > "$DETAILED_FILE" <<EOF
=========================================================
        GRIDX WORKSPACE COMPLEXITY REPORT
        Generated on: $(date)
        Lizard CCN warning threshold: $CCN_WARNING_THRESHOLD
=========================================================

EOF


cat > "$SUMMARY_FILE" <<'EOF'
# GridX Workspace — Static Complexity Summary

This report measures **static code complexity in the implementation that currently exists**.

It should not be interpreted as a direct measurement of production readiness,
bug probability, architectural quality, security, test coverage, or delivery risk.

Repositories at an early implementation stage may appear extremely healthy
simply because insufficient production logic exists to evaluate them reliably.

| Repository | Stage | NLOC | Functions | Avg NLOC | Avg CCN | Max CCN | Hotspots | Hotspot % | Static Complexity | Confidence |
| :--- | :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | :--- | :--- |
EOF


echo "Starting GridX complexity analysis..."

if [ -f "$IGNORE_FILE" ]; then
    echo "Using ignore rules from: $IGNORE_FILE"
fi

if [ -f "$MATURITY_FILE" ]; then
    echo "Using maturity metadata from: $MATURITY_FILE"
else
    echo "No $MATURITY_FILE found. Repository maturity will be reported as Unknown."
fi

echo

cd "$WORKSPACE_ROOT"

# ------------------------------------------------------------
# Analyze repositories
# ------------------------------------------------------------

for dir in */; do

    repo="${dir%/}"

    # Ignore the generated output folder.
    if [ ! -e "$dir/.git" ]; then
        echo "Skipping non-repository directory: $repo"
        continue
    fi

    if is_ignored "$repo"; then
        echo "Skipping ignored repository: $repo"
        continue
    fi

    echo "Analyzing: $repo"

    maturity=$(get_maturity "$repo")
    stage=$(maturity_label "$maturity")
    confidence=$(confidence_for_maturity "$maturity")

    echo "---------------------------------------------------------" >> "$DETAILED_FILE"
    echo " REPOSITORY: $repo" >> "$DETAILED_FILE"
    echo " MATURITY:   $stage" >> "$DETAILED_FILE"
    echo "---------------------------------------------------------" >> "$DETAILED_FILE"

    # --------------------------------------------------------
    # Run Lizard
    # --------------------------------------------------------

    lizard_output=$(
        lizard \
            -C "$CCN_WARNING_THRESHOLD" \
            "$dir" \
            2>&1 || true
    )

    printf '%s\n\n' "$lizard_output" >> "$DETAILED_FILE"


    # --------------------------------------------------------
    # Parse Lizard summary
    #
    # Expected structure:
    #
    # Total nloc   Avg.NLOC  AvgCCN ...
    # --------------------------------
    # 5309         12.3      1.7 ...
    # --------------------------------------------------------

    summary_line=$(
        printf '%s\n' "$lizard_output" |
        awk '
            /Total nloc[[:space:]]+Avg\.NLOC/ {
                # Skip separator line.
                getline

                # Read summary values.
                getline

                gsub(/^[[:space:]]+/, "")
                print
                exit
            }
        '
    )


    if [ -z "$summary_line" ]; then

        echo "| \`$repo\` | $stage | 0 | 0 | 0.0 | 0.0 | 0 | 0 | 0.0% | ⚪ NO ANALYZABLE CODE | $confidence |" \
            >> "$SUMMARY_FILE"

        echo "  No analyzable code found."
        echo

        continue
    fi


    # --------------------------------------------------------
    # Extract summary values
    #
    # Lizard:
    #
    # Total nloc
    # Avg.NLOC
    # AvgCCN
    # Avg.token
    # Fun Cnt
    # Warning cnt
    # Fun Rt
    # nloc Rt
    # --------------------------------------------------------

    read -r \
        nloc \
        avg_nloc \
        avg_ccn \
        avg_token \
        function_count \
        warning_count \
        fun_rate \
        nloc_rate \
        <<< "$summary_line"


    # Normalize values defensively.
    nloc="${nloc:-0}"
    avg_nloc="${avg_nloc:-0}"
    avg_ccn="${avg_ccn:-0}"
    function_count="${function_count:-0}"
    warning_count="${warning_count:-0}"


    # --------------------------------------------------------
    # Find maximum function CCN
    #
    # Restrict parsing to the individual function section,
    # before "X file analyzed."
    #
    # Function rows look roughly like:
    #
    # NLOC CCN TOKEN PARAM LENGTH LOCATION
    # 75   16  485   1     99   foo@...
    # --------------------------------------------------------

    max_ccn=$(
        printf '%s\n' "$lizard_output" |
        awk '
            /file analyzed\./ {
                finished=1
            }

            !finished &&
            $1 ~ /^[0-9]+$/ &&
            $2 ~ /^[0-9]+$/ &&
            $3 ~ /^[0-9]+$/ &&
            $4 ~ /^[0-9]+$/ &&
            $5 ~ /^[0-9]+$/ {

                if ($2 > max)
                    max=$2
            }

            END {
                print max + 0
            }
        '
    )


    # --------------------------------------------------------
    # Calculate hotspot percentage
    # --------------------------------------------------------

    hotspot_percent=$(
        awk \
            -v warnings="$warning_count" \
            -v functions="$function_count" '
        BEGIN {
            if (functions <= 0)
                printf "0.0"
            else
                printf "%.1f", (warnings / functions) * 100
        }
        '
    )


    # --------------------------------------------------------
    # Calculate static complexity score: 0 - 100
    #
    # 40 points — hotspot density
    # 20 points — average CCN
    # 20 points — average function size
    # 20 points — maximum CCN
    #
    # IMPORTANT:
    #
    # This is not a "business risk" score.
    # It measures concentration/severity of static code complexity.
    # --------------------------------------------------------

    complexity_score=$(
        awk \
            -v avg_ccn="$avg_ccn" \
            -v avg_nloc="$avg_nloc" \
            -v warnings="$warning_count" \
            -v functions="$function_count" \
            -v max_ccn="$max_ccn" '
        BEGIN {

            score = 0

            # ------------------------------------------------
            # Hotspot density — 40%
            # ------------------------------------------------

            if (functions > 0)
                density = warnings / functions
            else
                density = 0

            if      (density > 0.12) score += 40
            else if (density > 0.07) score += 32
            else if (density > 0.03) score += 24
            else if (density > 0.01) score += 12
            else                     score += 0


            # ------------------------------------------------
            # Average CCN — 20%
            #
            # Repo averages should be treated conservatively.
            # ------------------------------------------------

            if      (avg_ccn > 5.0) score += 20
            else if (avg_ccn > 4.0) score += 16
            else if (avg_ccn > 3.0) score += 12
            else if (avg_ccn > 2.0) score += 6


            # ------------------------------------------------
            # Average function size — 20%
            # ------------------------------------------------

            if      (avg_nloc > 60) score += 20
            else if (avg_nloc > 40) score += 16
            else if (avg_nloc > 30) score += 12
            else if (avg_nloc > 20) score += 6


            # ------------------------------------------------
            # Maximum CCN — 20%
            #
            # Captures individual severe hotspots that an
            # average would otherwise hide.
            # ------------------------------------------------

            if      (max_ccn > 40) score += 20
            else if (max_ccn > 30) score += 17
            else if (max_ccn > 20) score += 13
            else if (max_ccn > 15) score += 8
            else                   score += 0


            printf "%.0f", score
        }
        '
    )


    rating=$(complexity_rating "$complexity_score")


    # --------------------------------------------------------
    # Do not pretend skeletons are proven healthy.
    # --------------------------------------------------------

    case "$maturity" in

        not-started)
            rating="⚪ NOT ASSESSABLE"
            ;;

        skeleton)
            rating="🔵 LOW — EARLY CODEBASE"
            ;;

        early)
            rating="${rating}*"
            ;;

    esac


    # --------------------------------------------------------
    # Write summary row
    # --------------------------------------------------------

    echo "| \`$repo\` | $stage | $nloc | $function_count | $avg_nloc | $avg_ccn | $max_ccn | $warning_count | ${hotspot_percent}% | $rating | $confidence |" \
        >> "$SUMMARY_FILE"


    # --------------------------------------------------------
    # Console output
    # --------------------------------------------------------

    echo "  NLOC:              $nloc"
    echo "  Functions:         $function_count"
    echo "  Average NLOC:      $avg_nloc"
    echo "  Average CCN:       $avg_ccn"
    echo "  Maximum CCN:       $max_ccn"
    echo "  Hotspots:          $warning_count"
    echo "  Hotspot density:   ${hotspot_percent}%"
    echo "  Complexity score:  ${complexity_score}/100"
    echo "  Classification:    $rating"
    echo "  Confidence:        $confidence"
    echo

done


# ------------------------------------------------------------
# Add interpretation guide
# ------------------------------------------------------------

cat >> "$SUMMARY_FILE" <<'EOF'


---

## How to interpret this report

### Static Complexity

**🟢 LOW**

The analyzed implementation contains little concentrated static complexity.
This does **not** automatically mean the repository is production-ready.

**🟡 MODERATE**

Some functions or modules require more reasoning than normal.
Targeted review may be worthwhile, particularly as features expand.

**🟠 ELEVATED**

Complexity is becoming concentrated in multiple areas or in particularly
large/branch-heavy functions. Refactoring should be considered when those
areas are modified.

**🔴 SEVERE**

The analyzed implementation contains substantial concentrated complexity.
Large or highly branched functions are likely imposing significant cognitive
load on maintainers.

**🔵 LOW — EARLY CODEBASE**

Current code complexity is low, but implementation maturity is too low for the
metric to be considered strong evidence of long-term maintainability.

**⚪ NOT ASSESSABLE / NO ANALYZABLE CODE**

There is insufficient implementation for a meaningful static complexity
assessment.


## Assessment confidence

**🔵 LOW**

Skeleton or early-stage repository. Complexity may rise substantially as
business logic and integrations are implemented.

**🟡 MEDIUM**

A meaningful part of the implementation exists, but major layers or
integrations may still be incomplete.

**🟢 HIGH**

The repository is sufficiently implemented for static complexity metrics to
provide a meaningful maintainability signal.


## Metrics used

### Average CCN

Average cyclomatic complexity across analyzed functions.

Repository averages are treated as a secondary indicator because averages can
hide individual hotspots.


### Maximum CCN

The cyclomatic complexity of the most complex function found in the repository.

This helps expose "god functions" or decision-heavy algorithms that an average
would otherwise hide.


### Hotspots

Functions exceeding the configured Lizard cyclomatic-complexity threshold.

Current threshold:

`CCN > 15`


### Hotspot %

Calculated as:

`hotspot functions / total functions × 100`

This is more meaningful than comparing absolute warning counts between
repositories of very different sizes.


### Average NLOC

Average non-comment lines of code per function.

This is used as a rough indicator of how much code a developer must understand
within an individual unit.


---

## Important limitations

This report does **not** evaluate:

- automated test quality or coverage
- coupling between repositories
- runtime performance
- concurrency correctness
- database design
- security vulnerabilities
- API design quality
- backend/frontend integration quality
- deployment readiness
- observability maturity
- production reliability
- domain correctness

Static complexity should therefore be used as one engineering signal rather
than as a complete software quality score.
EOF


echo "========================================================="
echo "Analysis complete."
echo
echo "Reports:"
echo "  Executive summary: $SUMMARY_FILE"
echo "  Detailed report:   $DETAILED_FILE"
echo "========================================================="