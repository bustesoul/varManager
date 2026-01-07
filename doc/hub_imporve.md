# Hub 页面优化跟踪

## 目标
- 评估 Hub 前后端性能、请求频率与数据利用率
- 提升功能展示与交互体验
- 识别并清理前后端死代码/无用逻辑

## 当前已知问题（初步）
- 默认 payType 设为 Free，可能导致仅展示部分资源
- Job 轮询频率固定（500ms），额外请求偏多
- `hub_info` 与 `hub/options` 重复调用 `get_info`，缓存未共享
- `hub_info` 剔除 `users/tags` 后前端仍解析，存在无效字段
- Hub 资源卡使用字段有限，其他字段可能被浪费（已验证）

## 数据采集（已提供）
- [x] `hub_resources` 请求/响应日志
- [x] `hub_resource_detail` 请求/响应日志

## 日志分析结果（backend.log）
### 请求模式与频率
- `hub_resources` 在短时间内触发 3 次，其中 2 次参数完全一致（`username=LDR`），疑似重复触发
- `hub_resources` 默认参数包含 `paytype=Free`，将非免费资源过滤掉

### 请求参数快照（示例）
- `hub_resources`：`perpage=12`、`paytype=Free`、`sort=Latest Update`、`search` 为空
- `hub_resource_detail`：仅 `resource_id`

### 响应字段利用率（浪费重点）
- `hub_resources` 每条资源包含 39 个字段，前端仅使用 13 个字段
- 未使用字段（资源级，26 个）：
  `avatar_date`、`current_version_id`、`dependency_count`、`discussion_thread_id`、`external_url`、
  `hubDownloadable`、`hubHosted`、`hub_hosted`、`icon_url`、`package_id`、`parent_category_id`、
  `popularity`、`promotional_link`、`rating_weighted`、`reaction_score`、`release_date`、
  `resource_date`、`review_count`、`tags`、`thtrending_downloads_per_minute`、
  `thtrending_positive_rating_count`、`thtrending_positive_ratings_per_minute`、`update_count`、
  `user_id`、`version_string`、`view_count`
- `hubFiles` 子字段 10 个，仅使用 `filename`（用于版本解析），其余字段均未使用
- `hub_resource_detail` 响应 39 个字段，仅 `hubFiles` 与 `dependencies` 被用来生成下载列表

### 结论
- “只显示约 30% 资源”的主要原因极可能是默认 `paytype=Free`
- 多余请求主要来自重复触发 `hub_resources` 与重复拉取完整响应字段

### 字段逐项评估（逐个分析）
#### `hub_resources` 资源条目字段（39 个）
| 字段 | 含义/用途 | 当前使用 | 可加入项目功能 | 建议 |
| --- | --- | --- | --- | --- |
| `resource_id` | 资源唯一 ID | 已用 | 打开详情/下载/跳转 | 必留 |
| `title` | 标题 | 已用 | 卡片标题 | 必留 |
| `username` | 作者名 | 已用 | 作者筛选/跳转作者 | 必留 |
| `user_id` | 作者 ID | 未用 | 作者主页/头像接口（若有） | 可选 |
| `tag_line` | 简短描述 | 已用 | 卡片副标题 | 保留 |
| `tags` | 标签列表 | 未用 | 标签 chips/快速筛选 | 建议加入 |
| `type` | 资源类型 | 已用 | 类型筛选 | 保留 |
| `category` | 付费类型 | 已用 | 免费/付费筛选 | 保留（修正默认值） |
| `image_url` | 预览图 | 已用 | 卡片主图 | 保留 |
| `icon_url` | 图标 | 未用 | 无预览图时 fallback | 可选 |
| `avatar_date` | 头像相关日期 | 未用 | 含义不清 | 可裁剪 |
| `download_url` | 下载入口 | 已用（无 hubFiles 时） | 非 Hub 托管下载 | 保留 |
| `hubFiles` | 文件列表 | 已用 | 仓库状态/下载列表 | 保留（可改为按需） |
| `hubDownloadable` | 是否可下载 | 未用 | 禁用下载按钮/提示 | 可选 |
| `hubHosted` | Hub 托管标识 | 未用 | 决定下载方式 | 可选（保留其一） |
| `hub_hosted` | Hub 托管标识 | 未用 | 与 `hubHosted` 重复 | 可裁剪其一 |
| `dependency_count` | 依赖数 | 未用 | 复杂度提示/筛选 | 可选 |
| `version_string` | 版本号 | 未用 | 显示当前版本 | 可选 |
| `current_version_id` | 版本 ID | 未用 | 内部标识 | 可裁剪 |
| `package_id` | 包 ID | 未用 | 内部标识 | 可裁剪 |
| `parent_category_id` | 父类 ID | 未用 | 内部分类 | 可裁剪 |
| `discussion_thread_id` | 讨论帖 ID | 未用 | 打开讨论链接 | 可选 |
| `external_url` | 外部链接 | 未用 | 外部页面按钮 | 可选 |
| `promotional_link` | 推广链接 | 未用 | 展示推广 | 可选/谨慎 |
| `resource_date` | 资源日期 | 未用 | 创建/提交时间 | 可选 |
| `release_date` | 发布日期 | 未用 | 发布时间 | 可选（可能与 resource_date 重复） |
| `last_update` | 最后更新 | 已用 | 更新日期显示 | 保留 |
| `update_count` | 更新次数 | 未用 | 更新频率提示 | 可选 |
| `download_count` | 下载数 | 已用 | 热度指标 | 保留 |
| `view_count` | 浏览数 | 未用 | 热度指标 | 可选 |
| `rating_avg` | 平均评分 | 已用 | 评分显示 | 保留 |
| `rating_count` | 评分数 | 已用 | 评分可信度 | 保留 |
| `rating_weighted` | 加权评分 | 未用 | 排序/更准评分 | 可选 |
| `review_count` | 评论数 | 未用 | 互动指标 | 可选 |
| `reaction_score` | 反应分 | 未用 | 排序/热度 | 可选 |
| `popularity` | 热度分 | 未用 | 热门排序/徽章 | 可选 |
| `thtrending_downloads_per_minute` | 下载趋势 | 未用 | 趋势排序 | 可选 |
| `thtrending_positive_rating_count` | 正评趋势 | 未用 | 趋势排序 | 可选 |
| `thtrending_positive_ratings_per_minute` | 正评分趋势 | 未用 | 趋势排序 | 可选 |

#### `hubFiles` 子字段（来自 `hub_resources`/`hub_resource_detail`）
| 字段 | 含义/用途 | 当前使用 | 可加入项目功能 | 建议 |
| --- | --- | --- | --- | --- |
| `filename` | VAR 文件名 | 已用 | 版本解析/下载列表 | 必留 |
| `urlHosted` | 直接下载链接 | 未用（资源列表）/已用（详情） | 直接下载 | 保留 |
| `file_size` | 文件大小 | 未用 | 显示大小/排序 | 可选 |
| `licenseType` | 许可协议 | 未用 | 版权提示 | 可选 |
| `programVersion` | 兼容版本 | 未用 | 显示最低 VaM 版本 | 可选 |
| `creatorName` | 作者名 | 未用 | 冗余字段 | 可裁剪 |
| `username` | 作者名 | 未用 | 冗余字段 | 可裁剪 |
| `package_id` | 包 ID | 未用 | 内部标识 | 可裁剪 |
| `current_version_id` | 版本 ID | 未用 | 内部标识 | 可裁剪 |
| `attachment_id` | 附件 ID | 未用 | 内部标识 | 可裁剪 |

#### `hub_resource_detail` 专有字段
| 字段 | 含义/用途 | 当前使用 | 可加入项目功能 | 建议 |
| --- | --- | --- | --- | --- |
| `dependencies` | 依赖列表/下载链接 | 已用 | 依赖展示/缺失提示 | 必留 |

#### 适配建议（字段可加入的优先级）
- P0：`tags`（标签筛选）、`version_string`（版本显示）、`dependency_count`（复杂度提示）
- P1：`licenseType`、`file_size`、`programVersion`（下载/兼容提示）
- P2：`view_count`、`review_count`、`rating_weighted`（热度与可信度）
- P3：`popularity`、`thtrending_*`（趋势排序/徽章）

## 优化计划
### 阶段 1：观察与对齐
- [x] 后端输出 `hub_resources`/`hub_resource_detail` 请求与响应日志
- [x] 分析日志并建立字段利用率清单（已展示/可展示/无用）
- [ ] 确认默认筛选策略（是否默认 `All`）

### 阶段 2：性能与请求模式
- [x] 降低 job 轮询频率或按需拉取日志（仅在日志变化时拉取，并动态退避）
- [x] `hub_info` 与 `hub/options` 共享缓存，减少重复请求
- [x] 为 `hub_resources` 添加“参数相同且正在加载时跳过”的前端/后端防抖
- [x] 增加“请求参数一致的缓存”：
  - 缓存 key：`perpage/location/paytype/category/username/tags/search/sort/page`
  - 缓存命中时直接返回缓存结果
  - 点击刷新按钮强制刷新（绕过缓存）
  - 已设置 TTL=30 秒，防止过旧数据

### 阶段 3：UI/功能改进
- [x] 根据字段利用率调整卡片信息密度
- [x] P0：在卡片视图加入 `tags`、`version_string`、`dependency_count`
  - `tags` 过多时仅展示前 N 个（如 3~5），尾部显示 `+N`
- [x] P1/P2：新增 “Detail” 按钮，弹出轻量窗口展示扩展字段
  - P1：`licenseType`、`file_size`、`programVersion`
  - P2：`view_count`、`review_count`、`rating_weighted`
- [x] 增强筛选/排序交互（默认值、快捷筛选、重置）
- [x] 优化下载/仓库状态提示与操作路径
- [x] 可选：增加“仅资源文件/含依赖”下载模式，减少 `hub_resource_detail` 调用

### 阶段 4：清理与收尾
- [ ] 后端裁剪 `hub_resources` 响应（仅保留前端使用字段）
- [ ] 精简 `hub_resource_detail` 返回（只保留下载相关字段）
- [ ] 移除前端未使用字段或改为懒加载
- [ ] 补充必要测试或日志开关

## 日志说明
- Hub 请求日志已完成采集，相关临时日志已移除

## 进度记录
- 已完成：P0 卡片字段、Detail 弹窗、请求缓存与刷新绕过
- 已完成：轮询降频/按需拉取、Hub info/options 共享缓存、筛选重置与下载路径优化
