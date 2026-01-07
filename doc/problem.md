性能问题清单（按影响排序）

1) 日志触发全局重建：`varmanager_flutter/lib/app/app.dart` 中 `ref.watch(jobLogProvider)` 在 AppShell 顶层，任务日志频繁追加会导致整页重建，按钮操作和滚动卡顿感明显。状态：已修复（AppShell 移除日志 watch，`varmanager_flutter/lib/widgets/job_log_panel.dart` 自行判断空日志）。
2) 预览图解码/缩放成本高：`varmanager_flutter/lib/features/home/widgets/preview_panel.dart` 使用 `Image.network` 直接加载原图且未限制 `cacheWidth`/`ResizeImage`，预览网格与详情同时渲染时易卡顿。状态：已修复（加入 `cacheWidth` 与低/中等 `FilterQuality`）。
3) 后端预览图片同步读文件：`varManager_backend/src/api/mod.rs` 的 `get_preview` 使用 `std::fs::read` 同步读图且无缓存头，多图并发时阻塞明显。状态：已修复（改为 `tokio::fs::read`，增加 `Cache-Control`）。
4) 预览选择导致 HomePage 全量 rebuild：`varmanager_flutter/lib/features/home/home_page.dart` 多处 `setState` 在页面根部，预览切换会让列表/筛选/下拉全重建。状态：已修复（预览状态迁移到 `varmanager_flutter/lib/features/home/widgets/preview_panel.dart`）。
5) 预览加载走全量详情接口：`varmanager_flutter/lib/features/home/providers.dart` 使用 `getVarDetail`，`varManager_backend/src/api/mod.rs` 的 `get_var_detail` 含多类查询，预览切换时请求偏重。状态：已修复（改用 `list_var_previews` 并补充 `installed` 字段）。
6) 数据库缺少索引：`varManager_backend/src/infra/db.rs` 未创建索引，`list_vars`/`list_creators` 等查询为全表扫描，数据量大时查询显著变慢。状态：已修复（新增 creator/package/date/size/dep/scenes 等索引）。
7) 大数据筛选框一次性加载：Home/Scenes/Hub/Missing 等页面的 Creator/Tag 下拉在数据量大时一次性加载/渲染，导致卡顿且难以查找。状态：已修复（改为惰性搜索下拉，输入后分页加载，All 为默认）。
8) `list_vars` 计数 + 取页双扫描：`varManager_backend/src/api/mod.rs` 的 `list_vars` 每次 `COUNT` + `SELECT`，筛选频繁时性能下降。状态：待处理。
9) `open_default()` 每次请求 `ensure_schema()`：`varManager_backend/src/infra/db.rs` 反复执行建表/迁移语句，频率高时有额外开销。状态：待处理。
10) `list_scenes` 的磁盘遍历：`varManager_backend/src/api/mod.rs` 在包含 save/missinglink 时 `WalkDir` 扫盘，非首页但属潜在阻塞点。状态：待处理。
11) 预览弹窗重复注册监听器：`varmanager_flutter/lib/features/home/widgets/preview_dialog.dart` 在 build 内 `addListener` 会导致累积开销（若存在）。状态：待处理。
