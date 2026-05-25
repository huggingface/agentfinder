#!/usr/bin/env bash
set -euo pipefail

repo="${AI_CATALOG_REPO:-Agent-Card/ai-catalog}"
ref="${AI_CATALOG_REF:-main}"
source_dir="${AI_CATALOG_SOURCE_DIR:-specification}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
workspace_root="$(cd -- "${script_dir}/.." && pwd)"
dest_dir="${AI_CATALOG_DEST_DIR:-${workspace_root}/spec/ai-catalog}"

api_url="https://api.github.com/repos/${repo}/git/trees/${ref}?recursive=1"
raw_base_url="https://raw.githubusercontent.com/${repo}/${ref}"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

curl_headers=(
  --fail
  --location
  --silent
  --show-error
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  curl_headers+=(--header "Authorization: Bearer ${GITHUB_TOKEN}")
fi

echo "Fetching ${repo}@${ref}:${source_dir} file list..."
curl "${curl_headers[@]}" "${api_url}" >"${tmp_dir}/tree.json"

python - "${tmp_dir}/tree.json" "${source_dir}" >"${tmp_dir}/paths.txt" <<'PY'
import json
import sys
from pathlib import Path

tree_path = Path(sys.argv[1])
source_dir = sys.argv[2].strip("/")
prefix = f"{source_dir}/"

payload = json.loads(tree_path.read_text())
paths: list[str] = []

for item in payload.get("tree", []):
    path = item.get("path", "")
    if item.get("type") != "blob" or not path.startswith(prefix):
        continue
    if path.endswith((".md", ".json", ".schema.json")):
        paths.append(path)

for path in sorted(paths):
    print(path)
PY

if [[ ! -s "${tmp_dir}/paths.txt" ]]; then
  echo "No Markdown or JSON files found under ${repo}@${ref}:${source_dir}" >&2
  exit 1
fi

download_root="${tmp_dir}/download"
mkdir -p "${download_root}"

while IFS= read -r path; do
  relative_path="${path#${source_dir}/}"
  target_path="${download_root}/${relative_path}"
  mkdir -p "$(dirname -- "${target_path}")"
  echo "Downloading ${path}"
  curl "${curl_headers[@]}" "${raw_base_url}/${path}" >"${target_path}"
done <"${tmp_dir}/paths.txt"

cat >"${download_root}/SOURCE.md" <<EOF
# AI Catalog upstream source

Downloaded from \`${repo}\` at ref \`${ref}\`.

Source folder:

\`\`\`text
${source_dir}
\`\`\`

Refresh with:

\`\`\`bash
./scripts/update-ai-catalog-spec.sh
\`\`\`

Set \`AI_CATALOG_REF\`, \`AI_CATALOG_REPO\`, \`AI_CATALOG_SOURCE_DIR\`, or
\`AI_CATALOG_DEST_DIR\` to override the defaults.
EOF

rm -rf "${dest_dir}"
mkdir -p "$(dirname -- "${dest_dir}")"
mv "${download_root}" "${dest_dir}"

echo
echo "Updated ${dest_dir} with:"
find "${dest_dir}" -type f -print | sort
