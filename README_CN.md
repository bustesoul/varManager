# varManager
[English](README.md) | [简体中文](README_CN.md)

现代化的 Virt-A-Mate var 包管理工具。使用符号链接高效管理 var 文件，配备精美的跨平台界面和强大的后端服务。

## 当前版本：2.0.0（重大更新）

### v2.0.0 新特性

**完全架构重写** - 我们使用现代技术从零重构了 varManager：

#### 新架构
```
┌─────────────────────────────────┐
│  Flutter 前端 (Dart)            │  跨平台界面，Material Design 3
├─────────────────────────────────┤
│  Rust 后端 (HTTP 服务)          │  高性能异步作业系统
├─────────────────────────────────┤
│  SQLite 数据库                  │  轻量级数据存储
└─────────────────────────────────┘
```

#### 核心改进

**1. 现代化用户界面**
- Material Design 3 主题，响应式布局
- 实时作业日志流式输出
- 增强的过滤和搜索功能
- 更好的预览图管理
- PackSwitch 集成到主窗口

**2. 性能与可靠性**
- Rust 驱动的后端，处理速度更快
- 异步作业队列，支持并发执行
- 更好的内存管理和缓存机制
- 原生 Windows 符号链接支持

**3. 跨平台就绪**
- 使用 Flutter 构建 - 支持 Windows、macOS 和 Linux
- 无需 .NET Runtime 依赖
- 更小的部署包体积
- 安装更简单

**4. 功能增强**
- 完整的依赖分析（快速/普通/递归 三种模式）
- Hub 集成，支持批量下载
- 场景分析，支持拖拽排序
- 缺失 var 智能链接解析
- 过时包清理功能

#### 安装与部署

**发布包结构：**
```
varManager_v2.0.0/
├── varManager.exe              # 主程序（Flutter）
├── data/                        # 运行时数据和后端
│   ├── varManager_backend.exe  # 后端服务（Rust）
│   ├── flutter_windows.dll     # Flutter 运行时
│   ├── *_plugin.dll            # 插件 DLL
│   └── flutter_assets/         # Flutter 资源
├── VaM_Plugins/                 # VaM 游戏插件（可选）
│   ├── loadscene.cs            # MMD 场景加载器
│   ├── MorphMerger.cs          # 形态合并工具
│   └── README.txt              # 插件安装指南
└── config.json                 # 首次运行自动生成
```

**首次运行：**
1. 解压所有文件到一个文件夹
2. 运行 `varManager.exe`
3. 后端服务将自动启动
4. 在设置页面配置 VaM 路径
5. 点击 "Update DB" 扫描你的 var 文件

**VaM 插件（可选）：**

发布包中包含了可选的 VaM 插件脚本，位于 `VaM_Plugins/` 文件夹：

- **loadscene.cs** - 在 VaM 中直接加载 MMD 场景和动画
- **MorphMerger.cs** - 角色形态合并工具

使用这些插件：
1. 找到你的 VaM 安装目录
2. 进入 `Custom\Scripts\` 文件夹
3. 将 `VaM_Plugins/` 中的 `.cs` 文件复制到该文件夹
4. 启动 VaM，在插件列表中找到这些插件

⚠️ **注意：** 这些脚本运行在 VaM 的 Unity 引擎中，与 varManager 应用程序是分离的。

**Hub 下载支持：**

varManager 后端内置了从 VaM Hub 下载 var 包的支持：

- 集成在 Hub 浏览功能中
- 支持批量下载
- 自动处理 VaM Hub 身份验证
- 首次使用下载功能时在设置中配置 VaM Hub 凭据

**无需额外运行时：**
- ❌ 无需安装 .NET Runtime
- ❌ 无需管理员权限（正常操作）
- ✅ 自包含可执行文件
- ✅ 便携式 - 可从任意文件夹运行

#### C# 版本去哪了？

旧版 C# WinForms 应用程序（v1.0.4.x）已被**归档**到 `_archived/` 文件夹供参考。所有功能已迁移到新的 Flutter + Rust 架构，并保持功能对等和改进。

**如果你需要旧版 C# 程序：**
- 可在 `_archived/varManager/` 目录中找到
- 需要 .NET 9.0 Runtime
- 不再积极维护

#### 从 v1.0.4.x 迁移

你的数据是安全的！新版本使用相同的 SQLite 数据库格式：
- ✅ var 仓库配置已保留
- ✅ 所有包安装状态已保留
- ✅ 场景收藏和隐藏列表已保留
- ✅ 缺失 var 链接映射已保留

只需在同一文件夹中运行新版本,一切都会正常工作。

---

## 从源码构建（开发者）

如果你想从源码构建 varManager：

### 前置要求
- **Flutter SDK** 3.10+ (用于前端)
- **Rust toolchain** (用于后端)
- **Git**

### 构建所有组件
```powershell
# 构建 debug 版本 (Flutter + Rust 后端)
.\build.ps1 -Action build

# 构建 release 发布包
.\build.ps1 -Action release
```

构建脚本会自动：
1. 构建 Flutter 前端
2. 编译 Rust 后端
3. 复制 VaM 插件脚本
4. 打包所有文件到 `release/varManager_<version>/`

---

## 历史版本记录

### 版本 1.0.4.13 更新提示（已归档）：
0. **升级注意**：部署新版本前建议删除旧程序目录。清理指引（若保留目录）：`varManager.mdb`（旧 Access 数据库）、`varManager.exe`、`varManager.pdb`、`varManager.dll.config`（你可以编辑文本以提取旧版本配置）、`varManager.db*`、`varManager.log`。
1. **升级**：数据库切换为 SQLite，并升级到 .NET 9。
2. **首次运行注意**：首次运行请点击 `UPD_DB` 重建数据库。
3. **不丢数据**：var 文件与 profile 配置不依赖数据库，不会丢失。
4. **窗体优化**：更多窗口支持拖拽缩放，且 UpdateDB 重复文件日志更少。

### 版本 1.0.4.11 更新提示：
1. **支持批量下载**：在 MissingVarPage（获取缺失依赖后）和 HubPage（生成下载列表后）支持一次点击下载多个 var。
2. **注意**：该功能目前不稳定，可能需要手动检查下载结果并重新执行。下载后 *必须* 点击 `UPD_DB`，否则会重复下载相同的 var。

### 版本 1.0.4.10 更新提示：
0. **升级注意**：若需要保留旧的变量配置，请先备份 `varManager.mdb`。推荐使用全新配置以获得最佳性能。
1. **必须管理员运行**：从 1.0.4.9 起，由于 .NET 6.0 创建符号链接的要求，`varManager.exe` 必须以管理员身份运行。
2. **运行时安装**：如果 `varManager.exe` 无法运行，请安装 .NET Desktop Runtime 6.0，下载地址：[here](https://dotnet.microsoft.com/en-us/download/dotnet/6.0)。
3. **新按钮**：新增 `FetchDownloadFromHub` 按钮用于 Hub 资源获取与下载，目前支持在 `depends analyse` 页面下载单个缺失 var，下载功能由插件 [vam_downloader](https://github.com/bustesoul/vam_downloader) 提供。
