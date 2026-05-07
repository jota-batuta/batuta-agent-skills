#!/usr/bin/env bash
# post-edit-citation-warn.sh
# PostToolUse hook — Write|Edit
# Warns the model when newly written Python/TS/JS code contains import statements
# without an adjacent // Source: or # Source: citation comment.
#
# This implements the safety-net layer of rules/core/research-first-citations.md.
# The hook is NON-BLOCKING (always exits 0). Its output is a warning message
# on stderr that the model reads and acts on.
#
# Approach: read the file from disk (already written/patched by the time
# PostToolUse fires) and run grep-based analysis. Avoids parsing multiline
# content from stdin JSON.
#
# Fail-soft contract: any error exits 0. A broken hook must never block a session.

set +e
trap 'exit 0' ERR

input=$(cat 2>/dev/null || true)

# ---------------------------------------------------------------------------
# Parse file_path and tool_name from stdin JSON
# ---------------------------------------------------------------------------
if command -v jq >/dev/null 2>&1; then
  tool_name=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null)
  file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
  parsed=$(echo "$input" | HOOK_INPUT="$input" python3 -c '
import json, os, sys
try:
    d = json.loads(os.environ.get("HOOK_INPUT", "{}"))
    print("{}|{}".format(
        d.get("tool_name", ""),
        d.get("tool_input", {}).get("file_path", ""),
    ))
except Exception:
    print("|")
' 2>/dev/null)
  tool_name="${parsed%%|*}"
  file_path="${parsed#*|}"
else
  exit 0
fi

# Only process Write and Edit
case "$tool_name" in
  Write|Edit) ;;
  *) exit 0 ;;
esac

# Require a file_path
[[ -z "$file_path" ]] && exit 0

# ---------------------------------------------------------------------------
# Filter by extension — only Python and TS/JS family
# ---------------------------------------------------------------------------
ext="${file_path##*.}"
case "$ext" in
  py|ts|js|tsx|jsx|mjs|cjs) ;;
  *) exit 0 ;;
esac

# ---------------------------------------------------------------------------
# Exclude test files and vendored paths
# ---------------------------------------------------------------------------
case "$file_path" in
  */tests/*|*/test/*|*/__tests__/*|*/_test/*)  exit 0 ;;
  *_test.py|*.test.ts|*.test.js|*.spec.*)       exit 0 ;;
  */_vendored/*)                                 exit 0 ;;
esac

# ---------------------------------------------------------------------------
# File must exist on disk (Write has already written it; Edit has applied the patch)
# ---------------------------------------------------------------------------
[[ ! -f "$file_path" ]] && exit 0

# ---------------------------------------------------------------------------
# Language-specific settings
# ---------------------------------------------------------------------------
# Python stdlib modules that never need a Source: citation (incomplete but covers common cases).
# Rule: standard library modules ship with the interpreter; no external lookup needed.
PY_STDLIB="os|sys|re|json|pathlib|typing|datetime|collections|itertools|functools|io|logging|abc|dataclasses|enum|math|hashlib|base64|copy|time|threading|subprocess|shutil|glob|unittest|contextlib|traceback|inspect|types|weakref|string|struct|random|warnings|pprint|operator|tempfile|platform|signal|socket|ssl|stat|textwrap|csv|configparser|argparse|getpass|getopt|queue|heapq|bisect|array|decimal|fractions|numbers|cmath|statistics|secrets|hmac|uuid|pickle|shelve|sqlite3|zipfile|tarfile|gzip|bz2|lzma|zlib|html|http|urllib|xmlrpc|xml|email|mailbox|smtplib|ftplib|imaplib|nntplib|poplib|telnetlib|tokenize|token|ast|dis|py_compile|compileall|importlib|pkgutil|encodings|codecs|locale|gettext|unicodedata|readline|rlcompleter|pdb|profile|cProfile|timeit|trace|gc|resource|sysconfig|builtins|keyword|dis|code|codeop|zipimport|site|user|test|idlelib|tkinter|turtle|_thread|asyncio|concurrent|multiprocessing|ctypes"

# Node built-in modules that never need a Source: citation.
NODE_STDLIB="fs|path|url|crypto|http|https|net|os|child_process|stream|buffer|events|util|assert|querystring|readline|cluster|worker_threads|module|process|console|perf_hooks|vm|domain|tty|dgram|dns|zlib|v8|wasi|diagnostics_channel|inspector|trace_events|async_hooks|string_decoder|timers|punycode|repl"

# ---------------------------------------------------------------------------
# Read the file and find uncited imports
# ---------------------------------------------------------------------------
# Build the full file into a line-indexed array for lookups.
# We use mapfile (bash 4+) which is available on all modern Linux.
mapfile -t file_lines < "$file_path"
total_lines=${#file_lines[@]}

uncited_imports=()

for (( i=0; i<total_lines; i++ )); do
  line="${file_lines[$i]}"

  # Match import statements based on language
  is_import=0
  import_stmt=""
  if [[ "$ext" == "py" ]]; then
    if [[ "$line" =~ ^[[:space:]]*(import[[:space:]]+[A-Za-z_]|from[[:space:]]+[A-Za-z_.][A-Za-z0-9_.]*[[:space:]]+import) ]]; then
      is_import=1
      import_stmt="$line"
    fi
  else
    # TS/JS/TSX/JSX/MJS/CJS
    if [[ "$line" =~ ^[[:space:]]*(import[[:space:]]|const[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*require\() ]]; then
      is_import=1
      import_stmt="$line"
    fi
  fi

  [[ $is_import -eq 0 ]] && continue

  # ---------------------------------------------------------------------------
  # Stdlib exclusion check
  # ---------------------------------------------------------------------------
  skip=0
  if [[ "$ext" == "py" ]]; then
    # Extract the top-level module name from the import statement.
    # Handles: "import os", "import os.path", "from os import ...", "from pathlib import ..."
    mod=$(echo "$line" | sed -E 's/^[[:space:]]*(from[[:space:]]+([A-Za-z_][A-Za-z0-9_.]*)[[:space:]]+import.*|import[[:space:]]+([A-Za-z_][A-Za-z0-9_.]*).*)/\2\3/' | sed 's/\..*//' | tr -d '[:space:]')
    if [[ -n "$mod" ]] && echo "$mod" | grep -qE "^(${PY_STDLIB})$"; then
      skip=1
    fi
    # Also skip relative imports (from . import ..., from .. import ...)
    if [[ "$line" =~ ^[[:space:]]*from[[:space:]]+\.+ ]]; then
      skip=1
    fi
  else
    # Extract bare module name from: import X from 'y', import 'y', const x = require('y')
    mod=$(echo "$line" | grep -oE "(from|require\()[[:space:]]*['\"]([^'\"]+)['\"]" | grep -oE "['\"][^'\"]+['\"]" | tr -d "'\"" | head -1)
    if [[ -n "$mod" ]]; then
      # Strip leading ./ or ../ for relative imports — relative imports are internal, skip
      if [[ "$mod" =~ ^\./|^\.\. ]]; then
        skip=1
      else
        # Top-level module (first path segment)
        top_mod="${mod%%/*}"
        if echo "$top_mod" | grep -qE "^(${NODE_STDLIB})$"; then
          skip=1
        fi
      fi
    fi
  fi

  [[ $skip -eq 1 ]] && continue

  # ---------------------------------------------------------------------------
  # Check the 5 lines preceding this import for a Source: comment
  # ---------------------------------------------------------------------------
  # Window is lines max(0, i-5) to i-1 (0-indexed)
  start=$(( i > 5 ? i - 5 : 0 ))
  found_citation=0
  for (( j=start; j<i; j++ )); do
    prev="${file_lines[$j]}"
    if [[ "$ext" == "py" ]]; then
      # Note: no quotes around pattern — bash =~ with quoted RHS treats it as literal string,
      # which breaks [[:space:]] character class matching.
      if [[ "$prev" =~ \#[[:space:]]*Source: ]]; then
        found_citation=1
        break
      fi
    else
      # Same caveat: unquoted pattern so [[:space:]] is interpreted as a character class.
      # The // prefix does not need escaping inside [[ =~ ]].
      if [[ "$prev" =~ //[[:space:]]*Source: ]]; then
        found_citation=1
        break
      fi
    fi
  done

  if [[ $found_citation -eq 0 ]]; then
    # Trim whitespace for display
    trimmed=$(echo "$import_stmt" | sed 's/^[[:space:]]*//' | cut -c1-120)
    uncited_imports+=("$trimmed")
  fi
done

# ---------------------------------------------------------------------------
# Emit warning if any uncited imports were found
# ---------------------------------------------------------------------------
if [[ ${#uncited_imports[@]} -gt 0 ]]; then
  {
    echo "⚠️  research-first: ${file_path} has import(s) without Source: citation:"
    for stmt in "${uncited_imports[@]}"; do
      echo "    - ${stmt}"
    done
    echo "  Verify at Context7 or official docs and add a citation comment before this import."
    echo "  Format: # Source: <url> (verified YYYY-MM-DD, <lib>@<version>)  [Python]"
    echo "          // Source: <url> (verified YYYY-MM-DD, <lib>@<version>) [TS/JS]"
    echo "  Rule: rules/core/research-first-citations.md"
  } >&2
fi

exit 0
