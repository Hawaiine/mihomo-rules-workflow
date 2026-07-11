<p align="center">
  <img src="https://raw.githubusercontent.com/MetaCubeX/mihomo/Meta/docs/logo.png" width="80" alt="mihomo logo"/>
</p>

<h1 align="center">📖 mihomo-rules-skill</h1>

<p align="center">
  <b>Hermes Agent Skill — mihomo/clash-meta RULE-SET 规则集管理知识库</b>
</p>

<p align="center">
  <img alt="License" src="https://img.shields.io/static/v1?label=license&message=MIT&color=blue&style=flat-square"/>
  <img alt="Hermes Skill" src="https://img.shields.io/static/v1?label=Hermes&message=Skill+v2.2&color=blueviolet&style=flat-square"/>
  <img alt="Project" src="https://img.shields.io/static/v1?label=ref&message=Hawaiine/mihomo-rules&color=blue&style=flat-square"/>
</p>

---

## 🎯 这是什么

**mihomo-rules-skill** 是一个 [Hermes Agent](https://github.com/NousResearch/hermes) Skill，为管理 [Hawaiine/mihomo-rules](https://github.com/Hawaiine/mihomo-rules)（Mihomo / clash-meta 通用 RULE-SET 规则集仓库）而编写。

加载后，Hermes 掌握：
- ✅ 完整的项目结构、命名规范、文件格式
- ✅ 三大上游（v2fly / Loyalsoldier / blackmatrix7）的同步逻辑与合并策略
- ✅ 4 个核心脚本的完整工作流
- ✅ DNS 三段式分流配置规范 + geox-url Wiki 推荐 + NTP/skip-domain 调优
- ✅ 策略组最佳实践（自动选择/故障转移不含 DIRECT）
- ✅ GitHub Actions CI/CD 工作流
- ✅ 14 个已踩过的坑（include 递归丢失、YAML FE0F 字符、stats 行污染、阿里 DoH IP 直连不工作等）
- ✅ 16 项提交前验证清单

**省去每次重复说明规范的麻烦，直接让 Agent 干活。**

---

## 📂 仓库规划

```
mihomo-rules-skill/
├── 📖 README.md           # 本文件 —— 使用说明 + 项目概览
├── 📜 SKILL.md            # → Hermes Agent Skill（核心）
│                           #   加载后 agent 拥有全部项目管理知识
└── 🔗 关联项目
    └── Hawaiine/mihomo-rules   # 105 品牌 · 32 万+ 规则 · 每日同步
```

> 设计原则：**SKILL.md 即知识库**，README 是入口说明，不拆分多余目录。保持单文件可加载、零依赖。

---

## 🚀 使用方式

### 💬 对话中临时加载

告诉 Hermes：

```
skill_view(name='mihomo-rules-management')
```

### 📦 永久安装到 Hermes

```bash
# 1. 克隆仓库
git clone https://github.com/Hawaiine/mihomo-rules-skill.git

# 2. 复制到 Hermes skills 目录
cp mihomo-rules-skill/SKILL.md ~/.hermes/skills/mihomo-rules-management/

# 3. 下次对话自动生效
```

### 🧪 验证是否加载成功

问 Hermes：

> "帮我检查一下 mihomo-rules 的 ruleset 文件格式"

如果它能说出 Header 格式、行为检测、排序规则等规范，说明 skill 已生效。

---

## 📋 Skill 涵盖内容

| 模块 | 内容 | 版本 |
|------|------|------|
| 📏 **命名规范** | PascalCase、去符号、缩写保留、i-前缀、显示名映射 | ✅ |
| 📄 **文件格式** | 6 种 Header 计数、DOMAIN/DOMAIN-SUFFIX/IP-CIDR/PROCESS 排序 | ✅ |
| 🧠 **Behavior 检测** | 有 IP-CIDR/PROCESS/KEYWORD → classical，纯域名 → domain | ✅ |
| 🗺️ **规则顺序** | 6 段：拦截→品牌→局域网→国内IP→代理→兜底 | ✅ |
| 🛠️ **脚本工作流** | sync-upstream / validate / generate-config / sync-icons | ✅ |
| 🌐 **上游同步** | 3 源合并逻辑、v2fly include 递归、cross-type 去重 | ✅ |
| ⚙️ **配置生成** | 双平台、官方 key 顺序、DNS 三段分流、图标注入 | ✅ |
| 📡 **DNS 规范** | nameserver / proxy-server-ns / nameserver-policy / fallback 全段 UDP 兜底 + geox-url Wiki 推荐 | ✅ |
| 🎯 **策略组最佳实践** | 自动选择/故障转移/品牌组不含 🎯 全球直连，DIRECT 替代全部 | ✅ |
| 🤖 **CI/CD** | daily-sync.yml 工作流、Discord embed 通知（修复换行乱码） | ✅ |
| ⚠️ **常见陷阱** | include 递归、FE0F YAML、stats 污染、图标错配、阿里 DoH IP 直连不工作、DNS UDP 兜底等 17 个 | ✅ |
| ✅ **检查清单** | 16 项提交前验证标准 | ✅ |

---

## 🔗 关联资源

| 资源 | 链接 | 说明 |
|------|------|------|
| 📦 **mihomo-rules** | [Hawaiine/mihomo-rules](https://github.com/Hawaiine/mihomo-rules) | 105 品牌 · 32 万+ 规则 · 每日同步 |
| ⚡ **Mihomo 内核** | [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) | 开源代理核心 |
| 🌐 **Oasisic-Icons** | [Hawaiine/Oasisic-Icons](https://github.com/Hawaiine/Oasisic-Icons) | 品牌图标库 |
| 📡 **v2fly** | [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community) | 上游域名数据 |
| 🌍 **Loyalsoldier** | [Loyalsoldier/clash-rules](https://github.com/Loyalsoldier/clash-rules) | 上游基础规则 |
| 📱 **blackmatrix7** | [blackmatrix7/ios_rule_script](https://github.com/blackmatrix7/ios_rule_script) | 上游品牌规则 |
| 🔧 **Nikki** | [nikkinikki-org/OpenWrt-nikki](https://github.com/nikkinikki-org/OpenWrt-nikki) | OpenWrt 透明代理 |
| 🤖 **Hermes Agent** | [NousResearch/hermes](https://github.com/NousResearch/hermes) | AI Agent 框架 |

---

## 📜 License

MIT License — 自由使用、修改、分发。

---

<p align="center">
  <sub>Made with ❤️ for Hermes Agent · 同名 skill 已在本地安装</sub>
</p>