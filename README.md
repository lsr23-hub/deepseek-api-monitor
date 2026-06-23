# AI API Monitor

macOS 菜单栏小组件，实时监控 DeepSeek API 和快跑 API 的余额与用量。

## 功能

- 🐋 菜单栏显示 DeepSeek 余额（鲸鱼图标 + 金额）
- 🚀 快跑 API 账户余额监控（真实货币显示）
- 📊 下拉面板展示总余额、充值余额、本月消费
- 📈 按模型分类的月度消费数据
- 💰 快跑账户剩余额度 / 已使用 / 总额度，自动换算真实货币
- 🔒 全部凭证存储于 macOS Keychain，不上传明文
- 🔄 每 5 分钟自动刷新 + Mac 唤醒自动刷新
- 💾 离线缓存上次数据
- 🌓 自动适配浅色/深色模式

## 截图

点击菜单栏 🐋 图标展开：

```
┌──────────────────────────┐
│ 🧠 DeepSeek API     ⚙️  │
│──────────────────────────│
│  总余额              🟢可用│
│  ¥ 110.00                │
│                          │
│  💳 充值余额   📉 本月消费 │
│  ¥100.00       ¥3.45     │
│──────────────────────────│
│ 📊 快跑 API         🟢正常│
│  剩余额度                 │
│  $5.69                   │
│                          │
│  🔼 已使用   💳 总额度    │
│  $34.32      $40.02      │
│──────────────────────────│
│ 更新于 14:30:05     🔄刷新│
└──────────────────────────┘
```

## 快速开始

### 环境要求

- macOS 13.0+
- Xcode Command Line Tools（或 Xcode 15+）

检查是否已安装：

```bash
xcode-select -p && swift --version
```

未安装则运行：

```bash
xcode-select --install
```

### 安装运行

```bash
# 1. 克隆仓库
git clone https://github.com/lsr23-hub/deepseek-api-monitor.git
cd deepseek-api-monitor

# 2. 编译 release 版本
swift build -c release

# 3. 运行
.build/arm64-apple-macosx/release/DeepSeekMonitor
```

首次运行后菜单栏右侧出现 🐋 图标。点击展开面板，点击 ⚙️ 齿轮设置凭证。

### 配置

#### DeepSeek API（可选）

##### 获取 API Key

打开 [platform.deepseek.com](https://platform.deepseek.com/) → API Keys → 创建 Key → 复制。

在应用设置面板粘贴，点击「测试连接」。

##### 获取月度消费数据（可选）

1. 浏览器打开 [platform.deepseek.com](https://platform.deepseek.com/) 并登录
2. 按 `F12` → **Application** → **Local Storage** → 找到 `userToken` 键
3. 复制它的值（一串 JWT token）
4. 在设置面板粘贴到 userToken 输入框

#### 快跑 API（可选）

##### 获取 Access Token

1. 浏览器打开 [kuaipao.ai](https://kuaipao.ai/) 并登录
2. 控制台 → 个人设置 → 生成 Access Token
3. 复制 Token 值，在应用设置面板粘贴到「快跑 Access Token」输入框

##### 获取用户 ID

1. 在 kuaipao.ai 页面按 `F12` → **Console**
2. 输入 `JSON.parse(localStorage.getItem('user')).id`，回车
3. 复制输出的数字，在应用设置面板粘贴到「快跑 用户 ID」输入框

> DeepSeek 和快跑可独立配置，只填一个也能正常工作。

### 设为开机自启

```bash
# 将编译产物复制到 Applications
cp .build/arm64-apple-macosx/release/DeepSeekMonitor /Applications/

# macOS 系统设置 → 通用 → 登录项与扩展 → 添加 DeepSeekMonitor
```

完成后每次开机自动出现在菜单栏。

## 安全

| 存储项 | 方式 | 位置 |
| ------ | ---- | ---- |
| DeepSeek API Key | macOS Keychain | `~/Library/Keychains/` |
| DeepSeek userToken | macOS Keychain | `~/Library/Keychains/` |
| 快跑 Access Token | macOS Keychain | `~/Library/Keychains/` |
| 快跑 用户 ID | macOS Keychain | `~/Library/Keychains/` |
| 余额缓存 | UserDefaults | `~/Library/Preferences/` |

- 源代码零硬编码密钥
- 首次启动自动将旧版 UserDefaults 凭据迁移至 Keychain 并删除明文
- 所有网络请求仅访问 `api.deepseek.com`、`platform.deepseek.com` 和 `kuaipao.ai`

## 项目结构

```
Sources/DeepSeekMonitor/
├── App.swift                # @main 入口，MenuBarExtra 场景
├── MenuBarLabel.swift       # 菜单栏图标（🐋） + 余额文字
├── MenuBarContent.swift     # 下拉面板 UI（DeepSeek + 快跑双面板）
├── SettingsView.swift       # 凭证设置（API Key / userToken / Access Token / 用户 ID）
├── BalanceViewModel.swift   # 状态管理 + 自动刷新 + Keychain + 货币换算
├── DeepSeekAPI.swift        # DeepSeek API 客户端（余额 + 平台消费）
├── KuaipaoAPI.swift         # 快跑 API 客户端（账户余额 + 配额换算）
├── KeychainStore.swift      # macOS Keychain 安全存储封装
└── CurrencyFormatter.swift  # 货币格式化工具
```

## 更新日志

### v2.0.0 (2026-06-23)

- 新增快跑 API (kuaipao.ai) 账户余额监控
- 配额自动换算为真实货币（`$`）显示
- DeepSeek 与快跑独立刷新，可单独配置
- 快跑面板视觉风格与 DeepSeek 统一对齐

### v1.0.0 (2026-06-15)

- DeepSeek API 余额实时显示
- 月度消费详情（按模型分类）
- macOS Keychain 安全存储
- 自动刷新 + 唤醒刷新 + 离线缓存

## 许可证

MIT
