---
name: mihomo-rules
description: >
  OpenWrt mihomo/Meta proxy ruleset project maintenance — daily sync, config generation,
  brand ruleset management, CI, and upstream data pipeline. Covers sync-upstream.sh,
  generate-config.sh, validate-ruleset.sh, policy groups, icon sync, and multi-platform
  configs (Android/Nikki).
tags: [proxy, mihomo, openwrt, nftables, ruleset, sync, ci]
---

# mihomo-rules 管理 Skill

## Overview

管理 Mihomo/Clash-Meta 兼容 RULE-SET 级代理规则集仓库（106 品牌，32 万+ 规则）。上游同步 → 品牌规则集 → 配置生成 → CI。

## When to Use

- 用户要求添加/修改/删除 ruleset 品牌规则集
- 需要同步上游域名数据（v2fly / Loyalsoldier / blackmatrix7）
- 校验 ruleset 文件格式是否符合规范
- 生成 Nikki（OpenWrt）或 Clash for Android 配置文件
- 同步品牌图标（Oasisic-Icons）
- 调试 GitHub Actions CI/CD 工作流
- 排查 Discord 通知失败
- 审阅项目整体健康度（新：project-health-audit.md）

## 项目结构

```
mihomo-rules/
├── ruleset/                   # 规则集（每个品牌独立子目录）
├── configs/                   # 平台配置文件（Android + Nikki × config/min）
├── scripts/                   # 自动化脚本
│   ├── sync-upstream.sh       # 上游同步（v2fly + Loyalsoldier + bm7）
│   ├── generate-config.sh     # 配置生成（含 behavior 检测 + 图标注入）
│   ├── validate-ruleset.sh    # 格式校验 + 自动修复
│   └── sync-icons.sh          # Oasisic-Icons 图标同步
├── .github/workflows/
│   └── daily-sync.yml         # 每日同步工作流 (06:00 BJT)
├── CHANGELOG.md
└── README.md
```

## 核心规范

### 1. 命名规范

- **目录结构**: `ruleset/<Brand>/<Brand>.yaml`
- **文件名**: PascalCase（如 `Netflix.yaml`, `AIService.yaml`）
- **去符号**: 去掉括号、`@`、`-`、`+` 等（`U-NEXT` → `UNext`）
- **缩写保留**: `AI`, `TV`, `CDN`, `IP`, `ID` 等保持大写
- **Apple i-前缀**: `iCloud`, `iTunes` 保持首字母小写
- **裸文件**: 无后缀的文件自动加 `.yaml`

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
  - DOMAIN,example.com
  - IP-CIDR,1.0.0.0/24,no-resolve
```

**Header 顺序**：REGEX 类型必须在 SUFFIX 类型之前（post-2026-07-17 统一）。`validate-ruleset.sh` 中 for 循环和 header 写入顺序均已调整为 `REGEX→SUFFIX`。

**分组注释**：规则集文件中的 `# --- TYPE (N) ---` 分组注释已彻底移除（post-2026-07-17）。仅保留 header 计数行。详见 `references/group-comment-removal.md`。

### 4. 策略组顺序

```yaml
- RULE-SET,Reject,🛑 全球拦截
- RULE-SET,Applications,DIRECT
- RULE-SET,LanCIDR,DIRECT
- RULE-SET,Private,DIRECT
- RULE-SET,Direct,DIRECT
- RULE-SET,CNCIDR,DIRECT
- GEOIP,CN,DIRECT
- RULE-SET,Proxy,🔧 手动切换
- MATCH,🐟 漏网之鱼
```

### 5. 图标注入

从 Oasisic-Icons 同步图标，注入到 4 个 config 文件的策略组。

**图标映射去重（post-2026-07-17）**：`generate-config.sh` 中的 `get_icon_url()` 硬编码 case 语句已移除，改为纯读取 `icon-map.sh` 中的 `ICON_<Brand>=` 变量。`icon-map.sh` 是唯一数据源，由 `sync-icons.sh` 生成。新增 `Unsplash` 和 `Wallpaper` 品牌图标映射。

## 上游同步管线

### 3.1 品牌级并发拉取（post-2026-07-17）

`sync-upstream.sh` 的 `main()` 中品牌迭代默认使用 **`xargs -P 6` 并发 6 路并行**，串行模式仅用于单品牌调试（`sync-upstream.sh <Brand>` 参数）或 `xargs` 不可用环境。

**实现**：
```bash
# 并发模式
export -f sync_brand fetch_v2fly fetch_loyal fetch_bm7 merge_write clean_file \
    extract_existing normalize_cidr log err
export RULESET_DIR CACHE_DIR PROJECT_DIR NOW V2FLY_URL LOYAL_URL BM7_URL
get_brands | xargs -P 6 -I {} bash -c 'sync_brand "$@" || true' _ {}

# 串行模式（fallback）
while IFS= read -r brand; do
    sync_brand "$brand" || true
done < <(get_brands "$single")
```

**无竞态保证**：
- 每个品牌写独立 temp 文件（`$CACHE_DIR/v2fly_${brand}.txt` 等）
- 路由缓存（Google→YouTube, Microsoft→GitHub）各自写入 `routes/` 下独立文件
- v2fly include 缓存（`v2fly_inc_*.txt`）先写入者胜，后续复用
- 最终 `merge_write()` 串行执行，合并所有品牌

**性能提升**：106 品牌 × 3 上游 × 串行 ~40min → 6 并发 ~7min

### 上游来源

| 上游 | 用途 | 备注 |
|------|------|------|
| **v2fly** | 主要域名来源 | 包含 include 机制（如 Microsoft include:github） |
| **Loyalsoldier** | 补充/增强 | GEOIP 分类 |
| **blackmatrix7** | 仅 MAC 地址 | ⚠️ 自 2026-07-14 起停止域名同步 |

### 数据清洗管线 (`clean_file()`)

**所有 fetch 函数末尾必须调用 `clean_file()`，在 merge 之前完成清洗。** 顺序：

1. 剥离标签（`@cn`, `@!cn`, `@ads`）
2. 剥离尾部空白
3. 跳过空值（`DOMAIN,` 逗号结尾无内容）
4. 类型校验（仅保留 7 种有效类型）
5. 排序去重

### Include 路由 + 品牌过滤（双层防御）

v2fly include 机制会将其他品牌的域名内联到当前品牌中。双层处理：

**第一层 — Include 对比去重**（主路径）：
1. 同步源品牌时，解析 include 指令（如 `include:github`），将 include 目标的所有数据（7 类型）提取到缓存
2. 对比 include 缓存和目标品牌规则集：逐条检查，目标品牌已有的跳过，没有的补充
3. 将路由数据写入 `routes/` 缓存，从源品牌删除
4. 第二轮将路由缓存的域名合并到目标品牌

**第二层 — grep 兜底过滤**（边缘域名 catch）：
- 有些域名不在 v2fly include 数据中但属于目标品牌（如 `gh.io`、`githubnext.com`、`copilot-telemetry.githubusercontent.com`）
- 用 `grep -E` 模式匹配这些边缘域名，补充到路由缓存
- 模式需覆盖 `DOMAIN.*keyword`、`DOMAIN-SUFFIX.*keyword`、`DOMAIN-SUFFIX,edge.domain`

**⚠️ 路由规则类型覆盖**：
- `grep -E` 模式匹配适用于包含品牌关键词的条目类型（DOMAIN, SUFFIX, KEYWORD, REGEX, PROCESS-NAME）
- **IP-CIDR 不含域名关键词**，无法用 `.*github` 匹配。需改用对比去重模式
- 见 `references/route-rules-compare-dedup.md`

### ⚠️ 路由规则类型覆盖（post-2026-07-21）

**grep -E 兜底模式**：适用于包含品牌关键词的条目类型（DOMAIN, SUFFIX, KEYWORD, REGEX, PROCESS-NAME）。

**IP-CIDR / IP-CIDR6**：值里是 IP 地址，不含域名关键词。grep 模式匹配无效。
- **✅ 已解决**：Include 对比去重天然支持 7 类型全覆盖（数据驱动，不依赖关键词）
- **✅ 已解决**：层级匹配补充子域名（DOMAIN→SUFFIX）
- **✅ 已解决**：regexp: vs regex: 解析 bug 已修复（parse-v2fly.awk）

见 `references/include-compare-dedup-routing.md`。

### ⚠️ Amazon→AWS 路由已验证（post-2026-07-21）

Amazon 规则集曾混入 AWS 云服务域名（`amazonaws.com`、`cloudfront.net`、`elasticbeanstalk.com` 等），经 Amazon→AWS 路由后：
- **Amazon**: DOMAIN=0, REGEX=0, SUFFIX=179 — 纯电商
- **AWS**: DOMAIN=5, REGEX=3, SUFFIX=76 — 纯云服务
- **重叠**: 仅 5 条 CloudFront CDN 域名（电商也用 CloudFront，正常）

实现：`route-rules.sh` 中 Amazon→AWS 路由 = include 对比去重（`include:aws`，77 条精确匹配）+ grep 兜底（补边缘域名如 `a2z.org.cn`、`amplifyapp.com`）。

见 `references/include-compare-dedup-routing.md`。

### ⚠️ extract_existing() 尾空白匹配必须覆盖 \r（post-2026-07-19）

**Bug 场景**：`extract_existing()` 使用 `gsub(/[ \t]+$/, "", $0)` 仅匹配空格+tab，不匹配 `\r`(CR)。上游某次返回 CRLF 数据时，`\r` 穿透该函数写入规则集文件，导致 `DOMAIN-SUFFIX,\r` → 后续处理后变成 `DOMAIN-SUFFIX,`（空值）。

**修复**：改用 `gsub(/[[:space:]]+$/, "", $0)`，与 `clean_file()` 保持一致。sanitize 管线 CR 清除是事后兜底，`extract_existing()` 是源头根治。

**铁律**：awk 的 `[ \t]` 不匹配 `\r`（`\r` 是 `\x0d`）。处理可能含 CRLF 输入时，必须用 `[[:space:]]` 或显式 `[\r\n\t ]`。

## 关键注意事项

### ⚠️ 图标 auto-mapping 品牌碰撞（post-2026-07-16）

### ⚠️ icon-map.sh 可能被 sync-icons.sh 意外修改（post-2026-07-21）

`sync-icons.sh` 全量同步时会重新生成 `icon-map.sh`，可能自动发现新图标（如 Niconico）并写入。这会导致 push 时出现意料之外的 diff。

**Push 前检查**：`git diff -- scripts/icon-map.sh` 确认是否有意外变更。

## 提交前验证清单

详见 `references/prompt-verification-checklist.md`。

### ⚠️ Push 前必须检查 unstaged 变更（post-2026-07-16）

**Bug 场景**：`sync-icons.sh` 的 `sed -i` delete-before-patch 逻辑会删除 15 个品牌的 auto-mapping 条目，但手动补丁区只覆盖 7 个。剩余 9 个品牌（Apple, Facebook, Google, Instagram, Microsoft, Netflix, OpenAI, Reddit, YouTube）的图标会丢失。

**Push 前检查**：
```bash
# 1. 查看 unstaged 变更
git diff --stat

# 2. 对图标变更，逐品牌验证
for brand in Apple Facebook Google Instagram Microsoft Netflix OpenAI Reddit YouTube; do
    count=$(grep -c "^ICON_${brand}=" scripts/icon-map.sh)
    [ "$count" -eq 0 ] && echo "⚠️ $brand: ICON 丢失!"
done
```

**原则**：只提交你确认过影响的变更。未暂存的脚本变更（如 icon-map.sh）可能引入回归，必须先验证再决定。

## 代码审查修复工作流

详见 `references/code-review-fix-workflow.md`。

## 结构化代码审查报告格式

详见 `references/code-review-report-format.md`。

**铁律：所有结论必须有证据支撑。** 用户问"证据呢？"时必须展示实际命令输出和数据点。禁止：
- 说"看起来没问题"而不展示 `sort -u` 对比
- 说"无重复"而不展示 `grep -c` 输出
- 说"校验通过"而不展示 `validate-ruleset.sh` 结果
- 跳过 3 遍验证（用户明确要求时）
- 声称上游有脏数据而不展示 `curl` 结果
- 声称上游干净而不展示 `grep -c` 计数
- **声称无 `.ne` 污染而不使用行尾锚定 `$`**（`grep '\\.ne'` 会匹配 `.net` 子串，必须用 `grep -cE '\\.ne$'`）
- 说"上游没有污染"而不贴 `curl` + `grep` 原始输出（post-2026-07-15 新增铁律）

详见 `references/evidence-requirement.md`（完整证据格式示例 + 用户纠正记录 + 三遍验证协议）。

## 规则集完整性审计

当用户要求从某个 commit 到最新的 code review（查数据污染、归类错误、重复），使用 7 阶段审计流程。详见 `references/ruleset-audit-workflow.md`。

### ⚠️ 上游数据质量审计（post-2026-07-15）

**核心原则：发现污染时，必须先验证上游当前状态，再判断责任归属。** 不能假设一定是脚本 bug。

**四步审计法：**
1. **git trace** — 在各 commit 处计数污染模式，确定首次出现位置
2. **上游验证** — `curl` 直接请求当前上游 URL，grep 污染模式
3. **脚本检查** — `git show BASELINE:scripts/... | grep -n 'substr\|sed.*net\|gsub.*net'`
4. **交叉比对** — 上游 clean + 脚本 clean + HEAD dirty → 手动污染；上游 dirty + HEAD dirty → 上游数据质量问题

**⚠️ 上游可能已修复：** 上游数据源可能在问题发生后已修正，但历史同步仍携带了脏数据。始终检查 CURRENT upstream，不是历史版本。

详见 `references/upstream-data-quality-audit.md`。

### ⚠️ Force-Push 后 CI Race 条件（post-2026-07-15）

审计完成后 force-push 到 main，CI 会在 ~5 分钟内再次同步上游数据。即使 `sanitize_all_rulesets()` 已修复，dirty commit 仍会留在历史中。**必须**在推送后：
1. 等待 CI 完成
2. `git fetch origin main && git reset --hard origin/main`
3. 重新运行 Phase 2 检查（regexp 污染、Cloudflare IP-CIDR）
4. `bash scripts/validate-ruleset.sh` 确认 106/106 通过

详见 `references/post-audit-force-push-verification.md`。

### ⚠️ 多 commit 合并为一个（post-2026-07-21）

**场景**：rebase 到干净基座后，多个 commit 分散了路由重构、图标、脚本修复。用户要求合并为一个。

**正确流程**：
1. `git reset --hard <clean-base>` — 回到干净基座
2. 实施所有改动（路由、图标、脚本修复）
3. `git add -A && git commit --amend -m "<描述>"` — 合并为一个 commit
4. **验证前必做**：
   - 检查图标映射是否完整（F1TV/Pixiv/Niconico 等可能因 rebase 丢失）
   - `git show HEAD:scripts/icon-map.sh | grep -E 'ICON_F1TV|ICON_Pixiv|ICON_Niconico'`
   - 缺的补上，再 amend
5. `git push --force origin main`
6. `git fetch origin main && git log --oneline origin/main -3` — 确认历史干净

**铁律**：rebase 会丢弃中间 commit 的内容。合并前必须验证所有关键文件都在 HEAD 中。

### ⚠️ 增量推进纪律（post-2026-07-20）

**用户偏好**：rebase 到干净基座后，一个一个功能确认再添加，不要批量吞任务。

**步骤**：
1. `git reset --hard <clean-base>` 回到干净基座
2. 逐个功能实施 → 验证 → 告知用户 → 确认后再继续
3. 不要一次性推多个不相关的变更
4. GitHub 也要同步 force push

### ⚠️ 绝对禁止擅自推送（post-2026-07-20）

**铁律：没有用户明确说"推"，永远不要 push。**

- 用户说"推" = 可以直接推
- 用户说"先不动" = 别碰
- 用户说"验证三遍" = syntax + diff + 功能
- 用户说"一个一个来" = 逐项推进，不批量吞任务
- 用户说"给我diff" = 先 show diff 再操作
- 用户说"不要自己随便推" = NEVER push without confirming
- 用户说"加啊" = 强制执行
- 用户说"重来" = 重置到干净基座重新开始
- 用户说"你的意思是" = 确认理解，不是执行

**违规后果**：擅自推送 = 严重信任违规。用户明确要求"以后先跟我说，避免无暇操作"。

**正确流程**：
1. 实施改动
2. 给用户看 diff
3. 等用户确认
4. 用户说"推"才 push
5. 如果用户说"可以"，确认是"可以改"还是"可以推"——"可以"通常指可以改/提交，但不一定推
6. **增量推进纪律**：rebase 到干净基座后，一个一个功能确认再添加，不要批量吞任务。正确 rebase 命令序列：`git reset --hard <base>` → `git cherry-pick <commits>` → `git branch -f main HEAD` → `git checkout main` → `git push --force origin main`

## 变更日志

- `post-2026-07-21`: Amazon→AWS 路由已验证 — include 对比去重（54 条）+ grep 兜底（8 条），Amazon 残留 5 条 CloudFront CDN（正常），7 类型全覆盖，重叠 0
- `post-2026-07-21`: Include 路由双层架构 — 对比去重（精确匹配 7 类型）+ grep 兜底（边缘域名 catch），替代纯 grep 模式匹配。含验证方法和已知案例
- `post-2026-07-21`: route-rules.sh 新增 `^DOMAIN.*github` 和 `^DOMAIN-SUFFIX.*github` 兜底模式，捕获 copilot 子域名（copilot-telemetry.githubusercontent.com 等）
- `post-2026-07-21`: 网络重试机制 — fetch_v2fly() include 下载失败重试 3 次，处理 HTTP 429 限流（指数退避 1→2→4s）。GitHub raw 匿名 60 req/h，带 token 5000 req/h
- `post-2026-07-21`: 层级匹配 — 路由时 DOMAIN 条目（如 `DOMAIN,github.com`）自动转为 DOMAIN-SUFFIX（如 `DOMAIN-SUFFIX,github.com`）追加到目标品牌，避免子域名漏路由
- `post-2026-07-21`: parse-v2fly.awk regexp: 修复 — `substr(val, 7)` 多取 `:` 前缀（`regexp:` 7 字符），改用 `index(val, ":")` 定位冒号位置后截取
- `post-2026-07-21`: 层级匹配实现细节 — `merge_write()` 中第二层：提取目标品牌 `DOMAIN-SUFFIX` 列表，对源品牌每条 `DOMAIN` 检查是否为任一 SUFFIX 的子域名（`[[ "$dval" == *.$suffix ]]`），是则路由。已匹配行跳过（`grep -Fxq` 去重）
- `post-2026-07-21`: Apple 去重 — `*.akadns.net`/`*.edgekey.net` 子域名被 `DOMAIN-SUFFIX,akadns.net`/`edgekey.net` 覆盖而移除，属正常上游数据优化，非路由重构副作用
- `post-2026-07-21`: 多 commit 合并为一个 — rebase 到干净基座后，用 `git add -A && git commit --amend` 把所有改动合并为一个 commit，避免历史碎片化。推前必须验证：关键文件存在、图标映射完整、语法检查通过、统计正确
- `post-2026-07-21`: commit 合并后必须补全所有图标 — rebase 会丢失中间 commit 的图标（F1TV/Pixiv/Niconico），amend 前需用 `generate-config.sh` 重生成 config 并确认图标完整
- `post-2026-07-21`: parse-v2fly.awk regexp 解析 bug — `substr(val, 7)` 对 `regexp:`（7 字符）多取 `:` 前缀，导致路由匹配失败（Amazon 残留 3 条 DOMAIN-REGEX）。修复：改用 `index(val, ":")` 定位冒号后截取
- `post-2026-07-21`: 7 类型全量验证方法 — 重构 sync-upstream.sh 后必须逐类型 × 逐品牌与基座对比计数，不仅看总量
- `post-2026-07-20`: route-rules.sh 类型覆盖限制 — IP-CIDR 不含域名关键词，grep -E 模式匹配无效，需改用对比去重模式
- `post-2026-07-20`: 声明式路由模式 — route-rules.sh 替代 merge_write() 硬编码 case，每加一个路由只需加一行声明
- `post-2026-07-21`: route-rules.sh 新增 `^DOMAIN.*github` 和 `^DOMAIN-SUFFIX.*github` 兜底模式，捕获 copilot 子域名（copilot-telemetry.githubusercontent.com 等）
- `post-2026-07-22`: 废弃 dedup-brands.sh, 统一品牌去重到 route-rules.sh — 新增 8 对父子品牌路由（Microsoft→OneDrive, Google→GoogleAI, Apple→iCloud/AppleTV, Amazon→PrimeVideo, Facebook→Instagram/Messenger/WhatsApp）
- `post-2026-07-22`: 恢复 assert_sed_applied 校验函数（header-order.sh），generate-config.sh 中 4 处 sed 操作加校验
- `post-2026-07-22`: extract_existing() `[ \t]` → `[[:space:]]` 修复（CR 穿透导致空值）
- `post-2026-07-22`: 移除 Reject/Proxy 系统策略组硬编码图标
- `post-2026-07-22`: 修复 RULE-SET,Applications 被误删于 Android 配置（死代码清理时移出 if 块）

- `post-2026-07-19`: extract_existing() 尾空白匹配 `[ \\\\t]` → `[[:space:]]` 修复（CR 穿透导致空值根因）
- `post-2026-07-19`: AWS 品牌规则集新增（v2fly data/aws，77 条规则），105→106 品牌
- `post-2026-07-19`: route-rules.sh 声明式 include 路由抽象（Microsoft→GitHub, Google→YouTube, Amazon→AWS）
- `post-2026-07-19`: parse-v2fly.awk 修复 `regexp:` 前缀误解析（上游用 `regexp:` 但解析器只认 `regex:`）
- `post-2026-07-20`: 声明式路由模式 — route-rules.sh 替代 merge_write() 硬编码 case，每加一个路由只需加一行声明
- `post-2026-07-20`: parse-v2fly.awk 修复 `regex:` → `regexp?`（上游用 `regexp:` 带 p，导致 DOMAIN-REGEX 路由到 Amazon 时解析为 `DOMAIN-SUFFIX,regexp:...`）
- `post-2026-07-20`: export 数组变量不传播到 xargs -P 子进程 — merge_write() 内需重新 source route-rules.sh
- `references/aws-brand-classification.md` — AWS 与 Amazon 电商区分 + v2fly data/aws 上游分析
- `references/declarative-route-rules.md` — 声明式 include 路由抽象（route-rules.sh 替代硬编码 case）
- `references/parse-v2fly-regexp-fix.md` — parse-v2fly.awk `regex:` → `regexp?` 修复（上游用 `regexp:` 但解析器只认 `regex:`）
- `references/export-xargs-p-subprocess.md` — export 数组变量不传播到 xargs -P 子进程的修复模式
- `references/route-rules-ipcidr-limitation.md` — IP-CIDR 条目不含域名关键词，grep 模式匹配无效，需改用对比去重模式
- `references/route-rules-enhancements.md` — 网络重试（含 429 限流）+ 层级匹配（DOMAIN→SUFFIX）+ 验证模式
- `references/route-rules-grep-exhaustion.md` — grep 模式匹配穷举边界域名陷阱（`.*github` 能匹配已知域名但无法捕获 `gh.io`/`ghcr.io` 等边缘域名，需 include 对比去重为主 + grep 兜底为辅的双层架构）
- `references/rebase-cherry-pick-detached-head.md` — cherry-pick 在 detached HEAD 上创建 commit 后需 `git branch -f main HEAD` + `git checkout main` + `git push --force` 才能更新 main 分支（`.*github` 能匹配已知域名但无法捕获 `gh.io`/`ghcr.io` 等边缘域名，需 include 对比去重为主 + grep 兜底为辅的双层架构）
- `references/include-compare-dedup-routing.md` — Include 对比去重路由机制完整文档（三层架构、网络重试、regexp 解析 bug、验证方法、已知案例）
- `references/route-rules-grep-exhaustion.md` — grep 模式匹配穷举边界域名的陷阱：`.*github` 只能匹配已知域名，`gh.io`/`ghcr.io` 等边缘域名需额外 pattern。solution: include 对比去重为主 + grep 兜底为辅
- `references/comprehensive-7type-verification.md` — 7 类型 × 品牌全量验证方法（重构后逐类型对比基座计数）
- `references/brand-rules-list.md` — 品牌 RULE-SET 完整列表（97 条）
- `references/script-consolidation.md` — 脚本清理与合并方法论（识别覆盖关系、统一数据源、Git 提交纪律、验证清单）
- `references/ntp-interception-ordering.md` — NTP 域名跨规则集优先级拦截问题（Nikki 1053 端口劫持）
- `references/awk-stats-field-shift.md` — awk STATS 行 `rc=0` 时 `read` 字段错位

## 参考文档

- `references/assert-sed-applied.md` — `sed -i` 静默失败防护：assert_sed_applied() 公共函数实现、5 处已验证使用、铁律与常见陷阱
- `references/project-health-audit.md` — 项目健康审计 3 步法（需求落地检查 → 全量健康扫描 → 假阳性排查）
- `references/ruleset-audit-workflow.md` — 跨 commit 范围的 ruleset 完整性审计（7 阶段审查：数据污染/归类正确性/交叉引用/重复/CI可靠性/header一致性，3 遍验证协议）
- `references/full-ruleset-audit.md` — 全量规则集类型审计（4 部分检查脚本）
- `references/include-pipeline.md` — include 解析 + 双层路由/过滤
- `references/code-review-fix-workflow.md` — 系统性 CR 修复 + rebase 处理
- `references/code-review-report-format.md` — 结构化代码审查报告格式 + **6-phase audit workflow**（脚本检查→数据检查→commit追溯→config一致性→CI检查→报告汇总）
- `references/icon-sync-pitfalls.md` — 图标同步陷阱 + **known auto-mapping bugs table**（X→Xbox, 14 duplicate ICON_）
- `references/icon-ci-overwrite-protection.md` — 双图层保护 + **21 protected brands** + 策略组图标注入流程
- `references/incremental-sanitization.md` — `.synced_` 标记文件增量模式（避免全量扫 106 品牌）
- `references/concurrency-xargs-p6.md` — 品牌级并发拉取实现（xargs -P 6，无竞态保证）
- `references/header-order-sharing.md` — HEADER_ORDER 共享变量（sync-upstream.sh + validate-ruleset.sh 共用，防止分裂）
- `references/group-comment-removal.md` — 分组注释彻底移除（234 条→0 条，含验证方法）
- `references/discord-anomaly-alert.md` — 异常量级检测 → Discord embed 双通道报警
- `references/detect-behavior-fix.md` — behavior 自动检测逻辑
- `references/brand-cross-domain-pollution.md` — 跨品牌污染过滤
- `references/upstream-data-quirks.md` — 上游数据异常 + clean_file() 详解
- `references/category-ads-all-removal.md` — category-ads-all 移除
- `references/cloudflare-cdn-collision.md` — Cloudflare CDN 误判
- `references/ip-cidr6-dedup-gap.md` — IPv6 去重
- `references/config-verification-3pass.md` — 三遍验证
- `references/icon-token-support.md` — sync-icons.sh token 认证
- `references/fake-ip-filter-reference.md` — fake-ip-filter 规范
- `references/dns-platform-differences.md` — DNS listen 地址平台差异（Android 127.0.0.1 vs Nikki 0.0.0.0）
- `references/sed-escaping-gnu-sed.md` — GNU sed 转义行为差异
- `references/sed-escaping-trap-ip-comments.md` — sed 替换注释中 IP 模式的反斜杠逃逸陷阱
- `references/ci-log-inspection.md` — CI 日志诊断模式（零 counts、export 遗漏、unbound $1 排查）
- `references/readme-table-rendering-fix.md` — Android/Nikki README 表格 `||`→`|` 修复（GFM 多列白边）
- `references/icon-ci-overwrite-protection.md` — CI `generate-config.sh` 覆盖手工修改的防护工作流
- `references/logo-rendering.md` — SVG 图标渲染陷阱：cairo+rsvg 的 `fill="none"` 覆盖问题、viewBox 缩放工作流、PIL 居中方案
- `references/sanitize-dedup-bug.md` — sanitize awk 去重逻辑导致 payload 翻倍的根因、自锁机制与修复
- `references/prompt-verification-checklist.md` — 提交前验证清单
- `references/rule-types-complete.md` — 完整规则类型说明
- `references/direct-keyword-removal.md` — 🎯 全球直连 → DIRECT 关键字
- `references/normalize-cidr-shared.md` — normalize_cidr() 共用函数
- `references/brand-filter-variables.md` — GITHUB_PATTERN/YOUTUBE_PATTERN 变量管理
- `references/discord-icon-version.md` — Discord 图标版本修正
- `references/bm7-domain-sync-stop.md` — blackmatrix7 停止域名同步
- `references/script-consolidation.md` — 脚本清理与合并方法论（识别覆盖关系、统一数据源、Git 提交纪律、验证清单）
- `references/ntp-interception-ordering.md` — NTP 域名跨规则集优先级拦截问题（Nikki 1053 端口劫持）
- `references/awk-stats-field-shift.md` — awk STATS 行 `rc=0` 时 `read` 字段错位
- `references/code-review-report-format.md` — 结构化代码审查报告格式：执行摘要表、证据章节、commit 链影响、问题分级、结论