# DeepSeek API Monitor

macOS 菜单栏小组件，实时监控 DeepSeek API 余额和月度消费。

## 功能

- 🐋 菜单栏显示余额（鲸鱼图标 + 金额）
- 📊 下拉面板展示总余额、充值余额、本月消费
- 📈 月度消费数据（通过 platform.deepseek.com 内部 API）
- 🔒 API Key 存储于 macOS Keychain，不上传明文
- 🔄 每 5 分钟自动刷新 + Mac 唤醒自动刷新
- 💾 离线缓存上次数据
- 🌓 自动适配浅色/深色模式

## 系统要求

- macOS 13.0+
- Swift 5.9+（Xcode 15+ 或 Command Line Tools）

## 构建

```bash
cd api监控桌面组件
swift build -c release
```

编译产物在 `.build/arm64-apple-macosx/release/DeepSeekMonitor`

## 运行

```bash
# Debug 模式
swift run

# 或直接运行编译产物
.build/arm64-apple-macosx/release/DeepSeekMonitor
```

首次运行后会出现在菜单栏右侧（🐋 图标）。点击展开面板，点击 ⚙️ 设置 API Key。

## 配置

### 基础配置（必需）

1. 在 [DeepSeek 开放平台](https://platform.deepseek.com/) 获取 API Key
2. 点击面板中的 ⚙️ 齿轮按钮
3. 输入 API Key，点击「测试连接」
4. API Key **存储于 macOS Keychain**，安全加密

### 月度消费（可选）

1. 浏览器打开 [platform.deepseek.com](https://platform.deepseek.com/) 并登录
2. 按 `F12` → Application → Local Storage → 复制 `userToken` 值
3. 在设置面板粘贴到 userToken 输入框

## 安全

- API Key 和 userToken 存储于 **macOS Keychain**，不写入 UserDefaults
- 首次启动时自动将旧版 UserDefaults 中的凭据迁移至 Keychain
- 源代码不包含任何硬编码密钥

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
