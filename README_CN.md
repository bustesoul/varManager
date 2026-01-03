# varManager
[English](README.md) | [简体中文](README_CN.md)
varManager
用于 Virt-A-Mate 的 var 管理工具。
主要方式：把所有 var 文件放到仓库目录，需要使用时在 AddonPackages 中建立指向该 var 的符号链接。

### 版本 1.0.4.13 更新提示：
0. **升级注意**：部署新版本前建议删除旧程序目录。清理指引（若保留目录）：`varManager.mdb`（旧 Access 数据库）、`varManager.exe`、`varManager.pdb`、`varManager.dll.config`（你可以编辑文本以提取旧版本配置）、`varManager.db*`、`varManager.log`。
1. **升级**：数据库切换为 SQLite，并升级到 .NET 9。
2. **首次运行注意**：首次运行请点击 `UPD_DB` 重建数据库。
3. **不丢数据**：var 文件与 profile 配置不依赖数据库，不会丢失。

### 版本 1.0.4.11 更新提示：
1. **支持批量下载**：在 MissingVarPage（获取缺失依赖后）和 HubPage（生成下载列表后）支持一次点击下载多个 var。
2. **注意**：该功能目前不稳定，可能需要手动检查下载结果并重新执行。下载后 *必须* 点击 `UPD_DB`，否则会重复下载相同的 var。

### 版本 1.0.4.10 更新提示：
0. **升级注意**：若需要保留旧的变量配置，请先备份 `varManager.mdb`。推荐使用全新配置以获得最佳性能。
1. **必须管理员运行**：从 1.0.4.9 起，由于 .NET 6.0 创建符号链接的要求，`varManager.exe` 必须以管理员身份运行。
2. **运行时安装**：如果 `varManager.exe` 无法运行，请安装 .NET Desktop Runtime 6.0，下载地址：[here](https://dotnet.microsoft.com/en-us/download/dotnet/6.0)。
3. **新按钮**：新增 `FetchDownloadFromHub` 按钮用于 Hub 资源获取与下载，目前支持在 `depends analyse` 页面下载单个缺失 var，下载功能由插件 [vam_downloader](https://github.com/bustesoul/vam_downloader) 提供。
