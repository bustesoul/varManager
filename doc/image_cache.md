# 统一图片缓存系统实现计划

## 目标
将Hub图片请求迁移到后端，建立统一的两层图片缓存系统（内存+磁盘），优化性能和用户体验。

## 用户需求确认
- ✅ 缓存策略：内存缓存 + 磁盘缓存两层
- ✅ 容量限制：磁盘缓存 500MB
- ✅ API设计：统一 `/preview` 端点
- ✅ 管理功能：手动清理缓存API

---

## 系统架构

```
Flutter前端
    ↓ GET /preview?source=hub&url=...
后端API层
    ↓
ImageCacheService
    ├─ L1: Moka内存缓存 (100MB, 1小时TTL)
    │   └─ LRU驱逐
    ├─ L2: 磁盘缓存 (500MB, 24小时TTL)
    │   ├─ 存储: exe_dir()/ImageCache/
    │   ├─ 元数据: metadata.json
    │   └─ LRU驱逐 (按访问时间)
    └─ 下载器
        ├─ Hub: reqwest + hub_headers()
        └─ 本地: filesystem read
```

---

## 实现步骤

### Phase 1: 后端核心缓存服务 (高优先级)

#### 1.1 添加依赖
**文件:** `varManager_backend/Cargo.toml`
```toml
moka = { version = "0.12", features = ["future"] }
bytes = "1"
sha2 = "0.10"
hex = "0.4"
```

#### 1.2 创建缓存服务
**新建文件:** `src/services/mod.rs`
```rust
pub mod image_cache;
```

**新建文件:** `src/services/image_cache.rs` (约700行)
核心结构：
- `ImageCacheService` - 主服务类
- `DiskCache` - 磁盘缓存管理
- `CacheMetadata` - 元数据管理
- `ImageSource` - 图片来源枚举（Hub/本地）

核心方法：
- `get_or_fetch()` - 主入口，处理L1→L2→下载流程
- `download_hub_image()` - 下载Hub图片（带Cookie）
- `write_to_disk_cache()` - 磁盘缓存写入
- `cleanup_if_needed()` - LRU驱逐（按last_accessed排序）
- `ensure_disk_space()` - 容量管理

**关键实现细节：**
- 缓存Key: `hub:{sha256(url)}` 或 `local:{root}:{path}`
- 元数据存储: `ImageCache/metadata.json`
- 图片存储: `ImageCache/images/{hash}.{ext}`
- 并发控制: Semaphore限流 + Notify防重复下载
- 错误重试: 最多3次，指数退避

---

### Phase 2: API集成 (高优先级)

#### 2.1 修改AppState
**文件:** `src/app/mod.rs`
- 添加 `ImageCacheConfig` 到 `Config`
- 在 `AppState` 添加 `image_cache: Arc<ImageCacheService>`
- 初始化时创建缓存服务实例

**配置项：**
```rust
pub struct ImageCacheConfig {
    pub disk_cache_size_mb: u32,     // 默认500
    pub memory_cache_size_mb: u32,   // 默认100
    pub cache_ttl_hours: u32,        // 默认24
    pub enabled: bool,               // 默认true
}
```

#### 2.2 重写 /preview 端点
**文件:** `src/api/mod.rs` (行1965-2002)

**新API格式：**
- Hub图片: `GET /preview?source=hub&url={hub_url}`
- 本地文件: `GET /preview?root={varspath|vampath|cache}&path={path}` (向后兼容)

**实现：**
```rust
pub async fn get_preview(
    State(state): State<AppState>,
    Query(query): Query<PreviewQuery>,
) -> ApiResult<Response> {
    // 1. 解析ImageSource
    let source = parse_image_source(&state, query)?;

    // 2. 从缓存获取或下载
    let (bytes, content_type) = state.image_cache
        .get_or_fetch(source).await?;

    // 3. 返回图片 + Cache-Control头
    Ok(Response::builder()
        .header(CONTENT_TYPE, content_type)
        .header(CACHE_CONTROL, "public, max-age=3600")
        .body(Body::from(bytes.as_ref().clone()))?)
}
```

#### 2.3 添加缓存管理API
**新增路由：**
- `GET /cache/stats` - 查看缓存统计
- `POST /cache/clear` - 清空所有缓存
- `DELETE /cache/entry?key={key}` - 删除单个条目

**注册路由 (src/main.rs):**
```rust
.route("/cache/stats", get(api::get_cache_stats))
.route("/cache/clear", post(api::clear_cache))
.route("/cache/entry", delete(api::delete_cache_entry))
```

---

### Phase 3: 前端集成 (中优先级)

#### 3.1 扩展BackendClient
**文件:** `varmanager_flutter/lib/core/backend/backend_client.dart`

**新增方法：**
```dart
// Hub图片专用
String hubImageUrl(String imageUrl) {
  return previewUrl(source: 'hub', url: imageUrl);
}

// 缓存管理
Future<Map<String, dynamic>> getCacheStats() async {
  return _getJson('/cache/stats');
}

Future<void> clearCache() async {
  await _postJson('/cache/clear');
}
```

**修改现有方法：**
```dart
String previewUrl({
  String? root,
  String? path,
  String? source,
  String? url,
}) {
  // 支持新旧两种格式
}
```

#### 3.2 修改Hub页面
**文件:** `varmanager_flutter/lib/features/hub/hub_page.dart`

**修改内容：**
1. 删除 `_hubImageHeaders()` 函数 (行13-23)
2. 修改所有 `Image.network()` 调用：
   ```dart
   // 旧代码
   Image.network(imageUrl, headers: _hubImageHeaders(imageUrl))

   // 新代码
   Image.network(client.hubImageUrl(imageUrl))
   ```
3. 修改 `_openImagePreview()` 移除headers参数
4. 影响位置：
   - 行1179-1192: 资源卡片预览图
   - 行166-173: 列表页图片预览
   - 行1429-1435: 详情页图片预览
   - 行1609-1625: 详情对话框图片网格

---

### Phase 4: 边界情况处理 (中优先级)

#### 4.1 并发控制
- 使用 `Semaphore` 限制并发下载数量（最多5个）
- 使用 `HashMap<String, Notify>` 防止重复下载同一图片
- 等待机制：后续请求等待首个请求完成

#### 4.2 错误处理
- 下载失败重试：最多3次，指数退避 (500ms * retry_count)
- 超时设置：30秒
- 友好错误信息返回给前端

#### 4.3 容量管理
- 写入前检查：`ensure_disk_space()`
- LRU驱逐：按 `last_accessed` 排序，删除最旧条目
- 单文件过大拒绝：超过总容量的文件不缓存
- 元数据原子更新：写入临时文件→重命名

#### 4.4 定期维护
- 后台任务：每小时检查过期条目
- 过期策略：24小时未访问的图片自动删除
- 启动时自检：验证元数据完整性

---

## 关键文件清单

### 后端 (Rust)
1. **`src/services/image_cache.rs`** (新建，~700行)
   - 核心缓存服务实现

2. **`src/services/mod.rs`** (新建)
   - 模块声明

3. **`src/api/mod.rs`** (修改行1965-2002，新增3个端点)
   - 重写 `get_preview()`
   - 添加缓存管理API

4. **`src/app/mod.rs`** (修改Config和AppState)
   - 添加配置结构
   - 集成缓存服务

5. **`src/main.rs`** (修改路由注册)
   - 添加缓存管理路由

6. **`Cargo.toml`** (添加依赖)
   - moka, bytes, sha2, hex

### 前端 (Flutter)
7. **`lib/core/backend/backend_client.dart`** (新增方法)
   - `hubImageUrl()`, `getCacheStats()`, `clearCache()`

8. **`lib/features/hub/hub_page.dart`** (修改多处)
   - 删除 `_hubImageHeaders()`
   - 修改所有Hub图片加载调用

---

## 数据结构

### Rust核心结构
```rust
// 缓存服务
pub struct ImageCacheService {
    memory_cache: Cache<String, Arc<Bytes>>,
    disk_cache: Arc<DiskCache>,
    http_client: reqwest::Client,
    download_semaphore: Arc<Semaphore>,
    pending_downloads: Arc<RwLock<HashMap<String, Arc<Notify>>>>,
}

// 元数据
struct CacheMetadata {
    entries: HashMap<String, CacheEntry>,
    total_size: u64,
    version: u32,
}

struct CacheEntry {
    key: String,
    file_name: String,
    source: ImageSource,
    size_bytes: u64,
    content_type: String,
    created_at: SystemTime,
    last_accessed: SystemTime,
    access_count: u64,
}

// 图片来源
enum ImageSource {
    Hub { url: String, original_url: String },
    LocalFile { root: String, path: String },
}
```

### API请求格式
```rust
// GET /preview
struct PreviewQuery {
    source: Option<String>,  // "hub" | "local"
    url: Option<String>,     // Hub URL
    root: Option<String>,    // 本地root (兼容旧API)
    path: Option<String>,    // 本地path (兼容旧API)
}

// GET /cache/stats
struct CacheStatsResponse {
    memory: MemoryCacheStats,
    disk: DiskCacheStats,
}
```

---

## 测试策略

### 单元测试
- 缓存Key生成
- LRU驱逐算法
- 并发下载去重
- 容量限制检查

### 集成测试
1. Hub图片下载和缓存
2. L1/L2缓存命中
3. 容量超限驱逐
4. 并发请求处理
5. 网络失败重试
6. 缓存清空功能

### 性能指标
- L1命中延迟: <1ms
- L2命中延迟: <10ms
- Hub下载: <2s (网络依赖)
- 并发吞吐: >100 req/s

---

## 向后兼容性

### API兼容
- 旧API: `GET /preview?root=varspath&path=...` ✅ 继续支持
- 新API: `GET /preview?source=hub&url=...` ✅ 新增功能
- 兼容逻辑在 `parse_image_source()` 函数中处理

### 前端迁移路径
1. **阶段1**: 部署后端，前端无需修改（旧API仍可用）
2. **阶段2**: 仅修改Hub页面使用新API
3. **阶段3**: 其他页面逐步迁移（可选）

---

## 监控和日志

### 日志级别
- `INFO`: 缓存未命中，开始下载
- `DEBUG`: 缓存命中 (L1/L2)
- `WARN`: 下载失败重试
- `ERROR`: 磁盘满、元数据损坏

### 统计指标
```rust
struct CacheMetrics {
    l1_hits: AtomicU64,
    l1_misses: AtomicU64,
    l2_hits: AtomicU64,
    l2_misses: AtomicU64,
    downloads_success: AtomicU64,
    downloads_failed: AtomicU64,
    evictions: AtomicU64,
}
```

---

## 风险和缓解

| 风险 | 缓解措施 |
|------|----------|
| 磁盘缓存损坏 | 启动时自检，元数据备份 |
| 内存溢出 | Moka自动LRU，容量上限 |
| 并发冲突 | RwLock + Notify机制 |
| Hub网络失败 | 重试机制，降级错误 |
| 迁移兼容性 | 保持旧API，逐步迁移 |

---

## 实施时间估算
- Phase 1 (后端缓存): 3-4天
- Phase 2 (API集成): 1-2天
- Phase 3 (前端集成): 1-2天
- Phase 4 (边界处理): 2-3天
- 测试: 2-3天并行
- **总计**: 10-16天

---

## 配置示例 (config.json)
```json
{
  "image_cache": {
    "disk_cache_size_mb": 500,
    "memory_cache_size_mb": 100,
    "cache_ttl_hours": 24,
    "enabled": true
  }
}
```
