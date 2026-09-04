#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
catalog_path=${BASICS_CATALOG:-"$repo_root/../basics/network/resolver/endpoints_embed.json"}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/ecs-doh-test.XXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT

make_fake_curl() {
    local bin_dir="$1"
    mkdir -p "$bin_dir"
    cat >"$bin_dir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" >>"${FAKE_CURL_LOG:?}"
printf '\n' >>"${FAKE_CURL_LOG:?}"
if [[ "${1:-}" == "--help" && "${2:-}" == "all" ]]; then
    printf '%s\n' '      --doh-url <URL>'
    exit 0
fi
output=''
is_query=false
is_target=false
is_timeout=false
has_doh=false
for ((index = 1; index <= $#; index++)); do
    value="${!index}"
    case "$value" in
        -o|--output) next=$((index + 1)); output="${!next}" ;;
        --doh-url) has_doh=true ;;
        *'?dns='*) is_query=true ;;
        *target.example*) is_target=true ;;
        *timeout.example*) is_timeout=true ;;
    esac
done
if "$is_query"; then
    if [[ -n "$output" && "$output" != /dev/null ]]; then
        printf '\000\000\201\200\000\001\000\000\000\000\000\000' >"$output"
    fi
    printf '200|application/dns-message|12|0.010'
    exit 0
fi
if "$is_timeout"; then
    printf '%s\n' 'curl: (28) Connection timed out' >&2
    exit 28
fi
if "$is_target"; then
    if "$has_doh"; then
        printf '%s' 'downloaded-via-doh'
        exit 0
    fi
    printf '%s\n' 'curl: (6) Could not resolve host: target.example' >&2
    exit 6
fi
printf '%s\n' 'curl: (1) unexpected fake target' >&2
exit 1
EOF
    chmod +x "$bin_dir/curl"
}

extract_helper() {
    local script="$1"
    local destination="$2"
    local end_pattern='^pre_download\\(\\)'
    if [[ "$script" == ecs.sh ]]; then
        end_pattern='^# =============== 组件预安装及文件预下载 部分 ===============$'
    fi
    awk -v end_pattern="$end_pattern" '
        $0 == "# =============== 无本地 DNS 时的保守引导 ===============" { inside = 1 }
        inside && $0 ~ end_pattern { exit }
        inside { print }
    ' "$repo_root/$script" >"$destination"
}

test_script() {
    local script="$1"
    local test_dir="$work_dir/${script%.sh}"
    mkdir -p "$test_dir/bin" "$test_dir/tmp"
    make_fake_curl "$test_dir/bin"
    local helper="$test_dir/helper.sh"
    extract_helper "$script" "$helper"
    [[ -s "$helper" ]]
    PATH="$test_dir/bin:$PATH" FAKE_CURL_LOG="$test_dir/curl.log" TEMP_DIR="$test_dir/tmp" bash -s -- "$helper" <<'EOF'
set -euo pipefail
helper="$1"
source "$helper"
result=$(curl_with_dns_bootstrap --silent 'https://target.example/download')
[[ "$result" == downloaded-via-doh ]]
[[ -s "$DOH_BOOTSTRAP_CACHE" ]]
probes_before=$(grep -Fc '?dns=' "$FAKE_CURL_LOG")
result=$(curl_with_dns_bootstrap --silent 'https://target.example/download')
[[ "$result" == downloaded-via-doh ]]
[[ "$(grep -Fc '?dns=' "$FAKE_CURL_LOG")" == "$probes_before" ]]
if curl_with_dns_bootstrap --silent 'https://timeout.example/download' >/dev/null 2>&1; then
    echo 'timeout unexpectedly succeeded' >&2
    exit 1
fi
[[ "$(grep -Fc '?dns=' "$FAKE_CURL_LOG")" == "$probes_before" ]]
EOF
}

test_script ecs.sh
test_script ipcheck.sh
python3 "$repo_root/tools/sync_doh_catalog.py" --input "$catalog_path" --script "$repo_root/ecs.sh" --script "$repo_root/ipcheck.sh" --check
echo 'DoH bootstrap tests passed'
