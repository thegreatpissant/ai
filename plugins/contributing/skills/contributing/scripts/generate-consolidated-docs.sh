#!/usr/bin/env bash
#
# generate-consolidated-docs.sh
#
# Generates consolidated views of base documents + their amendments.
# Output goes to docs/.consolidated/ (gitignored, never committed).
#
# Usage:
#   ./scripts/generate-consolidated-docs.sh          # all base documents
#   ./scripts/generate-consolidated-docs.sh VISION   # only VISION.md consolidated view
#
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
DOCS_DIR="$REPO_ROOT/docs"
AI_CONTEXT_DIR="$DOCS_DIR/ai-context"
OUTPUT_DIR="$DOCS_DIR/.consolidated"
FILTER="${1:-}"

mkdir -p "$OUTPUT_DIR"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Get the last commit hash that touched a file. Returns "uncommitted" if the
# file has never been committed.
commit_hash_for() {
    local file="$1"
    local hash
    hash=$(git log -1 --format="%h" -- "$file" 2>/dev/null || true)
    echo "${hash:-uncommitted}"
}

# Extract a frontmatter field value from a markdown file.
# Handles both single-value and simple list forms:
#   base_document: "VISION.md"           -> VISION.md
#   targets:\n  - "VISION.md"            -> VISION.md
frontmatter_field() {
    local file="$1"
    local field="$2"
    # Read frontmatter block (between first and second ---)
    local fm
    fm=$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$file")

    # Try single-value first: field: "value" or field: value
    local single
    single=$(echo "$fm" | grep -E "^${field}:" | head -1 | sed 's/^[^:]*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' || true)

    if [[ -n "$single" && "$single" != *"- "* ]]; then
        echo "$single"
        return
    fi

    # Try list form: field:\n  - "value"\n  - "value"
    echo "$fm" | awk -v field="$field" '
        $0 ~ "^"field":" { capture=1; next }
        capture && /^  - / { gsub(/^  - "?|"?$/, ""); print; next }
        capture && /^[^ ]/ { exit }
    '
}

# Extract the amendment number from frontmatter
amendment_number() {
    local file="$1"
    frontmatter_field "$file" "amendment" | tr -d '"'
}

# ---------------------------------------------------------------------------
# Discover base documents and amendments
# ---------------------------------------------------------------------------

# Find all amendment files across docs/ and docs/ai-context/
find_amendments() {
    find "$DOCS_DIR" -maxdepth 2 \
        -name '*AMENDMENT-[0-9]*' -o -name '*amendment-[0-9]*' \
        | sort
}

# Resolve a base_document reference to an actual file path.
# Handles: "VISION.md", "docs/ai-context/AI-integration-architecture.md",
# or bare filenames found in docs/ or docs/ai-context/.
resolve_base_doc() {
    local ref="$1"

    # Absolute or repo-relative path
    if [[ -f "$REPO_ROOT/$ref" ]]; then
        echo "$REPO_ROOT/$ref"
        return
    fi

    # Try docs/
    if [[ -f "$DOCS_DIR/$ref" ]]; then
        echo "$DOCS_DIR/$ref"
        return
    fi

    # Try docs/ai-context/
    if [[ -f "$AI_CONTEXT_DIR/$ref" ]]; then
        echo "$AI_CONTEXT_DIR/$ref"
        return
    fi

    # Not found
    return 1
}

# Map: base_doc_path -> space-separated list of amendment paths (sorted by number)
declare -A BASE_TO_AMENDMENTS
declare -A BASE_DOC_SEEN

while IFS= read -r amd_file; do
    [[ -z "$amd_file" ]] && continue

    # Get targets from frontmatter — try both "targets" (list) and
    # "base_document" (single value)
    targets=()
    while IFS= read -r t; do
        [[ -n "$t" ]] && targets+=("$t")
    done < <(frontmatter_field "$amd_file" "targets")

    if [[ ${#targets[@]} -eq 0 ]]; then
        local_bd=$(frontmatter_field "$amd_file" "base_document")
        [[ -n "$local_bd" ]] && targets+=("$local_bd")
    fi

    for target_ref in "${targets[@]}"; do
        base_path=$(resolve_base_doc "$target_ref") || {
            echo "WARNING: amendment $(basename "$amd_file") references '$target_ref' which was not found — skipping" >&2
            continue
        }
        BASE_DOC_SEEN["$base_path"]=1
        BASE_TO_AMENDMENTS["$base_path"]+="$amd_file"$'\n'
    done
done < <(find_amendments)

# Also discover base documents that have NO amendments (gap register, etc.)
# so we know the full set — but only generate consolidated views for those
# that actually have amendments.

# ---------------------------------------------------------------------------
# Generate consolidated views
# ---------------------------------------------------------------------------

generated=0

for base_path in "${!BASE_DOC_SEEN[@]}"; do
    base_name=$(basename "$base_path" .md)

    # Apply filter if provided
    if [[ -n "$FILTER" ]] && [[ "$base_name" != *"$FILTER"* ]]; then
        continue
    fi

    output_file="$OUTPUT_DIR/${base_name}-current.md"
    amendments_raw="${BASE_TO_AMENDMENTS[$base_path]:-}"

    # Sort amendments by their amendment number
    sorted_amendments=()
    while IFS= read -r amd; do
        [[ -z "$amd" ]] && continue
        num=$(amendment_number "$amd")
        echo "$num $amd"
    done <<< "$amendments_raw" | sort -n -k1 | while read -r _ path; do
        sorted_amendments+=("$path")
    done

    # Re-read sorted (the subshell above doesn't persist)
    sorted_amendments=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        sorted_amendments+=("$(echo "$line" | cut -d' ' -f2-)")
    done < <(
        while IFS= read -r amd; do
            [[ -z "$amd" ]] && continue
            num=$(amendment_number "$amd")
            echo "$num $amd"
        done <<< "$amendments_raw" | sort -n -k1
    )

    # Build provenance header
    base_hash=$(commit_hash_for "$base_path")
    base_rel=$(realpath --relative-to="$REPO_ROOT" "$base_path")

    {
        echo "---"
        echo "generated: true"
        echo "do_not_edit: true"
        echo "built_from:"
        echo "  - \"${base_rel} @ ${base_hash}\""

        for amd in "${sorted_amendments[@]}"; do
            amd_hash=$(commit_hash_for "$amd")
            amd_rel=$(realpath --relative-to="$REPO_ROOT" "$amd")
            echo "  - \"${amd_rel} @ ${amd_hash}\""
        done

        echo "generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "---"
        echo ""

        # Base document content (strip its own frontmatter if present)
        echo "<!-- ======================================== -->"
        echo "<!-- BASE DOCUMENT: ${base_rel} -->"
        echo "<!-- ======================================== -->"
        echo ""
        awk '
            BEGIN { in_fm=0; past_fm=0 }
            /^---$/ && !past_fm { in_fm = !in_fm; if (!in_fm) { past_fm=1 }; next }
            in_fm { next }
            { print }
        ' "$base_path"

        # Append each amendment
        for amd in "${sorted_amendments[@]}"; do
            amd_rel=$(realpath --relative-to="$REPO_ROOT" "$amd")
            amd_num=$(amendment_number "$amd")
            amd_title=$(frontmatter_field "$amd" "title")
            amd_status=$(frontmatter_field "$amd" "status")

            echo ""
            echo ""
            echo "<!-- ======================================== -->"
            echo "<!-- AMENDMENT ${amd_num}: ${amd_title} -->"
            echo "<!-- Status: ${amd_status} -->"
            echo "<!-- Source: ${amd_rel} -->"
            echo "<!-- ======================================== -->"
            echo ""

            # Strip frontmatter from amendment
            awk '
                BEGIN { in_fm=0; past_fm=0 }
                /^---$/ && !past_fm { in_fm = !in_fm; if (!in_fm) { past_fm=1 }; next }
                in_fm { next }
                { print }
            ' "$amd"
        done
    } > "$output_file"

    generated=$((generated + 1))
    echo "Generated: $output_file (base + ${#sorted_amendments[@]} amendment(s))"
done

if [[ $generated -eq 0 ]]; then
    if [[ -n "$FILTER" ]]; then
        echo "No base documents matching '$FILTER' with amendments found."
    else
        echo "No base documents with amendments found."
    fi
    exit 0
fi

echo ""
echo "Done. $generated consolidated view(s) in $OUTPUT_DIR/"
