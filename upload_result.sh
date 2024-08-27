#!/bin/bash

base_path=$(cd $(dirname $0) || exit; pwd)

source "${base_path}/config.sh"

#上传 http 文件名
http_file="addressesnotlsapi.txt"
#上传 https 文件名
https_file="addressesapi.txt"

# 打印日志，带时间
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') $1"
}

# 判断ip在ip_list_path的哪个文件中存在，返回文件名，如果不存在则返回 Unknown
get_ip_country() {
  ip=$1
  for file in "$ip_list_path"/*.txt; do
    [ -e "$file" ] || continue
    if grep -q "$ip" "$file"; then
      # 返回文件名，不要后缀
      basename "$file" .txt
      return
    fi
  done
  echo "Unknown"
}

transform_upload_text() {
  local arr=("$@")

  for item in "${arr[@]}"; do
    # 分割多个参数
    IFS=',' read -r ip port country delay speed <<<"$item"

    echo "$ip:$port#$country"
  done
}

upload_to_textasset() {
  local file=$1

  shift 1

  local data=("$@")

  # 判断 upload_url 和 upload_token 是否存在并且不为空
  if [ -z "$upload_url" ] || [ -z "$upload_token" ]; then
    log "upload_url 或 upload_token 为空，跳过上传"
    return
  fi

  local text

  text=$(transform_upload_text "${data[@]}")

  log "即将上传的文本："
  echo "$text"

  # base64 编码

  text=$(printf '%s' "$text" | base64 -w 0)

  local url="${upload_url}/${file}?token=${upload_token}&b64=${text}"

  echo "上传地址: $url"

  local response
  # 发起 Get 请求
  response=$(curl -s -o /dev/null -w "%{http_code}" "$url")

  if [ "$response" -eq 200 ]; then
    log "上传 $file 成功"
  else
    log "上传 $file 失败，状态码: $response"
  fi
}

# 去重，返回去重后的数组
remove_duplicate() {
  local data_var=$1
  local result_var=$2
  local ip port country speed
  local -a data

  # 读取传入的数据到数组中
  eval "data=(\"\${$data_var[@]}\")"

  local result=()
  local -a seen_ips=()
  local -a fastest_entries=()

  for line in "${data[@]}"; do
    IFS=',' read -r ip port country delay speed <<<"$line"
    local found=0

    # 查找是否已有该 IP
    for i in "${!seen_ips[@]}"; do
      if [[ "${seen_ips[$i]}" == "$ip" ]]; then
        found=1
        # 比较速度并替换
        local existing_speed="${fastest_entries[$i]%%,*}"
        if (($(awk -v s1="$speed" -v s2="$existing_speed" 'BEGIN {print (s1 > s2) ? 1 : 0}'))); then
          fastest_entries[$i]="$speed,$port,$country,$delay"
        fi
        break
      fi
    done

    # 如果 IP 不存在，添加到列表中
    if [[ $found -eq 0 ]]; then
      seen_ips+=("$ip")
      fastest_entries+=("$speed,$port,$country,$delay")
    fi
  done

  # 生成结果数组
  for i in "${!seen_ips[@]}"; do
    ip="${seen_ips[$i]}"
    IFS=',' read -r speed port country delay <<<"${fastest_entries[$i]}"
    result+=("$ip,$port,$country,$delay,$speed")
  done

  # 将结果数组返回
  eval "$result_var=(\"\${result[@]}\")"
}

urlencode() {
    local LC_ALL=C
    local string="$1"
    local length="${#string}"
    for (( i = 0; i < length; i++ )); do
        local c="${string:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "%s" "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
}

# 发送通知
send_notification() {
  # 判断 push_key 是否存在并且不为空
  if [ -z "$push_key" ]; then
    return
  fi

  local arr1_str="$1[@]"
  local arr2_str="$2[@]"
    
  local result_tls=("${!arr1_str}")
  local result_not_tls=("${!arr2_str}")

  # 生成消息, markdown 格式, 数组
  local message=()

  message+=("**HTTPS 优选结果:**")
  message+=("")
  
  for item in "${result_tls[@]}"; do
    message+=("* $item")
  done

  message+=("")
  message+=("**HTTP 优选结果:**")
  message+=("")

  for item in "${result_not_tls[@]}"; do
    message+=("* $item")
  done

  local desp
  desp=$(printf "%s\n" "${message[@]}")

  # 进行 urlencode
  desp=$(urlencode "$desp")

  local title="CF 优选 IP"
  title=$(urlencode "$title")

  local url="https://api2.pushdeer.com/message/push?pushkey=${push_key}&text=${title}&desp=${desp}&type=markdown"

  log "发送通知: $url"

  local response
  # 发起 Get 请求
  response=$(curl -s -o /dev/null -w "%{http_code}" "$url")

  if [ "$response" -eq 200 ]; then
    log "通知发送成功"
  else
    log "通知发送失败，状态码: $response"
  fi
}

# 写入到最终结果文件 csv
write_to_csv() {
  local arr1_str="$1[@]"
  local arr2_str="$2[@]"
    
  local result_tls=("${!arr1_str}")
  local result_not_tls=("${!arr2_str}")

  local text=()

  text+=("IP,端口,国家,延迟,速度")
  
  for item in "${result_tls[@]}"; do
    text+=("$item")
  done

  for item in "${result_not_tls[@]}"; do
    text+=("$item")
  done

  local file="$cf_test_save_path/result.csv"

  log "写入结果到 $file"

  local desp
  desp=$(printf "%s\n" "${text[@]}")

  echo "$desp" >"$file"
}

main() {

  log "开始上传结果, 目录: $cf_test_save_path"

  # 查找所有 csv 文件, 不读取子目录
  local files
  files=$(find "$cf_test_save_path" -maxdepth 1 -type f -name "*.csv")
  [ -z "$files" ] && echo "找不到任何文件，退出程序" && exit 1

  local result_tls=()
  local result_not_tls=()

  while IFS= read -r file; do
    local port
    port=$(basename "$file" .csv)

    # 必须是数字
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
      continue
    fi

    while IFS=',' read -r ip _ _ _ delay speed; do
      [[ -z $ip || -z $speed ]] && continue

      if ! awk -v speed="$speed" -v min="$speed_test_min_speed" 'BEGIN {exit !(speed >= min)}'; then
        continue
      fi

      local country
      country=$(get_ip_country "$ip")

      if [[ "$port" =~ ^(443|2053|2083|2087|2096|8443)$ ]]; then
        result_tls+=("$ip,$port,$country,$delay,$speed")
      else
        result_not_tls+=("$ip,$port,$country,$delay,$speed")
      fi
    done < <(tail -n +2 "$file")
  done <<<"$files"

  # 如果没有任何结果 直接退出
  if [[ ${#result_tls[@]} -eq 0 && ${#result_not_tls[@]} -eq 0 ]]; then
    log "没有任何结果，退出程序" 
    exit 0
  fi

  # 去重
  local filtered_result_tls filtered_result_not_tls
  remove_duplicate result_tls filtered_result_tls
  remove_duplicate result_not_tls filtered_result_not_tls

  log "HTTPS 优选结果:"
  for item in "${filtered_result_tls[@]}"; do
    echo "$item"
  done

  echo "----------------------------------------"

  log "HTTP 优选结果:"
  for item in "${filtered_result_not_tls[@]}"; do
    echo "$item"
  done

  # 发送通知
  send_notification filtered_result_tls filtered_result_not_tls

  # 写入到 csv
  write_to_csv filtered_result_tls filtered_result_not_tls

  echo "----------------------------------------"

  # 上传
  log "开始上传 HTTPS 优选结果"
  upload_to_textasset "$https_file" "${filtered_result_tls[@]}"

  echo "----------------------------------------"

  log "开始上传 HTTP 优选结果"
  upload_to_textasset "$http_file" "${filtered_result_not_tls[@]}"
}

main
