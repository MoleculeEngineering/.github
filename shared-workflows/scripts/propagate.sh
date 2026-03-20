#!/bin/bash
ORG="MoleculeEngineering"
WORKFLOW_FILE="shared-workflows/check-main-merged.yml"
DEST_PATH=".github/workflows/check-main-merged.yml"

# --limit must exceed total repo count (647) so all repos are fetched
# before the pattern filter is applied.
# --no-archived skips read-only archived repos which would fail the API call.
REPOS=$(gh repo list $ORG --limit 1000 --no-archived --json name \
  -q '.[].name | select(startswith("api-auths") or startswith("mfe-tictactoe"))')

TOTAL=$(echo "$REPOS" | wc -l | tr -d ' ')
echo "Repos matched (api-* and mfe-*): $TOTAL"
echo "-----------------------------------"
echo "$REPOS"
echo "-----------------------------------"

SUCCEEDED=()
FAILED=()

for REPO in $REPOS; do
  echo "Processing $REPO..."

  # Check if file already exists and get its sha.
  # sha is required by the GitHub API when updating an existing file.
  SHA=$(gh api /repos/$ORG/$REPO/contents/$DEST_PATH \
    --jq '.sha' 2>/dev/null || echo "")

  if [ -z "$SHA" ]; then
    # File doesn't exist — create it.
    # [skip ci] prevents CircleCI from triggering a deployment on this commit.
    if gh api \
      --method PUT \
      -H "Accept: application/vnd.github+json" \
      /repos/$ORG/$REPO/contents/$DEST_PATH \
      --field message="chore: add main-sync validation workflow [skip ci]" \
      --field content="$(base64 -w 0 $WORKFLOW_FILE)" \
      --field branch="main" > /dev/null 2>&1; then
      echo "  ✓ Created"
      SUCCEEDED+=("$REPO")
    else
      echo "  ✗ Failed to create"
      FAILED+=("$REPO")
    fi
  else
    # File exists — update it using the existing sha.
    # [skip ci] prevents CircleCI from triggering a deployment on this commit.
    if gh api \
      --method PUT \
      -H "Accept: application/vnd.github+json" \
      /repos/$ORG/$REPO/contents/$DEST_PATH \
      --field message="chore: update main-sync validation workflow [skip ci]" \
      --field content="$(base64 -w 0 $WORKFLOW_FILE)" \
      --field sha="$SHA" \
      --field branch="main" > /dev/null 2>&1; then
      echo "  ✓ Updated"
      SUCCEEDED+=("$REPO")
    else
      echo "  ✗ Failed to update"
      FAILED+=("$REPO")
    fi
  fi
done

echo ""
echo "==================================="
echo "SUMMARY"
echo "==================================="
echo "Total repos processed : $TOTAL"
echo "Succeeded             : ${#SUCCEEDED[@]}"
echo "Failed                : ${#FAILED[@]}"

if [ ${#FAILED[@]} -gt 0 ]; then
  echo ""
  echo "Failed repos:"
  for REPO in "${FAILED[@]}"; do
    echo "  - $REPO"
  done
  echo ""
  echo "Re-run the script targeting only failed repos, or check"
  echo "permissions and branch protection settings for those repos."
fi