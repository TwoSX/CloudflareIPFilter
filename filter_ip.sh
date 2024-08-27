#!/bin/bash

base_path=$(cd $(dirname $0) || exit; pwd)

source "${base_path}/config.sh"

# https 端口
https_ports=("443" "2053" "2083" "2087" "2096" "8443")
# http 端口
http_ports=("80" "8080" "8880" "2052" "2082" "2086" "2095")

# 定义 User-Agent 列表
user_agents=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.101 Safari/537.36"
    "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Mobile/15E148 Safari/604.1"
    "Mozilla/5.0 (iPad; CPU OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/91.0.4472.80 Mobile/15E148 Safari/604.1"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.59"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 OPR/78.0.4093.112"
    "Mozilla/5.0 (Linux; Android 11; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36"
)

# 获取随机 User-Agent
get_random_user_agent() {
    echo "${user_agents[$RANDOM % ${#user_agents[@]}]}"
}

# 打印日志，带时间
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') $1"
}

# 获取ip列表
fetch_ip_list() {
    url=$1
    # 保存到 ip_list_path 文件夹
    [ ! -d "$ip_list_path" ] && mkdir -p "$ip_list_path"
    # 通过 url 获取文件名
    file_path="${ip_list_path}/$(basename "$url")"
    # 如果文件存在，则删除
    [ -f "$file_path" ] && rm -f "$file_path"
    # 下载文件
    curl -s "$url" -o "$file_path"
    # 输出文件内容, 一行一个ip，去除回车符和空行, 保存到第二个参数

    eval "$2=($(tr -d '\r' <"$file_path" | awk NF))"
}

# 将ip 和 端口加入黑名单
add_blacklist() {
    ip=$1
    port=$2

    # 如果文件不存在，创建文件
    if [ ! -f "${cf_blacklist_path}/${port}.txt" ]; then
        touch "${cf_blacklist_path}/${port}.txt"
    fi

    echo "$ip" >>"${cf_blacklist_path}/${port}.txt"
}

# 将ip 和 端口加入白名单
add_whitelist() {
    ip=$1
    port=$2

    # 如果文件不存在，创建文件
    if [ ! -f "${cf_whitelist_path}/${port}.txt" ]; then
        touch "${cf_whitelist_path}/${port}.txt"
    fi

    echo "$ip" >>"${cf_whitelist_path}/${port}.txt"
}

# 通过 port 获取黑名单
get_blacklist() {
    local port=$1
    local path=$cf_blacklist_path

    mkdir -p "${path}"
    [ ! -f "${path}/${port}.txt" ] && touch "${path}/${port}.txt"

    mapfile -t list < <(sed '/^$/d' "${path}/${port}.txt" | tr -d '\r')
    eval "$2=(${list[*]})"
}

# 通过 port 获取白名单
get_whitelist() {
    local port=$1
    local path=$cf_whitelist_path

    mkdir -p "${path}"
    [ ! -f "${path}/${port}.txt" ] && touch "${path}/${port}.txt"

    mapfile -t list < <(sed '/^$/d' "${path}/${port}.txt" | tr -d '\r')
    eval "$2=(${list[*]})"
}

# 写入到结果文件
add_to_result_file() {
    local port=$1
    local ip=$2

    [ ! -f "${cf_ip_path}/${port}.txt" ] && touch "${cf_ip_path}/${port}.txt"
    echo "$ip" >> "${cf_ip_path}/${port}.txt"
}

# 过滤 Cloudflare 代理 IP
filter_cf_proxy_ip() {
    local ip_list=("$@")
    local ports=("${https_ports[@]}" "${http_ports[@]}")
    local max_jobs=32

    log "开始过滤 Cloudflare 代理 IP..., 端口包括 ${ports[*]}"

    process_ip() {
        local port=$1
        local ip=$2

        local url="http://${ip}:${port}/cdn-cgi/trace"
        # echo "检测: $url"
        local user_agent=$(get_random_user_agent)
        local response=$(curl -s --max-time 2 -A "$user_agent" "$url")

        if [[ $response == *"cloudflare"* || $response == *"visit_scheme=http"* ]]; then
            add_to_result_file "$port" "$ip"
            add_whitelist "$ip" "$port"
            echo "通过: $ip:$port"
        else
            add_blacklist "$ip" "$port"
        fi
    }

    for port in "${ports[@]}"; do
        local blacklist=()
        local whitelist=()
        get_blacklist "$port" blacklist
        get_whitelist "$port" whitelist

        local -A blacklist_hash=()
        local -A whitelist_hash=()

        for ip in "${blacklist[@]}"; do blacklist_hash["$ip"]=1; done
        for ip in "${whitelist[@]}"; do whitelist_hash["$ip"]=1; done

        log "开始检测端口: $port ，黑名单: ${#blacklist[@]} 个，白名单: ${#whitelist[@]} 个"

        for ip in "${ip_list[@]}"; do
            if [[ -n "${whitelist_hash[$ip]}" ]]; then
                # echo "在白名单中: $ip $port"
                add_to_result_file "$port" "$ip"
                continue
            fi

            if [[ -n "${blacklist_hash[$ip]}" ]]; then
                # echo "在黑名单中: $ip $port"
                continue
            fi

            # echo "检测: $ip:$port"

            while [[ $(jobs -r | wc -l) -ge $max_jobs ]]; do
                sleep 0.5
            done

            process_ip "$port" "$ip" &
        done
    done

    wait
}

# 判断 item 是否在 list 中
is_item_in_list() {
    local item=$1
    shift
    local list=("$@")

    for i in "${list[@]}"; do
        [[ "$i" == "$item" ]] && return 0
    done

    return 1
}

main() {
    # 判断文件夹是否存在，不存在则创建
    [ ! -d "$out_path" ] && mkdir -p "$out_path"
    [ ! -d "$cf_blacklist_path" ] && mkdir -p "$cf_blacklist_path"
    [ ! -d "$cf_whitelist_path" ] && mkdir -p "$cf_whitelist_path"

    # result文件夹如果存在，把里面的 txt 文件备份 到 当前时间文件夹
    if [ -d "$cf_ip_path" ]; then
        # 存在 .txt 文件，才备份
        if [ -n "$(ls -A ${cf_ip_path}/*.txt 2>/dev/null)" ]; then
            local bak_path="${cf_ip_path}/bak_$(date +'%Y%m%d%H%M%S')"
            mkdir -p "$bak_path"
            mv "${cf_ip_path}"/*.txt "$bak_path"
        fi
    else
        mkdir -p "$cf_ip_path"
    fi

    ip_list_url=(
        'https://gh-proxy.com/https://raw.githubusercontent.com/China-xb/CloudflareCDNFission/main/US.txt'
        'https://gh-proxy.com/https://raw.githubusercontent.com/China-xb/CloudflareCDNFission/main/HK.txt'
        # 'https://gh-proxy.com/https://raw.githubusercontent.com/China-xb/CloudflareCDNFission/main/JP.txt'
    )

    log "开始下载ip列表..."

    ip_list=()
    for url in "${ip_list_url[@]}"; do
        fetch_ip_list "$url" ip_tmp_list

        ip_list+=("${ip_tmp_list[@]}")
    done

    log "下载完成, 共有${#ip_list[@]}个ip"

    # 如果ip列表为空，退出
    if [[ ${#ip_list[@]} -eq 0 ]]; then
        log "ip列表为空, 退出"
        exit 1
    fi

    filter_cf_proxy_ip "${ip_list[@]}"
}

main
