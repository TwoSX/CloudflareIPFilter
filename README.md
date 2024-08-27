# Cloudflare 优选 IP

## 说明

- 筛选有效反代 IP
- 对 IP 不同端口进行测速
- 整理出优选 IP, 自动上传

参考：[自建 Cloudflare 优选 IP 筛选](https://www.twosx.xyz/self-built-cloudflare-optimal-ip-filter)

## 使用

先下载测速工具 https://github.com/XIU2/CloudflareSpeedTest/releases/tag/v2.2.5

下载合适系统的版本, 把 `CloudflareST` 放到项目根目录

```shell
# 授权
chmod +x CloudflareST
chmod +x *.sh

# 运行
bash ./run.sh
```

可根据需要修改 `config.sh` 中的参数

最终结果保存在 `output/speed_test/result.csv` 中
