// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get commonOk => '确定';

  @override
  String get commonCancel => '取消';

  @override
  String get commonSave => '保存';

  @override
  String get commonClear => '清除';

  @override
  String get commonSelectAll => '全选';

  @override
  String get commonSelect => '选择';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonRefresh => '刷新';

  @override
  String get commonBrowse => '浏览';

  @override
  String get commonClose => '关闭';

  @override
  String get commonDelete => '删除';

  @override
  String get commonAdd => '添加';

  @override
  String get commonDetails => '详情';

  @override
  String get commonLocate => '定位';

  @override
  String get commonAnalyze => '分析';

  @override
  String get commonLoad => '加载';

  @override
  String get commonUse => '使用';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonRetry => '重试';

  @override
  String get commonFilter => '筛选';

  @override
  String get navHome => '首页';

  @override
  String get navScenes => '场景';

  @override
  String get navHub => 'Hub';

  @override
  String get navSettings => '设置';

  @override
  String jobFailed(Object kind, Object message) {
    return '任务失败：$kind（$message）';
  }

  @override
  String get backendReady => '后端就绪';

  @override
  String get backendError => '后端错误';

  @override
  String get backendStarting => '后端启动中';

  @override
  String get backendStartingHint => '正在启动后端...';

  @override
  String backendStartFailed(Object message) {
    return '后端启动失败：$message';
  }

  @override
  String get jobLogsTitle => '任务日志';

  @override
  String get noMatches => '无匹配项';

  @override
  String get imagePreviewPrevious => '上一张';

  @override
  String get imagePreviewNext => '下一张';

  @override
  String get imagePreviewScroll => '滚轮';

  @override
  String get paginationFirstPageTooltip => '第一页';

  @override
  String get paginationPreviousPageTooltip => '上一页';

  @override
  String get paginationNextPageTooltip => '下一页';

  @override
  String get paginationLastPageTooltip => '最后一页';

  @override
  String get previewFirstItemTooltip => '第一项';

  @override
  String get previewPreviousItemTooltip => '上一项';

  @override
  String get previewNextItemTooltip => '下一项';

  @override
  String get previewLastItemTooltip => '最后一项';

  @override
  String get previewOpenTooltip => '打开预览';

  @override
  String get previewOpenDoubleClickTooltip => '双击打开预览';

  @override
  String get previewSelectOrOpenTooltip => '单击选择，双击预览';

  @override
  String get selectMissingVarTooltip => '选择缺失 Var';

  @override
  String get jobLogExpandTooltip => '展开日志面板';

  @override
  String get jobLogCollapseTooltip => '折叠日志面板';

  @override
  String get downloadManagerTitle => '下载管理器';

  @override
  String downloadSelectionCount(Object count) {
    return '已选 $count 项';
  }

  @override
  String get downloadNoSelection => '未选择';

  @override
  String get downloadNoActive => '没有活动下载';

  @override
  String downloadItemsProgress(Object completed, Object total) {
    return '项目 $completed/$total';
  }

  @override
  String get downloadActionPause => '暂停';

  @override
  String get downloadActionResume => '继续';

  @override
  String get downloadActionRemoveRecord => '移除记录';

  @override
  String get downloadActionDeleteFile => '删除文件';

  @override
  String get downloadStatusPaused => '已暂停';

  @override
  String get downloadStatusDownloading => '下载中';

  @override
  String get downloadStatusQueued => '队列中';

  @override
  String get downloadStatusFailed => '失败';

  @override
  String get downloadStatusCompleted => '已完成';

  @override
  String get downloadImportLabel => '导入';

  @override
  String get downloadImportTooltip => '从文本文件导入下载链接（支持 Hub 页面复制的格式）';

  @override
  String downloadImportSuccess(Object count) {
    return '已导入 $count 个链接';
  }

  @override
  String get downloadImportEmpty => '未找到有效链接';

  @override
  String get confirmDeleteTitle => '确认删除';

  @override
  String get confirmDeleteMessage => '将永久删除该文件，确定吗？';

  @override
  String get settingsSectionUi => '界面';

  @override
  String get settingsSectionListen => '监听与日志';

  @override
  String get settingsSectionPaths => '路径';

  @override
  String get settingsSectionAbout => '关于';

  @override
  String get themeLabel => '主题';

  @override
  String get themeDefault => '默认';

  @override
  String get themeOcean => '海洋蓝';

  @override
  String get themeForest => '森林绿';

  @override
  String get themeRose => '玫瑰';

  @override
  String get themeDark => '暗色';

  @override
  String themeSelectTooltip(Object theme) {
    return '切换到$theme主题';
  }

  @override
  String get languageLabel => '语言';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get listenHostLabel => '监听地址';

  @override
  String get listenPortLabel => '监听端口';

  @override
  String get logLevelLabel => '日志级别';

  @override
  String get jobConcurrencyLabel => '任务并发数';

  @override
  String get proxySectionLabel => '代理';

  @override
  String get proxyModeLabel => '代理模式';

  @override
  String get proxyModeSystem => '系统';

  @override
  String get proxyModeManual => '手动';

  @override
  String get proxyHostLabel => '代理主机';

  @override
  String get proxyPortLabel => '代理端口';

  @override
  String get proxyUserLabel => '代理用户';

  @override
  String get proxyPasswordLabel => '代理密码';

  @override
  String get varspathLabel => 'varspath';

  @override
  String get vampathLabel => 'vampath';

  @override
  String get vamExecLabel => 'vam_exec';

  @override
  String get downloaderSavePathLabel => '下载保存路径';

  @override
  String get chooseVamHint => '推荐: 选择 Virt-A-Mate 目录';

  @override
  String get chooseAddonPackagesHint => '推荐: 选择 AddonPackages 目录';

  @override
  String get appVersionLabel => '应用版本';

  @override
  String get backendVersionLabel => '后端版本';

  @override
  String get configSaved => '配置已保存';

  @override
  String get configSavedRestartHint => '配置已保存；listen_host/port 与代理需重启生效。';

  @override
  String get searchVarPackageLabel => '搜索 Var/包';

  @override
  String get creatorLabel => '作者';

  @override
  String get allCreators => '全部作者';

  @override
  String get statusAllLabel => '全部状态';

  @override
  String get statusInstalled => '已安装';

  @override
  String get statusNotInstalled => '未安装';

  @override
  String get sortMetaDate => '元数据日期';

  @override
  String get sortVarDate => 'Var 日期';

  @override
  String get sortVarName => 'Var 名称';

  @override
  String get sortCreator => '作者';

  @override
  String get sortPackage => '包';

  @override
  String get sortSize => '大小';

  @override
  String get sortDesc => '降序';

  @override
  String get sortAsc => '升序';

  @override
  String perPageLabel(Object value) {
    return '每页 $value';
  }

  @override
  String selectedCount(Object count) {
    return '已选 $count';
  }

  @override
  String get selectPageTooltip => '选择当前页全部项目。';

  @override
  String get selectPageLabel => '选择本页';

  @override
  String get invertPageTooltip => '反选当前页。';

  @override
  String get invertPageLabel => '反选本页';

  @override
  String get clearAllTooltip => '清除全部选择。';

  @override
  String get clearAllLabel => '清除全部';

  @override
  String get resetFiltersTooltip => '重置所有筛选为默认。';

  @override
  String get resetFiltersLabel => '重置筛选';

  @override
  String get showAdvancedTooltip => '显示高级筛选。';

  @override
  String get hideAdvancedTooltip => '隐藏高级筛选。';

  @override
  String get advancedFiltersLabel => '高级筛选';

  @override
  String get hideAdvancedLabel => '隐藏高级';

  @override
  String get packageFilterLabel => '包筛选';

  @override
  String get versionFilterLabel => '版本筛选';

  @override
  String get enabledAllLabel => '全部';

  @override
  String get enabledOnlyLabel => '仅启用';

  @override
  String get disabledOnlyLabel => '仅禁用';

  @override
  String get minSizeLabel => '最小大小 (MB)';

  @override
  String get maxSizeLabel => '最大大小 (MB)';

  @override
  String get minDepsLabel => '最小依赖';

  @override
  String get maxDepsLabel => '最大依赖';

  @override
  String get actionsTitle => '操作';

  @override
  String get actionGroupCore => '核心';

  @override
  String get actionGroupCoreTooltip => '核心操作与依赖检查。';

  @override
  String get actionGroupMaintenance => '维护';

  @override
  String get actionGroupMaintenanceTooltip => '清理与维护任务。';

  @override
  String get updateDbLabel => '更新数据库';

  @override
  String get updateDbTooltip => '扫描 Vars、提取预览并更新数据库。';

  @override
  String get updateDbRequiredTitle => '需要更新数据库';

  @override
  String updateDbRequiredMessage(Object path) {
    return '检测到 AddonPackages 包含实际 .var 文件或不是符号链接（$path）。请先执行更新数据库。';
  }

  @override
  String get updateDbSummaryTitle => '更新数据库完成';

  @override
  String updateDbSummaryScanned(Object count) {
    return '扫描到 $count 个包。';
  }

  @override
  String get updateDbSummaryEmpty => '没有需要移动的包。';

  @override
  String updateDbSummaryMoveLine(Object count, Object from, Object to) {
    return '$count 从 $from 移动到 $to';
  }

  @override
  String updateDbSummaryMoveLineStatus(
    Object status,
    Object count,
    Object from,
    Object to,
  ) {
    return '$status：移动 $count 个，从 $from 到 $to';
  }

  @override
  String get updateDbSummaryStatusSucceed => '成功';

  @override
  String get updateDbSummaryStatusInvalid => '不合规';

  @override
  String get updateDbSummaryStatusRedundant => '冗余';

  @override
  String get startVamLabel => '启动 VaM';

  @override
  String get startVamTooltip => '启动 VaM 应用。';

  @override
  String get prepareSavesLabel => '准备存档';

  @override
  String get prepareSavesTooltip => '打开存档准备与依赖工具。';

  @override
  String get missingDepsSourceTooltip => '选择缺失依赖的检测来源。';

  @override
  String get missingDepsSourceLabel => '缺失依赖来源';

  @override
  String get missingDepsSourceInstalled => '已安装包';

  @override
  String get missingDepsSourceAll => '全部包';

  @override
  String get missingDepsSourceFiltered => '筛选列表';

  @override
  String get missingDepsSourceSaves => '存档目录';

  @override
  String get missingDepsSourceLog => '日志 (output_log.txt)';

  @override
  String get runMissingDepsLabel => '运行缺失依赖';

  @override
  String get runMissingDepsTooltip => '分析缺失依赖并打开结果。';

  @override
  String get rebuildLinksLabel => '重建链接';

  @override
  String get rebuildLinksTooltip => '更换 Vars 目录后重建链接。';

  @override
  String get fixPreviewLabel => '修复预览';

  @override
  String get fixPreviewTooltip => '重新提取缺失的预览图。';

  @override
  String get staleVarsLabel => '过期 Vars';

  @override
  String get staleVarsTooltip => '移动未被依赖的旧版本。';

  @override
  String get oldVersionsLabel => '旧版本';

  @override
  String get oldVersionsTooltip => '查找或管理旧包版本。';

  @override
  String totalItems(Object count) {
    return '共 $count 项';
  }

  @override
  String loadFailed(Object error) {
    return '加载失败：$error';
  }

  @override
  String get installSelectedLabel => '安装所选';

  @override
  String get installSelectedTooltip => '安装所选 Vars 及其依赖。';

  @override
  String get uninstallSelectedLabel => '卸载所选';

  @override
  String get uninstallSelectedTooltip => '卸载所选 Vars 及相关项。';

  @override
  String get deleteSelectedLabel => '删除所选';

  @override
  String get deleteSelectedTooltip => '删除所选 Vars 及相关项。';

  @override
  String get moveLinksLabel => '移动链接';

  @override
  String get moveLinksTooltip => '将所选链接项移动到目标文件夹。';

  @override
  String get targetDirLabel => '目标目录';

  @override
  String get exportInstalledLabel => '导出已安装';

  @override
  String get exportInstalledTooltip => '导出已安装 Vars 到文本文件。';

  @override
  String get exportPathTitle => '导出路径';

  @override
  String get installFromListLabel => '从列表安装';

  @override
  String get installFromListTooltip => '从文本列表安装 Vars。';

  @override
  String get installListPathLabel => '安装列表路径';

  @override
  String get packSwitchTitle => '包切换';

  @override
  String get activeLabel => '当前';

  @override
  String get noSwitchesAvailable => '无可用切换';

  @override
  String get activateLabel => '激活';

  @override
  String get renameLabel => '重命名';

  @override
  String get newSwitchNameTitle => '新切换名称';

  @override
  String get renameSwitchTitle => '重命名切换';

  @override
  String get switchAlreadyExists => '切换已存在';

  @override
  String get newNameMustBeDifferent => '新名称需不同';

  @override
  String get switchNameAlreadyExists => '目标名称已存在';

  @override
  String get deleteSwitchTitle => '删除切换';

  @override
  String deleteSwitchConfirm(Object name) {
    return '删除切换“$name”？';
  }

  @override
  String presenceFilterLabel(Object label) {
    return '$label：';
  }

  @override
  String get presenceAllLabel => '全部';

  @override
  String get presenceHasLabel => '有';

  @override
  String get presenceNoneLabel => '无';

  @override
  String get compactModeHint => '窗口过小，放大窗口以显示预览面板。';

  @override
  String get categoryScenes => '场景';

  @override
  String get categoryLooks => '外观';

  @override
  String get categoryClothing => '服装';

  @override
  String get categoryHairstyle => '发型';

  @override
  String get categoryAssets => '资产';

  @override
  String get categoryMorphs => '变形';

  @override
  String get categoryPose => '姿势';

  @override
  String get categorySkin => '皮肤';

  @override
  String get categoryHair => '头发';

  @override
  String get categoryTextures => '纹理';

  @override
  String get categoryPlugins => '插件';

  @override
  String get categoryScripts => '脚本';

  @override
  String get categorySubScene => '子场景';

  @override
  String get categoryAppearance => '外观配置';

  @override
  String get categoryBreast => '胸部';

  @override
  String get categoryGlute => '臀部';

  @override
  String get clickVarToLoadPreviews => '点击 Var 加载预览';

  @override
  String get noPreviewEntriesForVar => '所选 Var 无预览条目';

  @override
  String previewLoadFailed(Object error) {
    return '预览加载失败：$error';
  }

  @override
  String get allTypesLabel => '全部类型';

  @override
  String get loadableLabel => '可加载';

  @override
  String itemsCount(Object count) {
    return '项目 $count';
  }

  @override
  String itemPosition(Object current, Object total) {
    return '项目 $current/$total';
  }

  @override
  String get noPreviewsAfterFilters => '筛选后无预览';

  @override
  String get selectPreviewHint => '请选择一个预览';

  @override
  String get installVarTitle => '安装 Var';

  @override
  String installVarConfirm(Object varName) {
    return '将安装 $varName，继续吗？';
  }

  @override
  String get installLabel => '安装';

  @override
  String get uninstallLabel => '卸载';

  @override
  String get missingDependenciesTitle => '缺失依赖';

  @override
  String get ignoreVersionMismatch => '忽略版本不匹配';

  @override
  String get allMissingVars => '全部缺失 Vars';

  @override
  String get includeLinkedLabel => '包含已链接';

  @override
  String get includeLinkedTooltip => '显示已建立替换链接的条目。';

  @override
  String rowPosition(Object current, Object total) {
    return '行 $current / $total';
  }

  @override
  String appliedCount(Object count) {
    return '已应用 $count';
  }

  @override
  String draftCount(Object count) {
    return '草稿 $count';
  }

  @override
  String brokenCount(Object count) {
    return '损坏 $count';
  }

  @override
  String get missingVarHeader => '缺失 Var';

  @override
  String get substituteHeader => '替换';

  @override
  String get downloadHeaderShort => '下载';

  @override
  String get detailsTitle => '详情';

  @override
  String selectedLabel(Object value) {
    return '已选：$value';
  }

  @override
  String resolvedLabel(Object value) {
    return '已解析：$value';
  }

  @override
  String downloadLabel(Object value) {
    return '下载：$value';
  }

  @override
  String linkStatusLabel(Object value) {
    return '链接状态：$value';
  }

  @override
  String get linkSubstitutionTitle => '链接替换';

  @override
  String get linkSubstitutionDescription =>
      '链接会在 ___MissingVarLink___ 中创建符号链接用于替换缺失依赖。';

  @override
  String appliedLinkLabel(Object value) {
    return '已应用：$value';
  }

  @override
  String draftLinkLabel(Object value) {
    return '草稿：$value';
  }

  @override
  String suggestionLabel(Object value) {
    return '建议：$value';
  }

  @override
  String get useSuggestionTooltip => '使用建议的已解析 Var 作为草稿链接。';

  @override
  String get findTargetLabel => '查找目标';

  @override
  String get pickTargetLabel => '选择目标';

  @override
  String get limitSamePackageLabel => '限制为同作者/包';

  @override
  String get limitSamePackageTooltip => '将选择范围限制为同作者/包。';

  @override
  String get targetVarLabel => '目标 Var';

  @override
  String get setDraftLabel => '设为草稿';

  @override
  String get setDraftTooltip => '保存所选缺失 Var 的草稿链接。';

  @override
  String get clearDraftLabel => '清除草稿';

  @override
  String get clearDraftTooltip => '清除草稿链接（将移除）。';

  @override
  String get revertDraftLabel => '撤销草稿';

  @override
  String get revertDraftTooltip => '将草稿恢复为当前已应用链接。';

  @override
  String get applyToPackageLabel => '应用到包';

  @override
  String get applyToPackageTooltip => '将草稿目标应用到同包所有缺失 Var。';

  @override
  String get autoFillResolvedLabel => '自动填充已解析';

  @override
  String get autoFillResolvedTooltip => '用最佳解析匹配填充草稿。';

  @override
  String get applyLinkChangesLabel => '应用链接变更';

  @override
  String get applyLinkChangesTooltip => '根据草稿创建/更新/移除链接。';

  @override
  String get saveMapLabel => '保存映射';

  @override
  String get saveMapTooltip => '将当前有效映射保存到文本文件。';

  @override
  String get loadMapLabel => '加载映射';

  @override
  String get loadMapTooltip => '加载映射文件作为草稿。';

  @override
  String get discardDraftsLabel => '丢弃草稿';

  @override
  String get discardDraftsTooltip => '丢弃所有草稿变更。';

  @override
  String get googleSearchLabel => 'Google 搜索';

  @override
  String get googleSearchTooltip => '在网络上搜索缺失 Var。';

  @override
  String get fetchHubLinksLabel => '获取 Hub 链接';

  @override
  String get fetchHubLinksTooltip => '查询 Hub 获取下载链接。';

  @override
  String get downloadSelectedLabel => '下载所选';

  @override
  String get downloadSelectedTooltip => '下载所选缺失 Var 的链接（如有）。';

  @override
  String get downloadAllLabel => '全部下载';

  @override
  String get downloadAllTooltip => '下载所有选中的资源';

  @override
  String get dependentsTitle => '依赖项';

  @override
  String get noDependents => '无依赖项';

  @override
  String get dependentSavesTitle => '依赖存档';

  @override
  String get noDependentSaves => '无依赖存档';

  @override
  String get linkStatusBroken => '链接损坏';

  @override
  String get linkStatusRemove => '移除链接';

  @override
  String get linkStatusClear => '清空链接';

  @override
  String get linkStatusNew => '新链接';

  @override
  String get linkStatusLinked => '已链接';

  @override
  String get linkStatusChanged => '链接已变更';

  @override
  String get linkStatusNotLinked => '未链接';

  @override
  String get downloadStatusDirect => '直连';

  @override
  String get downloadStatusNoVersion => '无版本';

  @override
  String get downloadStatusNone => '无';

  @override
  String get missingSelectFirst => '请先选择一个缺失 Var。';

  @override
  String get missingFetchHubLinksFirst => '请先点击“获取 Hub 链接”。';

  @override
  String get missingNoDownloadUrlForSelected => '所选 Var 无可用下载链接。';

  @override
  String get missingAddedDownload => '已添加 1 个下载。';

  @override
  String get missingNoDownloadUrlsAvailable => '没有可用下载链接。';

  @override
  String missingAddedDownloads(Object count) {
    return '已添加 $count 个下载。';
  }

  @override
  String linkChangesApplied(
    Object total,
    Object created,
    Object skipped,
    Object failed,
  ) {
    return '链接变更已应用：总计 $total，创建 $created，跳过 $skipped，失败 $failed。';
  }

  @override
  String get missingStatus => '缺失';

  @override
  String closestMatch(Object name) {
    return '$name（最接近）';
  }

  @override
  String get draftClearLabel => '（清空）';

  @override
  String get textFileTypeLabel => '文本';

  @override
  String varDetailsTitle(Object varName) {
    return '详情：$varName';
  }

  @override
  String get filterByCreator => '按作者筛选';

  @override
  String get missingDeps => '缺失依赖';

  @override
  String get dependenciesTitle => '依赖';

  @override
  String get saveDependenciesTitle => '存档依赖';

  @override
  String get previewsTitle => '预览';

  @override
  String get noPreviews => '无预览';

  @override
  String previewTitleWithType(Object title, Object type) {
    return '$title（$type）';
  }

  @override
  String totalCount(Object count) {
    return '总计 $count';
  }

  @override
  String get nameFilterLabel => '名称筛选';

  @override
  String get sortNewToOld => '从新到旧';

  @override
  String get sortSceneName => '场景名';

  @override
  String get columnsLabel => '列：';

  @override
  String get columnHide => '隐藏';

  @override
  String get columnNormal => '普通';

  @override
  String get columnFav => '收藏';

  @override
  String get mergeLabel => '合并';

  @override
  String get forMaleLabel => '男性';

  @override
  String get hideLabel => '隐藏';

  @override
  String get unhideLabel => '取消隐藏';

  @override
  String get favLabel => '收藏';

  @override
  String get unfavLabel => '取消收藏';

  @override
  String columnTitleWithCount(Object count, Object title) {
    return '$title（$count）';
  }

  @override
  String get locationLabel => '位置';

  @override
  String get locationInstalled => '已安装';

  @override
  String get locationNotInstalled => '未安装';

  @override
  String get locationMissingLink => '缺失链接';

  @override
  String get locationSave => '存档';

  @override
  String get clearCacheLabel => '清除缓存';

  @override
  String personLabel(Object value) {
    return '人物 $value';
  }

  @override
  String get uninstallPreviewTitle => '卸载预览';

  @override
  String uninstallPackageCount(Object count) {
    return '将卸载 $count 个包';
  }

  @override
  String get uninstallTagRequested => '请求';

  @override
  String get uninstallTagImplicated => '受影响';

  @override
  String previewsCount(Object count) {
    return '预览（$count）';
  }

  @override
  String dependenciesCount(Object count) {
    return '依赖（$count）';
  }

  @override
  String get noDependencies => '无依赖';

  @override
  String get prepareSavesTitle => '准备存档';

  @override
  String get outputFolderLabel => '输出文件夹';

  @override
  String get outputFolderReady => '输出文件夹可用。';

  @override
  String get outputFolderValidationFailed => '输出文件夹验证失败。';

  @override
  String get validateOutputLabel => '验证输出';

  @override
  String get savesTreeTitle => '存档树';

  @override
  String get noSavesFound => '未找到存档';

  @override
  String selectedFilesCount(Object count) {
    return '已选 $count 个文件';
  }

  @override
  String get filtersActionsTitle => '筛选与操作';

  @override
  String get basicFiltersTitle => '基础筛选';

  @override
  String get advancedFiltersTitle => '高级筛选';

  @override
  String get sortOptionsTitle => '排序选项';

  @override
  String get allLocationsLabel => '全部位置';

  @override
  String get allPayTypesLabel => '全部付费类型';

  @override
  String get payTypeLabel => '付费类型';

  @override
  String get categoryLabel => '类别';

  @override
  String get tagLabel => '标签';

  @override
  String get allTagsLabel => '全部标签';

  @override
  String get primarySortLabel => '主排序';

  @override
  String get secondarySortLabel => '次排序';

  @override
  String get noSortOptions => '无可用排序';

  @override
  String get loadingLabel => '加载中...';

  @override
  String get noSecondarySort => '无次排序';

  @override
  String get scanMissingLabel => '扫描缺失';

  @override
  String get scanUpdatesLabel => '扫描更新';

  @override
  String get downloadListTitle => '下载列表';

  @override
  String totalLinksSize(Object count, Object sizeLabel) {
    return '共 $count 个链接，总计 $sizeLabel';
  }

  @override
  String addedDownloads(Object count) {
    return '已添加 $count 个下载。';
  }

  @override
  String get copyLinksLabel => '复制链接';

  @override
  String get copyLinksTooltip => '复制下载链接到剪贴板（可在下载管理器中导入）';

  @override
  String get clearListLabel => '清空列表';

  @override
  String get clearListTooltip => '清空下载列表';

  @override
  String resourcesCount(Object count) {
    return '资源（$count）';
  }

  @override
  String ratingDownloads(Object avg, Object count, Object downloads) {
    return '评分 $avg（$count） | $downloads 次下载';
  }

  @override
  String updatedLabel(Object date) {
    return '更新于 $date';
  }

  @override
  String versionLabel(Object version) {
    return '版本 $version';
  }

  @override
  String depsCountLabel(Object count) {
    return '依赖 $count';
  }

  @override
  String extraTagsLabel(Object count) {
    return '+$count';
  }

  @override
  String get repoStatusGoToDownload => '前往下载';

  @override
  String get repoStatusGenerateDownloadList => '生成下载列表';

  @override
  String get repoStatusInRepository => '已在本地库中';

  @override
  String repoStatusUpgrade(Object installedVersion, Object hubVersion) {
    return '从 $installedVersion 升级到 $hubVersion';
  }

  @override
  String get unknownStatusLabel => '未知状态';

  @override
  String get untitledLabel => '未命名';

  @override
  String get unknownLabel => '未知';

  @override
  String get detailLabel => '详情';

  @override
  String get addFilesOnlyLabel => '仅添加文件';

  @override
  String get addWithDependenciesLabel => '添加并包含依赖';

  @override
  String get openPageLabel => '打开页面';

  @override
  String get basicInfoTitle => '基本信息';

  @override
  String get loadingDetailsLabel => '正在加载详细信息...';

  @override
  String loadDetailsFailed(Object error) {
    return '加载详情失败：$error';
  }

  @override
  String get descriptionTitle => '描述';

  @override
  String get imagesTitle => '图片';

  @override
  String get sceneAnalysisTitle => '场景分析';

  @override
  String get analysisLoadFailed => '加载分析摘要失败';

  @override
  String entryLabel(Object entry) {
    return '条目：$entry';
  }

  @override
  String get genderLabel => '性别';

  @override
  String get personsLabel => '人物';

  @override
  String get atomsLabel => '原子';

  @override
  String get depsLabel => '依赖';

  @override
  String get missingLabel => '缺失';

  @override
  String get mismatchLabel => '不匹配';

  @override
  String get peopleTitle => '人物';

  @override
  String get atomsTitle => '原子';

  @override
  String get noPersonAtomsFound => '未找到人物原子';

  @override
  String get poseTag => '姿势';

  @override
  String get animationTag => '动画';

  @override
  String get pluginTag => '插件';

  @override
  String get presetsActionsTitle => '预设与操作';

  @override
  String get lookOptionsTitle => '外观选项';

  @override
  String get loadLookLabel => '加载外观';

  @override
  String get loadPoseLabel => '加载姿势';

  @override
  String get loadAnimationLabel => '加载动画';

  @override
  String get loadPluginLabel => '加载插件';

  @override
  String get posePresetHint => '姿势预设需要 .json 场景条目。';

  @override
  String get atomSearchTitle => '原子搜索';

  @override
  String get filterAtomsHint => '按名称筛选原子';

  @override
  String get selectionTitle => '选择';

  @override
  String selectedAtomsCount(Object count) {
    return '已选 $count 个原子';
  }

  @override
  String get selectBaseLabel => '选择基础';

  @override
  String get selectTypeLabel => '选择类型';

  @override
  String selectTypeWithCount(Object type, Object count) {
    return '选择 $type（$count）';
  }

  @override
  String get includeBaseAtomsLabel => '包含基础原子';

  @override
  String get atomTreeTitle => '原子树';

  @override
  String get noAtomsAvailable => '无可用原子';

  @override
  String get sceneActionsTitle => '场景操作';

  @override
  String get loadSceneLabel => '加载场景';

  @override
  String get addToSceneLabel => '添加到场景';

  @override
  String get addAsSubsceneLabel => '添加为子场景';

  @override
  String get dependencySearchTitle => '依赖搜索';

  @override
  String get filterDependenciesHint => '筛选依赖';

  @override
  String get filtersTitle => '筛选';

  @override
  String get filterAllLabel => '全部';

  @override
  String get filterMissingLabel => '缺失';

  @override
  String get filterMismatchLabel => '不匹配';

  @override
  String get filterResolvedLabel => '已解析';

  @override
  String get filterInstalledLabel => '已安装';

  @override
  String get missingDepsCopied => '缺失依赖已复制';

  @override
  String get copyMissingLabel => '复制缺失';

  @override
  String get noDependenciesMatch => '无匹配依赖';

  @override
  String get presetTargetTitle => '预设目标';

  @override
  String get ignoreGenderLabel => '忽略性别';

  @override
  String get ignoreGenderHint => '仅适用于人物预设，原子操作忽略此项。';

  @override
  String labelValue(Object label, Object value) {
    return '$label：$value';
  }

  @override
  String pageOf(Object current, Object total) {
    return '第 $current/$total 页';
  }

  @override
  String get commonNext => '下一步';

  @override
  String get commonBack => '返回';

  @override
  String get commonSkip => '跳过教程';

  @override
  String bootstrapWelcomeTitle(Object app) {
    return '欢迎使用 $app';
  }

  @override
  String get bootstrapWelcomeBody => '本向导将帮助你完成基础配置、自检和关键功能的快速了解。';

  @override
  String get bootstrapWelcomeHint => '高级用户可以跳过引导，稍后在设置中完成配置。';

  @override
  String get bootstrapWelcomeSkip => '我是高级用户，跳过引导';

  @override
  String get bootstrapWelcomeStart => '开始引导';

  @override
  String get bootstrapSkipConfirmTitle => '确认跳过引导？';

  @override
  String get bootstrapSkipConfirmBody =>
      '跳过将不执行配置与自检，你仍可在设置中完成。若需重新进入引导，可在根目录创建空的 INSTALL.txt。';

  @override
  String get bootstrapSkipConfirmYes => '确认跳过';

  @override
  String get bootstrapFeaturesTitle => '功能一览';

  @override
  String get bootstrapFeatureVars => '管理 VAR：高级筛选、批量操作，并集成 PackSwitch。';

  @override
  String get bootstrapFeatureScenes => '场景三列看板，拖拽整理，快捷操作。';

  @override
  String get bootstrapFeatureHub => 'Hub 卡片 + 标签搜索 + 详情 + 下载列表。';

  @override
  String get bootstrapFeaturePacks => '在主页侧栏快速切换 Pack 配置。';

  @override
  String get bootstrapConfigTitle => '基础配置';

  @override
  String get bootstrapConfigBody => '填写关键路径，确保能够索引包并启动 VaM。';

  @override
  String get bootstrapConfigVarspathRequired => '必须填写 varspath。';

  @override
  String get bootstrapConfigVamExecHint => '推荐：VaM (Desktop Mode).bat';

  @override
  String get bootstrapChecksTitle => '功能自检';

  @override
  String get bootstrapChecksBody => '将测试写入权限、文件操作和软链接能力。';

  @override
  String get bootstrapRunChecks => '开始自检';

  @override
  String get bootstrapChecksSkipTitle => '跳过自检？';

  @override
  String get bootstrapChecksSkipBody => '可以继续，但部分功能可能无法正常工作。';

  @override
  String get bootstrapCheckBackendLabel => '后端健康检查';

  @override
  String get bootstrapCheckVarspathLabel => 'varspath 可用性';

  @override
  String get bootstrapCheckDownloaderLabel => '下载目录写入权限';

  @override
  String get bootstrapCheckFileOpsLabel => '文件复制/移动/重命名';

  @override
  String get bootstrapCheckSymlinkLabel => '软链接创建/读取/移动';

  @override
  String get bootstrapCheckVamExecLabel => 'VaM 启动脚本路径';

  @override
  String get bootstrapCheckVarspathHint => '请先在配置中设置 varspath。';

  @override
  String get bootstrapCheckDownloaderHint => '请选择可写的下载目录。';

  @override
  String get bootstrapCheckFileOpsHint => '可能原因：目录只读、权限不足或文件被占用。';

  @override
  String get bootstrapCheckSymlinkHint => '可能原因：需要管理员/开发者模式、文件系统不支持软链接或磁盘只读。';

  @override
  String get bootstrapCheckVamExecHint => '请在设置中填写正确的 VaM 启动脚本。';

  @override
  String get bootstrapCheckStatusPass => '通过';

  @override
  String get bootstrapCheckStatusWarn => '警告';

  @override
  String get bootstrapCheckStatusFail => '失败';

  @override
  String get bootstrapCheckStatusPending => '等待';

  @override
  String get bootstrapTourHomeTitle => '主页：筛选 + PackSwitch';

  @override
  String get bootstrapTourHomeBody =>
      '更新数据库后，使用高级筛选和批量操作管理 VAR，右侧 PackSwitch 快速切换配置。(如果你是varManager新用户, 请注意执行此操作会永久改变varspath内的*.var包组织结构)';

  @override
  String get bootstrapTourHomeBodyIntro =>
      '更新数据库后，使用高级筛选和批量操作管理 VAR，右侧 PackSwitch 快速切换配置。';

  @override
  String get bootstrapTourHomeBodyWarning =>
      '（请注意执行此操作会永久改变varspath内的*.var包组织结构）';

  @override
  String get bootstrapTourScenesTitle => 'Scenes：三列拖拽';

  @override
  String get bootstrapTourScenesBody => 'Hide/Normal/Fav 三列拖拽整理，支持位置筛选和清理缓存。';

  @override
  String get bootstrapTourHubTagsTitle => 'Hub：标签与快捷筛选';

  @override
  String get bootstrapTourHubTagsBody => '按标签/作者筛选，快捷芯片一键过滤，详情可查看版本/依赖信息。';

  @override
  String get bootstrapTourHubDownloadsTitle => 'Hub：下载列表';

  @override
  String get bootstrapTourHubDownloadsBody => '生成下载列表显示总大小，可复制链接或一键加入下载队列。';

  @override
  String get bootstrapTourDownloadManagerTitle => '下载管理器：统一查看下载';

  @override
  String get bootstrapTourDownloadManagerBody =>
      '在 Hub 中添加的依赖或开始下载后，任务会汇总到这里，随时查看进度与状态。';

  @override
  String get bootstrapTourSettingsTitle => '设置：实时配置';

  @override
  String get bootstrapTourSettingsBody => '运行中编辑路径和后端配置，切换主题与语言。';

  @override
  String get bootstrapFinishTitle => '完成';

  @override
  String get bootstrapFinishBody =>
      '引导已完成，可以开始使用。若需重新进入引导，可在根目录创建空的 INSTALL.txt。';

  @override
  String get bootstrapFinishHint => '后续可在设置中检查配置。';

  @override
  String get bootstrapFinishStart => '开始使用 varManager';

  @override
  String get bootstrapFinishDeleteFailed => '删除 INSTALL.txt 失败，请手动删除。';
}
