#!/usr/bin/env bash
# ci/check-jenkinsfile-syntax.sh — parse-check ci/Jenkinsfile.skills.ci
# without requiring a Jenkins install.
#
# Uses the system `groovy` CLI (Groovy 4.x). Strips Jenkins-only
# annotations and library-provided class references that the bare
# GroovyShell can't resolve, then asks the parser to compile the rest.
# This catches real syntax errors (unbalanced braces, missing parens,
# bad string interpolation) on every CI run instead of waiting for a
# Jenkins job to surface them.
#
# Exit codes:
#   0   Jenkinsfile parses cleanly.
#   1   parse error (real syntactic bug — fix before push).
#   2   `groovy` not on PATH (install Groovy 4.x: brew install groovy
#       on macOS, apt-get install groovy on Ubuntu).

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-${SCRIPT_DIR}/Jenkinsfile.skills.ci}"

if ! command -v groovy >/dev/null 2>&1; then
    echo "ci/check-jenkinsfile-syntax.sh: \`groovy\` not on PATH. Install Groovy 4.x." >&2
    echo "  macOS:  brew install groovy" >&2
    echo "  Ubuntu: apt-get install groovy" >&2
    exit 2
fi

if [ ! -f "${TARGET}" ]; then
    echo "ci/check-jenkinsfile-syntax.sh: target not found: ${TARGET}" >&2
    exit 2
fi

WORKDIR="$(mktemp -d -t check-jf-XXXXXX)"
trap 'rm -rf "${WORKDIR}"' EXIT

cat > "${WORKDIR}/check.groovy" <<'EOF'
import org.codehaus.groovy.control.CompilerConfiguration
import org.codehaus.groovy.control.MultipleCompilationErrorsException

def args = this.binding.variables["args"] ?: []
if (args.size() == 0) {
    System.err.println("usage: check.groovy <Jenkinsfile>")
    System.exit(2)
}
def file = new File(args[0])
def content = file.text
def stripped = content
    .replaceAll(/(?m)^@Library\(.*\)\s*_\s*$/,            '// (stripped @Library)')
    .replaceAll(/(?m)^import org\.nvidia\.doca\..*$/,     '// (stripped doca import)')
    .replaceAll(/new GitUtils\(this\)/,                   'new Object()')
    .replaceAll(/Constants\.GITHUB_HTTPS_(CRED_ID|BASE_URL|USER_PASS_ID)/, '"<stub>"')

def shell = new GroovyShell(new CompilerConfiguration())
try {
    shell.parse(stripped, file.name)
    println "OK: ${args[0]} parses cleanly (Groovy ${GroovySystem.version})."
} catch (MultipleCompilationErrorsException e) {
    System.err.println("FAIL: ${args[0]} has compilation errors:")
    System.err.println(e.message)
    System.exit(1)
}
EOF

exec groovy "${WORKDIR}/check.groovy" "${TARGET}"
