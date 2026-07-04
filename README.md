<p align="center">
  <img src="https://raw.githubusercontent.com/MetaCubeX/mihomo/Meta/docs/logo.png" width="64" alt="mihomo logo"/>
</p>

<h1 align="center">📖 mihomo-rules-workflow</h1>

<p align="center">
  <b>Hermes Agent Skill — mihomo/clash-meta RULE-SET 规则集管理知识库</b>
</p>

<p align="center">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-blue?style=flat-square"/>
  <img alt="Hermes Skill" src="https://img.shields.io/badge/Hermes-Skill-purple?style=flat-square"/>
</p>

---

## 🎯 这是什么

这是一个 **Hermes Agent Skill**，记录了管理 mihomo/clash-meta RULE-SET 规则集项目的完整规范和工作流。

任何 Hermes Agent 实例加载此 skill 后，都能直接上手管理类似项目。

---

## 📂 仓库内容

```
├── 📖 README.md      # 本文件
└── 📜 SKILL.md       # → Hermes Agent Skill（核心）
```

> 🔗 参考实现：[Hawaiine/mihomo-rules](https://github.com/Hawaiine/mihomo-rules)
> 这是一个真实项目，展示了本 skill 所描述的完整工作流。

---

## 🚀 使用方式

### 方式 1：在对话中直接加载

```
skill_view(name='mihomo-rules-management')
```

### 方式 2：克隆后永久安装

```bash
git clone https://github.com/Hawaiine/mihomo-rules-workflow.git
cp SKILL.md ~/.hermes/skills/mihomo-rules-management/
```

---

## 📋 Skill 涵盖的内容

| 模块 | 说明 |
|------|------|
| 📏 **命名规范** | PascalCase 命名、去符号规则、缩写处理 |
| 📄 **文件格式** | YAML header 规范、DOMAIN/SUFFIX/IP-CIDR 排序 |
| 🗺️ **路由架构** | RULE-SET 级分流、策略组映射 |
| 📜 **脚本参考** | `sync-upstream.sh`、`validate-ruleset.sh`、`generate-config.sh` 完整用法 |
| 🌐 **上游数据源** | v2fly/Loyalsoldier/MetaCubeX 数据拉取 |
| 🤖 **CI/CD** | GitHub Actions 每日同步工作流参考 |
| ⚠️ **常见陷阱** | include 递归、JSON 破坏、CI 超时等 6 个已知坑 |
| ✅ **检查清单** | 12 项验证标准 |

---

## 🔗 相关资源

| 资源 | 链接 |
|------|------|
| 参考实现 | [Hawaiine/mihomo-rules](https://github.com/Hawaiine/mihomo-rules) |
| mihomo 内核 | [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) |
| v2fly 域名数据 | [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community) |
| Loyalsoldier 规则 | [Loyalsoldier/clash-rules](https://github.com/Loyalsoldier/clash-rules) |

---

<p align="center">
  <sub>Made with ❤️ for Hermes Agent</sub>
</p>