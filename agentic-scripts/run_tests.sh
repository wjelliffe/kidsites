#!/usr/bin/env bash
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${repo_root}" ]]; then
  echo "run_tests.sh must be executed inside a git repository" >&2
  exit 1
fi

package_manager="npm"
if [[ -f "${repo_root}/pnpm-lock.yaml" ]]; then
  package_manager="pnpm"
elif [[ -f "${repo_root}/yarn.lock" ]]; then
  package_manager="yarn"
elif [[ -f "${repo_root}/bun.lockb" || -f "${repo_root}/bun.lock" ]]; then
  package_manager="bun"
fi

tests_json="$(
REPO_ROOT="${repo_root}" python3 <<'PY'
import json
import os

package_json = os.path.join(os.environ["REPO_ROOT"], "package.json")
if not os.path.exists(package_json):
    print("[]")
    raise SystemExit

with open(package_json, "r", encoding="utf-8") as handle:
    data = json.load(handle)

scripts = data.get("scripts", {})
ordered = [name for name in ("test", "test:unit", "test:integration") if name in scripts]
print(json.dumps(ordered))
PY
)"

mapfile -t tests < <(TESTS_JSON="${tests_json}" python3 <<'PY'
import json
import os

for entry in json.loads(os.environ["TESTS_JSON"]):
    print(entry)
PY
)

results=()
overall_status="pass"

run_script() {
  local name="$1"
  case "${package_manager}" in
    npm) npm run "${name}" ;;
    pnpm) pnpm run "${name}" ;;
    yarn) yarn "${name}" ;;
    bun) bun run "${name}" ;;
    *) return 127 ;;
  esac
}

for test_name in "${tests[@]}"; do
  output_file="$(mktemp)"
  start_time="$(python3 - <<'PY'
import time
print(time.time())
PY
)"
  if run_script "${test_name}" >"${output_file}" 2>&1; then
    exit_code=0
    status="pass"
  else
    exit_code=$?
    status="fail"
    overall_status="fail"
  fi
  end_time="$(python3 - <<'PY'
import time
print(time.time())
PY
)"
  results+=("$(TEST_NAME="${test_name}" STATUS="${status}" EXIT_CODE="${exit_code}" OUTPUT_FILE="${output_file}" START_TIME="${start_time}" END_TIME="${end_time}" python3 <<'PY'
import json
import os

with open(os.environ["OUTPUT_FILE"], "r", encoding="utf-8", errors="replace") as handle:
    output = handle.read().strip()

payload = {
    "name": os.environ["TEST_NAME"],
    "status": os.environ["STATUS"],
    "exit_code": int(os.environ["EXIT_CODE"]),
    "duration_seconds": round(float(os.environ["END_TIME"]) - float(os.environ["START_TIME"]), 3),
    "output": output[-4000:],
}

print(json.dumps(payload))
PY
)")
  rm -f "${output_file}"
done

RESULT_LINES="$(printf '%s\n' "${results[@]:-}")" OVERALL_STATUS="${overall_status}" python3 <<'PY'
import json
import os

lines = [line for line in os.environ.get("RESULT_LINES", "").splitlines() if line.strip()]
payload = {
    "ok": os.environ["OVERALL_STATUS"] != "fail",
    "overall_status": os.environ["OVERALL_STATUS"],
    "tests": [json.loads(line) for line in lines],
}
print(json.dumps(payload, indent=2))
PY
