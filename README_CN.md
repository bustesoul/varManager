# varManager
[English](README.md) | [简体中文](README_CN.md)

现代化的 Virt-A-Mate var 包管理工具。使用符号链接高效管理 var 文件，配备精美的 Flutter 界面和强大的后端服务。

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

#### 核心改进（相对 v1.0.4.x）

**1. 现代 UI 与流程**
- Material 3 响应式布局与导航栏
- 交互式向导：首次运行引导完成路径配置
- 主题与语言切换（海洋/森林/玫瑰/暗色；中英）
- VAR 高级筛选（大小/依赖/内容类型）与批量操作
- PackSwitch 集成到主页侧栏
- 已安装列表导出/导入，便于分享或备份
- 缺失 VAR 详情侧栏（依赖/映射/Hub 动作）

**2. 场景与分析**
- Hide/Normal/Fav 三列看板，拖拽整理
- 原子树视图，含依赖追踪与人物详情
- 场景分析缓存与清理功能
- 快捷操作：加载/分析/定位

**3. Hub 与下载**
- 标签搜索 + 快捷筛选；卡片视图含评分/版本/依赖
- 详情弹窗补充文件大小、兼容版本、授权等信息
- 下载列表构建：计算总大小，支持复制链接给外部工具，并提供一键下载
- 内置下载管理（暂停/恢复/取消/重试），并发数可配置
- Hub 结果缓存，减少重复请求

**4. 依赖与链接管理**
- 缺失依赖扫描来源：已安装包、Saves 文件夹、VaM 日志
- 链接替换工作流：在详情面板中草稿/应用映射
- 原生符号链接支持（无需管理员）

**5. 性能与部署**
- Rust 后端异步任务队列 + 日志流
- 统一预览管线，内存 + 磁盘双层缓存
- 运行期配置编辑与校验（含文件选择器）
- 自包含打包，后端自动启停
- Windows 优先的 Flutter 应用（具备跨平台潜力）

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

**系统要求：**
- **系统:** Windows 10/11 (64位)
- **运行时:** 无需安装（完全自包含）
- **权限:** 普通用户（无需管理员）

**配置贴士：**
- **代理支持:** 在设置中配置 HTTP 代理（系统自动检测或手动设置），以加速 Hub 资源下载
- **路径说明:** `varspath` 为 VaM `AddonPackages` 目录；`vampath` 为 VaM 主安装目录

**已知问题：**
- **Windows 优先:** 本次发布暂不包含 macOS 和 Linux 版本
- **Hub 限制:** 进行大量批量下载时，可能会触发 VaM Hub 的速率限制

#### C# 版本去哪了？

旧版 C# WinForms 应用程序（v1.0.4.x）已停止维护。所有功能已迁移到新的 Flutter + Rust 架构，并保持功能对等和改进。

**如果你需要旧版 C# 程序：**
- 需要 .NET 9.0 Runtime
- 不再积极维护

#### 从 v1.0.4.x 迁移

你的数据是安全的！varManager 不会删除你的 var 包。新版本使用相同的 SQLite 数据库格式：
- ✅ var 仓库配置已保留
- ✅ 所有包安装状态已保留
- ✅ 场景收藏和隐藏列表已保留
- ✅ 缺失 var 链接映射已保留

只需在同一文件夹中运行新版本并点击 "Update DB" 重建数据库，一切都会正常工作。

**完整更新日志:** [View on GitHub 在 GitHub 上查看](https://github.com/bustesoul/varManager/compare/v1.0.4.13...v2.0.0)

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
