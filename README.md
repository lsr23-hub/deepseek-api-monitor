# DeepSeek API Monitor

macOS 菜单栏小组件，实时监控 DeepSeek API 余额和月度消费。

## 功能

- 🐋 菜单栏显示余额（鲸鱼图标 + 金额）
- 📊 下拉面板展示总余额、充值余额、本月消费
- 📈 按模型分类的月度消费数据
- 🔒 API Key 存储于 macOS Keychain，不上传明文
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

首次运行后菜单栏右侧出现 🐋 图标。点击展开面板，点击 ⚙️ 齿轮设置 API Key。

### 配置

**1. 获取 API Key**（必需）

打开 [platform.deepseek.com](https://platform.deepseek.com/) → API Keys → 创建 Key → 复制。

在应用设置面板粘贴，点击「测试连接」。

**2. 获取月度消费数据**（可选）

1. 浏览器打开 [platform.deepseek.com](https://platform.deepseek.com/) 并登录
2. 按 `F12` → **Application** → **Local Storage** → 找到 `userToken` 键
3. 复制它的值（一串 JWT token）
4. 在设置面板粘贴到 userToken 输入框

> **获取方式图解：**
> ![获取userToken的步骤](https://img.shields.io/badge/步骤-F12_→_Application_→_Local_Storage_→_userToken-blue)

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
| API Key | macOS Keychain（加密） | `~/Library/Keychains/` |
| userToken | macOS Keychain（加密） | `~/Library/Keychains/` |
| 余额缓存 | UserDefaults | `~/Library/Preferences/` |

- 源代码零硬编码密钥
- 首次启动自动将旧版 UserDefaults 凭据迁移至 Keychain 并删除明文

## 项目结构

```
Sources/DeepSeekMonitor/
├── App.swift                # @main 入口，MenuBarExtra 场景
├── MenuBarLabel.swift       # 菜单栏图标（🐋） + 余额文字
├── MenuBarContent.swift     # 下拉面板 UI
├── SettingsView.swift       # API Key / userToken 设置
├── BalanceViewModel.swift   # 状态管理 + 自动刷新 + Keychain
├── DeepSeekAPI.swift        # DeepSeek API 客户端（余额 + 平台消费）
├── KeychainStore.swift      # macOS Keychain 安全存储封装
└── CurrencyFormatter.swift  # 货币格式化工具
```

## 许可证

MIT
