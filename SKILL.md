---
name: mihomo-rules-management
description: >-
  Use when managing mihomo/clash-meta compatible RULE-SET proxy rulesets —
  syncing upstream domain lists (v2fly/Loyalsoldier/blackmatrix7),
  adding/reseeding brand rulesets, validating YAML format, generating platform
  configs (Nikki/Clash for Android), syncing icons from Oasisic-Icons, and
  operating the associated GitHub Actions CI/CD pipeline. Covers the
  Hawaiine/mihomo-rules project conventions.
version: 2.2.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [mihomo, clash, proxy, ruleset, sync, nikki, openwrt]
    related_skills: [github-actions-workflows, bash-projects, systematic-debugging, hermes-agent-skill-authoring]
---

# mihomo-rules 管理 Skill

## Overview

Manage a mihomo-compatible RULE-SET-level proxy ruleset repository (~105 brands, 320k+ rules). The project syncs upstream domain lists from multiple sources, validates YAML format with auto-fix, generates platform-specific configs for OpenWrt Nikki and Clash for Android, injects brand icons from Oasisic-Icons, and notifies via Discord webhook.

## When to Use

- 用户要求添加/修改/删除 ruleset 品牌规则集
- 需要同步上游域名数据（v2fly / Loyalsoldier / blackmatrix7）
- 校验 ruleset 文件格式是否符合规范
- 生成 Nikki（OpenWrt）或 Clash for Android 配置文件
- 同步品牌图标（Oasisic-Icons）
- 调试 GitHub Actions CI/CD 工作流
- 排查 Discord 通知失败

## 项目结构

```
mihomo-rules/
├── ruleset/                   # 规则集（每个品牌独立子目录）
│   ├── Direct/                # 基础规则集 (8个)
│   ├── Netflix/               # 品牌规则集 (105个)
│   └── .../
├── configs/                   # 平台配置文件
│   ├── Nikki/config.yaml      # OpenWrt Nikki (mihomo 内核)
│   └── Android/config.yaml    # Clash for Android
├── scripts/                   # 自动化脚本
│   ├── sync-upstream.sh       # 上游同步（v2fly + Loyalsoldier + blackmatrix7）
│   ├── generate-config.sh     # 配置生成（含 behavior 检测 + 图标注入）
│   ├── validate-ruleset.sh    # 格式校验 + 自动修复 + README 同步
│   └── sync-icons.sh          # Oasisic-Icons 图标同步
│   ├── parse-loyalsoldier.awk    # Loyalsoldier 解析器
│   └── parse-v2fly.awk           # v2fly 解析器
├── .github/workflows/
│   └── daily-sync.yml         # 每日同步工作流 (06:00 BJT)
├── CHANGELOG.md               # 变更日志
└── README.md                  # 项目主页
```

## 核心规范

### 1. 命名规范

- **目录结构**: `ruleset/<Brand>/<Brand>.yaml`（子目录 + 同名 yaml）
- **文件名**: PascalCase（如 `Netflix.yaml`, `AIService.yaml`）
- **去符号**: 去掉括号、`@`、`-`、`+` 等（`U-NEXT` → `UNext`, `Karaoke@DAM` → `KaraokeDam`）
- **缩写保留**: `AI`, `TV`, `CDN`, `IP`, `ID` 等常见缩写保持大写
- **Apple i-前缀**: `iCloud`, `iTunes` 等保持首字母小写
- **裸文件**: 无后缀的文件自动加 `.yaml`（`bagumi` → `Bagumi.yaml`）

### 2. 显示名映射

品牌文件名 → Config 策略组显示名（`get_brand_display_name()`）：

| 文件名 | 显示名 |
|--------|--------|
| `UNext` | `U-NEXT` |
| `ZLibrary` | `Z-Library` |
| `AppleIntelligence` | `Apple Intelligence` |
| `AppleTV` | `Apple TV` |
| `GoogleAI` | `Google AI` |
| `GeneralAI` | `General AI` |
| `YouTubeMusic` | `YouTube Music` |
| `PrimeVideo` | `Prime Video` |

### 3. Ruleset 文件格式

```yaml
# ===========================================
# Rule Name: Netflix
# Author: Hawaiine
# Updated: 2026-07-08 14:30:00
# DOMAIN: 27
# DOMAIN-KEYWORD: 0
# DOMAIN-SUFFIX: 1
# IP-CIDR: 8
# IP-CIDR6: 0
# PROCESS-NAME: 0
# ===========================================
payload:
  # --- DOMAIN (27) ---
  - DOMAIN,netflix.com
  # --- DOMAIN-SUFFIX (1) ---
  - DOMAIN-SUFFIX,nflxvideo.net
  # --- IP-CIDR (8) ---
  - IP-CIDR,10.0.0.0/8,no-resolve
```

**要求：**
- Header 必须包含全部 6 种计数：`DOMAIN`, `DOMAIN-KEYWORD`, `DOMAIN-SUFFIX`, `IP-CIDR`, `IP-CIDR6`, `PROCESS-NAME`
- 无 `# Source:` 行，无 `@ads`、`@cn` 等标签
- 计数器必须与实际条目数一致（validate 自动检查）
- 更新时间：`Asia/Shanghai` 时区，格式 `YYYY-MM-DD HH:mm:ss`
- IP-CIDR 保留 `,no-resolve` 后缀

### 4. Behavior 检测

```
有 IP-CIDR / IP-CIDR6 / PROCESS-NAME / DOMAIN-KEYWORD → classical
纯 DOMAIN / DOMAIN-SUFFIX                               → domain
```

### 5. 规则匹配顺序（Config 中 rules: 段）

```
1️⃣ 拦截    RULE-SET,Reject + GEOSITE 广告
2️⃣ 品牌    Netflix/Bilibili 等（子品牌优先于父品牌，避免被宽泛规则截胡）
           例: YouTube 在 Google 前, AppleTV 在 Apple 前, OneDrive 在 Microsoft 前
3️⃣ 局域网   LanCIDR + Private + Direct
4️⃣ 国内IP  CNCIDR + GEOIP,CN
5️⃣ 代理    RULE-SET,Proxy
6️⃣ 兜底    MATCH
```

### 6. 规则集类别

- **基础规则集** (8): Direct, Proxy, Reject, Private, LanCIDR, CNCIDR, Telegram, Applications
- **品牌规则集** (105): 流媒体、AI、社交、音乐、游戏、云服务、电商等
- **Porn/PornChina**: 特殊处理，不在 README 公开

## 上游数据源

| # | 上游 | 内容 | 拉取方式 |
|---|------|------|---------|
| ① | [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community) | 仅域名 | `data/<brand>` 文件，递归解析 `include:` |
| ② | [Loyalsoldier/clash-rules](https://github.com/Loyalsoldier/clash-rules) | 域名 + IP-CIDR | `parse-loyalsoldier.awk` 解析 YAML payload |
| ③ | [blackmatrix7/ios_rule_script](https://github.com/blackmatrix7/ios_rule_script) | 域名 + IP-CIDR + PROC | `rule/Clash/<Brand>/` 的 `.yaml` 文件 |

### 合并逻辑

1. 基础数据（已有规则集内容）
2. v2fly 补充域名
3. Loyalsoldier 补充域名 + IP-CIDR
4. blackmatrix7 补充：域名仅补漏，IP-CIDR/PROCESS-NAME 无条件全加

## 脚本操作

### sync-upstream.sh

上游同步脚本，支持全量或单品牌同步。

```bash
# 全量同步（全部品牌 + 基础规则集）
bash scripts/sync-upstream.sh

# 单品牌同步
bash scripts/sync-upstream.sh Netflix

# 同步基础规则集
bash scripts/sync-upstream.sh Direct
```

**关键特性：**
- 递归解析 v2fly `include:` 指令（最多 5 层深度）
- 品牌名映射：`Porn` → `category-porn`, `NHK` → `nhk`
- 自动发现空 ruleset 文件并填充上游数据
- cross-type 去重：DOMAIN 被 DOMAIN-SUFFIX 覆盖时移除 DOMAIN
- 空值过滤：跳过 `DOMAIN-SUFFIX,` 等无效行
- Loyalsoldier 用 awk 解析（11 万行 ~0.03 秒）

### validate-ruleset.sh

格式校验 + 自动修复 + README 同步。

```bash
# 校验所有 ruleset
bash scripts/validate-ruleset.sh

# 校验单个
bash scripts/validate-ruleset.sh ruleset/Netflix/Netflix.yaml
```

**自动修复能力：**
- 裸域名 → `DOMAIN,` 格式
- `+.xxx` / `.xxx` → `DOMAIN-SUFFIX,xxx`
- 去掉 `@ads` `@cn` 标签
- 小写文件名 → PascalCase
- Header 计数与实际条目同步
- 自动生成/更新品牌 README.md
- 幂等：无变化不覆写

### generate-config.sh

生成 Nikki + Android 双平台配置文件。

```bash
bash scripts/generate-config.sh
```

自动输出的 config 结构（按官方 mihomo 文档顺序排列）：

```
mixed-port → allow-lan → find-process-mode → mode → geox-url → log-level →
ipv6 → external-controller → profile → tun → dns → proxy-providers →
proxy-groups → rule-providers → rules
```

**功能：**
- 自动检测 behavior（classical / domain）
- 品牌显示名映射（AppleIntelligence → Apple Intelligence）
- 图标注入（Oasisic-Icons CDN URL）
- DNS 三段式分流（nameserver + nameserver-policy + fallback）
- 策略组名和引用统一加引号，组间空行分隔

### sync-icons.sh

从 Oasisic-Icons 仓库扫描品牌图标，生成映射表。

```bash
bash scripts/sync-icons.sh
```

## DNS 配置规范（Nikki）

```
default-nameserver: 223.5.5.5, 119.29.29.29        ← 仅解析 nameserver 域名 IP
nameserver:         doh.pub, dns.alidns.com DoH     ← 国内 DoH 主力（含 UDP 兜底 119.29.29.29/223.5.5.5）
proxy-server-ns:    doh.pub, dns.alidns.com DoH     ← 全国内！代理服务器专用（含 UDP 兜底）
nameserver-policy:
  geosite:private,cn        → 国内 DNS（含 UDP 兜底）← 按 geosite 分流
  geosite:geolocation-!cn   → cloudflare-dns.com, dns.google（含 UDP 兜底）
fallback:                   cloudflare-dns.com, dns.google（含 UDP 兜底 1.1.1.1/8.8.8.8）
fallback-filter:            geoip:cn + ipcidr       ← CN 域名不经过 fallback (geosite 已废弃移除)
fake-ip-filter:             +.lan, +.local, +.corp,
                            +.pool.ntp.org, +.time.apple.com,
                            +.time.google.com       ← NTP 域名走真实 IP
skip-domain (sniffer):      +.apple.com, +.digicert.com, +.microsoft.com
                            ← Apple/证书/CDN 保留 DNS mapping
```

端口：
- **Android**: `dns.listen: 0.0.0.0:53`
- **Nikki**: `dns.listen: 0.0.0.0:1053`（nftables 劫持 53→1053）

## geox-url 配置（Wiki 推荐）

```
geoip:   https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat
geosite: https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat
mmdb:    https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/country.mmdb
asn:     https://github.com/xishang0128/geoip/releases/download/latest/GeoLite2-ASN.mmdb
```

## CI/CD 工作流

`.github/workflows/daily-sync.yml`:

| 步骤 | 描述 |
|------|------|
| checkout | actions/checkout@v3 |
| sync-upstream.sh | 全量同步（60min 超时） |
| sync-icons.sh | 图标映射更新 |
| validate-ruleset.sh | 格式校验 + README 同步 |
| generate-config.sh | 双平台配置生成 |
| git commit + push | 中文 emoji 提交，北京时间 |
| cleanup | 清理失败 Actions |
| Discord webhook | embed 卡片通知 |

## 关键配置参考

### v2fly 品牌名映射

```bash
case "$brand" in
  Porn) v2fly_lower="category-porn" ;;
  NHK)  v2fly_lower="nhk" ;;
esac
```

### Discord Webhook Embed

```json
{
  "embeds": [{
    "title": "🔄 规则集已更新",
    "description": "| 规则集 | 变更 |\n|--------|------|\n| Netflix | +8 条 |\n| Disney | +3 条 |",
    "color": 5814783,
    "footer": { "text": "mihomo-rules · 自动同步", "icon_url": "..." },
    "timestamp": "2026-07-07 14:30:00"
  }]
}
```

### Config Key 顺序（官方规范）

```
mixed-port → port → socks-port → allow-lan → bind-address → mode →
log-level → ipv6 → keep-alive-interval → keep-alive-idle → find-process-mode →
external-controller → secret → external-ui → external-ui-name → external-ui-url →
profile → unified-delay → tcp-concurrent → geodata-loader →
geo-auto-update → geo-update-interval → geox-url →
tun → dns → sniffer → proxy-providers → proxy-groups → rule-providers → rules
```

## 常见陷阱

1. **include 递归丢失原始内容**：`cat >> v2fly_all.txt` 前必须 `cp v2fly.txt v2fly_all.txt`
2. **DOMAIN-KEYWORD 含有完整域名**：需转为 DOMAIN 条目（`DOMAIN-KEYWORD,example.com` → `DOMAIN,example.com`）
3. **stats 行污染 payload**：awk END 块必须单行输出 `STATS`，不能多行 `printf`
4. **YAML 解析 FE0F 字符**：`♻️` 后的变体选择符 `U+FE0F` 使 YAML 解析器报 `?`，必须移除
5. **brand 组 YAML 格式**：必须用 `- name: "Brand"` 格式，不能用 `Brand:`（非序列项）
6. **图标错配**：`X` 前缀匹配 `Xbox`，需硬编码修正或精确正则
7. **Commit message 破坏 JSON**：必须用 `git log --format='%s'`（单行）
8. **Porn/PornChina 不应在 README 公开**
9. **阿里 DoH IP 直连不工作**：`https://223.5.5.5/dns-query` 不支持，必须用 `dns.alidns.com` 域名
10. **fallback-filter.geosite 已废弃**：用 `nameserver-policy` 替代，`geosite:gfw` 被子集 `geolocation-!cn` 覆盖
11. **自动选择/故障转移不要放 DIRECT**：直交由规则层处理，代理组只留真实节点
12. **geox-url 用 Wiki 推荐**：`testingcf.jsdelivr.net`（国内加速）+ 完整版文件 + `xishang0128` ASN
13. **🎯 全球直连已移除**：全部用 `DIRECT` 关键字替代。品牌组/漏网之鱼/国内媒体都直接用 DIRECT，不再使用 🎯 组
14. **DNS 必须加 UDP 兜底**：DoH 可能因 TLS 握手超时失败。所有 DNS 段（nameserver/fallback/nameserver-policy/proxy-server-ns）都要有 UDP 后备
15. **注释对齐用后处理**：`generate-config.sh` 生成后自动跑 Python 脚本，所有行内 `#` 固定在 52 列
16. **Discord embed 换行用 `$'\n'`**：bash 中 `\\n` 是字面文本。用 `$'\n'`（ANSI-C quoting）产生真正换行，`jq --arg` 才能正确序列化
17. **disable-icmp-forwarding**：Nikki TUN 段加 `disable-icmp-forwarding: true`，防 ping 走代理

## 验证检查清单

- [ ] 新 ruleset 使用子目录 + PascalCase
- [ ] Header 6 种计数与实际一致
- [ ] 无 `@ads`、`@cn` 等标签
- [ ] 无 `# Source:` 行
- [ ] 条目按类型分组，组内字母序
- [ ] behavior 检测正确（classical / domain）
- [ ] config 按官方 key 顺序排列
- [ ] 品牌显示名映射正确
- [ ] DNS 端口平台独立（Android 53 / Nikki 1053）
- [ ] 图标同步无误（无 404）
- [ ] CI 工作流语法正确 (`bash -n`)
- [ ] 敏感信息未提交
- [ ] README + CHANGELOG 已更新