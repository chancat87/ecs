#!/usr/bin/env bash
#by spiritlhl
#From https://github.com/spiritLHLS/ecs
#2025.02.12

cd /root >/dev/null 2>&1
myvar=$(pwd)
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ipcheck.XXXXXX") || exit 1
SECURITY_CHECK_BIN="${TEMP_DIR}/securityCheck"
PORT_CHECKER_BIN="${TEMP_DIR}/pck"
IP_QUALITY_GOOGLE_FILE="${TEMP_DIR}/ip_quality_google"
IP_QUALITY_SECURITY_FILE="${TEMP_DIR}/ip_quality_security_check"
IP_QUALITY_EMAIL_FILE="${TEMP_DIR}/ip_quality_email_check"
cleanup_temp_dir() {
    if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf -- "$TEMP_DIR"
    fi
}
trap cleanup_temp_dir EXIT
ver="2026.08.27"
changeLog="IP质量测试，支持明确 DNS 解析失败时的保守 DoH 引导"
en_status=false
shorturl=""
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "alpine")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Alpine")
PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update" "yum -y update" "apk update -f")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "apk add -f")
CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")
rm -f -- sc_result.txt

# 安全的清屏函数
clear_screen() {
    if [ -t 1 ]; then
        tput clear 2>/dev/null || echo -e "\033[2J\033[H" || clear
    fi
}

utf8_locale=$(locale -a 2>/dev/null | grep -i -m 1 -E "UTF-8|utf8")
SYS="${CMD[0]}"
if [[ -z "$utf8_locale" ]]; then
    echo "No UTF-8 locale found"
else
    export LC_ALL="$utf8_locale"
    export LANG="$utf8_locale"
    export LANGUAGE="$utf8_locale"
    echo "Locale set to $utf8_locale"
fi

[[ -n $SYS ]] || exit 1
for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}"
        [[ -n $SYSTEM ]] && break
    fi
done

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"
_red() { echo -e "\033[31m\033[01m$*\033[0m"; }
_green() { echo -e "\033[32m\033[01m$*\033[0m"; }
_yellow() { echo -e "\033[33m\033[01m$*\033[0m"; }
_blue() { echo -e "\033[36m\033[01m$*\033[0m"; }
reading() { read -rp "$(_green "$1")" "$2"; }

os=$(uname -s)
arch=$(uname -m)

print_intro() {
    echo "-----------------------A Bench Script By spiritlhl-----------------------"
    echo "                   测评频道: https://t.me/+UHVoo2U4VyA5NTQ1                    "
    echo "版本：$ver"
    echo "更新日志：$changeLog"
}

check_and_cat_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        if [[ -s "$file" ]] && [[ "$(grep -vE '^\s*$' "$file")" ]]; then
            if ! grep -q "error" "$file"; then
                cat "$file"
            fi
        fi
    fi
}

format_output() {
    local file="$1"
    sed -i 's/\x1B\[[0-9;]*[JKmsu]//g' "$file"
    sed -i 's/^\[H//' "$file"
    if ! grep -q "A Bench Script By spiritlhl" "$file"; then
        sed -i '1i\-------------------- A Bench Script By spiritlhl ---------------------' "$file"
    fi
}

build_text() {
    cd "$myvar" >/dev/null 2>&1
    if [ -f "sc_result.txt" ]; then
        format_output "sc_result.txt"
        awk '/A Bench Script By spiritlhl/{flag=1} flag; /^$/{flag=0}' sc_result.txt >"$TEMP_DIR/sc_result.tmp" && mv "$TEMP_DIR/sc_result.tmp" sc_result.txt
        sed -i -e 's/\x1B\[[0-9;]\+[a-zA-Z]//g' sc_result.txt
        sed -i -e '/^$/d' sc_result.txt
        sed -i 's/\r//' sc_result.txt
        # 检查文件大小是否小于 25KB
        if [ ! -s sc_result.txt ]; then
            echo "The file sc_result.txt is empty and has not been uploaded."
            return
        fi
        file_size=$(wc -c <"sc_result.txt")
        if [ "$file_size" -ge 25600 ]; then
            echo "Files larger than 25KB (${file_size} bytes) are not uploaded."
            return
        fi
        if [ -s sc_result.txt ]; then
            http_short_url=$(curl_with_dns_bootstrap --ipv4 -sL -m 10 -X POST \
                -H "Authorization: $ST" \
                -F "file=@${myvar}/sc_result.txt" \
                "https://paste.spiritlhl.net/api/UL/upload")
            if [ $? -eq 0 ] && [ -n "$http_short_url" ] && echo "$http_short_url" | grep -q "show"; then
                file_id=$(echo "$http_short_url" | grep -o '[^/]*$')
                shorturl="https://paste.spiritlhl.net/#/show/${file_id}"
            else
                https_short_url=$(curl_with_dns_bootstrap --ipv6 -sL -m 10 -X POST \
                    -H "Authorization: $ST" \
                    -F "file=@${myvar}/sc_result.txt" \
                    "https://paste.spiritlhl.net/api/UL/upload")
                if [ $? -eq 0 ] && [ -n "$https_short_url" ] && echo "$https_short_url" | grep -q "show"; then
                    file_id=$(echo "$https_short_url" | grep -o '[^/]*$')
                    shorturl="https://paste.spiritlhl.net/#/show/${file_id}"
                else
                    shorturl=""
                fi
            fi
        fi
    fi
}

check_cdn() {
    local o_url=$1
    for cdn_url in "${cdn_urls[@]}"; do
        if curl_with_dns_bootstrap -sL --proto '=https' --proto-redir '=https' "$cdn_url$o_url" --max-time 6 | grep -q "success" >/dev/null 2>&1; then
            export cdn_success_url="$cdn_url"
            return
        fi
        sleep 0.5
    done
    export cdn_success_url=""
}

check_cdn_file() {
    check_cdn "https://raw.githubusercontent.com/spiritLHLS/ecs/main/back/test"
    if [ -n "$cdn_success_url" ]; then
        _yellow "CDN available, using CDN"
    else
        _yellow "No CDN available, using original links"
        export cdn_success_url=""
    fi
}

# =============== 无本地 DNS 时的保守引导 ===============
# Try the normal resolver first. Only an explicit curl "Could not resolve
# host" error activates a fixed-address encrypted DNS probe; transient HTTP,
# TLS, timeout, and packet-loss failures keep the original behavior.
DOH_QUERY_PAYLOAD="AAABAAABAAAAAAAAB2V4YW1wbGUDY29tAAABAAE"
DOH_BOOTSTRAP_CACHE="${TEMP_DIR}/doh-bootstrap.endpoint"
DOH_BOOTSTRAP_LOCK="${TEMP_DIR}/doh-bootstrap.lock"
## DOH_BOOTSTRAP_CATALOG_BEGIN
DOH_BOOTSTRAP_SPECS=(
    "AliDNS|dns.alidns.com|https://dns.alidns.com/dns-query|223.5.5.5,223.6.6.6,2400:3200::1,2400:3200:baba::1|223.5.5.5,223.6.6.6"
    "DNSPod|doh.pub|https://doh.pub/dns-query|1.12.12.12,120.53.53.53|1.12.12.12,120.53.53.53"
    "360 Public DNS|doh.360.cn|https://doh.360.cn/dns-query|101.198.192.33,101.198.193.29,101.199.254.118,112.65.69.15,123.6.48.18|101.198.192.33,101.198.193.29,101.199.254.118,112.65.69.15,123.6.48.18"
    "DNS.SB|doh.sb|https://doh.sb/dns-query|185.222.222.222,45.11.45.11|185.222.222.222,45.11.45.11"
    "Cloudflare|cloudflare-dns.com|https://cloudflare-dns.com/dns-query|1.0.0.1,1.1.1.1,104.16.248.249,104.16.249.249,2606:4700:4700::1001,2606:4700:4700::1111|1.0.0.1,1.1.1.1,104.16.248.249,104.16.249.249"
    "Google|dns.google|https://dns.google/dns-query|8.8.4.4,8.8.8.8,2001:4860:4860::8844,2001:4860:4860::8888|8.8.4.4,8.8.8.8"
    "Quad9 Unsecured|dns10.quad9.net|https://dns10.quad9.net/dns-query|149.112.112.10,9.9.9.10,2620:fe::10,2620:fe::fe:10|149.112.112.10,9.9.9.10"
    "OpenDNS|doh.opendns.com|https://doh.opendns.com/dns-query|146.112.41.2|146.112.41.2"
    "AdGuard Unfiltered|unfiltered.adguard-dns.com|https://unfiltered.adguard-dns.com/dns-query|94.140.14.140,94.140.14.141,2a10:50c0::1:ff,2a10:50c0::2:ff|94.140.14.140,94.140.14.141"
)
## DOH_BOOTSTRAP_CATALOG_END

curl_doh_supported() {
    command -v curl >/dev/null 2>&1 || return 1
    command curl --help all 2>/dev/null | grep -Fq -- "--doh-url"
}

doh_cache_read() {
    [ -s "$DOH_BOOTSTRAP_CACHE" ] || return 1
    IFS='|' read -r DOH_BOOTSTRAP_NAME DOH_BOOTSTRAP_HOST DOH_BOOTSTRAP_URL DOH_BOOTSTRAP_ADDRESSES <"$DOH_BOOTSTRAP_CACHE" || return 1
    [[ "$DOH_BOOTSTRAP_NAME" =~ ^[A-Za-z0-9._[:space:]-]+$ ]] || return 1
    [[ "$DOH_BOOTSTRAP_HOST" =~ ^[A-Za-z0-9.-]+$ ]] || return 1
    [[ "$DOH_BOOTSTRAP_URL" == https://* ]] || return 1
    [ -n "$DOH_BOOTSTRAP_ADDRESSES" ] || return 1
    return 0
}

doh_probe_spec() {
    local spec="$1"
    local name host endpoint addresses ipv4 result status content size latency response_file response_flags
    IFS='|' read -r name host endpoint addresses ipv4 <<<"$spec"
    response_file=$(mktemp "$TEMP_DIR/doh-response.XXXXXX") || return 1
    result=$(command curl --silent --show-error --fail --connect-timeout 2 --max-time 5 \
        --resolve "${host}:443:${addresses}" \
        -H 'Accept: application/dns-message' \
        -o "$response_file" -w '%{http_code}|%{content_type}|%{size_download}|%{time_total}' \
        "${endpoint}?dns=${DOH_QUERY_PAYLOAD}" 2>/dev/null) || {
        if [ "$addresses" = "$ipv4" ]; then
            rm -f -- "$response_file"
            return 1
        fi
        result=$(command curl --silent --show-error --fail --connect-timeout 2 --max-time 5 \
            --resolve "${host}:443:${ipv4}" \
            -H 'Accept: application/dns-message' \
            -o "$response_file" -w '%{http_code}|%{content_type}|%{size_download}|%{time_total}' \
            "${endpoint}?dns=${DOH_QUERY_PAYLOAD}" 2>/dev/null) || {
            rm -f -- "$response_file"
            return 1
        }
    }
    IFS='|' read -r status content size latency <<<"$result"
    response_flags=$(od -An -j 2 -N 1 -tu1 "$response_file" 2>/dev/null | tr -d '[:space:]')
    rm -f -- "$response_file"
    [[ "$status" = "200" && "$content" == *dns-message* ]] || return 1
    [[ "$size" =~ ^[0-9]+$ && "$size" -ge 12 ]] || return 1
    [[ "$response_flags" =~ ^[0-9]+$ && $((response_flags & 128)) -ne 0 ]] || return 1
    [[ "$latency" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
    printf '%s|%s|%s|%s|%s\n' "$latency" "$name" "$host" "$endpoint" "$addresses"
}

select_doh_bootstrap() {
    doh_cache_read && return 0
    curl_doh_supported || return 1
    mkdir -p "$TEMP_DIR" 2>/dev/null || return 1
    if mkdir "$DOH_BOOTSTRAP_LOCK" 2>/dev/null; then
        if doh_cache_read; then
            rmdir "$DOH_BOOTSTRAP_LOCK" 2>/dev/null || true
            return 0
        fi
        local probe_dir
        probe_dir=$(mktemp -d "$TEMP_DIR/doh-probes.XXXXXX") || {
            rmdir "$DOH_BOOTSTRAP_LOCK" 2>/dev/null || true
            return 1
        }
        local probe_pids=()
        local probe_index=0
        local spec
        for spec in "${DOH_BOOTSTRAP_SPECS[@]}"; do
            (doh_probe_spec "$spec" >"$probe_dir/$probe_index") &
            probe_pids+=("$!")
            probe_index=$((probe_index + 1))
        done
        local probe_pid
        for probe_pid in "${probe_pids[@]}"; do
            wait "$probe_pid" 2>/dev/null || true
        done
        local best=""
        local probe_file candidate
        for probe_file in "$probe_dir"/*; do
            [ -s "$probe_file" ] || continue
            candidate=$(sed -n '1p' "$probe_file")
            [[ "$candidate" =~ ^[0-9]+([.][0-9]+)?\| ]] || continue
            if [ -z "$best" ] || awk -F'|' -v left="$candidate" -v right="$best" 'BEGIN { exit !((left + 0) < (right + 0)) }'; then
                best="$candidate"
            fi
        done
        local selected_status=1
        if [ -n "$best" ]; then
            IFS='|' read -r _ DOH_BOOTSTRAP_NAME DOH_BOOTSTRAP_HOST DOH_BOOTSTRAP_URL DOH_BOOTSTRAP_ADDRESSES <<<"$best"
            printf '%s|%s|%s|%s\n' "$DOH_BOOTSTRAP_NAME" "$DOH_BOOTSTRAP_HOST" "$DOH_BOOTSTRAP_URL" "$DOH_BOOTSTRAP_ADDRESSES" >"$DOH_BOOTSTRAP_CACHE"
            doh_cache_read && selected_status=0
        fi
        for probe_file in "$probe_dir"/*; do
            [ -f "$probe_file" ] && rm -f -- "$probe_file"
        done
        rmdir "$probe_dir" 2>/dev/null || true
        rmdir "$DOH_BOOTSTRAP_LOCK" 2>/dev/null || true
        return "$selected_status"
    fi
    for _ in $(seq 1 60); do
        doh_cache_read && return 0
        [ -d "$DOH_BOOTSTRAP_LOCK" ] || break
        sleep 0.2
    done
    doh_cache_read
}

curl_with_dns_bootstrap() {
    local error_root="${TEMP_DIR:-${TMPDIR:-/tmp}}"
    local error_file
    error_file=$(mktemp "$error_root/curl-error.XXXXXX" 2>/dev/null) || {
        command curl "$@"
        return $?
    }
    local curl_status
    if command curl "$@" 2>"$error_file"; then
        curl_status=0
    else
        curl_status=$?
    fi
    if [ "$curl_status" -eq 0 ]; then
        rm -f -- "$error_file"
        return 0
    fi
    if ! grep -Fqi 'Could not resolve host' "$error_file"; then
        cat "$error_file" >&2
        rm -f -- "$error_file"
        return "$curl_status"
    fi
    if ! select_doh_bootstrap; then
        cat "$error_file" >&2
        rm -f -- "$error_file"
        return "$curl_status"
    fi
    local retry_error
    retry_error=$(mktemp "$error_root/curl-doh-error.XXXXXX" 2>/dev/null) || retry_error="$error_file"
    local retry_status
    if command curl "$@" \
        --doh-url "$DOH_BOOTSTRAP_URL" \
        --resolve "${DOH_BOOTSTRAP_HOST}:443:${DOH_BOOTSTRAP_ADDRESSES}" \
        2>"$retry_error"; then
        retry_status=0
    else
        retry_status=$?
    fi
    if [ "$retry_status" -ne 0 ]; then
        cat "$retry_error" >&2
    fi
    if [ "$retry_error" != "$error_file" ]; then
        rm -f -- "$retry_error"
    fi
    rm -f -- "$error_file"
    return "$retry_status"
}

pre_download() {
    local platform
    local machine
    case $os in
    Linux) platform="linux" ;;
    Darwin) platform="darwin" ;;
    FreeBSD) platform="freebsd" ;;
    *)
        echo "Unsupported operating system: $os"
        exit 1
        ;;
    esac
    case $arch in
    "x86_64" | "x86" | "amd64" | "x64") machine="amd64" ;;
    "i386" | "i686") machine="386" ;;
    "armv7l" | "armv8" | "armv8l" | "aarch64") machine="arm64" ;;
    *)
        echo "Unsupported architecture: $arch"
        exit 1
        ;;
    esac
    if ! curl_with_dns_bootstrap --fail --location --proto '=https' --proto-redir '=https' -o "$SECURITY_CHECK_BIN.download" "${cdn_success_url}https://github.com/oneclickvirt/securityCheck/releases/download/output/securityCheck-${platform}-${machine}"; then
        rm -f "$SECURITY_CHECK_BIN.download"
        return 1
    fi
    mv "$SECURITY_CHECK_BIN.download" "$SECURITY_CHECK_BIN"
    if ! curl_with_dns_bootstrap --fail --location --proto '=https' --proto-redir '=https' -o "$PORT_CHECKER_BIN.download" "${cdn_success_url}https://github.com/oneclickvirt/portchecker/releases/download/output/portchecker-${platform}-${machine}"; then
        rm -f "$PORT_CHECKER_BIN.download"
        return 1
    fi
    mv "$PORT_CHECKER_BIN.download" "$PORT_CHECKER_BIN"
}

translate_status() {
    if [[ "$1" == "false" ]]; then
        echo "No"
    elif [[ "$1" == "true" ]]; then
        echo "Yes"
    else
        echo "$1"
    fi
}

google() {
    local curl_result=$(curl_with_dns_bootstrap -sL -m 10 "https://www.google.com/search?q=www.spiritysdx.top" -H "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:54.0) Gecko/20100101 Firefox/54.0")
    rm -f "$IP_QUALITY_GOOGLE_FILE"
    if [ "$en_status" = true ]; then
        if echo "$curl_result" | grep -q "二叉树的博客"; then
            echo "Google search feasibility: YES" >>"$IP_QUALITY_GOOGLE_FILE"
        else
            echo "Google search feasibility: NO" >>"$IP_QUALITY_GOOGLE_FILE"
        fi
    else
        if echo "$curl_result" | grep -q "二叉树的博客"; then
            echo "Google搜索可行性：YES" >>"$IP_QUALITY_GOOGLE_FILE"
        else
            echo "Google搜索可行性：NO" >>"$IP_QUALITY_GOOGLE_FILE"
        fi
    fi
}

security_check() {
    local language=$1
    cd "$myvar" >/dev/null 2>&1
    if [ -f "$SECURITY_CHECK_BIN" ]; then
        chmod 700 "$SECURITY_CHECK_BIN"
        "$SECURITY_CHECK_BIN" -l "$language" -e yes | sed '1d' >>"$IP_QUALITY_SECURITY_FILE"
    fi
}

email_check() {
    cd "$myvar" >/dev/null 2>&1
    if [ -f "$PORT_CHECKER_BIN" ]; then
        chmod 700 "$PORT_CHECKER_BIN"
        "$PORT_CHECKER_BIN" | sed '1d' >>"$IP_QUALITY_EMAIL_FILE"
    fi
}

ST="OvwKx5qgJtf7PZgCKbtyojSU.MTcwMTUxNzY1MTgwMw"

next() {
    echo -en "\r"
    [ "${Var_OSRelease}" = "freebsd" ] && printf "%-72s\n" "-" | tr ' ' '-' && return
    printf "%-72s\n" "-" | sed 's/\s/-/g'
}

print_end_time() {
    end_time=$(date +%s)
    time=$((${end_time} - ${start_time}))
    if [ ${time} -gt 60 ]; then
        min=$(expr $time / 60)
        sec=$(expr $time % 60)
        echo " 总共花费        : ${min} 分 ${sec} 秒"
    else
        echo " 总共花费        : ${time} 秒"
    fi
    date_time=$(date +%Y-%m-%d" "%H:%M:%S)
    echo " 时间          : $date_time"
}

ipcheck() {
    {
        google
        if [[ $? -ne 0 ]]; then
            echo "Google检测执行失败" >>"$IP_QUALITY_GOOGLE_FILE"
        fi
    } &

    if [ "$en_status" = true ]; then
        {
            security_check "en"
            if [[ $? -ne 0 ]]; then
                echo "Security check failed" >>"$IP_QUALITY_SECURITY_FILE"
            fi
        } &
    else
        {
            security_check "zh"
            if [[ $? -ne 0 ]]; then
                echo "安全检查执行失败" >>"$IP_QUALITY_SECURITY_FILE"
            fi
        } &
    fi

    {
        email_check
        if [[ $? -ne 0 ]]; then
            echo "邮件端口检测执行失败" >>"$IP_QUALITY_EMAIL_FILE"
        fi
    } &

    # 等待所有后台任务完成
    wait

    # 检查并显示结果
    local has_output=false

    if [ -f "$IP_QUALITY_SECURITY_FILE" ]; then
        check_and_cat_file "$IP_QUALITY_SECURITY_FILE"
        has_output=true
    fi

    if [ -f "$IP_QUALITY_GOOGLE_FILE" ]; then
        check_and_cat_file "$IP_QUALITY_GOOGLE_FILE"
        has_output=true
    fi

    if [ "$en_status" = true ]; then
        echo -e "---------Email-Port-Detection--Base-On-oneclickvirt/portchecker----------"
    else
        echo -e "----------邮件端口检测--基于oneclickvirt/portchecker开源----------"
    fi

    if [ -f "$IP_QUALITY_EMAIL_FILE" ]; then
        check_and_cat_file "$IP_QUALITY_EMAIL_FILE"
        has_output=true
    fi

    # 如果没有任何输出，输出错误信息
    if [ "$has_output" = false ]; then
        echo "警告: 未能获取到任何检测结果"
    fi

    # 清理临时文件
    rm -f "$IP_QUALITY_SECURITY_FILE" "$IP_QUALITY_GOOGLE_FILE" "$IP_QUALITY_EMAIL_FILE"
}

main() {
    cdn_urls=("https://cdn0.spiritlhl.top/" "https://cdn.spiritlhl.net/")
    check_cdn_file
    pre_download || exit 1
    chmod 700 "$SECURITY_CHECK_BIN" 2>/dev/null
    # 清屏
    clear_screen
    start_time=$(date +%s)
    print_intro
    _yellow "数据仅作参考，不代表100%准确，IP类型如果不一致请手动查询多个数据库比对"
    echo -e "----------IP质量检测--基于oneclickvirt/securityCheck使用----------"
    # 执行检测并保存到临时文件
    temp_output=$(mktemp "$TEMP_DIR/output.XXXXXX")
    ipcheck | tee "$temp_output"
    # 检查输出
    if [ ! -s "$temp_output" ]; then
        echo "警告: 首次检测结果为空，正在重试..."
        sleep 2
        ipcheck | tee "$temp_output"
    fi
    rm -f "$temp_output"
    next
    print_end_time
    next
}

: >sc_result.txt
main | tee -i sc_result.txt
build_text
if [ -n "$shorturl" ]; then
    _green "  短链:"
    _blue "    $shorturl"
fi
cleanup_temp_dir
