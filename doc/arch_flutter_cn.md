# varManager Flutter 架构说明（Flutter Architecture Notes）

## 目的（Purpose）
- 使用 Flutter（Windows、Material3（Material 3 设计））替换 WinForms UI（界面）。
- 与仍在使用的 WinForms 流程保持行为一致；跳过已知 deadcode（死代码）。
- 前端（frontend）以后台（backend）为唯一数据源。
- Flutter 负责管理后台生命周期（start/health/shutdown：启动/健康检查/关闭）。
- 分发方式：解压包内同目录包含 Flutter exe（可执行文件）+ 后台 exe（可执行文件）+ downloader（下载器）。

## 非目标（Non-Goals）
- 跨平台支持（cross-platform）。
- 后台 schema（模式）重设计（SQLite schema 保持不变）。
- 多实例支持（multi-instance）。

## 运行时概览（Runtime Overview）
```
Flutter App（Flutter 应用）
  ├─ BackendProcessManager（后台进程管理：spawn/health/shutdown）
  └─ BackendClient（HTTP 客户端）
        └─ Rust Backend（jobs + queries：任务与查询）
              └─ Filesystem + downloader exe（文件系统 + 下载器可执行文件）
```
- Flutter UI 不直接读取 SQLite 或 filesystem（文件系统）。
- 所有数据与文件访问都通过 backend APIs（后台 API）。

## 配置（Configuration）
- Config（配置）通过后台 `config.json` API 读取。
- UI 可通过后台 API 编辑 config（校验并持久化）。
- Base URL 默认使用后台 `listen_host` + `listen_port`。

## 后台生命周期（Flutter 责任）（Backend Lifecycle (Flutter Responsibility)）
- 应用启动（on app start）：
  - 若后台未运行则启动 backend exe（可执行文件）。
  - 轮询 `GET /health` 直到就绪或超时。
- 运行期间（during runtime）：
  - 所有操作使用 HTTP APIs。
- 应用退出（on app exit）：
  - 调用 `POST /shutdown`，短暂等待后若仍存活则强制结束。

## 模块结构（Flutter）（Module Structure (Flutter)）
```
lib/
  app/                // app entry, theme, routing（应用入口、主题、路由）
  core/
    backend/          // BackendClient, BackendProcessManager, JobRunner（后台客户端、进程管理、任务执行）
    models/           // DTOs and UI models（数据传输对象与 UI 模型）
    utils/            // shared helpers (format, debounce, etc.)（通用工具：格式化、去抖等）
  features/
    home/             // main vars list + filters（主变量列表与筛选）
    settings/
    missing_vars/
    scenes/
    hub/
    analysis/
    prepare_saves/
    var_detail/
    uninstall_vars/
    packswitch/
  widgets/            // shared UI components（通用组件）
  main.dart
```

## 状态管理（Keep It Simple）
- 使用 `flutter_riverpod` 做特性级状态管理与 DI（依赖注入）。
- 异步列表/任务状态使用 `StateNotifier` + `AsyncValue`。
- 本地 widget（组件）状态（选择、视图模式）使用 `ValueNotifier`。

## UI 页面映射（UI Pages and Mapping）
| Flutter 特性/页面（Feature/Page） | WinForms 来源（Source） | 说明（Notes） | 状态（Status） |
| --- | --- | --- | --- |
| Home（Vars（Var 包）列表） | Form1 | 主列表、筛选、工具栏操作 | PARTIAL（部分完成） |
| Settings Dialog（设置对话框） | FormSettings | 读取 + 编辑配置 | DONE（完成） |
| Missing Vars Dialog（缺失 Vars（Var 包）对话框） | FormMissingVars | 链接映射 + Hub 动作 | DONE（完成） |
| Scenes Page（场景页） | FormScenes | 场景列表 + 动作 | DONE（完成） |
| Hub Page（Hub 页） | FormHub + HubItem | 浏览 + 下载 | DONE（完成） |
| Analysis Dialog（分析对话框） | FormAnalysis | 预设/场景分析 | DONE（完成） |
| Prepare Saves Dialog（准备存档对话框） | PrepareSaves | 输出校验 + 复制列表 | DONE（完成） |
| Var Detail Dialog（Var 详情对话框） | FormVarDetail | 详情 + 定位 + 过滤 | DONE（完成） |
| Uninstall Vars Dialog（卸载 Vars（Var 包）对话框） | FormUninstallVars | 预览导航 | DONE（完成） |
| PackSwitch Dialogs（PackSwitch 对话框） | FormSwitchAdd/Rename + VarsMove | 添加/重命名/移动 | DONE（完成） |

## Deadcode 跳过规则（Deadcode Skip Rule）
- 仅移植可从有效 UI 处理器到达的功能。
- 排除未使用的处理器、隐藏调试功能或不可达菜单。
- 任何不明确功能标记为 "SkipCandidate（候选跳过）"。

## Job 流程（标准模式）（Job Flow (Standard Pattern)）
1. 通过 `POST /jobs` 提交 `{ kind, args }`
2. 轮询 `GET /jobs/{id}` 获取状态/进度
3. 可选：`GET /jobs/{id}/logs` 进行日志流（log streaming）
4. 成功后获取 `GET /jobs/{id}/result`

## 后台 API 契约（Flutter 使用）（Backend API Contract (Flutter Usage)）
### 已存在（后台完成/Flutter 已使用）（Existing (Backend Done / Used by Flutter)）
- `GET /health`
- `GET /config`
- `PUT /config`
- `POST /shutdown`
- `POST /jobs`
- `GET /jobs/{id}`
- `GET /jobs/{id}/logs`
- `GET /jobs/{id}/result`
- `GET /vars`
- `GET /vars/{varName}`
- `POST /vars/resolve`
- `POST /vars/dependencies`
- `POST /vars/previews`
- `GET /scenes`
- `GET /creators`
- `GET /stats`
- `GET /packswitch`
- `GET /analysis/atoms`
- `GET /saves/tree`
- `POST /saves/validate_output`
- `POST /missing/map/save`
- `POST /missing/map/load`
- `GET /preview`

### Flutter UI 需要（待后端新增）（Needed for Flutter UI (To Add in Backend)）
- None（无）

Notes（备注）:
- 优先使用简单、稳定的 DTO（数据传输对象）与分页（pagination）。
- 文件流（file streaming）仅允许在 varspath/vampath/cache 范围内（allowlist）。

## UX/性能规则（UX/Performance Rules）
- 预览图延迟加载（lazy-load）；缩略图缓存到内存。
- 搜索/筛选输入去抖（debounce）（200-300ms）。
- 轮询任务状态间隔 300-800ms；空闲时降低频率。
- 使用共享日志面板以匹配 WinForms UX（用户体验）。

## 部署规则（Deployment Rules）
- 打包布局（zip）：
  - `varManager_flutter.exe`
  - `varManager_backend.exe`
  - `plugin/vam_downloader.exe`
  - `config.json`（缺失时创建）
- 工作目录为打包根目录。

## 进度跟踪（Progress Tracking）
### 里程碑（Milestones）
- [x] App shell + theme + routing（应用外壳 + 主题 + 路由）
- [x] Backend process manager + health check（后台进程管理 + 健康检查）
- [x] Core list (vars) + filters（核心列表（vars）+ 筛选）
- [x] Job runner + log panel（任务执行器 + 日志面板）
- [x] Settings (read/write config)（设置（读/写配置））
- [x] Missing vars flow（缺失 vars 流程）
- [x] Scenes + analysis flows（场景 + 分析流程）
- [x] Hub flow（Hub 流程）
- [ ] Packaging + smoke tests（打包 + 冒烟测试）

### 跟踪表（Tracking Table）
| 区域（Area） | 任务（Task） | 状态（Status） | 备注（Notes） |
| --- | --- | --- | --- |
| App Shell（应用外壳） | Theme + routing + layout（主题 + 路由 + 布局） | DONE（完成） | Material3 baseline + rail（Material3 基线 + 导航栏） |
| Backend（后台） | Process manager + health（进程管理 + 健康检查） | DONE（完成） | Start/stop flow（启动/停止流程） |
| Data（数据） | BackendClient + DTOs（后台客户端 + DTO） | DONE（完成） | Single base URL（单一 Base URL） |
| Home（首页） | Vars list + filters（Vars 列表 + 筛选） | PARTIAL（部分完成） | list + preview + pagination/sort done; column-level filters + grid columns pending（列表 + 预览 + 分页/排序完成；列级过滤 + 网格列待完成） |
| Jobs（任务） | Update DB / install / uninstall（更新 DB / 安装 / 卸载） | DONE（完成） | job flow + logs（任务流程 + 日志） |
| Scenes（场景） | List + actions（列表 + 动作） | DONE（完成） | 3-column layout + drag + filters + paging done; no width toggles（3 列布局 + 拖拽 + 筛选 + 分页完成；无宽度切换） |
| Hub | Browse + download（浏览 + 下载） | DONE（完成） | hub_info filters + cards + paging + repo status（hub_info 筛选 + 卡片 + 分页 + 仓库状态） |
| Missing Vars（缺失 Vars） | Link map + actions（链接映射 + 动作） | DONE（完成） | ignore-version + row nav + downloads + map io（忽略版本 + 行导航 + 下载 + 映射 IO） |
| Settings（设置） | Config read/write（配置读写） | DONE（完成） | runtime update（运行期更新） |
| Packaging（打包） | Zip layout + smoke test（Zip 布局 + 冒烟测试） | TODO（待办） |  |

### 对齐待办（WinForms -> Flutter）（Parity TODO）
- Home：列级筛选（WinForms DgvFilter）。
- Home：暴露网格列（size/type counts/disabled（大小/类型计数/禁用））或等效详情视图。
- Home：为当前预览条目提供 Clear Cache（清理缓存）动作。
- Scenes：Hide/Normal/Fav 列宽度切换（可选对齐）。

## UI 全面对比：Flutter vs WinForms（Comprehensive UI Differences: Flutter vs WinForms）

### 1. Home 页面（Form1）差异（Home Page (Form1) Differences）

#### 1.1 数据展示（Data Display）
| 功能（Feature） | WinForms（Form1） | Flutter（HomePage） | 影响（Impact） |
|---------|------------------|-------------------|--------|
| **主列表（Main List）** | DataGridView（20 列） | ListView + ListTile（列表项） | 视图更简化 |
| **列数量（Column Count）** | 20 个可见列（varName（变量名）、installed（已安装）、fsize（文件大小）、metaDate（元数据日期）、varDate（包日期）、scenes（场景）、looks（外观）、clothing（服装）、hairstyle（发型）、plugins（插件）、assets（资源）、morphs（变形）、pose（姿势）、skin（皮肤）、disabled（已禁用）等） | 4 个可见字段（title（标题）、subtitle（副标题）、status chip（状态 Chip）、details button（详情按钮）） | 信息密度降低 |
| **列过滤（Column Filtering）** | DgvFilterPopup（列过滤弹窗）- 右键列头进行高级过滤 | 无列级过滤 | 缺少高级过滤能力 |
| **行选择（Row Selection）** | 点击行选择 | Checkbox（复选框）+ 行点击 | 相似 |
| **详情按钮（Detail Button）** | 网格列内按钮 | ListTile 尾部按钮 | 功能相似 |
| **安装状态（Install Status）** | Checkbox 列（可点击切换） | Chip 指示器（仅展示，不可交互） | 直接控制减少 |

#### 1.2 筛选与搜索（Filtering & Search）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **基础筛选（Basic Filters）** | Creator dropdown（创作者下拉框）、search textbox（搜索框）、installed 3-state checkbox（已安装三态复选） | Creator dropdown（创作者下拉框）、search textbox（搜索框）、installed dropdown（已安装下拉，3 选项） | 能力相近 |
| **高级筛选（Advanced Filters）** | DgvFilterPopup（列级筛选） | 专用筛选行：package name（包名）、version（版本）、disabled（禁用）、size range（大小范围，min/max MB）、dependency count range（依赖数量范围，min/max）、12 项 presence filters（存在性筛选，如 hasScene、hasLook 等） | 方案不同：Flutter 有专用高级筛选但无列头筛选 |
| **筛选重置（Filter Reset）** | Reset 按钮 + DgvFilterPopup 重置 | 选择行中的 Clear 按钮 | 相似 |
| **去抖（Debouncing）** | 无（即时筛选） | 搜索 250ms、筛选 300ms 去抖 | Flutter 体验更好 |

#### 1.3 预览面板（Preview Panel）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **布局（Layout）** | SplitContainer（可调整） | 响应式布局（Row/Column 随宽度切换） | Flutter 更适配屏幕 |
| **预览列表（Preview List）** | ListView（VirtualMode，128x128 图片） | GridView（动态 2-6 列，响应式） | Flutter 更灵活 |
| **缓存清理（Cache Clear）** | 当前预览条目的 Clear Cache 按钮 | 缺失（MISSING） | 功能缺失 |
| **预览类型筛选（Preview Type Filter）** | ComboBox + "Loadable" checkbox | Dropdown filter（下拉筛选） | 相似 |
| **预览详情（Preview Detail）** | TableLayoutPanel + 文本字段 | Card（卡片）+ 图片 + 文本 + 按钮 | 布局方式不同 |
| **图片尺寸（Image Size）** | 固定 ImageList 128x128 | BorderedImage（可变尺寸） | Flutter 更灵活 |

#### 1.4 工具栏与动作（Toolbar & Actions）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **主动作（Main Actions）** | Update DB、Start VAM、Install Selected、Uninstall Selected、Delete Selected | Update DB、Start VaM、Install Selected、Uninstall Selected（主工具栏无 Delete） | Delete 移到选择操作 |
| **Pack Switch** | ComboBox + Add/Del/Rename 按钮（右侧面板） | 独立 PackSwitch 页面 | 导航重组 |
| **依赖分析（Dependency Analysis）** | 4 个按钮：Installed Packages、All Packages、Saves JsonFile、Filtered Packages | 3 个 "Missing deps"（缺失依赖）按钮，含 level 标识（fast/normal/recursive） | 简化为缺失依赖 |
| **导出/导入（Export/Import）** | Export Insted、Install By TXT 按钮 | Export List、Import List 按钮（选择操作内） | 功能相似 |
| **移动到子目录（Move to SubDir）** | 独立按钮 | "Move to subdir" 按钮（选择操作内） | 功能相同 |
| **浏览/Hub（Browser/Hub）** | 带 Hub 图标的 "Brow" 按钮 | 独立 Hub 导航入口 | Flutter 组织更好 |

#### 1.5 分页（Pagination）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **控件（Controls）** | BindingNavigator（首页/上页/下页/末页） | 带页码 + 导航按钮的 Row | 功能相似 |
| **每页选项（Per-Page Options）** | 主表中不可见 | 下拉（25/50/100/200） | Flutter 更灵活 |
| **位置（Position）** | 列表顶部 | 列表顶部 + 底部 | Flutter 体验更好 |

#### 1.6 选择信息（Selection Info）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **选择数量（Selection Count）** | 不明显显示 | "X selected" 文本 + Clear 按钮 | Flutter 可见性更好 |
| **选择动作（Selection Actions）** | 底部 FlowLayoutPanel | 列表下方 Wrap（Install、Uninstall、Delete、Move、Export、Import、Locate） | 动作更完整 |

---

### 2. Settings 页面差异（Settings Page Differences）

| 功能（Feature） | WinForms（FormSettings） | Flutter（SettingsPage） | 影响（Impact） |
|---------|------------------------|----------------------|--------|
| **编辑模式（Edit Mode）** | 只读显示 + 文件夹浏览 | 可编辑 TextFields | **重大（MAJOR）** - Flutter 允许运行期修改配置 |
| **路径选择（Path Selection）** | FolderBrowserDialog、OpenFileDialog | 手工输入 + 校验 | Flutter 便捷性降低（无文件选择器） |
| **配置持久化（Config Persistence）** | 未实现（只读） | `PUT /config` API 保存到后台 | 功能改进 |
| **字段（Fields）** | varspath、vampath、exec（3 个字段） | `config.json` 全字段可编辑 | 更全面 |
| **校验（Validation）** | 无 | 保存时后台校验 | 错误处理更好 |

---

### 3. Missing Vars 页面差异（Missing Vars Page Differences）

#### 3.1 布局（Layout）
| 功能（Feature） | WinForms（FormMissingVars） | Flutter（MissingVarsPage） | 影响（Impact） |
|---------|---------------------------|--------------------------|--------|
| **主列表（Main List）** | DataGridView + ToolStrip | 自定义行表（表头 + ListView） | 视觉风格不同 |
| **列（Columns）** | 网格列 | Flex Row（Missing Var、Link To、DL 图标） | 信息相近 |
| **详情面板（Details Panel）** | 无 | 右侧栏（360px），含 Details/Dependents/Dependent Saves | **重大（MAJOR）** - 信息展示更好 |

#### 3.2 筛选（Filtering）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **版本筛选（Version Filter）** | ToolStrip ComboBox（ignore version） | Dropdown（ignore/all） | 功能相同 |
| **创作者筛选（Creator Filter）** | 不可见 | Dropdown filter | Flutter 新增 |
| **搜索（Search）** | 不可见 | TextField 搜索 | Flutter 新增 |

#### 3.3 导航（Navigation）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **行导航（Row Navigation）** | 仅滚动 | 分页导航（首页/上页/下页/末页 + 行计数） | Flutter 导航更好 |

#### 3.4 动作（Actions）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **下载（Download）** | ToolStrip 按钮 | 详情面板内的卡片按钮 | 组织更好 |
| **映射 I/O（Map I/O）** | ToolStrip 按钮 | 独立卡片按钮 | 功能相似 |
| **链接编辑（Link Editing）** | 表格内编辑 | 详情面板 TextField + Set/Clear 按钮 | 交互更明确 |
| **Google 搜索（Google Search）** | 不可见 | 选中 var 的 "Google Search" 按钮 | Flutter 新增 |

#### 3.5 下载状态（Download Status）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **指示器（Indicator）** | 列文本/图标 | 图标 + 颜色编码（cloud_done=green、cloud_download=orange、block=grey） | 更直观 |

---

### 4. Scenes 页面差异（Scenes Page Differences）

#### 4.1 显示模式（Display Mode）
| 功能（Feature） | WinForms（FormScenes） | Flutter（ScenesPage） | 影响（Impact） |
|---------|----------------------|---------------------|--------|
| **主视图（Main View）** | 单一 ListView（VirtualMode） | 3 列布局（Hide/Normal/Fav） | **重大（MAJOR）** - 组织方式不同 |
| **列可见性（Column Visibility）** | 单列表视图 | FilterChips 切换列显示 | Flutter 更灵活 |
| **宽度切换（Width Toggles）** | 无 | 无（响应式宽度） | 对齐一致 |

#### 4.2 场景卡片（Scene Cards）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **布局（Layout）** | ListViewItem + 图片 | Card + Wrap（图片 + 文本 + Chips + 按钮） | Flutter 更丰富 |
| **图片尺寸（Image Size）** | 固定（来自 ImageList） | ClipRRect 72x72 | 相似 |
| **动作（Actions）** | 右键菜单或按钮 | 6 个 TextButtons（Load、Analyze、Locate 等） | Flutter 更可见 |

#### 4.3 拖拽（Drag & Drop）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **实现（Implementation）** | DragAndDropListView 自定义控件 | LongPressDraggable + DragTarget | 均支持拖拽 |
| **反馈（Visual Feedback）** | 自定义反馈 | Material elevation + opacity | Flutter 更精致 |

#### 4.4 筛选（Filtering）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **类别（Category）** | ComboBox（8 types） | Dropdown（8 types） | 相同 |
| **创作者（Creator）** | ComboBox | Dropdown | 相同 |
| **位置（Location）** | 不可见 | FilterChips（Installed/Not installed/MissingLink/Save） | Flutter 新增 |
| **名称搜索（Name Search）** | TextBox | TextField | 相同 |
| **排序（Sorting）** | ComboBox（Date/VarName/Creator） | Dropdown（4 选项） | 相近 |
| **高级选项（Advanced Options）** | Checkboxes（Merge、Ignore gender、Male） | FilterChips | 功能相同，控件不同 |
| **人物顺序（Person Order）** | RadioButtons（1-8） | Dropdown（1-8） | 控件不同 |

---

### 5. Hub 页面差异（Hub Page Differences）

#### 5.1 布局（Layout）
| 功能（Feature） | WinForms（FormHub） | Flutter（HubPage） | 影响（Impact） |
|---------|-------------------|------------------|--------|
| **主视图（Main View）** | DataGridView | GridView + ResourceCards | 更视觉化 |
| **侧边栏（Sidebar）** | 无 | 左侧栏（340px），包含所有筛选 | Flutter 组织更好 |

#### 5.2 资源展示（Resource Display）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **格式（Format）** | 表格行 | 卡片（图片 + 元数据） | 更现代 |
| **图片（Image）** | 无预览图 | 96x96 缩略图 | 更利于浏览 |
| **动作（Actions）** | 列按钮 | 按钮行（Repository status、Add Downloads、Open Page） | 功能相似 |
| **快捷筛选（Quick Filters）** | 无 | ActionChip 标签（paytype/type/creator） | Flutter 新增便捷入口 |

#### 5.3 筛选（Filtering）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **筛选位置（Filter Location）** | 顶部 ComboBoxes | 左侧栏（集中展示） | 组织更好 |
| **筛选数量（Filter Count）** | 7 个筛选 | 7 个筛选（Location、Pay Type、Category、Creator、Tag、Primary Sort、Secondary Sort） | 覆盖一致 |
| **搜索（Search）** | 搜索框 | 侧边栏 TextField | 相同 |

#### 5.4 下载管理（Download Management）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **下载列表（Download List）** | 独立区域/对话框 | 侧边栏卡片 | 更集成 |
| **动作（Actions）** | ToolStrip 按钮 | Outlined 按钮（Download All、Copy Links、Clear List） | 功能相似 |

#### 5.5 仓库状态（Repository Status）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **状态展示（Status Display）** | 表格文本 | FilledButton.tonal + 动态文本（In Repository/Generate Download/Upgrade 等） | Flutter 反馈更直观 |

---

### 6. Analysis 页面差异（Analysis Page Differences）

#### 6.1 布局（Layout）
| 功能（Feature） | WinForms（FormAnalysis） | Flutter（AnalysisPage） | 影响（Impact） |
|---------|------------------------|----------------------|--------|
| **主视图（Main View）** | TreeView + ListBox | 左侧面板（320px）+ 右侧树面板（展开） | 组织不同 |
| **树控件（Tree Control）** | triStateTreeViewAtoms（自定义） | ExpansionTile 树 + Checkbox | 功能相似 |

#### 6.2 人物选择（Person Selection）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **控件（Control）** | ListBox | Card 内 RadioListTile | 更符合 Material Design |

#### 6.3 Look 选项（Look Options）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **类型筛选（Type Filters）** | Checkboxes | FilterChips | Flutter 更紧凑 |
| **人物顺序（Person Order）** | Analysis 窗体内不可见 | Dropdown（1-8） | Flutter 新增 |
| **忽略性别（Ignore Gender）** | Checkbox | FilterChip | 功能相同 |

#### 6.4 动作（Actions）
| 功能（Feature） | WinForms | Flutter | 影响（Impact） |
|---------|----------|---------|--------|
| **单个 Atom（Single Atom）** | Buttons | FilledButtons（4 个：Load Look、Load Pose、Load Animation、Load Plugin） | 功能相同 |
| **场景加载（Scene Load）** | Buttons | FilledButtons（4 个：Load Scene、Add To Scene、Add as Subscene、Clear Selection） | 功能相同 |
| **选择计数（Selection Count）** | 未显示 | "X atoms selected" 文本 | Flutter 反馈更好 |

---

### 7. Var 详情页面差异（Var Detail Page Differences）

| 功能（Feature） | WinForms（FormVarDetail） | Flutter（VarDetailPage） | 影响（Impact） |
|---------|-------------------------|------------------------|--------|
| **布局（Layout）** | 3 个 DataGridView（Dependencies、Dependent Vars、Dependent Saves） | 卡片 + ListTile 列表 | 视觉方式不同 |
| **颜色编码（Color Coding）** | 行颜色（red=missing、yellow=version mismatch、green=installed） | 行颜色（red=missing、orange=close version、green=installed） | 相似但略有差异 |
| **动作（Actions）** | Locate 按钮、Filter 按钮 | Locate 按钮、Filter 按钮 | 功能相同 |
| **信息展示（Info Display）** | TextBox 字段 | Card 文本字段 | 相似 |

---

### 8. 其他页面差异（Other Pages Differences）

#### 8.1 PackSwitch
| 功能（Feature） | WinForms（FormSwitchAdd/Rename + VarsMove） | Flutter（PackSwitchPage） | 影响（Impact） |
|---------|-------------------------------------------|-------------------------|--------|
| **组织方式（Organization）** | 3 个独立对话框 | 单页 + Tabs/Sections | Flutter 体验更好 |
| **列表展示（List Display）** | 无 | 现有 switches 列表 | Flutter 可见性更高 |

#### 8.2 Uninstall Vars 预览（Uninstall Vars Preview）
| 功能（Feature） | WinForms（FormUninstallVars） | Flutter（UninstallVarsPage） | 影响（Impact） |
|---------|------------------------------|---------------------------|--------|
| **预览列表（Preview List）** | DataGridView + 预览面板 | 列表 + 预览图片 | 相似 |
| **依赖展示（Dependency Display）** | DataGridView | 列表 | 信息相近 |
