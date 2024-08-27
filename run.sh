#!/bin/bash

# 打印日志，带时间
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') $1"
}

# 获取当前脚本所在目录
base_path=$(cd $(dirname $0) || exit; pwd)

log "当前目录: $base_path"

log "===> 开始过滤 Cloudflare 反代 IP"

# 执行 filter_ip.sh
bash "$base_path/filter_ip.sh"

log "===> 过滤 Cloudflare 反代 IP 完成"

log "===> 开始测速"

# 执行 speed_test.sh
bash "$base_path/speed_test.sh"

log "===> 测速完成"

log "===> 开始上传结果"

# 执行 upload_result.sh
bash "$base_path/upload_result.sh"

log "===> 上传结果完成"
