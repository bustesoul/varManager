// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonSelectAll => 'Select All';

  @override
  String get commonSelect => 'Select';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonBrowse => 'Browse';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonDetails => 'Details';

  @override
  String get commonLocate => 'Locate';

  @override
  String get commonAnalyze => 'Analyze';

  @override
  String get commonLoad => 'Load';

  @override
  String get commonUse => 'Use';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonFilter => 'Filter';

  @override
  String get navHome => 'Home';

  @override
  String get navScenes => 'Scenes';

  @override
  String get navHub => 'Hub';

  @override
  String get navSettings => 'Settings';

  @override
  String jobFailed(Object kind, Object message) {
    return 'Job failed: $kind ($message)';
  }

  @override
  String get backendReady => 'Backend ready';

  @override
  String get backendError => 'Backend error';

  @override
  String get backendStarting => 'Starting backend';

  @override
  String get backendStartingHint => 'Starting backend...';

  @override
  String backendStartFailed(Object message) {
    return 'Backend start failed: $message';
  }

  @override
  String get jobLogsTitle => 'Job Logs';

  @override
  String get noMatches => 'No matches';

  @override
  String get imagePreviewPrevious => 'Previous';

  @override
  String get imagePreviewNext => 'Next';

  @override
  String get imagePreviewScroll => 'Scroll';

  @override
  String get paginationFirstPageTooltip => 'First page';

  @override
  String get paginationPreviousPageTooltip => 'Previous page';

  @override
  String get paginationNextPageTooltip => 'Next page';

  @override
  String get paginationLastPageTooltip => 'Last page';

  @override
  String get previewFirstItemTooltip => 'First item';

  @override
  String get previewPreviousItemTooltip => 'Previous item';

  @override
  String get previewNextItemTooltip => 'Next item';

  @override
  String get previewLastItemTooltip => 'Last item';

  @override
  String get previewOpenTooltip => 'Open preview';

  @override
  String get previewOpenDoubleClickTooltip => 'Double-click to open preview';

  @override
  String get previewSelectOrOpenTooltip =>
      'Click to select, double-click to preview';

  @override
  String get selectMissingVarTooltip => 'Select missing var';

  @override
  String get jobLogExpandTooltip => 'Expand log panel';

  @override
  String get jobLogCollapseTooltip => 'Collapse log panel';

  @override
  String get downloadManagerTitle => 'Download Manager';

  @override
  String downloadSelectionCount(Object count) {
    return '$count selected';
  }

  @override
  String get downloadNoSelection => 'No selection';

  @override
  String get downloadNoActive => 'No active downloads';

  @override
  String downloadItemsProgress(Object completed, Object total) {
    return 'Items $completed/$total';
  }

  @override
  String get downloadActionPause => 'Pause';

  @override
  String get downloadActionResume => 'Resume';

  @override
  String get downloadActionRemoveRecord => 'Remove Record';

  @override
  String get downloadActionDeleteFile => 'Delete File';

  @override
  String get downloadStatusPaused => 'Paused';

  @override
  String get downloadStatusDownloading => 'Downloading';

  @override
  String get downloadStatusQueued => 'Queued';

  @override
  String get downloadStatusFailed => 'Failed';

  @override
  String get downloadStatusCompleted => 'Completed';

  @override
  String get downloadImportLabel => 'Import';

  @override
  String get downloadImportTooltip =>
      'Import download links from text file (supports format from Hub page)';

  @override
  String downloadImportSuccess(Object count) {
    return 'Imported $count links';
  }

  @override
  String get downloadImportEmpty => 'No valid links found';

  @override
  String get confirmDeleteTitle => 'Confirm Delete';

  @override
  String get confirmDeleteMessage =>
      'This will permanently delete the file. Are you sure?';

  @override
  String get settingsSectionUi => 'UI';

  @override
  String get settingsSectionListen => 'Listen & Logs';

  @override
  String get settingsSectionPaths => 'Paths';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeDefault => 'Default';

  @override
  String get themeOcean => 'Ocean Blue';

  @override
  String get themeForest => 'Forest Green';

  @override
  String get themeRose => 'Rose';

  @override
  String get themeDark => 'Dark';

  @override
  String themeSelectTooltip(Object theme) {
    return 'Switch to $theme theme';
  }

  @override
  String get languageLabel => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get listenHostLabel => 'Listen host';

  @override
  String get listenPortLabel => 'Listen port';

  @override
  String get logLevelLabel => 'Log level';

  @override
  String get jobConcurrencyLabel => 'Job concurrency';

  @override
  String get proxySectionLabel => 'Proxy';

  @override
  String get proxyModeLabel => 'Proxy mode';

  @override
  String get proxyModeSystem => 'System';

  @override
  String get proxyModeManual => 'Manual';

  @override
  String get proxyHostLabel => 'Proxy host';

  @override
  String get proxyPortLabel => 'Proxy port';

  @override
  String get proxyUserLabel => 'Proxy username';

  @override
  String get proxyPasswordLabel => 'Proxy password';

  @override
  String get varspathLabel => 'varspath';

  @override
  String get vampathLabel => 'vampath';

  @override
  String get vamExecLabel => 'vam_exec';

  @override
  String get downloaderSavePathLabel => 'Downloader save path';

  @override
  String get chooseVamHint => 'Recommended: choose virt_a_mate directory';

  @override
  String get chooseAddonPackagesHint => 'Recommended: choose AddonPackages';

  @override
  String get appVersionLabel => 'App version';

  @override
  String get backendVersionLabel => 'Backend version';

  @override
  String get configSaved => 'Config saved';

  @override
  String get configSavedRestartHint =>
      'Config saved; listen_host/port and proxy apply after restart.';

  @override
  String get searchVarPackageLabel => 'Search var/package';

  @override
  String get creatorLabel => 'Creator';

  @override
  String get allCreators => 'All creators';

  @override
  String get statusAllLabel => 'All status';

  @override
  String get statusInstalled => 'Installed';

  @override
  String get statusNotInstalled => 'Not installed';

  @override
  String get sortMetaDate => 'Meta date';

  @override
  String get sortVarDate => 'Var date';

  @override
  String get sortVarName => 'Var name';

  @override
  String get sortCreator => 'Creator';

  @override
  String get sortPackage => 'Package';

  @override
  String get sortSize => 'Size';

  @override
  String get sortDesc => 'Desc';

  @override
  String get sortAsc => 'Asc';

  @override
  String perPageLabel(Object value) {
    return 'Per page $value';
  }

  @override
  String selectedCount(Object count) {
    return 'Selected $count';
  }

  @override
  String get selectPageTooltip => 'Select all items on the current page.';

  @override
  String get selectPageLabel => 'Select page';

  @override
  String get invertPageTooltip => 'Invert selection on the current page.';

  @override
  String get invertPageLabel => 'Invert page';

  @override
  String get clearAllTooltip => 'Clear all selected items.';

  @override
  String get clearAllLabel => 'Clear all';

  @override
  String get resetFiltersTooltip => 'Reset all filters to defaults.';

  @override
  String get resetFiltersLabel => 'Reset filters';

  @override
  String get showAdvancedTooltip => 'Show advanced filters.';

  @override
  String get hideAdvancedTooltip => 'Hide advanced filters.';

  @override
  String get advancedFiltersLabel => 'Advanced filters';

  @override
  String get hideAdvancedLabel => 'Hide advanced';

  @override
  String get packageFilterLabel => 'Package filter';

  @override
  String get versionFilterLabel => 'Version filter';

  @override
  String get enabledAllLabel => 'All enabled';

  @override
  String get enabledOnlyLabel => 'Enabled only';

  @override
  String get disabledOnlyLabel => 'Disabled only';

  @override
  String get minSizeLabel => 'Min size (MB)';

  @override
  String get maxSizeLabel => 'Max size (MB)';

  @override
  String get minDepsLabel => 'Min deps';

  @override
  String get maxDepsLabel => 'Max deps';

  @override
  String get actionsTitle => 'Actions';

  @override
  String get actionGroupCore => 'Core';

  @override
  String get actionGroupCoreTooltip => 'Core actions and dependency checks.';

  @override
  String get actionGroupMaintenance => 'Maintenance';

  @override
  String get actionGroupMaintenanceTooltip => 'Cleanup and maintenance jobs.';

  @override
  String get updateDbLabel => 'Update DB';

  @override
  String get updateDbTooltip =>
      'Scan vars, extract previews, and update the database.';

  @override
  String get updateDbRequiredTitle => 'Update DB required';

  @override
  String updateDbRequiredMessage(Object path) {
    return 'AddonPackages at $path is not a symlink. Run Update DB before switching packs.';
  }

  @override
  String get updateDbSummaryTitle => 'Update DB completed';

  @override
  String updateDbSummaryScanned(Object count) {
    return 'Scanned $count packages.';
  }

  @override
  String get updateDbSummaryEmpty => 'No packages moved.';

  @override
  String updateDbSummaryMoveLine(Object count, Object from, Object to) {
    return '$count from $from to $to';
  }

  @override
  String get startVamLabel => 'Start VaM';

  @override
  String get startVamTooltip => 'Launch the VaM application.';

  @override
  String get prepareSavesLabel => 'Prepare Saves';

  @override
  String get prepareSavesTooltip =>
      'Open the saves preparation and dependency tools.';

  @override
  String get missingDepsSourceTooltip =>
      'Choose the source used to detect missing dependencies.';

  @override
  String get missingDepsSourceLabel => 'Missing deps source';

  @override
  String get missingDepsSourceInstalled => 'Installed packages';

  @override
  String get missingDepsSourceAll => 'All packages';

  @override
  String get missingDepsSourceFiltered => 'Filtered list';

  @override
  String get missingDepsSourceSaves => 'Saves folder';

  @override
  String get missingDepsSourceLog => 'Log (output_log.txt)';

  @override
  String get runMissingDepsLabel => 'Run Missing Deps';

  @override
  String get runMissingDepsTooltip =>
      'Analyze missing dependencies and open the results.';

  @override
  String get rebuildLinksLabel => 'Rebuild Links';

  @override
  String get rebuildLinksTooltip =>
      'Rebuild symlinks after changing the Vars source directory.';

  @override
  String get fixPreviewLabel => 'Fix Preview';

  @override
  String get fixPreviewTooltip => 'Re-extract missing preview images.';

  @override
  String get staleVarsLabel => 'Stale Vars';

  @override
  String get staleVarsTooltip =>
      'Move old versions not referenced by dependencies.';

  @override
  String get oldVersionsLabel => 'Old Versions';

  @override
  String get oldVersionsTooltip => 'Find or manage old package versions.';

  @override
  String totalItems(Object count) {
    return 'Total $count items';
  }

  @override
  String loadFailed(Object error) {
    return 'Load failed: $error';
  }

  @override
  String get installSelectedLabel => 'Install Selected';

  @override
  String get installSelectedTooltip =>
      'Install selected vars and dependencies.';

  @override
  String get uninstallSelectedLabel => 'Uninstall Selected';

  @override
  String get uninstallSelectedTooltip =>
      'Uninstall selected vars and affected items.';

  @override
  String get deleteSelectedLabel => 'Delete Selected';

  @override
  String get deleteSelectedTooltip =>
      'Delete selected vars and affected items.';

  @override
  String get moveLinksLabel => 'Move Links';

  @override
  String get moveLinksTooltip =>
      'Move selected symlink entries to a target folder.';

  @override
  String get targetDirLabel => 'Target dir';

  @override
  String get exportInstalledLabel => 'Export Installed';

  @override
  String get exportInstalledTooltip => 'Export installed vars to a text file.';

  @override
  String get exportPathTitle => 'Export path';

  @override
  String get installFromListLabel => 'Install from List';

  @override
  String get installFromListTooltip => 'Install vars from a text list.';

  @override
  String get installListPathLabel => 'Install list path';

  @override
  String get packSwitchTitle => 'Pack Switch';

  @override
  String get activeLabel => 'Active';

  @override
  String get noSwitchesAvailable => 'No switches available';

  @override
  String get activateLabel => 'Activate';

  @override
  String get renameLabel => 'Rename';

  @override
  String get newSwitchNameTitle => 'New Switch Name';

  @override
  String get renameSwitchTitle => 'Rename Switch';

  @override
  String get switchAlreadyExists => 'Switch already exists';

  @override
  String get newNameMustBeDifferent => 'New name must be different';

  @override
  String get switchNameAlreadyExists => 'Target name already exists';

  @override
  String get deleteSwitchTitle => 'Delete Switch';

  @override
  String deleteSwitchConfirm(Object name) {
    return 'Delete switch \"$name\"?';
  }

  @override
  String presenceFilterLabel(Object label) {
    return '$label: ';
  }

  @override
  String get presenceAllLabel => 'All';

  @override
  String get presenceHasLabel => 'Has';

  @override
  String get presenceNoneLabel => 'None';

  @override
  String get compactModeHint =>
      'Window too small. Enlarge window to show preview panel.';

  @override
  String get categoryScenes => 'Scenes';

  @override
  String get categoryLooks => 'Looks';

  @override
  String get categoryClothing => 'Clothing';

  @override
  String get categoryHairstyle => 'Hairstyle';

  @override
  String get categoryAssets => 'Assets';

  @override
  String get categoryMorphs => 'Morphs';

  @override
  String get categoryPose => 'Pose';

  @override
  String get categorySkin => 'Skin';

  @override
  String get categoryHair => 'Hair';

  @override
  String get categoryTextures => 'Textures';

  @override
  String get categoryPlugins => 'Plugins';

  @override
  String get categoryScripts => 'Scripts';

  @override
  String get categorySubScene => 'SubScene';

  @override
  String get categoryAppearance => 'Appearance';

  @override
  String get categoryBreast => 'Breast';

  @override
  String get categoryGlute => 'Glute';

  @override
  String get clickVarToLoadPreviews => 'Click on a var to load previews';

  @override
  String get noPreviewEntriesForVar => 'No preview entries for selected var';

  @override
  String previewLoadFailed(Object error) {
    return 'Preview load failed: $error';
  }

  @override
  String get allTypesLabel => 'All types';

  @override
  String get loadableLabel => 'Loadable';

  @override
  String itemsCount(Object count) {
    return 'Items $count';
  }

  @override
  String itemPosition(Object current, Object total) {
    return 'Item $current/$total';
  }

  @override
  String get noPreviewsAfterFilters => 'No previews after filters';

  @override
  String get selectPreviewHint => 'Select a preview';

  @override
  String get installVarTitle => 'Install Var';

  @override
  String installVarConfirm(Object varName) {
    return '$varName will be installed. Continue?';
  }

  @override
  String get installLabel => 'Install';

  @override
  String get uninstallLabel => 'Uninstall';

  @override
  String get missingDependenciesTitle => 'Missing Dependencies';

  @override
  String get ignoreVersionMismatch => 'Ignore version mismatch';

  @override
  String get allMissingVars => 'All missing vars';

  @override
  String get includeLinkedLabel => 'Include Linked';

  @override
  String get includeLinkedTooltip =>
      'Show entries that already have link substitutions.';

  @override
  String rowPosition(Object current, Object total) {
    return 'Row $current / $total';
  }

  @override
  String appliedCount(Object count) {
    return 'Applied $count';
  }

  @override
  String draftCount(Object count) {
    return 'Draft $count';
  }

  @override
  String brokenCount(Object count) {
    return 'Broken $count';
  }

  @override
  String get missingVarHeader => 'Missing Var';

  @override
  String get substituteHeader => 'Substitute';

  @override
  String get downloadHeaderShort => 'DL';

  @override
  String get detailsTitle => 'Details';

  @override
  String selectedLabel(Object value) {
    return 'Selected: $value';
  }

  @override
  String resolvedLabel(Object value) {
    return 'Resolved: $value';
  }

  @override
  String downloadLabel(Object value) {
    return 'Download: $value';
  }

  @override
  String linkStatusLabel(Object value) {
    return 'Link status: $value';
  }

  @override
  String get linkSubstitutionTitle => 'Link Substitution';

  @override
  String get linkSubstitutionDescription =>
      'Links create symlinks in ___MissingVarLink___ to substitute missing dependencies.';

  @override
  String appliedLinkLabel(Object value) {
    return 'Applied: $value';
  }

  @override
  String draftLinkLabel(Object value) {
    return 'Draft: $value';
  }

  @override
  String suggestionLabel(Object value) {
    return 'Suggestion: $value';
  }

  @override
  String get useSuggestionTooltip =>
      'Use suggested resolved var as draft link.';

  @override
  String get findTargetLabel => 'Find target';

  @override
  String get pickTargetLabel => 'Pick target';

  @override
  String get limitSamePackageLabel => 'Limit to same creator/package';

  @override
  String get limitSamePackageTooltip =>
      'Limit picker to same creator/package as missing var.';

  @override
  String get targetVarLabel => 'Target Var';

  @override
  String get setDraftLabel => 'Set Draft';

  @override
  String get setDraftTooltip => 'Save draft link for selected missing var.';

  @override
  String get clearDraftLabel => 'Clear Draft';

  @override
  String get clearDraftTooltip =>
      'Clear draft link for selected var (will remove).';

  @override
  String get revertDraftLabel => 'Revert Draft';

  @override
  String get revertDraftTooltip => 'Revert draft to currently applied link.';

  @override
  String get applyToPackageLabel => 'Apply to Package';

  @override
  String get applyToPackageTooltip =>
      'Apply draft target to all missing vars in same package.';

  @override
  String get autoFillResolvedLabel => 'Auto-fill Resolved';

  @override
  String get autoFillResolvedTooltip =>
      'Fill drafts using best resolved matches.';

  @override
  String get applyLinkChangesLabel => 'Apply Link Changes';

  @override
  String get applyLinkChangesTooltip =>
      'Create/update/remove symlinks from draft changes.';

  @override
  String get saveMapLabel => 'Save Map';

  @override
  String get saveMapTooltip => 'Save current effective map to a text file.';

  @override
  String get loadMapLabel => 'Load Map';

  @override
  String get loadMapTooltip => 'Load a map file as drafts for this list.';

  @override
  String get discardDraftsLabel => 'Discard Drafts';

  @override
  String get discardDraftsTooltip => 'Discard all draft changes.';

  @override
  String get googleSearchLabel => 'Google Search';

  @override
  String get googleSearchTooltip => 'Search the missing var on the web.';

  @override
  String get fetchHubLinksLabel => 'Fetch Hub Links';

  @override
  String get fetchHubLinksTooltip =>
      'Query hub for download links for missing vars.';

  @override
  String get downloadSelectedLabel => 'Download Selected';

  @override
  String get downloadSelectedTooltip =>
      'Download link for selected missing var if available.';

  @override
  String get downloadAllLabel => 'Download All';

  @override
  String get downloadAllTooltip => 'Download all selected resources';

  @override
  String get dependentsTitle => 'Dependents';

  @override
  String get noDependents => 'No dependents';

  @override
  String get dependentSavesTitle => 'Dependent Saves';

  @override
  String get noDependentSaves => 'No dependent saves';

  @override
  String get linkStatusBroken => 'Broken link';

  @override
  String get linkStatusRemove => 'Remove link';

  @override
  String get linkStatusClear => 'Clear link';

  @override
  String get linkStatusNew => 'New link';

  @override
  String get linkStatusLinked => 'Linked';

  @override
  String get linkStatusChanged => 'Link changed';

  @override
  String get linkStatusNotLinked => 'Not linked';

  @override
  String get downloadStatusDirect => 'Direct';

  @override
  String get downloadStatusNoVersion => 'No Version';

  @override
  String get downloadStatusNone => 'None';

  @override
  String get missingSelectFirst => 'Please select a missing var first.';

  @override
  String get missingFetchHubLinksFirst =>
      'Please click \"Fetch Hub Links\" first to get download URLs.';

  @override
  String get missingNoDownloadUrlForSelected =>
      'No download URL available for the selected var.';

  @override
  String get missingAddedDownload => 'Added 1 download.';

  @override
  String get missingNoDownloadUrlsAvailable => 'No download URLs available.';

  @override
  String missingAddedDownloads(Object count) {
    return 'Added $count downloads.';
  }

  @override
  String linkChangesApplied(
    Object total,
    Object created,
    Object skipped,
    Object failed,
  ) {
    return 'Link changes applied: $total total, $created created, $skipped skipped, $failed failed.';
  }

  @override
  String get missingStatus => 'missing';

  @override
  String closestMatch(Object name) {
    return '$name (closest)';
  }

  @override
  String get draftClearLabel => '(clear)';

  @override
  String get textFileTypeLabel => 'Text';

  @override
  String varDetailsTitle(Object varName) {
    return 'Details: $varName';
  }

  @override
  String get filterByCreator => 'Filter by Creator';

  @override
  String get missingDeps => 'Missing Deps';

  @override
  String get dependenciesTitle => 'Dependencies';

  @override
  String get saveDependenciesTitle => 'Save Dependencies';

  @override
  String get previewsTitle => 'Previews';

  @override
  String get noPreviews => 'No previews';

  @override
  String previewTitleWithType(Object title, Object type) {
    return '$title ($type)';
  }

  @override
  String totalCount(Object count) {
    return 'Total $count';
  }

  @override
  String get nameFilterLabel => 'Name filter';

  @override
  String get sortNewToOld => 'New to Old';

  @override
  String get sortSceneName => 'SceneName';

  @override
  String get columnsLabel => 'Columns:';

  @override
  String get columnHide => 'Hide';

  @override
  String get columnNormal => 'Normal';

  @override
  String get columnFav => 'Fav';

  @override
  String get mergeLabel => 'Merge';

  @override
  String get forMaleLabel => 'For Male';

  @override
  String get hideLabel => 'Hide';

  @override
  String get unhideLabel => 'Unhide';

  @override
  String get favLabel => 'Fav';

  @override
  String get unfavLabel => 'Unfav';

  @override
  String columnTitleWithCount(Object count, Object title) {
    return '$title ($count)';
  }

  @override
  String get locationLabel => 'Location';

  @override
  String get locationInstalled => 'Installed';

  @override
  String get locationNotInstalled => 'Not installed';

  @override
  String get locationMissingLink => 'MissingLink';

  @override
  String get locationSave => 'Save';

  @override
  String get clearCacheLabel => 'Clear cache';

  @override
  String personLabel(Object value) {
    return 'Person $value';
  }

  @override
  String get uninstallPreviewTitle => 'Uninstall Preview';

  @override
  String uninstallPackageCount(Object count) {
    return 'Will uninstall $count packages';
  }

  @override
  String get uninstallTagRequested => 'Requested';

  @override
  String get uninstallTagImplicated => 'Implicated';

  @override
  String previewsCount(Object count) {
    return 'Previews ($count)';
  }

  @override
  String dependenciesCount(Object count) {
    return 'Dependencies ($count)';
  }

  @override
  String get noDependencies => 'No dependencies';

  @override
  String get prepareSavesTitle => 'Prepare Saves';

  @override
  String get outputFolderLabel => 'Output folder';

  @override
  String get outputFolderReady => 'Output folder is ready.';

  @override
  String get outputFolderValidationFailed => 'Output folder validation failed.';

  @override
  String get validateOutputLabel => 'Validate Output';

  @override
  String get savesTreeTitle => 'Saves Tree';

  @override
  String get noSavesFound => 'No saves found';

  @override
  String selectedFilesCount(Object count) {
    return 'Selected $count files';
  }

  @override
  String get filtersActionsTitle => 'Filters & Actions';

  @override
  String get basicFiltersTitle => 'Basic Filters';

  @override
  String get advancedFiltersTitle => 'Advanced Filters';

  @override
  String get sortOptionsTitle => 'Sort Options';

  @override
  String get allLocationsLabel => 'All locations';

  @override
  String get allPayTypesLabel => 'All pay types';

  @override
  String get payTypeLabel => 'Pay Type';

  @override
  String get categoryLabel => 'Category';

  @override
  String get tagLabel => 'Tag';

  @override
  String get allTagsLabel => 'All tags';

  @override
  String get primarySortLabel => 'Primary Sort';

  @override
  String get secondarySortLabel => 'Secondary Sort';

  @override
  String get noSortOptions => 'No sort options available';

  @override
  String get loadingLabel => 'Loading...';

  @override
  String get noSecondarySort => 'No secondary sort';

  @override
  String get scanMissingLabel => 'Scan Missing';

  @override
  String get scanUpdatesLabel => 'Scan Updates';

  @override
  String get downloadListTitle => 'Download List';

  @override
  String totalLinksSize(Object count, Object sizeLabel) {
    return 'Total $count links, Total $sizeLabel';
  }

  @override
  String addedDownloads(Object count) {
    return 'Added $count downloads.';
  }

  @override
  String get copyLinksLabel => 'Copy Links';

  @override
  String get copyLinksTooltip =>
      'Copy download links to clipboard (can be imported in download manager)';

  @override
  String get clearListLabel => 'Clear List';

  @override
  String get clearListTooltip => 'Clear download list';

  @override
  String resourcesCount(Object count) {
    return 'Resources ($count)';
  }

  @override
  String ratingDownloads(Object avg, Object count, Object downloads) {
    return 'Rating $avg ($count) | $downloads downloads';
  }

  @override
  String updatedLabel(Object date) {
    return 'Updated $date';
  }

  @override
  String versionLabel(Object version) {
    return 'Version $version';
  }

  @override
  String depsCountLabel(Object count) {
    return 'Deps $count';
  }

  @override
  String extraTagsLabel(Object count) {
    return '+$count';
  }

  @override
  String get repoStatusGoToDownload => 'Go To Download';

  @override
  String get repoStatusGenerateDownloadList => 'Generate Download List';

  @override
  String get repoStatusInRepository => 'In Repository';

  @override
  String repoStatusUpgrade(Object installedVersion, Object hubVersion) {
    return 'Upgrade $installedVersion to $hubVersion';
  }

  @override
  String get unknownStatusLabel => 'Unknown Status';

  @override
  String get untitledLabel => 'Untitled';

  @override
  String get unknownLabel => 'unknown';

  @override
  String get detailLabel => 'Detail';

  @override
  String get addFilesOnlyLabel => 'Add Files Only';

  @override
  String get addWithDependenciesLabel => 'Add With Dependencies';

  @override
  String get openPageLabel => 'Open Page';

  @override
  String get basicInfoTitle => 'Basic Information';

  @override
  String get loadingDetailsLabel => 'Loading detailed information...';

  @override
  String loadDetailsFailed(Object error) {
    return 'Failed to load details: $error';
  }

  @override
  String get descriptionTitle => 'Description';

  @override
  String get imagesTitle => 'Images';

  @override
  String get sceneAnalysisTitle => 'Scene Analysis';

  @override
  String get analysisLoadFailed => 'Failed to load analysis summary';

  @override
  String entryLabel(Object entry) {
    return 'Entry: $entry';
  }

  @override
  String get genderLabel => 'Gender';

  @override
  String get personsLabel => 'Persons';

  @override
  String get atomsLabel => 'Atoms';

  @override
  String get depsLabel => 'Deps';

  @override
  String get missingLabel => 'Missing';

  @override
  String get mismatchLabel => 'Mismatch';

  @override
  String get peopleTitle => 'People';

  @override
  String get atomsTitle => 'Atoms';

  @override
  String get noPersonAtomsFound => 'No person atoms found';

  @override
  String get poseTag => 'Pose';

  @override
  String get animationTag => 'Animation';

  @override
  String get pluginTag => 'Plugin';

  @override
  String get presetsActionsTitle => 'Presets & Actions';

  @override
  String get lookOptionsTitle => 'Look Options';

  @override
  String get loadLookLabel => 'Load Look';

  @override
  String get loadPoseLabel => 'Load Pose';

  @override
  String get loadAnimationLabel => 'Load Animation';

  @override
  String get loadPluginLabel => 'Load Plugin';

  @override
  String get posePresetHint => 'Pose presets require .json scene entries.';

  @override
  String get atomSearchTitle => 'Atom Search';

  @override
  String get filterAtomsHint => 'Filter atoms by name';

  @override
  String get selectionTitle => 'Selection';

  @override
  String selectedAtomsCount(Object count) {
    return 'Selected $count atoms';
  }

  @override
  String get selectBaseLabel => 'Select Base';

  @override
  String get selectTypeLabel => 'Select Type';

  @override
  String selectTypeWithCount(Object type, Object count) {
    return 'Select $type ($count)';
  }

  @override
  String get includeBaseAtomsLabel => 'Include base atoms';

  @override
  String get atomTreeTitle => 'Atom Tree';

  @override
  String get noAtomsAvailable => 'No atoms available';

  @override
  String get sceneActionsTitle => 'Scene Actions';

  @override
  String get loadSceneLabel => 'Load Scene';

  @override
  String get addToSceneLabel => 'Add To Scene';

  @override
  String get addAsSubsceneLabel => 'Add as Subscene';

  @override
  String get dependencySearchTitle => 'Dependency Search';

  @override
  String get filterDependenciesHint => 'Filter dependencies';

  @override
  String get filtersTitle => 'Filters';

  @override
  String get filterAllLabel => 'All';

  @override
  String get filterMissingLabel => 'Missing';

  @override
  String get filterMismatchLabel => 'Mismatch';

  @override
  String get filterResolvedLabel => 'Resolved';

  @override
  String get filterInstalledLabel => 'Installed';

  @override
  String get missingDepsCopied => 'Missing deps copied';

  @override
  String get copyMissingLabel => 'Copy Missing';

  @override
  String get noDependenciesMatch => 'No dependencies match';

  @override
  String get presetTargetTitle => 'Preset Target';

  @override
  String get ignoreGenderLabel => 'Ignore Gender';

  @override
  String get ignoreGenderHint =>
      'Applies to person presets only. Atom actions ignore this.';

  @override
  String labelValue(Object label, Object value) {
    return '$label: $value';
  }

  @override
  String pageOf(Object current, Object total) {
    return 'Page $current/$total';
  }

  @override
  String get commonNext => 'Next';

  @override
  String get commonBack => 'Back';

  @override
  String get commonSkip => 'Skip tutorial';

  @override
  String bootstrapWelcomeTitle(Object app) {
    return 'Welcome to $app';
  }

  @override
  String get bootstrapWelcomeBody =>
      'This guide will help you finish basic setup, run self-checks, and learn key workflows.';

  @override
  String get bootstrapWelcomeHint =>
      'Advanced users can skip and configure everything later in Settings.';

  @override
  String get bootstrapWelcomeSkip => 'I am an advanced user, skip guide';

  @override
  String get bootstrapWelcomeStart => 'Start guide';

  @override
  String get bootstrapSkipConfirmTitle => 'Skip onboarding?';

  @override
  String get bootstrapSkipConfirmBody =>
      'Skipping will bypass configuration and self-checks. You can still configure everything later. To re-enter the tour, create an empty INSTALL.txt in the app root directory.';

  @override
  String get bootstrapSkipConfirmYes => 'Skip now';

  @override
  String get bootstrapFeaturesTitle => 'What you can do';

  @override
  String get bootstrapFeatureVars =>
      'Manage VARs with advanced filters, batch actions, and PackSwitch integration.';

  @override
  String get bootstrapFeatureScenes =>
      'Scenes board with Hide/Normal/Fav columns, drag-and-drop, and quick actions.';

  @override
  String get bootstrapFeatureHub =>
      'Hub cards with tag search, detail info, and download lists.';

  @override
  String get bootstrapFeaturePacks =>
      'Switch pack profiles fast from the Home sidebar.';

  @override
  String get bootstrapConfigTitle => 'Basic configuration';

  @override
  String get bootstrapConfigBody =>
      'Fill in key paths so varManager can index packages and launch VaM.';

  @override
  String get bootstrapConfigVarspathRequired => 'varspath is required.';

  @override
  String get bootstrapConfigVamExecHint =>
      'Recommended: VaM (Desktop Mode).bat';

  @override
  String get bootstrapChecksTitle => 'Self-check';

  @override
  String get bootstrapChecksBody =>
      'We will test write access, file operations, and symlink support.';

  @override
  String get bootstrapRunChecks => 'Run checks';

  @override
  String get bootstrapChecksSkipTitle => 'Skip self-check?';

  @override
  String get bootstrapChecksSkipBody =>
      'You can continue without checks, but some features may fail later.';

  @override
  String get bootstrapCheckBackendLabel => 'Backend health';

  @override
  String get bootstrapCheckVarspathLabel => 'varspath availability';

  @override
  String get bootstrapCheckDownloaderLabel => 'Download path write access';

  @override
  String get bootstrapCheckFileOpsLabel => 'File copy/move/rename';

  @override
  String get bootstrapCheckSymlinkLabel => 'Symlink create/read/move';

  @override
  String get bootstrapCheckVamExecLabel => 'VaM executable path';

  @override
  String get bootstrapCheckVarspathHint => 'Set varspath in configuration.';

  @override
  String get bootstrapCheckDownloaderHint => 'Choose a writable download path.';

  @override
  String get bootstrapCheckFileOpsHint =>
      'Possible reasons: read-only folder, missing permissions, or locked files.';

  @override
  String get bootstrapCheckSymlinkHint =>
      'Possible reasons: admin/dev mode required, unsupported filesystem, or read-only drive.';

  @override
  String get bootstrapCheckVamExecHint =>
      'Set the correct VaM launch script in Settings.';

  @override
  String get bootstrapCheckStatusPass => 'Pass';

  @override
  String get bootstrapCheckStatusWarn => 'Warning';

  @override
  String get bootstrapCheckStatusFail => 'Fail';

  @override
  String get bootstrapCheckStatusPending => 'Pending';

  @override
  String get bootstrapTourHomeTitle => 'Home: Filters + PackSwitch';

  @override
  String get bootstrapTourHomeBody =>
      'Update DB to index new VARs, then use advanced filters, batch actions, and the PackSwitch sidebar to manage installs. (If you are a new varManager user, please note that performing this operation will permanently change the *.var package organization structure within Varspath.)';

  @override
  String get bootstrapTourHomeBodyIntro =>
      'Update DB to index new VARs, then use advanced filters, batch actions, and the PackSwitch sidebar to manage installs.';

  @override
  String get bootstrapTourHomeBodyWarning =>
      '(If you are a new varManager user, please note that performing this operation will permanently change the *.var package organization structure within Varspath.)';

  @override
  String get bootstrapTourScenesTitle => 'Scenes: 3-column board';

  @override
  String get bootstrapTourScenesBody =>
      'Scenes are split into Hide/Normal/Fav; drag cards to organize, filter by location, and clear cache when needed.';

  @override
  String get bootstrapTourHubTagsTitle => 'Hub: Tags + quick filters';

  @override
  String get bootstrapTourHubTagsBody =>
      'Search by tags/creator and use quick chips; open details for version and dependency info.';

  @override
  String get bootstrapTourHubDownloadsTitle => 'Hub: Download list';

  @override
  String get bootstrapTourHubDownloadsBody =>
      'Build a download list, see total size, copy links, or Download All to enqueue.';

  @override
  String get bootstrapTourDownloadManagerTitle =>
      'Download Manager: All downloads in one place';

  @override
  String get bootstrapTourDownloadManagerBody =>
      'Dependencies added from Hub and started downloads will appear here so you can track progress and status.';

  @override
  String get bootstrapTourSettingsTitle => 'Settings: Live config';

  @override
  String get bootstrapTourSettingsBody =>
      'Edit paths and backend config at runtime, plus theme/language switching.';

  @override
  String get bootstrapFinishTitle => 'All set';

  @override
  String get bootstrapFinishBody =>
      'You are ready to use varManager. To re-enter the tour, create an empty INSTALL.txt in the app root directory.';

  @override
  String get bootstrapFinishHint =>
      'You can revisit this guide later from Settings (if enabled in future).';

  @override
  String get bootstrapFinishStart => 'Start using varManager';

  @override
  String get bootstrapFinishDeleteFailed =>
      'Failed to remove INSTALL.txt. Please delete it manually.';
}
