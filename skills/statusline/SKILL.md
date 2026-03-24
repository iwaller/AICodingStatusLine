---
name: statusline
description: Use when 用户想查看或修改 Claude Code 状态栏配置（主题/theme、布局/layout、段落可见性/segments、进度条样式/bar-style、宽度/max-width、时间格式/time-format），或提到 statusline、状态栏等关键词时触发。
---

# 状态栏配置管理（statusline）

## 命令路由

| 命令 | 动作 |
|------|------|
| `/statusline` | 展示当前配置 + 可用命令 |
| `/statusline show` | 仅展示当前配置表格 |
| `/statusline segments` | 交互式多选段落可见性（checkbox） |
| `/statusline segments show <name>` | 显示指定段落 |
| `/statusline segments hide <name>` | 隐藏指定段落 |
| `/statusline segments reset` | 重置段落（显示全部） |
| `/statusline theme [值]` | 查看/单选切换主题 |
| `/statusline layout [值]` | 查看/单选切换布局 |
| `/statusline bar-style [值]` | 查看/单选切换进度条样式 |
| `/statusline pct-mode [值]` | 查看/单选切换百分比模式 |
| `/statusline max-width [值\|auto]` | 设置宽度预算 |
| `/statusline time-format [值]` | 设置 7d 时间格式（strftime） |
| `/statusline reset` | 恢复所有配置为默认值 |
| `/statusline preview [主题]` | ANSI 色块预览主题色板 |
| `/statusline update` | 从 GitHub 拉取最新版本并安装 |

## 配置项与合法值

| 配置项 | 环境变量 | 合法值 | 默认值 |
|--------|---------|--------|--------|
| segments | `CLAUDE_CODE_STATUSLINE_SEGMENTS` | 逗号分隔：`model,eff,git,ctx,5h,7d,extra` | (空=全部显示) |
| theme | `CLAUDE_CODE_STATUSLINE_THEME` | `default`, `forest`, `dracula`, `monokai`, `solarized`, `ocean`, `sunset`, `amber`, `rose` | `default` |
| layout | `CLAUDE_CODE_STATUSLINE_LAYOUT` | `bars`, `compact` | `bars` |
| bar-style | `CLAUDE_CODE_STATUSLINE_BAR_STYLE` | `ascii`, `dots`, `squares`, `blocks`, `braille`, `shades`, `diamonds`, `custom:<填充>:<空白>` | `ascii` |
| pct-mode | `CLAUDE_CODE_STATUSLINE_PCT_MODE` | `used`, `left` | `used` |
| max-width | `CLAUDE_CODE_STATUSLINE_MAX_WIDTH` | 正整数 或 `auto`（删除该键） | auto |
| time-format | `CLAUDE_CODE_STATUSLINE_SEVEN_DAY_TIME_FORMAT` | strftime 格式字符串 | `%m/%d %H:%M` |

## 工作流

### 0) 读取当前配置

始终先读取 `~/.claude/settings.json`，提取 `.env` 下所有 `CLAUDE_CODE_STATUSLINE_*` 键：

```bash
jq -r '.env // {} | to_entries[] | select(.key | startswith("CLAUDE_CODE_STATUSLINE_")) | "\(.key)=\(.value)"' ~/.claude/settings.json
```

### 1) 无参数或 `show`：展示配置表格

输出一个表格，列出所有配置项的当前值和默认值：

```
| 配置项     | 当前值         | 默认值   | 状态     |
|-----------|---------------|---------|---------|
| segments  | (全部)         | (全部)   | 默认     |
| theme     | dracula       | default | 已自定义 |
| layout    | bars          | bars    | 默认     |
| bar-style | diamonds      | ascii   | 已自定义 |
| pct-mode  | left          | used    | 已自定义 |
| max-width | (auto)        | auto    | 默认     |
```

表格后列出可用命令。

---

## 交互式显示

### `/statusline segments` — 多选 Checkbox

读取当前 `CLAUDE_CODE_STATUSLINE_SEGMENTS` 值。如果为空/未设置，则所有段落默认勾选。

显示格式：

```
段落配置：

[x] model    模型名（如 Opus 4.6）
[x] eff      推理努力（eff low/med/high）
[x] git      Git 分支 + diff 统计
[x] ctx      上下文使用率
[x] 5h       5 小时限制 + reset 时间
[x] 7d       7 天限制 + reset 时间
[ ] extra    额外用量（$12/$20）

输入段落名切换显示/隐藏（支持模糊匹配），如：extra, git
或使用命令：/statusline segments show extra
```

#### 切换逻辑

用户输入段落名后（支持逗号分隔多个，支持模糊前缀匹配）：

1. 读取当前 SEGMENTS 值，解析为集合
2. 如果当前为空（全部显示），先填充完整列表 `model,eff,git,ctx,5h,7d,extra`
3. 用户输入的段落名如果在集合中则移除（取消勾选），不在则添加（勾选）
4. 如果操作后集合包含全部 7 个段落，则删除 env var（恢复默认=全部显示）
5. 否则写入逗号分隔列表

写入命令：
```bash
# 设置
jq --arg val "model,eff,git,ctx" '.env["CLAUDE_CODE_STATUSLINE_SEGMENTS"] = $val' ~/.claude/settings.json > /tmp/claude-settings-tmp.json && mv /tmp/claude-settings-tmp.json ~/.claude/settings.json

# 删除（恢复全部）
jq 'del(.env["CLAUDE_CODE_STATUSLINE_SEGMENTS"])' ~/.claude/settings.json > /tmp/claude-settings-tmp.json && mv /tmp/claude-settings-tmp.json ~/.claude/settings.json
```

#### `/statusline segments show <name>`

将 name 添加到 SEGMENTS 列表（如果已在则提示无需操作）。

#### `/statusline segments hide <name>`

将 name 从 SEGMENTS 列表移除。如果当前为空（全部显示），先填充完整列表再移除。

#### `/statusline segments reset`

删除 SEGMENTS env var，恢复全部显示。

---

### `/statusline theme` — 单选 Radio

读取当前 THEME 值，显示单选列表：

```
可用主题：

(●) default      蓝色主调，高对比度
( ) forest       绿色主调，柔和自然
( ) dracula      紫色主调，暗色背景下表现出色
( ) monokai      青色主调，经典代码编辑器风格
( ) solarized    蓝色主调，低对比度护眼
( ) ocean        青蓝主调，清爽海洋风
( ) sunset       珊瑚橙主调，温暖日落氛围
( ) amber        琥珀金主调，沉稳大地色
( ) rose         玫瑰粉主调，柔和优雅

输入主题名切换（支持模糊匹配）
```

用户输入后执行模糊匹配、写入、展示变更前后对比，并自动触发该主题的 preview 色块展示。

### `/statusline layout` — 单选 Radio

```
可用布局：

(●) bars      概览行 + 5h/7d 进度条（默认，3 行）
( ) compact   所有信息单行紧凑显示

输入布局名切换
```

### `/statusline bar-style` — 单选 Radio

```
可用进度条样式：

(●) ascii       [====-----]
( ) dots        [●●●●○○○○○]
( ) squares     [■■■■□□□□□]
( ) blocks      [████░░░░░]
( ) braille     [⣿⣿⣿⣿⣀⣀⣀⣀⣀]
( ) shades      [▓▓▓▓░░░░░]
( ) diamonds    [◆◆◆◆◇◇◇◇◇]
( ) custom:X:Y  自定义填充/空白字符

输入样式名切换（支持模糊匹配）
```

### `/statusline pct-mode` — 单选 Radio

```
百分比模式：

(●) used   显示已用百分比（如 83%）
( ) left   显示剩余百分比（如 17% left）

输入模式名切换
```

---

## 子命令有参数：直接切换

例如 `/statusline theme dracula`，直接切换无需交互。

### 值验证

- **segments**: 每个值必须是 `model,eff,git,ctx,5h,7d,extra` 之一
- **theme**: 必须是 9 个合法值之一，支持模糊匹配
- **layout**: 必须是 `bars` 或 `compact`
- **bar-style**: 必须是 7 个预设之一或 `custom:<filled>:<empty>` 格式，支持模糊匹配
- **pct-mode**: 必须是 `used` 或 `left`
- **max-width**: 必须是正整数或 `auto`
- **time-format**: 必须包含至少一个 `%` 占位符

### 模糊匹配

对 theme 和 bar-style 的值进行前缀/子串匹配：
- `drac` → `dracula`
- `sol` → `solarized`
- `dia` → `diamonds`

若匹配到多个候选，列出所有匹配项让用户选择。若无匹配，提示合法值列表。

### 写入 settings.json

使用 jq + 临时文件 + mv 原子操作：

```bash
# 设置值
jq --arg val "<VALUE>" '.env["CLAUDE_CODE_STATUSLINE_<KEY>"] = $val' ~/.claude/settings.json > /tmp/claude-settings-tmp.json && mv /tmp/claude-settings-tmp.json ~/.claude/settings.json

# 删除值（用于 reset 或 max-width auto）
jq 'del(.env["CLAUDE_CODE_STATUSLINE_<KEY>"])' ~/.claude/settings.json > /tmp/claude-settings-tmp.json && mv /tmp/claude-settings-tmp.json ~/.claude/settings.json
```

### 变更确认

写入后输出变更前后对比：

```
✅ theme: default → dracula

提示：新配置将在下次状态栏刷新时生效。
```

---

## `reset`：恢复默认

删除 `.env` 下所有 `CLAUDE_CODE_STATUSLINE_*` 键：

```bash
jq 'if .env then .env |= with_entries(select(.key | startswith("CLAUDE_CODE_STATUSLINE_") | not)) else . end' ~/.claude/settings.json > /tmp/claude-settings-tmp.json && mv /tmp/claude-settings-tmp.json ~/.claude/settings.json
```

输出所有被清除的自定义项列表。

---

## `preview`：ANSI 色块预览

读取脚本中对应主题的 RGB 值，输出 ANSI 色块预览。

对每个颜色角色，用 `\033[48;2;R;G;Bm  \033[0m` 输出背景色块 + 角色名：

```bash
printf '\033[48;2;189;147;249m  \033[0m accent  '
printf '\033[48;2;139;233;253m  \033[0m teal  '
```

最终效果：
```
dracula 主题色板：
██ accent (模型名)  ██ teal (路径)  ██ branch (分支名)
██ muted (次要信息)  ██ red (删除/错误)  ██ orange (警告)
██ yellow (中等)  ██ green (新增/正常)  ██ white (文本)
```

如果用户没指定主题名，预览当前激活的主题。

---

## `update`：从 GitHub 拉取最新版本并安装

远程仓库：`https://github.com/kaelinda/AICodingStatusLine`
本地缓存目录：`/tmp/AICodingStatusLine`

流程：

1. 克隆或更新本地缓存：

```bash
REPO_DIR="/tmp/AICodingStatusLine"
if [ -d "$REPO_DIR/.git" ]; then
    git -C "$REPO_DIR" pull --ff-only
else
    rm -rf "$REPO_DIR"
    git clone https://github.com/kaelinda/AICodingStatusLine.git "$REPO_DIR"
fi
```

2. 比较并复制有差异的文件到 `~/.claude/statusline.sh`

3. 输出更新结果（已更新的文件列表 + 最近 5 条 commit）

---

## 智能联动提示

修改配置后，根据上下文给出建议：

- 修改 `bar-style` 但 `layout` 不是 `bars` 时：
  > 提示：进度条样式仅在 `layout=bars` 时可见。要切换布局吗？

- 修改 `layout` 为 `bars` 且 `bar-style` 是 `ascii` 时：
  > 建议：bars 布局搭配 `dots`、`blocks` 或 `diamonds` 样式效果更佳。

- 修改 `theme` 时，自动触发该主题的 preview 色块展示。

---

## 注意事项

- 始终使用 jq 操作 JSON，不要手动拼接字符串
- 写入前确保 `.env` 对象存在：`jq '.env //= {}' ...`
- 如果 `~/.claude/settings.json` 不存在，用 `{"env":{}}` 初始化
- 所有输出使用中文
- 每次修改后提醒用户配置将在下次状态栏刷新时生效
