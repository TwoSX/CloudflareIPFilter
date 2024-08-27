#!/bin/bash

base_path=$(cd $(dirname $0) || exit; pwd)

source "${base_path}/config.sh"


# 打印日志，带时间
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') $1"
}

# 根据端口获取测速链接
get_speed_test_url() {
    local port=$1
    case $port in
        80|8080|8880|2052|2082|2086|2095)
            echo $speed_test_url_http
            ;;
        *)
            echo $speed_test_url_https
            ;;
    esac
}

# 获取文件列表
get_files() {
    local files=()
    for file in "$cf_ip_path"/*.txt; 
    do
        [ -e "$file" ] || continue
        local port=$(basename "$file" .txt)
        files+=("$port:$file")
    done
    echo "${files[@]}"
}

# 运行测试
run_test() {
    local port=$1
    local file_path=$2
    local save_path=$3

    local test_url=$(get_speed_test_url "$port")
    local save_file="$save_path/$port.csv"

    log "开始测试 $port 端口，运行命令为："

    # 构建命令
    local command=("$base_path/CloudflareST" "-httping" "-n" "10" "-t" "5" "-sl" "$speed_test_min_speed" "-tl" "$speed_test_max_delay" "-tp" "$port" "-url" "$test_url" "-f" "$file_path" "-o" "$save_file")

    # 打印出命令
    echo "${command[@]}"

    # 执行命令
    "${command[@]}"

    log "测试 $port 完成"
}

main() {
    # 判断是否存在 cf_ip 文件夹，不存在退出
    if [ ! -d "$cf_ip_path" ]; then
        log "cf_ip 文件夹不存在, 程序退出"
        exit 1
    fi

    # 判断 "$base_path/CloudflareST" 是否存在
    if [ ! -f "$base_path/CloudflareST" ]; then
        log "CloudflareST 文件不存在, 程序退出"
        exit 1
    fi

    # cf_test_save_path 如果存在，把文件夹的.csv文件备份到 bak_date 文件夹
    if [ -d "$cf_test_save_path" ]; then
        # 存在 .txt 文件，才备份
        if [ -n "$(ls -A ${cf_test_save_path}/*.csv 2>/dev/null)" ]; then
            local bak_path="${cf_test_save_path}/bak_$(date +'%Y%m%d%H%M%S')"
            mkdir -p "$bak_path"
            mv "${cf_test_save_path}"/*.csv "$bak_path"
        fi
    else
        mkdir -p "$cf_test_save_path"
    fi

    local save_path=$(realpath "$cf_test_save_path")

    log "结果将保存到: $save_path"

    local files=($(get_files))

    for file in "${files[@]}"; do
        local port="${file%%:*}"
        local file_path="${file##*:}"
        file_path=$(realpath "$file_path")

        run_test "$port" "$file_path" "$save_path"
    done
}

main
