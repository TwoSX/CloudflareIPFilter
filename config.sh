#!/bin/bash

# 获取当前脚本所在目录
base_path=$(cd $(dirname $0) || exit; pwd)
# 输出文件夹
out_path="${base_path}/output"
# 黑名单文件夹
cf_blacklist_path="${out_path}/cf_blacklist"
# 白名单文件夹
cf_whitelist_path="${out_path}/cf_whitelist"
# 结果文件夹
cf_ip_path="${out_path}/cf_ip"
# 原始ip列表文件夹
ip_list_path="${out_path}/ip_list"
# 测试结果保存路径
cf_test_save_path="$out_path/speed_test"

# 测速链接，分 http 和 https, 可参考 https://github.com/XIU2/CloudflareSpeedTest/discussions/490 修改
speed_test_url_http="http://ipv4.download.thinkbroadband.com/512MB.zip"
speed_test_url_https="https://speed.cloudflare.com/__down?bytes=200000000"

# 测速最低速度(MB/s)
speed_test_min_speed=8
# 最高延迟
speed_test_max_delay=500

# 上传链接, 参考 https://github.com/cmliu/CF-Workers-TEXT2KV
upload_url=""
upload_token="xxxxxxxxxxxxxxxxxxxxx"

# pushdeer 推送 key
push_key=""
