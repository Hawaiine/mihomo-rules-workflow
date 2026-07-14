---
name: mihomo-rules-management
description: >-
  Use when managing mihomo/clash-meta compatible RULE-SET proxy rulesets —
  syncing upstream domain lists (v2fly/Loyalsoldier/blackmatrix7),
  adding/reseeding brand rulesets, validating YAML format, generating platform
  configs (Nikki/Clash for Android), syncing icons from Oasisic-Icons, and
  operating the associated GitHub Actions CI/CD pipeline. Covers the
  Hawaiine/mihomo-rules project conventions.
version: 2.3.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [mihomo, clash, proxy, ruleset, sync, nikki, openwrt]
    related_skills: [github-actions-workflows, bash-projects, systematic-debugging, hermes-agent-skill-authoring]
---

# mihomo-rules 管理 Skill

## Overview

Manage a mihomo-compatible RULE-SET-level proxy ruleset repository (105 brands, 320k+ rules). The project syncs upstream domain lists from multiple sources, validates YAML format with auto-fix, generates platform-specific configs for OpenWrt Nikki and Clash for Android, injects brand icons from Oasisic-Icons, and notifies via Discord webhook.

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
│   ├── Android/config.yaml    # Clash for Android（含注释）
│   ├── Android/config.min.yaml
│   ├── Nikki/config.yaml      # OpenWrt Nikki (mihomo 内核)
│   └── Nikki/config.min.yaml
├── scripts/                   # 自动化脚本
│   ├── sync-upstream.sh       # 上游同步（三层合并 + 清洗 + 路由 + 幂等）
│   ├── generate-config.sh     # 配置生成（含 behavior 检测 + min 自动生成）
│   ├── validate-ruleset.sh    # 格式校验 + 自动修复 + README 同步
│   ├── sync-icons.sh          # Oasisic-Icons 图标同步（含 token 支持）
│   ├── parse-loyalsoldier.awk # Loyalsoldier 解析器
│   ├── parse-v2fly.awk        # v2fly 解析器
│   └── icon-map.sh            # 图标映射表（自动生成，不手动维护）
├── providers/                 # 订阅配置模板
│   ├── airport/               # 订阅配置
│   └── nodes/                 # 单节点配置
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
# DOMAIN: 4
# DOMAIN-KEYWORD: 2
# DOMAIN-REGEX: 4
# DOMAIN-SUFFIX: 30
# IP-CIDR: 0
# IP-CIDR6: 0
# PROCESS-NAME: 1
# ===========================================
payload:
  # --- DOMAIN (4) ---
  - DOMAIN,netflix.com
  # --- DOMAIN-REGEX (4) ---
  - DOMAIN-REGEX,(^|\.)dualstack\.apiproxy-.+\.amazonaws\.com$
  # --- DOMAIN-SUFFIX (30) ---
  - DOMAIN-SUFFIX,nflxvideo.net
  # --- PROCESS-NAME (1) ---
  - PROCESS-NAME,com.netflix.mediaclient
```

**要求：**
- Header 必须包含全部 7 种计数：`DOMAIN`, `DOMAIN-KEYWORD`, `DOMAIN-REGEX`, `DOMAIN-SUFFIX`, `IP-CIDR`, `IP-CIDR6`, `PROCESS-NAME`
- Header 顺序：DOMAIN → DOMAIN-KEYWORD → DOMAIN-REGEX → DOMAIN-SUFFIX → IP-CIDR → IP-CIDR6 → PROCESS-NAME
- 无 `# Source:` 行，无 `@ads`、`@cn` 等标签
- 计数器必须与实际条目数一致（validate 自动检查）
- 更新时间：`Asia/Shanghai` 时区，格式 `YYYY-MM-DD HH:mm:ss`
- IP-CIDR 统一加 `,no-resolve` 后缀

### 4. Behavior 检测

`generate-config.sh` 中的 `detect_behavior()` 根据 payload 实际类型自动判断（非硬编码）：

```
IP-CIDR/IP-CIDR6/PROCESS-NAME/DOMAIN-KEYWORD/DOMAIN-REGEX 任一 > 0 → classical
纯 DOMAIN/DOMAIN-SUFFIX                                            → domain
```

当前分布：71 domain + 34 classical = 105。

### 5. 规则匹配顺序（Config 中 rules: 段）

```
1️⃣ 拦截    RULE-SET,Reject（无 category-ads-all，Reject 已覆盖）
2️⃣ 品牌    Netflix/Bilibili 等（子品牌优先于父品牌，避免被宽泛规则截胡）
           例: YouTube 在 Google 前, AppleTV 在 Apple 前, OneDrive 在 Microsoft 前
3️⃣ 直连    Applications + LanCIDR + Private + Direct
4️⃣ 国内IP  CNCIDR + GEOIP,CN → DIRECT（无 🎯 全球直连 策略组）
5️⃣ 代理    RULE-SET,Proxy → 🔧 手动切换
6️⃣ 兜底    MATCH → 🐟 漏网之鱼
```

### 6. 规则集类别

- **基础规则集** (8): Direct, Proxy, Reject, Private, LanCIDR, CNCIDR, Telegram, Applications
- **品牌规则集** (105): 流媒体、AI、社交、音乐、游戏、云服务、电商等
- **Porn/PornChina**: 特殊处理，不在 README 公开

## 上游数据源

| # | 上游 | 内容 | 拉取方式 |
|---|------|------|---------|
| ① | [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community) | 仅域名（主上游） | `data/<brand>` 文件，递归解析 `include:` |
| ② | [Loyalsoldier/clash-rules](https://github.com/Loyalsoldier/clash-rules) | 域名 + IP-CIDR | `parse-loyalsoldier.awk` 解析 YAML payload |
| ③ | [blackmatrix7/ios_rule_script](https://github.com/blackmatrix7/ios_rule_script) | 仅 CIDR/IP6/REGEX/PROC（不做域名同步） | `fetch_bm7()` 去重转换 |

### 合并逻辑

1. 基础数据（已有规则集内容）
2. v2fly 补充域名（主上游）
3. Loyalsoldier 补充域名 + IP-CIDR
4. blackmatrix7 仅补充 IP-CIDR/IP-CIDR6/DOMAIN-REGEX/PROCESS-NAME，不贡献域名
5. 数据清洗 → Include 路由 → 品牌过滤兜底 → IP-CIDR/IP-CIDR6 标准化 → DOMAIN-SUFFIX 重合去重

### 数据处理管线（sync-upstream.sh）

```
每个 fetch 函数末尾调用 clean_file():
  fetch_v2fly() → clean_file() → 去重+去tag+去空白
  fetch_loyal() → clean_file() → 同上
  fetch_bm7()   → clean_file() → 同上（仅 CIDR/IP6/REGEX/PROC）

merge_write() 内:
  合并 → sort -u
  ↓
  第一层: Include 路由
    - Microsoft 的 GitHub 域名 → routes/GitHub.txt
    - Google 的 YouTube 域名 → routes/YouTube.txt
    - 从当前品牌删除
  ↓
  第二层: 品牌过滤兜底
    - GITHUB_PATTERN / YOUTUBE_PATTERN 变量集中管理
    - 路由未覆盖的域名在此拦截
  ↓
  DOMAIN,regexp: → DOMAIN-REGEX 转换
  ↓
  normalize_cidr("IP-CIDR")  → 去重 no-resolve 变体
  normalize_cidr("IP-CIDR6") → 同上（共用函数）
  ↓
  DOMAIN 被 DOMAIN-SUFFIX 覆盖 → 移除 DOMAIN
  ↓
  构建 YAML → payload diff 幂等检查 → 无变更不覆盖
  ↓
  更新 README + CHANGELOG

main() 后处理:
  扫描 routes/*.txt → 去重合并到目标品牌规则集
```

## 脚本操作

### sync-upstream.sh

上游同步脚本（560 行），支持全量或单品牌同步。

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
- 品牌名映射：`Porn` → `category-porn`, `X` → `twitter`
- 统一清洗函数 `clean_file()`：去重 + 去 @tag + 去空白 + 过滤无效类型
- Include 路由：跨品牌域名自动路由到对应规则集（Microsoft→GitHub, Google→YouTube）
- 品牌过滤兜底：路由未能覆盖的用 `GITHUB_PATTERN`/`YOUTUBE_PATTERN` 变量拦截
- `normalize_cidr()` 共用函数：IP-CIDR 和 IP-CIDR6 统一去重 no-resolve 变体
- 幂等：payload diff 比较，无变化不覆盖
- bm7 仅提取 IP-CIDR/IP-CIDR6/PROCESS-NAME/DOMAIN-REGEX，不做域名同步
- `DOMAIN,regexp:` → `DOMAIN-REGEX` 自动转换

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
- Header 计数与实际条目同步（7 种类型含 DOMAIN-REGEX）
- 自动生成/更新品牌 README.md
- 幂等：无变化不覆写

### generate-config.sh

生成 Nikki + Android 双平台配置文件（含 config.min.yaml 自动生成）。

```bash
bash scripts/generate-config.sh
```

**功能：**
- `detect_behavior()` 动态检测：读取 YAML payload 自动判断 domain/classical（非硬编码）
- 品牌显示名映射（AppleIntelligence → Apple Intelligence）
- 图标注入（Oasisic-Icons CDN URL，含 19 个硬编码修正）
- DNS 三段式分流（nameserver + nameserver-policy + fallback）
- 行内注释自动对齐（固定 52 列）
- 后处理：`sed` 自动生成无注释 config.min.yaml

### sync-icons.sh

从 Oasisic-Icons 仓库扫描品牌图标，生成映射表。

```bash
# CI 模式（有本地仓库克隆）
bash scripts/sync-icons.sh

# 本地 API 模式（无克隆时自动备用）
GITHUB_TOKEN=ghp_xxxxx bash scripts/sync-icons.sh
```

**特性：**
- 双模式：CI（本地扫描） / API（GitHub API 备用）
- 支持 `GITHUB_TOKEN` 和 `GH_TOKEN` 环境变量（解决本地 API 限流）
- 四层匹配策略：裸名 → 编号变体 → 精确前缀 → 大小写不敏感
- 19 个特殊品牌硬编码补丁（`X`, `GeneralAI`, `Telegram` 等）

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
| checkout | actions/checkout@v7 |
| sync-icons.sh | 图标映射更新 |
| sync-upstream.sh | 全量同步（schedule 触发） |
| validate-ruleset.sh | 格式校验 + README 同步 |
| generate-config.sh | 双平台配置生成 |
| git commit + push | 中文 emoji 提交，北京时间 |
| Discord webhook | embed 卡片通知 |
| cleanup | 清理失败 Actions |

**触发机制：**
- `push` → 仅 validate + generate（~30秒），不做上游同步
- `schedule` (06:00 BJT) → 全量 sync + validate + generate + push + Discord

## 验证检查清单

- [ ] 新 ruleset 使用子目录 + PascalCase
- [ ] Header 7 种计数与实际一致（含 DOMAIN-REGEX）
- [ ] 无 `@ads`、`@cn` 等标签
- [ ] 无 `# Source:` 行
- [ ] 条目按类型分组，组内字母序
- [ ] behavior 检测正确（71 domain / 34 classical）
- [ ] config 按官方 key 顺序排列
- [ ] config.min.yaml 自动生成与 config.yaml 同步
- [ ] 品牌显示名映射正确
- [ ] DNS 端口平台独立（Android 53 / Nikki 1053）
- [ ] 图标同步无误（无 404）
- [ ] `bash -n scripts/*.sh` 全部通过
- [ ] `validate-ruleset.sh` 全部文件通过
- [ ] `python3 -c "import yaml; yaml.safe_load(open(...))"` YAML 有效
- [ ] 敏感信息未提交
- [ ] README + CHANGELOG 已更新