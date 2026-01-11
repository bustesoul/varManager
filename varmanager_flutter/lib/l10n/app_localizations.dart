import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get commonSelectAll;

  /// No description provided for @commonSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get commonSelect;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get commonBrowse;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get commonDetails;

  /// No description provided for @commonLocate.
  ///
  /// In en, this message translates to:
  /// **'Locate'**
  String get commonLocate;

  /// No description provided for @commonAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get commonAnalyze;

  /// No description provided for @commonLoad.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get commonLoad;

  /// No description provided for @commonUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get commonUse;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get commonFilter;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navScenes.
  ///
  /// In en, this message translates to:
  /// **'Scenes'**
  String get navScenes;

  /// No description provided for @navHub.
  ///
  /// In en, this message translates to:
  /// **'Hub'**
  String get navHub;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @jobFailed.
  ///
  /// In en, this message translates to:
  /// **'Job failed: {kind} ({message})'**
  String jobFailed(Object kind, Object message);

  /// No description provided for @backendReady.
  ///
  /// In en, this message translates to:
  /// **'Backend ready'**
  String get backendReady;

  /// No description provided for @backendError.
  ///
  /// In en, this message translates to:
  /// **'Backend error'**
  String get backendError;

  /// No description provided for @backendStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting backend'**
  String get backendStarting;

  /// No description provided for @backendStartingHint.
  ///
  /// In en, this message translates to:
  /// **'Starting backend...'**
  String get backendStartingHint;

  /// No description provided for @backendStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Backend start failed: {message}'**
  String backendStartFailed(Object message);

  /// No description provided for @jobLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Job Logs'**
  String get jobLogsTitle;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @imagePreviewPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get imagePreviewPrevious;

  /// No description provided for @imagePreviewNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get imagePreviewNext;

  /// No description provided for @imagePreviewScroll.
  ///
  /// In en, this message translates to:
  /// **'Scroll'**
  String get imagePreviewScroll;

  /// No description provided for @downloadManagerTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Manager'**
  String get downloadManagerTitle;

  /// No description provided for @downloadSelectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String downloadSelectionCount(Object count);

  /// No description provided for @downloadNoSelection.
  ///
  /// In en, this message translates to:
  /// **'No selection'**
  String get downloadNoSelection;

  /// No description provided for @downloadNoActive.
  ///
  /// In en, this message translates to:
  /// **'No active downloads'**
  String get downloadNoActive;

  /// No description provided for @downloadItemsProgress.
  ///
  /// In en, this message translates to:
  /// **'Items {completed}/{total}'**
  String downloadItemsProgress(Object completed, Object total);

  /// No description provided for @downloadActionPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get downloadActionPause;

  /// No description provided for @downloadActionResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get downloadActionResume;

  /// No description provided for @downloadActionRemoveRecord.
  ///
  /// In en, this message translates to:
  /// **'Remove Record'**
  String get downloadActionRemoveRecord;

  /// No description provided for @downloadActionDeleteFile.
  ///
  /// In en, this message translates to:
  /// **'Delete File'**
  String get downloadActionDeleteFile;

  /// No description provided for @downloadStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get downloadStatusPaused;

  /// No description provided for @downloadStatusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadStatusDownloading;

  /// No description provided for @downloadStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get downloadStatusQueued;

  /// No description provided for @downloadStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get downloadStatusFailed;

  /// No description provided for @downloadStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get downloadStatusCompleted;

  /// No description provided for @downloadImportLabel.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get downloadImportLabel;

  /// No description provided for @downloadImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} links'**
  String downloadImportSuccess(Object count);

  /// No description provided for @downloadImportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No valid links found'**
  String get downloadImportEmpty;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete the file. Are you sure?'**
  String get confirmDeleteMessage;

  /// No description provided for @settingsSectionUi.
  ///
  /// In en, this message translates to:
  /// **'UI'**
  String get settingsSectionUi;

  /// No description provided for @settingsSectionListen.
  ///
  /// In en, this message translates to:
  /// **'Listen & Logs'**
  String get settingsSectionListen;

  /// No description provided for @settingsSectionPaths.
  ///
  /// In en, this message translates to:
  /// **'Paths'**
  String get settingsSectionPaths;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get themeDefault;

  /// No description provided for @themeOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean Blue'**
  String get themeOcean;

  /// No description provided for @themeForest.
  ///
  /// In en, this message translates to:
  /// **'Forest Green'**
  String get themeForest;

  /// No description provided for @themeRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get themeRose;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @listenHostLabel.
  ///
  /// In en, this message translates to:
  /// **'Listen host'**
  String get listenHostLabel;

  /// No description provided for @listenPortLabel.
  ///
  /// In en, this message translates to:
  /// **'Listen port'**
  String get listenPortLabel;

  /// No description provided for @logLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Log level'**
  String get logLevelLabel;

  /// No description provided for @jobConcurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Job concurrency'**
  String get jobConcurrencyLabel;

  /// No description provided for @varspathLabel.
  ///
  /// In en, this message translates to:
  /// **'varspath'**
  String get varspathLabel;

  /// No description provided for @vampathLabel.
  ///
  /// In en, this message translates to:
  /// **'vampath'**
  String get vampathLabel;

  /// No description provided for @vamExecLabel.
  ///
  /// In en, this message translates to:
  /// **'vam_exec'**
  String get vamExecLabel;

  /// No description provided for @downloaderSavePathLabel.
  ///
  /// In en, this message translates to:
  /// **'Downloader save path'**
  String get downloaderSavePathLabel;

  /// No description provided for @chooseVamHint.
  ///
  /// In en, this message translates to:
  /// **'choose virt_a_mate'**
  String get chooseVamHint;

  /// No description provided for @chooseAddonPackagesHint.
  ///
  /// In en, this message translates to:
  /// **'choose AddonPackages'**
  String get chooseAddonPackagesHint;

  /// No description provided for @appVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersionLabel;

  /// No description provided for @backendVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Backend version'**
  String get backendVersionLabel;

  /// No description provided for @configSavedRestartHint.
  ///
  /// In en, this message translates to:
  /// **'Config saved; listen_host/port applies after restart.'**
  String get configSavedRestartHint;

  /// No description provided for @searchVarPackageLabel.
  ///
  /// In en, this message translates to:
  /// **'Search var/package'**
  String get searchVarPackageLabel;

  /// No description provided for @creatorLabel.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get creatorLabel;

  /// No description provided for @allCreators.
  ///
  /// In en, this message translates to:
  /// **'All creators'**
  String get allCreators;

  /// No description provided for @statusAllLabel.
  ///
  /// In en, this message translates to:
  /// **'All status'**
  String get statusAllLabel;

  /// No description provided for @statusInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get statusInstalled;

  /// No description provided for @statusNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get statusNotInstalled;

  /// No description provided for @sortMetaDate.
  ///
  /// In en, this message translates to:
  /// **'Meta date'**
  String get sortMetaDate;

  /// No description provided for @sortVarDate.
  ///
  /// In en, this message translates to:
  /// **'Var date'**
  String get sortVarDate;

  /// No description provided for @sortVarName.
  ///
  /// In en, this message translates to:
  /// **'Var name'**
  String get sortVarName;

  /// No description provided for @sortCreator.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get sortCreator;

  /// No description provided for @sortPackage.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get sortPackage;

  /// No description provided for @sortSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sortSize;

  /// No description provided for @sortDesc.
  ///
  /// In en, this message translates to:
  /// **'Desc'**
  String get sortDesc;

  /// No description provided for @sortAsc.
  ///
  /// In en, this message translates to:
  /// **'Asc'**
  String get sortAsc;

  /// No description provided for @perPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Per page {value}'**
  String perPageLabel(Object value);

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'Selected {count}'**
  String selectedCount(Object count);

  /// No description provided for @selectPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select all items on the current page.'**
  String get selectPageTooltip;

  /// No description provided for @selectPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Select page'**
  String get selectPageLabel;

  /// No description provided for @invertPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Invert selection on the current page.'**
  String get invertPageTooltip;

  /// No description provided for @invertPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Invert page'**
  String get invertPageLabel;

  /// No description provided for @clearAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear all selected items.'**
  String get clearAllTooltip;

  /// No description provided for @clearAllLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAllLabel;

  /// No description provided for @resetFiltersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset all filters to defaults.'**
  String get resetFiltersTooltip;

  /// No description provided for @resetFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get resetFiltersLabel;

  /// No description provided for @showAdvancedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show advanced filters.'**
  String get showAdvancedTooltip;

  /// No description provided for @hideAdvancedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide advanced filters.'**
  String get hideAdvancedTooltip;

  /// No description provided for @advancedFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Advanced filters'**
  String get advancedFiltersLabel;

  /// No description provided for @hideAdvancedLabel.
  ///
  /// In en, this message translates to:
  /// **'Hide advanced'**
  String get hideAdvancedLabel;

  /// No description provided for @packageFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Package filter'**
  String get packageFilterLabel;

  /// No description provided for @versionFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Version filter'**
  String get versionFilterLabel;

  /// No description provided for @enabledAllLabel.
  ///
  /// In en, this message translates to:
  /// **'All enabled'**
  String get enabledAllLabel;

  /// No description provided for @enabledOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Enabled only'**
  String get enabledOnlyLabel;

  /// No description provided for @disabledOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Disabled only'**
  String get disabledOnlyLabel;

  /// No description provided for @minSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Min size (MB)'**
  String get minSizeLabel;

  /// No description provided for @maxSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Max size (MB)'**
  String get maxSizeLabel;

  /// No description provided for @minDepsLabel.
  ///
  /// In en, this message translates to:
  /// **'Min deps'**
  String get minDepsLabel;

  /// No description provided for @maxDepsLabel.
  ///
  /// In en, this message translates to:
  /// **'Max deps'**
  String get maxDepsLabel;

  /// No description provided for @actionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actionsTitle;

  /// No description provided for @actionGroupCore.
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get actionGroupCore;

  /// No description provided for @actionGroupCoreTooltip.
  ///
  /// In en, this message translates to:
  /// **'Core actions and dependency checks.'**
  String get actionGroupCoreTooltip;

  /// No description provided for @actionGroupMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get actionGroupMaintenance;

  /// No description provided for @actionGroupMaintenanceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cleanup and maintenance jobs.'**
  String get actionGroupMaintenanceTooltip;

  /// No description provided for @updateDbLabel.
  ///
  /// In en, this message translates to:
  /// **'Update DB'**
  String get updateDbLabel;

  /// No description provided for @updateDbTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scan vars, extract previews, and update the database.'**
  String get updateDbTooltip;

  /// No description provided for @startVamLabel.
  ///
  /// In en, this message translates to:
  /// **'Start VaM'**
  String get startVamLabel;

  /// No description provided for @startVamTooltip.
  ///
  /// In en, this message translates to:
  /// **'Launch the VaM application.'**
  String get startVamTooltip;

  /// No description provided for @prepareSavesLabel.
  ///
  /// In en, this message translates to:
  /// **'Prepare Saves'**
  String get prepareSavesLabel;

  /// No description provided for @prepareSavesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open the saves preparation and dependency tools.'**
  String get prepareSavesTooltip;

  /// No description provided for @missingDepsSourceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Choose the source used to detect missing dependencies.'**
  String get missingDepsSourceTooltip;

  /// No description provided for @missingDepsSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Missing deps source'**
  String get missingDepsSourceLabel;

  /// No description provided for @missingDepsSourceInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed packages'**
  String get missingDepsSourceInstalled;

  /// No description provided for @missingDepsSourceAll.
  ///
  /// In en, this message translates to:
  /// **'All packages'**
  String get missingDepsSourceAll;

  /// No description provided for @missingDepsSourceFiltered.
  ///
  /// In en, this message translates to:
  /// **'Filtered list'**
  String get missingDepsSourceFiltered;

  /// No description provided for @missingDepsSourceSaves.
  ///
  /// In en, this message translates to:
  /// **'Saves folder'**
  String get missingDepsSourceSaves;

  /// No description provided for @missingDepsSourceLog.
  ///
  /// In en, this message translates to:
  /// **'Log (output_log.txt)'**
  String get missingDepsSourceLog;

  /// No description provided for @runMissingDepsLabel.
  ///
  /// In en, this message translates to:
  /// **'Run Missing Deps'**
  String get runMissingDepsLabel;

  /// No description provided for @runMissingDepsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Analyze missing dependencies and open the results.'**
  String get runMissingDepsTooltip;

  /// No description provided for @rebuildLinksLabel.
  ///
  /// In en, this message translates to:
  /// **'Rebuild Links'**
  String get rebuildLinksLabel;

  /// No description provided for @rebuildLinksTooltip.
  ///
  /// In en, this message translates to:
  /// **'Rebuild symlinks after changing the Vars source directory.'**
  String get rebuildLinksTooltip;

  /// No description provided for @fixPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Fix Preview'**
  String get fixPreviewLabel;

  /// No description provided for @fixPreviewTooltip.
  ///
  /// In en, this message translates to:
  /// **'Re-extract missing preview images.'**
  String get fixPreviewTooltip;

  /// No description provided for @staleVarsLabel.
  ///
  /// In en, this message translates to:
  /// **'Stale Vars'**
  String get staleVarsLabel;

  /// No description provided for @staleVarsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Move old versions not referenced by dependencies.'**
  String get staleVarsTooltip;

  /// No description provided for @oldVersionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Old Versions'**
  String get oldVersionsLabel;

  /// No description provided for @oldVersionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Find or manage old package versions.'**
  String get oldVersionsTooltip;

  /// No description provided for @totalItems.
  ///
  /// In en, this message translates to:
  /// **'Total {count} items'**
  String totalItems(Object count);

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {error}'**
  String loadFailed(Object error);

  /// No description provided for @installSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Install Selected'**
  String get installSelectedLabel;

  /// No description provided for @installSelectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Install selected vars and dependencies.'**
  String get installSelectedTooltip;

  /// No description provided for @uninstallSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Uninstall Selected'**
  String get uninstallSelectedLabel;

  /// No description provided for @uninstallSelectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Uninstall selected vars and affected items.'**
  String get uninstallSelectedTooltip;

  /// No description provided for @deleteSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected'**
  String get deleteSelectedLabel;

  /// No description provided for @deleteSelectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete selected vars and affected items.'**
  String get deleteSelectedTooltip;

  /// No description provided for @moveLinksLabel.
  ///
  /// In en, this message translates to:
  /// **'Move Links'**
  String get moveLinksLabel;

  /// No description provided for @moveLinksTooltip.
  ///
  /// In en, this message translates to:
  /// **'Move selected symlink entries to a target folder.'**
  String get moveLinksTooltip;

  /// No description provided for @targetDirLabel.
  ///
  /// In en, this message translates to:
  /// **'Target dir'**
  String get targetDirLabel;

  /// No description provided for @exportInstalledLabel.
  ///
  /// In en, this message translates to:
  /// **'Export Installed'**
  String get exportInstalledLabel;

  /// No description provided for @exportInstalledTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export installed vars to a text file.'**
  String get exportInstalledTooltip;

  /// No description provided for @exportPathTitle.
  ///
  /// In en, this message translates to:
  /// **'Export path'**
  String get exportPathTitle;

  /// No description provided for @installFromListLabel.
  ///
  /// In en, this message translates to:
  /// **'Install from List'**
  String get installFromListLabel;

  /// No description provided for @installFromListTooltip.
  ///
  /// In en, this message translates to:
  /// **'Install vars from a text list.'**
  String get installFromListTooltip;

  /// No description provided for @installListPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Install list path'**
  String get installListPathLabel;

  /// No description provided for @packSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Pack Switch'**
  String get packSwitchTitle;

  /// No description provided for @activeLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeLabel;

  /// No description provided for @noSwitchesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No switches available'**
  String get noSwitchesAvailable;

  /// No description provided for @activateLabel.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get activateLabel;

  /// No description provided for @renameLabel.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameLabel;

  /// No description provided for @newSwitchNameTitle.
  ///
  /// In en, this message translates to:
  /// **'New Switch Name'**
  String get newSwitchNameTitle;

  /// No description provided for @renameSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Switch'**
  String get renameSwitchTitle;

  /// No description provided for @switchAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Switch already exists'**
  String get switchAlreadyExists;

  /// No description provided for @newNameMustBeDifferent.
  ///
  /// In en, this message translates to:
  /// **'New name must be different'**
  String get newNameMustBeDifferent;

  /// No description provided for @switchNameAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Target name already exists'**
  String get switchNameAlreadyExists;

  /// No description provided for @deleteSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Switch'**
  String get deleteSwitchTitle;

  /// No description provided for @deleteSwitchConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete switch \"{name}\"?'**
  String deleteSwitchConfirm(Object name);

  /// No description provided for @presenceFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'{label}: '**
  String presenceFilterLabel(Object label);

  /// No description provided for @presenceAllLabel.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get presenceAllLabel;

  /// No description provided for @presenceHasLabel.
  ///
  /// In en, this message translates to:
  /// **'Has'**
  String get presenceHasLabel;

  /// No description provided for @presenceNoneLabel.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get presenceNoneLabel;

  /// No description provided for @compactModeHint.
  ///
  /// In en, this message translates to:
  /// **'Window too small. Enlarge window to show preview panel.'**
  String get compactModeHint;

  /// No description provided for @categoryScenes.
  ///
  /// In en, this message translates to:
  /// **'Scenes'**
  String get categoryScenes;

  /// No description provided for @categoryLooks.
  ///
  /// In en, this message translates to:
  /// **'Looks'**
  String get categoryLooks;

  /// No description provided for @categoryClothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get categoryClothing;

  /// No description provided for @categoryHairstyle.
  ///
  /// In en, this message translates to:
  /// **'Hairstyle'**
  String get categoryHairstyle;

  /// No description provided for @categoryAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get categoryAssets;

  /// No description provided for @categoryMorphs.
  ///
  /// In en, this message translates to:
  /// **'Morphs'**
  String get categoryMorphs;

  /// No description provided for @categoryPose.
  ///
  /// In en, this message translates to:
  /// **'Pose'**
  String get categoryPose;

  /// No description provided for @categorySkin.
  ///
  /// In en, this message translates to:
  /// **'Skin'**
  String get categorySkin;

  /// No description provided for @categoryHair.
  ///
  /// In en, this message translates to:
  /// **'Hair'**
  String get categoryHair;

  /// No description provided for @categoryTextures.
  ///
  /// In en, this message translates to:
  /// **'Textures'**
  String get categoryTextures;

  /// No description provided for @categoryPlugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get categoryPlugins;

  /// No description provided for @categoryScripts.
  ///
  /// In en, this message translates to:
  /// **'Scripts'**
  String get categoryScripts;

  /// No description provided for @categorySubScene.
  ///
  /// In en, this message translates to:
  /// **'SubScene'**
  String get categorySubScene;

  /// No description provided for @categoryAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get categoryAppearance;

  /// No description provided for @categoryBreast.
  ///
  /// In en, this message translates to:
  /// **'Breast'**
  String get categoryBreast;

  /// No description provided for @categoryGlute.
  ///
  /// In en, this message translates to:
  /// **'Glute'**
  String get categoryGlute;

  /// No description provided for @clickVarToLoadPreviews.
  ///
  /// In en, this message translates to:
  /// **'Click on a var to load previews'**
  String get clickVarToLoadPreviews;

  /// No description provided for @noPreviewEntriesForVar.
  ///
  /// In en, this message translates to:
  /// **'No preview entries for selected var'**
  String get noPreviewEntriesForVar;

  /// No description provided for @previewLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Preview load failed: {error}'**
  String previewLoadFailed(Object error);

  /// No description provided for @allTypesLabel.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get allTypesLabel;

  /// No description provided for @loadableLabel.
  ///
  /// In en, this message translates to:
  /// **'Loadable'**
  String get loadableLabel;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'Items {count}'**
  String itemsCount(Object count);

  /// No description provided for @itemPosition.
  ///
  /// In en, this message translates to:
  /// **'Item {current}/{total}'**
  String itemPosition(Object current, Object total);

  /// No description provided for @noPreviewsAfterFilters.
  ///
  /// In en, this message translates to:
  /// **'No previews after filters'**
  String get noPreviewsAfterFilters;

  /// No description provided for @selectPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Select a preview'**
  String get selectPreviewHint;

  /// No description provided for @installVarTitle.
  ///
  /// In en, this message translates to:
  /// **'Install Var'**
  String get installVarTitle;

  /// No description provided for @installVarConfirm.
  ///
  /// In en, this message translates to:
  /// **'{varName} will be installed. Continue?'**
  String installVarConfirm(Object varName);

  /// No description provided for @installLabel.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get installLabel;

  /// No description provided for @uninstallLabel.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get uninstallLabel;

  /// No description provided for @missingDependenciesTitle.
  ///
  /// In en, this message translates to:
  /// **'Missing Dependencies'**
  String get missingDependenciesTitle;

  /// No description provided for @ignoreVersionMismatch.
  ///
  /// In en, this message translates to:
  /// **'Ignore version mismatch'**
  String get ignoreVersionMismatch;

  /// No description provided for @allMissingVars.
  ///
  /// In en, this message translates to:
  /// **'All missing vars'**
  String get allMissingVars;

  /// No description provided for @includeLinkedLabel.
  ///
  /// In en, this message translates to:
  /// **'Include Linked'**
  String get includeLinkedLabel;

  /// No description provided for @includeLinkedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show entries that already have link substitutions.'**
  String get includeLinkedTooltip;

  /// No description provided for @rowPosition.
  ///
  /// In en, this message translates to:
  /// **'Row {current} / {total}'**
  String rowPosition(Object current, Object total);

  /// No description provided for @appliedCount.
  ///
  /// In en, this message translates to:
  /// **'Applied {count}'**
  String appliedCount(Object count);

  /// No description provided for @draftCount.
  ///
  /// In en, this message translates to:
  /// **'Draft {count}'**
  String draftCount(Object count);

  /// No description provided for @brokenCount.
  ///
  /// In en, this message translates to:
  /// **'Broken {count}'**
  String brokenCount(Object count);

  /// No description provided for @missingVarHeader.
  ///
  /// In en, this message translates to:
  /// **'Missing Var'**
  String get missingVarHeader;

  /// No description provided for @substituteHeader.
  ///
  /// In en, this message translates to:
  /// **'Substitute'**
  String get substituteHeader;

  /// No description provided for @downloadHeaderShort.
  ///
  /// In en, this message translates to:
  /// **'DL'**
  String get downloadHeaderShort;

  /// No description provided for @detailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get detailsTitle;

  /// No description provided for @selectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected: {value}'**
  String selectedLabel(Object value);

  /// No description provided for @resolvedLabel.
  ///
  /// In en, this message translates to:
  /// **'Resolved: {value}'**
  String resolvedLabel(Object value);

  /// No description provided for @downloadLabel.
  ///
  /// In en, this message translates to:
  /// **'Download: {value}'**
  String downloadLabel(Object value);

  /// No description provided for @linkStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Link status: {value}'**
  String linkStatusLabel(Object value);

  /// No description provided for @linkSubstitutionTitle.
  ///
  /// In en, this message translates to:
  /// **'Link Substitution'**
  String get linkSubstitutionTitle;

  /// No description provided for @linkSubstitutionDescription.
  ///
  /// In en, this message translates to:
  /// **'Links create symlinks in ___MissingVarLink___ to substitute missing dependencies.'**
  String get linkSubstitutionDescription;

  /// No description provided for @appliedLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Applied: {value}'**
  String appliedLinkLabel(Object value);

  /// No description provided for @draftLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Draft: {value}'**
  String draftLinkLabel(Object value);

  /// No description provided for @suggestionLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggestion: {value}'**
  String suggestionLabel(Object value);

  /// No description provided for @useSuggestionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Use suggested resolved var as draft link.'**
  String get useSuggestionTooltip;

  /// No description provided for @findTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Find target'**
  String get findTargetLabel;

  /// No description provided for @pickTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Pick target'**
  String get pickTargetLabel;

  /// No description provided for @limitSamePackageLabel.
  ///
  /// In en, this message translates to:
  /// **'Limit to same creator/package'**
  String get limitSamePackageLabel;

  /// No description provided for @limitSamePackageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Limit picker to same creator/package as missing var.'**
  String get limitSamePackageTooltip;

  /// No description provided for @targetVarLabel.
  ///
  /// In en, this message translates to:
  /// **'Target Var'**
  String get targetVarLabel;

  /// No description provided for @setDraftLabel.
  ///
  /// In en, this message translates to:
  /// **'Set Draft'**
  String get setDraftLabel;

  /// No description provided for @setDraftTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save draft link for selected missing var.'**
  String get setDraftTooltip;

  /// No description provided for @clearDraftLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear Draft'**
  String get clearDraftLabel;

  /// No description provided for @clearDraftTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear draft link for selected var (will remove).'**
  String get clearDraftTooltip;

  /// No description provided for @revertDraftLabel.
  ///
  /// In en, this message translates to:
  /// **'Revert Draft'**
  String get revertDraftLabel;

  /// No description provided for @revertDraftTooltip.
  ///
  /// In en, this message translates to:
  /// **'Revert draft to currently applied link.'**
  String get revertDraftTooltip;

  /// No description provided for @applyToPackageLabel.
  ///
  /// In en, this message translates to:
  /// **'Apply to Package'**
  String get applyToPackageLabel;

  /// No description provided for @applyToPackageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Apply draft target to all missing vars in same package.'**
  String get applyToPackageTooltip;

  /// No description provided for @autoFillResolvedLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto-fill Resolved'**
  String get autoFillResolvedLabel;

  /// No description provided for @autoFillResolvedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Fill drafts using best resolved matches.'**
  String get autoFillResolvedTooltip;

  /// No description provided for @applyLinkChangesLabel.
  ///
  /// In en, this message translates to:
  /// **'Apply Link Changes'**
  String get applyLinkChangesLabel;

  /// No description provided for @applyLinkChangesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create/update/remove symlinks from draft changes.'**
  String get applyLinkChangesTooltip;

  /// No description provided for @saveMapLabel.
  ///
  /// In en, this message translates to:
  /// **'Save Map'**
  String get saveMapLabel;

  /// No description provided for @saveMapTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save current effective map to a text file.'**
  String get saveMapTooltip;

  /// No description provided for @loadMapLabel.
  ///
  /// In en, this message translates to:
  /// **'Load Map'**
  String get loadMapLabel;

  /// No description provided for @loadMapTooltip.
  ///
  /// In en, this message translates to:
  /// **'Load a map file as drafts for this list.'**
  String get loadMapTooltip;

  /// No description provided for @discardDraftsLabel.
  ///
  /// In en, this message translates to:
  /// **'Discard Drafts'**
  String get discardDraftsLabel;

  /// No description provided for @discardDraftsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Discard all draft changes.'**
  String get discardDraftsTooltip;

  /// No description provided for @googleSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Google Search'**
  String get googleSearchLabel;

  /// No description provided for @googleSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search the missing var on the web.'**
  String get googleSearchTooltip;

  /// No description provided for @fetchHubLinksLabel.
  ///
  /// In en, this message translates to:
  /// **'Fetch Hub Links'**
  String get fetchHubLinksLabel;

  /// No description provided for @fetchHubLinksTooltip.
  ///
  /// In en, this message translates to:
  /// **'Query hub for download links for missing vars.'**
  String get fetchHubLinksTooltip;

  /// No description provided for @downloadSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Download Selected'**
  String get downloadSelectedLabel;

  /// No description provided for @downloadSelectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Download link for selected missing var if available.'**
  String get downloadSelectedTooltip;

  /// No description provided for @downloadAllLabel.
  ///
  /// In en, this message translates to:
  /// **'Download All'**
  String get downloadAllLabel;

  /// No description provided for @downloadAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'Queue downloads for all missing vars with links.'**
  String get downloadAllTooltip;

  /// No description provided for @dependentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Dependents'**
  String get dependentsTitle;

  /// No description provided for @noDependents.
  ///
  /// In en, this message translates to:
  /// **'No dependents'**
  String get noDependents;

  /// No description provided for @dependentSavesTitle.
  ///
  /// In en, this message translates to:
  /// **'Dependent Saves'**
  String get dependentSavesTitle;

  /// No description provided for @noDependentSaves.
  ///
  /// In en, this message translates to:
  /// **'No dependent saves'**
  String get noDependentSaves;

  /// No description provided for @linkStatusBroken.
  ///
  /// In en, this message translates to:
  /// **'Broken link'**
  String get linkStatusBroken;

  /// No description provided for @linkStatusRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get linkStatusRemove;

  /// No description provided for @linkStatusClear.
  ///
  /// In en, this message translates to:
  /// **'Clear link'**
  String get linkStatusClear;

  /// No description provided for @linkStatusNew.
  ///
  /// In en, this message translates to:
  /// **'New link'**
  String get linkStatusNew;

  /// No description provided for @linkStatusLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get linkStatusLinked;

  /// No description provided for @linkStatusChanged.
  ///
  /// In en, this message translates to:
  /// **'Link changed'**
  String get linkStatusChanged;

  /// No description provided for @linkStatusNotLinked.
  ///
  /// In en, this message translates to:
  /// **'Not linked'**
  String get linkStatusNotLinked;

  /// No description provided for @downloadStatusDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get downloadStatusDirect;

  /// No description provided for @downloadStatusNoVersion.
  ///
  /// In en, this message translates to:
  /// **'No Version'**
  String get downloadStatusNoVersion;

  /// No description provided for @downloadStatusNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get downloadStatusNone;

  /// No description provided for @missingSelectFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a missing var first.'**
  String get missingSelectFirst;

  /// No description provided for @missingFetchHubLinksFirst.
  ///
  /// In en, this message translates to:
  /// **'Please click \"Fetch Hub Links\" first to get download URLs.'**
  String get missingFetchHubLinksFirst;

  /// No description provided for @missingNoDownloadUrlForSelected.
  ///
  /// In en, this message translates to:
  /// **'No download URL available for the selected var.'**
  String get missingNoDownloadUrlForSelected;

  /// No description provided for @missingAddedDownload.
  ///
  /// In en, this message translates to:
  /// **'Added 1 download.'**
  String get missingAddedDownload;

  /// No description provided for @missingNoDownloadUrlsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No download URLs available.'**
  String get missingNoDownloadUrlsAvailable;

  /// No description provided for @missingAddedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Added {count} downloads.'**
  String missingAddedDownloads(Object count);

  /// No description provided for @linkChangesApplied.
  ///
  /// In en, this message translates to:
  /// **'Link changes applied: {total} total, {created} created, {skipped} skipped, {failed} failed.'**
  String linkChangesApplied(
    Object total,
    Object created,
    Object skipped,
    Object failed,
  );

  /// No description provided for @missingStatus.
  ///
  /// In en, this message translates to:
  /// **'missing'**
  String get missingStatus;

  /// No description provided for @closestMatch.
  ///
  /// In en, this message translates to:
  /// **'{name} (closest)'**
  String closestMatch(Object name);

  /// No description provided for @draftClearLabel.
  ///
  /// In en, this message translates to:
  /// **'(clear)'**
  String get draftClearLabel;

  /// No description provided for @textFileTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get textFileTypeLabel;

  /// No description provided for @varDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details: {varName}'**
  String varDetailsTitle(Object varName);

  /// No description provided for @filterByCreator.
  ///
  /// In en, this message translates to:
  /// **'Filter by Creator'**
  String get filterByCreator;

  /// No description provided for @missingDeps.
  ///
  /// In en, this message translates to:
  /// **'Missing Deps'**
  String get missingDeps;

  /// No description provided for @dependenciesTitle.
  ///
  /// In en, this message translates to:
  /// **'Dependencies'**
  String get dependenciesTitle;

  /// No description provided for @saveDependenciesTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Dependencies'**
  String get saveDependenciesTitle;

  /// No description provided for @previewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Previews'**
  String get previewsTitle;

  /// No description provided for @noPreviews.
  ///
  /// In en, this message translates to:
  /// **'No previews'**
  String get noPreviews;

  /// No description provided for @previewTitleWithType.
  ///
  /// In en, this message translates to:
  /// **'{title} ({type})'**
  String previewTitleWithType(Object title, Object type);

  /// No description provided for @totalCount.
  ///
  /// In en, this message translates to:
  /// **'Total {count}'**
  String totalCount(Object count);

  /// No description provided for @nameFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Name filter'**
  String get nameFilterLabel;

  /// No description provided for @sortNewToOld.
  ///
  /// In en, this message translates to:
  /// **'New to Old'**
  String get sortNewToOld;

  /// No description provided for @sortSceneName.
  ///
  /// In en, this message translates to:
  /// **'SceneName'**
  String get sortSceneName;

  /// No description provided for @columnsLabel.
  ///
  /// In en, this message translates to:
  /// **'Columns:'**
  String get columnsLabel;

  /// No description provided for @columnHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get columnHide;

  /// No description provided for @columnNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get columnNormal;

  /// No description provided for @columnFav.
  ///
  /// In en, this message translates to:
  /// **'Fav'**
  String get columnFav;

  /// No description provided for @mergeLabel.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get mergeLabel;

  /// No description provided for @forMaleLabel.
  ///
  /// In en, this message translates to:
  /// **'For Male'**
  String get forMaleLabel;

  /// No description provided for @hideLabel.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hideLabel;

  /// No description provided for @unhideLabel.
  ///
  /// In en, this message translates to:
  /// **'Unhide'**
  String get unhideLabel;

  /// No description provided for @favLabel.
  ///
  /// In en, this message translates to:
  /// **'Fav'**
  String get favLabel;

  /// No description provided for @unfavLabel.
  ///
  /// In en, this message translates to:
  /// **'Unfav'**
  String get unfavLabel;

  /// No description provided for @columnTitleWithCount.
  ///
  /// In en, this message translates to:
  /// **'{title} ({count})'**
  String columnTitleWithCount(Object count, Object title);

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @locationInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get locationInstalled;

  /// No description provided for @locationNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get locationNotInstalled;

  /// No description provided for @locationMissingLink.
  ///
  /// In en, this message translates to:
  /// **'MissingLink'**
  String get locationMissingLink;

  /// No description provided for @locationSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get locationSave;

  /// No description provided for @clearCacheLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCacheLabel;

  /// No description provided for @personLabel.
  ///
  /// In en, this message translates to:
  /// **'Person {value}'**
  String personLabel(Object value);

  /// No description provided for @uninstallPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Uninstall Preview'**
  String get uninstallPreviewTitle;

  /// No description provided for @uninstallPackageCount.
  ///
  /// In en, this message translates to:
  /// **'Will uninstall {count} packages'**
  String uninstallPackageCount(Object count);

  /// No description provided for @uninstallTagRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get uninstallTagRequested;

  /// No description provided for @uninstallTagImplicated.
  ///
  /// In en, this message translates to:
  /// **'Implicated'**
  String get uninstallTagImplicated;

  /// No description provided for @previewsCount.
  ///
  /// In en, this message translates to:
  /// **'Previews ({count})'**
  String previewsCount(Object count);

  /// No description provided for @dependenciesCount.
  ///
  /// In en, this message translates to:
  /// **'Dependencies ({count})'**
  String dependenciesCount(Object count);

  /// No description provided for @noDependencies.
  ///
  /// In en, this message translates to:
  /// **'No dependencies'**
  String get noDependencies;

  /// No description provided for @prepareSavesTitle.
  ///
  /// In en, this message translates to:
  /// **'Prepare Saves'**
  String get prepareSavesTitle;

  /// No description provided for @outputFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Output folder'**
  String get outputFolderLabel;

  /// No description provided for @outputFolderReady.
  ///
  /// In en, this message translates to:
  /// **'Output folder is ready.'**
  String get outputFolderReady;

  /// No description provided for @outputFolderValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Output folder validation failed.'**
  String get outputFolderValidationFailed;

  /// No description provided for @validateOutputLabel.
  ///
  /// In en, this message translates to:
  /// **'Validate Output'**
  String get validateOutputLabel;

  /// No description provided for @savesTreeTitle.
  ///
  /// In en, this message translates to:
  /// **'Saves Tree'**
  String get savesTreeTitle;

  /// No description provided for @noSavesFound.
  ///
  /// In en, this message translates to:
  /// **'No saves found'**
  String get noSavesFound;

  /// No description provided for @selectedFilesCount.
  ///
  /// In en, this message translates to:
  /// **'Selected {count} files'**
  String selectedFilesCount(Object count);

  /// No description provided for @filtersActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters & Actions'**
  String get filtersActionsTitle;

  /// No description provided for @basicFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Basic Filters'**
  String get basicFiltersTitle;

  /// No description provided for @advancedFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced Filters'**
  String get advancedFiltersTitle;

  /// No description provided for @sortOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort Options'**
  String get sortOptionsTitle;

  /// No description provided for @allLocationsLabel.
  ///
  /// In en, this message translates to:
  /// **'All locations'**
  String get allLocationsLabel;

  /// No description provided for @allPayTypesLabel.
  ///
  /// In en, this message translates to:
  /// **'All pay types'**
  String get allPayTypesLabel;

  /// No description provided for @payTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Pay Type'**
  String get payTypeLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @tagLabel.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get tagLabel;

  /// No description provided for @allTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'All tags'**
  String get allTagsLabel;

  /// No description provided for @primarySortLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary Sort'**
  String get primarySortLabel;

  /// No description provided for @secondarySortLabel.
  ///
  /// In en, this message translates to:
  /// **'Secondary Sort'**
  String get secondarySortLabel;

  /// No description provided for @noSortOptions.
  ///
  /// In en, this message translates to:
  /// **'No sort options available'**
  String get noSortOptions;

  /// No description provided for @loadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loadingLabel;

  /// No description provided for @noSecondarySort.
  ///
  /// In en, this message translates to:
  /// **'No secondary sort'**
  String get noSecondarySort;

  /// No description provided for @scanMissingLabel.
  ///
  /// In en, this message translates to:
  /// **'Scan Missing'**
  String get scanMissingLabel;

  /// No description provided for @scanUpdatesLabel.
  ///
  /// In en, this message translates to:
  /// **'Scan Updates'**
  String get scanUpdatesLabel;

  /// No description provided for @downloadListTitle.
  ///
  /// In en, this message translates to:
  /// **'Download List'**
  String get downloadListTitle;

  /// No description provided for @totalLinksSize.
  ///
  /// In en, this message translates to:
  /// **'Total {count} links, Total {sizeLabel}'**
  String totalLinksSize(Object count, Object sizeLabel);

  /// No description provided for @addedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Added {count} downloads.'**
  String addedDownloads(Object count);

  /// No description provided for @copyLinksLabel.
  ///
  /// In en, this message translates to:
  /// **'Copy Links'**
  String get copyLinksLabel;

  /// No description provided for @clearListLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear List'**
  String get clearListLabel;

  /// No description provided for @resourcesCount.
  ///
  /// In en, this message translates to:
  /// **'Resources ({count})'**
  String resourcesCount(Object count);

  /// No description provided for @ratingDownloads.
  ///
  /// In en, this message translates to:
  /// **'Rating {avg} ({count}) | {downloads} downloads'**
  String ratingDownloads(Object avg, Object count, Object downloads);

  /// No description provided for @updatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String updatedLabel(Object date);

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(Object version);

  /// No description provided for @depsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Deps {count}'**
  String depsCountLabel(Object count);

  /// No description provided for @extraTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'+{count}'**
  String extraTagsLabel(Object count);

  /// No description provided for @repoStatusGoToDownload.
  ///
  /// In en, this message translates to:
  /// **'Go To Download'**
  String get repoStatusGoToDownload;

  /// No description provided for @repoStatusGenerateDownloadList.
  ///
  /// In en, this message translates to:
  /// **'Generate Download List'**
  String get repoStatusGenerateDownloadList;

  /// No description provided for @repoStatusInRepository.
  ///
  /// In en, this message translates to:
  /// **'In Repository'**
  String get repoStatusInRepository;

  /// No description provided for @repoStatusUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade {installedVersion} to {hubVersion}'**
  String repoStatusUpgrade(Object installedVersion, Object hubVersion);

  /// No description provided for @unknownStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Unknown Status'**
  String get unknownStatusLabel;

  /// No description provided for @untitledLabel.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitledLabel;

  /// No description provided for @unknownLabel.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get unknownLabel;

  /// No description provided for @detailLabel.
  ///
  /// In en, this message translates to:
  /// **'Detail'**
  String get detailLabel;

  /// No description provided for @addFilesOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Add Files Only'**
  String get addFilesOnlyLabel;

  /// No description provided for @addWithDependenciesLabel.
  ///
  /// In en, this message translates to:
  /// **'Add With Dependencies'**
  String get addWithDependenciesLabel;

  /// No description provided for @openPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Open Page'**
  String get openPageLabel;

  /// No description provided for @basicInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get basicInfoTitle;

  /// No description provided for @loadingDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading detailed information...'**
  String get loadingDetailsLabel;

  /// No description provided for @loadDetailsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load details: {error}'**
  String loadDetailsFailed(Object error);

  /// No description provided for @descriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionTitle;

  /// No description provided for @imagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get imagesTitle;

  /// No description provided for @sceneAnalysisTitle.
  ///
  /// In en, this message translates to:
  /// **'Scene Analysis'**
  String get sceneAnalysisTitle;

  /// No description provided for @analysisLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load analysis summary'**
  String get analysisLoadFailed;

  /// No description provided for @entryLabel.
  ///
  /// In en, this message translates to:
  /// **'Entry: {entry}'**
  String entryLabel(Object entry);

  /// No description provided for @genderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderLabel;

  /// No description provided for @personsLabel.
  ///
  /// In en, this message translates to:
  /// **'Persons'**
  String get personsLabel;

  /// No description provided for @atomsLabel.
  ///
  /// In en, this message translates to:
  /// **'Atoms'**
  String get atomsLabel;

  /// No description provided for @depsLabel.
  ///
  /// In en, this message translates to:
  /// **'Deps'**
  String get depsLabel;

  /// No description provided for @missingLabel.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get missingLabel;

  /// No description provided for @mismatchLabel.
  ///
  /// In en, this message translates to:
  /// **'Mismatch'**
  String get mismatchLabel;

  /// No description provided for @peopleTitle.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get peopleTitle;

  /// No description provided for @atomsTitle.
  ///
  /// In en, this message translates to:
  /// **'Atoms'**
  String get atomsTitle;

  /// No description provided for @noPersonAtomsFound.
  ///
  /// In en, this message translates to:
  /// **'No person atoms found'**
  String get noPersonAtomsFound;

  /// No description provided for @poseTag.
  ///
  /// In en, this message translates to:
  /// **'Pose'**
  String get poseTag;

  /// No description provided for @animationTag.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get animationTag;

  /// No description provided for @pluginTag.
  ///
  /// In en, this message translates to:
  /// **'Plugin'**
  String get pluginTag;

  /// No description provided for @presetsActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Presets & Actions'**
  String get presetsActionsTitle;

  /// No description provided for @lookOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Look Options'**
  String get lookOptionsTitle;

  /// No description provided for @loadLookLabel.
  ///
  /// In en, this message translates to:
  /// **'Load Look'**
  String get loadLookLabel;

  /// No description provided for @loadPoseLabel.
  ///
  /// In en, this message translates to:
  /// **'Load Pose'**
  String get loadPoseLabel;

  /// No description provided for @loadAnimationLabel.
  ///
  /// In en, this message translates to:
  /// **'Load Animation'**
  String get loadAnimationLabel;

  /// No description provided for @loadPluginLabel.
  ///
  /// In en, this message translates to:
  /// **'Load Plugin'**
  String get loadPluginLabel;

  /// No description provided for @posePresetHint.
  ///
  /// In en, this message translates to:
  /// **'Pose presets require .json scene entries.'**
  String get posePresetHint;

  /// No description provided for @atomSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Atom Search'**
  String get atomSearchTitle;

  /// No description provided for @filterAtomsHint.
  ///
  /// In en, this message translates to:
  /// **'Filter atoms by name'**
  String get filterAtomsHint;

  /// No description provided for @selectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Selection'**
  String get selectionTitle;

  /// No description provided for @selectedAtomsCount.
  ///
  /// In en, this message translates to:
  /// **'Selected {count} atoms'**
  String selectedAtomsCount(Object count);

  /// No description provided for @selectBaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Select Base'**
  String get selectBaseLabel;

  /// No description provided for @selectTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Select Type'**
  String get selectTypeLabel;

  /// No description provided for @selectTypeWithCount.
  ///
  /// In en, this message translates to:
  /// **'Select {type} ({count})'**
  String selectTypeWithCount(Object type, Object count);

  /// No description provided for @includeBaseAtomsLabel.
  ///
  /// In en, this message translates to:
  /// **'Include base atoms'**
  String get includeBaseAtomsLabel;

  /// No description provided for @atomTreeTitle.
  ///
  /// In en, this message translates to:
  /// **'Atom Tree'**
  String get atomTreeTitle;

  /// No description provided for @noAtomsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No atoms available'**
  String get noAtomsAvailable;

  /// No description provided for @sceneActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Scene Actions'**
  String get sceneActionsTitle;

  /// No description provided for @loadSceneLabel.
  ///
  /// In en, this message translates to:
  /// **'Load Scene'**
  String get loadSceneLabel;

  /// No description provided for @addToSceneLabel.
  ///
  /// In en, this message translates to:
  /// **'Add To Scene'**
  String get addToSceneLabel;

  /// No description provided for @addAsSubsceneLabel.
  ///
  /// In en, this message translates to:
  /// **'Add as Subscene'**
  String get addAsSubsceneLabel;

  /// No description provided for @dependencySearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Dependency Search'**
  String get dependencySearchTitle;

  /// No description provided for @filterDependenciesHint.
  ///
  /// In en, this message translates to:
  /// **'Filter dependencies'**
  String get filterDependenciesHint;

  /// No description provided for @filtersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filtersTitle;

  /// No description provided for @filterAllLabel.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAllLabel;

  /// No description provided for @filterMissingLabel.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get filterMissingLabel;

  /// No description provided for @filterMismatchLabel.
  ///
  /// In en, this message translates to:
  /// **'Mismatch'**
  String get filterMismatchLabel;

  /// No description provided for @filterResolvedLabel.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get filterResolvedLabel;

  /// No description provided for @filterInstalledLabel.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get filterInstalledLabel;

  /// No description provided for @missingDepsCopied.
  ///
  /// In en, this message translates to:
  /// **'Missing deps copied'**
  String get missingDepsCopied;

  /// No description provided for @copyMissingLabel.
  ///
  /// In en, this message translates to:
  /// **'Copy Missing'**
  String get copyMissingLabel;

  /// No description provided for @noDependenciesMatch.
  ///
  /// In en, this message translates to:
  /// **'No dependencies match'**
  String get noDependenciesMatch;

  /// No description provided for @presetTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Preset Target'**
  String get presetTargetTitle;

  /// No description provided for @ignoreGenderLabel.
  ///
  /// In en, this message translates to:
  /// **'Ignore Gender'**
  String get ignoreGenderLabel;

  /// No description provided for @ignoreGenderHint.
  ///
  /// In en, this message translates to:
  /// **'Applies to person presets only. Atom actions ignore this.'**
  String get ignoreGenderHint;

  /// No description provided for @labelValue.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String labelValue(Object label, Object value);

  /// No description provided for @pageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {current}/{total}'**
  String pageOf(Object current, Object total);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
