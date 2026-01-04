using SimpleJSON;
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Windows.Forms;
using varManager.Backend;
using varManager.Properties;
using static SimpleLogger;

namespace varManager
{
    public partial class FormHub : Form
    {
        private static SimpleLogger simpLog = new SimpleLogger();
        public Form1 form1;
        private static HttpClient httpClient;
        private static CancellationToken cancellationToken;
        private List<string> listPayType, listLocation, listSort, listTags, listCategory, listCreator;
        private bool downlistHide = true;
        Dictionary<string, string> downloadUrls = new Dictionary<string, string>();
        private readonly Dictionary<string, string> downloadUrlsByUrl = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        private bool refreshInProgress;
        private bool refreshQueued;
        private bool refreshQueuedGenePages;
        private string? lastQuerySignature;
        private const int intPerPage = 48;
        private InvokeAddLoglist addlog;
        static string vam_download_exe = "vam_downloader.exe";
        static string vam_download_path = Path.Combine(".\\plugin\\", vam_download_exe);
        static string vam_download_save_path = Path.Combine(Settings.Default.vampath, "AddonPackages");

        private void LogBackendLine(string line)
        {
            if (string.IsNullOrWhiteSpace(line))
            {
                return;
            }
            string msg = line.Trim();
            LogLevel level = LogLevel.INFO;
            if (msg.StartsWith("error:", StringComparison.OrdinalIgnoreCase))
            {
                level = LogLevel.ERROR;
                msg = msg.Substring("error:".Length).TrimStart();
            }
            else if (msg.StartsWith("debug:", StringComparison.OrdinalIgnoreCase))
            {
                level = LogLevel.DEBUG;
                msg = msg.Substring("debug:".Length).TrimStart();
            }
            BeginInvoke(addlog, new Object[] { msg, level });
        }

        private void LogDebug(string message)
        {
            LogBackendLine($"debug: {message}");
        }

        private static bool IsVersionedVarName(string name)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                return false;
            }
            string[] parts = name.Split('.');
            if (parts.Length < 3)
            {
                return false;
            }
            return int.TryParse(parts[parts.Length - 1], out _);
        }

        private void AddDownloadUrl(string varName, string url)
        {
            if (string.IsNullOrWhiteSpace(varName) || string.IsNullOrWhiteSpace(url))
            {
                return;
            }
            if (downloadUrls.TryGetValue(varName, out var existingUrl) &&
                !string.Equals(existingUrl, url, StringComparison.OrdinalIgnoreCase))
            {
                downloadUrlsByUrl.Remove(existingUrl);
            }
            if (downloadUrlsByUrl.TryGetValue(url, out var existingName))
            {
                if (string.Equals(existingName, varName, StringComparison.OrdinalIgnoreCase))
                {
                    downloadUrls[varName] = url;
                    return;
                }
                bool existingVersioned = IsVersionedVarName(existingName);
                bool newVersioned = IsVersionedVarName(varName);
                if (newVersioned && !existingVersioned)
                {
                    downloadUrls.Remove(existingName);
                    downloadUrls[varName] = url;
                    downloadUrlsByUrl[url] = varName;
                }
                return;
            }
            downloadUrls[varName] = url;
            downloadUrlsByUrl[url] = varName;
        }

        private void NormalizeDownloadUrls()
        {
            var source = downloadUrls;
            downloadUrls = new Dictionary<string, string>();
            downloadUrlsByUrl.Clear();
            foreach (var kvp in source)
            {
                AddDownloadUrl(kvp.Key, kvp.Value);
            }
        }

        private static string? NormalizeFilter(string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                return null;
            }
            string trimmed = value.Trim();
            if (trimmed.Equals("All", StringComparison.OrdinalIgnoreCase))
            {
                return null;
            }
            return trimmed;
        }

        private static string BuildQuerySignature(
            int perpage,
            string? location,
            string? paytype,
            string? category,
            string? username,
            string? tags,
            string? search,
            string? sort,
            int page)
        {
            return string.Join("|", perpage,
                location ?? string.Empty,
                paytype ?? string.Empty,
                category ?? string.Empty,
                username ?? string.Empty,
                tags ?? string.Empty,
                search ?? string.Empty,
                sort ?? string.Empty,
                page);
        }

        private static string TrimForLog(string value, int maxLength)
        {
            if (string.IsNullOrEmpty(value))
            {
                return string.Empty;
            }
            if (value.Length <= maxLength)
            {
                return value;
            }
            return value.Substring(0, maxLength) + "...";
        }

        private Task<BackendJobResult> RunBackendJobAsync(string kind, object? args)
        {
            return BackendSession.RunJobAsync(kind, args, LogBackendLine, CancellationToken.None);
        }

        private BackendJobResult RunBackendJob(string kind, object? args)
        {
            return BackendSession.RunJob(kind, args, LogBackendLine, CancellationToken.None);
        }

        private T? DeserializeResult<T>(BackendJobResult result)
        {
            if (!result.Result.HasValue)
            {
                return default;
            }
            return JsonSerializer.Deserialize<T>(result.Result.Value.GetRawText());
        }

        private sealed class HubDownloadList
        {
            [JsonPropertyName("download_urls")]
            public Dictionary<string, string> DownloadUrls { get; set; } = new Dictionary<string, string>();

            [JsonPropertyName("download_urls_no_version")]
            public Dictionary<string, string> DownloadUrlsNoVersion { get; set; } = new Dictionary<string, string>();
        }
        
        public FormHub()
        {
            InitializeComponent();
            addlog = new InvokeAddLoglist(UpdateAddLoglist);
            httpClient = new HttpClient();
            cancellationToken = new CancellationToken();
        }
        private void buttonScanHub_Click(object sender, EventArgs e)
        {
            string message = "Scan hub for missing Depends from All organized vars. A download link list that will be generated. You must be logged in at hub.virtamate.com before you can download these links, It is recommended to use Chrono for Chrome to download.";

            const string caption = "AllMissingDepends";
            var result = MessageBox.Show(message, caption,
                                         MessageBoxButtons.YesNo,
                                         MessageBoxIcon.Question,
                                         MessageBoxDefaultButton.Button1);
            if (result == DialogResult.Yes)
            {
                AllMissingDepends();
            }
        }
        public delegate void InvokeAddLoglist(string message, LogLevel logLevel);

        public void UpdateAddLoglist(string message, LogLevel logLevel)
        {
            string msg = simpLog.WriteFormattedLog(logLevel, message);
            listBoxLog.Items.Add(msg);
            listBoxLog.TopIndex = listBoxLog.Items.Count - 1;
        }
        private async void AllMissingDepends()
        {
            this.BeginInvoke(addlog, new Object[] { "Search for dependencies...", LogLevel.INFO });
            try
            {
                var result = await RunBackendJobAsync("hub_missing_scan", null);
                var payload = DeserializeResult<HubDownloadList>(result);
                downloadUrls = payload?.DownloadUrls ?? new Dictionary<string, string>();
                if (payload != null)
                {
                    foreach (var kvp in payload.DownloadUrlsNoVersion)
                    {
                        if (!downloadUrls.ContainsKey(kvp.Key))
                        {
                            downloadUrls[kvp.Key] = kvp.Value;
                        }
                    }
                }
                NormalizeDownloadUrls();
                if (form1 != null)
                {
                    downloadUrls = downloadUrls
                        .Where(kvp => !form1.FindByvarName(kvp.Key))
                        .ToDictionary(kvp => kvp.Key, kvp => kvp.Value);
                    NormalizeDownloadUrls();
                }

                if (downloadUrls.Count > 0)
                {
                    this.BeginInvoke(addlog, new Object[] { $"Total {downloadUrls.Count} download links found", LogLevel.INFO });
                    ShowDownList();
                    DrawDownloadListView();
                }
                else
                {
                    this.BeginInvoke(addlog, new Object[] { "No download link found", LogLevel.INFO });
                }
            }
            catch (Exception ex)
            {
                this.BeginInvoke(addlog, new Object[] { $"Hub scan failed: {ex.Message}", LogLevel.ERROR });
            }
        }

        private void DrawDownloadListView()
        {
            listViewDownList.Items.Clear();
            foreach (var varname in downloadUrls.Keys)
            {
                ListViewItem downloaditem = new ListViewItem();
                downloaditem.Text = varname;
                downloaditem.SubItems.Add(downloadUrls[varname]);
                listViewDownList.Items.Add(downloaditem);
            }
        }

        private static async Task<string> FindPackages(string packages)
        {
            string url = "https://hub.virtamate.com/citizenx/api.php";
            JSONClass jns = new JSONClass();
            jns.Add("source", "VaM");
            jns.Add("action", "findPackages");
            jns.Add("packages", packages);
            var data = new StringContent(jns.ToString(), Encoding.UTF8, "application/json");

            using (var client = new HttpClient())
            {
                var response = await client.PostAsync(url, data);
                string reponse = response.Content.ReadAsStringAsync().Result;
                return reponse;
            }
        }

        private async void FormHub_Load(object sender, EventArgs e)
        {
            this.Enabled = false;
            this.UseWaitCursor = true;
            if(!await GetInfoListAsync())
            {
                MessageBox.Show("Error getting HUB information!");
                this.Close();
                return;
            }
            comboBoxHosted.Items.Add("All");
            foreach (string item in listLocation)
            {
                comboBoxHosted.Items.Add(item);
            }

            comboBoxPayType.Items.Add("All");
            foreach (string item in listPayType)
            {
                comboBoxPayType.Items.Add(item);
            }


            comboBoxCategory.Items.Add("All");
            foreach (string item in listCategory)
            {
                comboBoxCategory.Items.Add(item);
            }

            comboBoxCreator.Items.Add("All");
            foreach (string item in listCreator)
            {
                comboBoxCreator.Items.Add(item);
            }

            comboBoxTags.Items.Add("All");
            foreach (string item in listTags)
            {
                comboBoxTags.Items.Add(item);
            }
            foreach (string item in listSort)
            {
                comboBoxPriSort.Items.Add(item);
            }
            comboBoxSecSort.Items.Add("");
            foreach (string item in listSort)
            {
                comboBoxSecSort.Items.Add(item);
            }
            downlistHide = true;
            splitContainer1.SplitterDistance = splitContainer1.Size.Width - 80;
            List<HubItem> items = new List<HubItem>();

            for (int i = 0; i < intPerPage; i++)
            {
                HubItem item = new HubItem();
                item.LogSink = LogBackendLine;
                item.ClickFilter += Item_ClickFilter;
                item.GenLinkList += Item_GenLinkList;
                item.RetPackageName += Item_RetPackageName;


                flowLayoutPanelHubItems.Controls.Add(item);
                items.Add(item);
            }
            ClearFilter();
            this.UseWaitCursor = false;
            this.Enabled = true;
            await GenerateHabItemsAsync(force: true);
            EnableFilterEvent();
            
        }

        private void Item_RetPackageName(object sender, PackageNameEventArgs e)
        {
            form1.SelectVarInList(e.PackageName);
            form1.Activate();
            //form1.LocateVar(e.PackageName);
        }

        private void Item_GenLinkList(object sender, DownloadLinkListEventArgs e)
        {
            foreach (var kvp in e.DownloadLinks)
            {
                string varname = kvp.Key;
                string url = kvp.Value;
                var exitname = form1.VarExistName(varname);
                if (exitname == "missing"|| exitname.EndsWith("$"))
                {
                    AddDownloadUrl(varname, url);
                }
            }
            DrawDownloadListView();
        }

        private void DisableFilterEvent()
        {
            comboBoxHosted.SelectedIndexChanged -= ComboBoxSelectedChanged;
            comboBoxPayType.SelectedIndexChanged -= ComboBoxSelectedChanged;
            comboBoxCategory.SelectedIndexChanged -= ComboBoxSelectedChanged;
            comboBoxCreator.SelectedIndexChanged -= ComboBoxSelectedChanged;
            comboBoxTags.SelectedIndexChanged -= ComboBoxSelectedChanged;
            comboBoxPriSort.SelectedIndexChanged -= ComboBoxSelectedChanged;
            comboBoxSecSort.SelectedIndexChanged -= ComboBoxSelectedChanged;
            comboBoxPages.SelectedIndexChanged -= ComboBoxSelectedChanged;
            textBoxSearch.TextChanged -= ComboBoxSelectedChanged;
        }

        private void EnableFilterEvent()
        {
            comboBoxHosted.SelectedIndexChanged += ComboBoxSelectedChanged;
            comboBoxPayType.SelectedIndexChanged += ComboBoxSelectedChanged;
            comboBoxCategory.SelectedIndexChanged += ComboBoxSelectedChanged;
            comboBoxCreator.SelectedIndexChanged += ComboBoxSelectedChanged;
            comboBoxTags.SelectedIndexChanged += ComboBoxSelectedChanged;
            comboBoxPriSort.SelectedIndexChanged += ComboBoxSelectedChanged;
            comboBoxSecSort.SelectedIndexChanged += ComboBoxSelectedChanged;
            comboBoxPages.SelectedIndexChanged += ComboBoxSelectedChanged;
            textBoxSearch.TextChanged += ComboBoxSelectedChanged;
        }

        private void ClearFilter()
        {
           // if (comboBoxHosted.Items.Contains("Hub And Dependencies"))
           //     comboBoxHosted.SelectedItem = "Hub And Dependencies";
           // else
                comboBoxHosted.SelectedIndex = 0;

            if (comboBoxPayType.Items.Contains("Free"))
                comboBoxPayType.SelectedItem = "Free";
            else
                comboBoxPayType.SelectedIndex = 0;

            comboBoxCategory.SelectedIndex = 0;
            comboBoxCreator.SelectedIndex = 0;
            comboBoxTags.SelectedIndex = 0;
            comboBoxPriSort.SelectedIndex = 0;
            comboBoxSecSort.SelectedIndex = 0;

            textBoxSearch.Text = "Search...";
            textBoxSearch.ForeColor = SystemColors.GrayText;

        }

        private void Item_ClickFilter(object sender, HubItemFilterEventArgs e)
        {
            DisableFilterEvent();
            
            HubItem hubItem = sender as HubItem;
            if (e.FilterType == "category")
            {
                ClearFilter();
                comboBoxPayType.Text = e.PayType;
                comboBoxCategory.Text = e.Category;
            }
            else if (e.FilterType == "creator")
            {
                ClearFilter();
                comboBoxCreator.Text = e.Creator;
            }
            EnableFilterEvent();
            _ = GenerateHabItemsAsync();
        }

        private void ComboBoxSelectedChanged(object sender, EventArgs e)
        {

            if (comboBoxPages == sender)
            {
                _ = GenerateHabItemsAsync(false);
            }
            else
            {
                _ = GenerateHabItemsAsync();
            }
        }

        private async Task GenerateHabItemsAsync(bool genePages = true, bool force = false)
        {
            if (refreshInProgress)
            {
                refreshQueued = true;
                refreshQueuedGenePages = refreshQueuedGenePages || genePages;
                return;
            }
            refreshInProgress = true;
            string location = comboBoxHosted.Text, paytype = comboBoxPayType.Text,
             category = comboBoxCategory.Text, username = comboBoxCreator.Text,
                 tags = comboBoxTags.Text, search = textBoxSearch.Text;
            if(search == "Search...")
            {
                search = "";
            }
            string? locationFilter = NormalizeFilter(location);
            string? paytypeFilter = NormalizeFilter(paytype);
            string? categoryFilter = NormalizeFilter(category);
            string? usernameFilter = NormalizeFilter(username);
            string? tagsFilter = NormalizeFilter(tags);
            string? searchFilter = string.IsNullOrWhiteSpace(search) ? null : search.Trim();
            string sort = comboBoxPriSort.Text;
            if (!string.IsNullOrEmpty(comboBoxSecSort.Text))
                sort = sort + "," + comboBoxSecSort.Text;
            int page = 1;
            if (comboBoxPages.Items.Count > 0)
            {
                if (comboBoxPages.SelectedIndex >= 0)
                    page = comboBoxPages.SelectedIndex + 1;
            }
            string signature = BuildQuerySignature(intPerPage, locationFilter, paytypeFilter, categoryFilter,
                usernameFilter, tagsFilter, searchFilter, sort, page);
            try
            {
                if (!force && signature == lastQuerySignature)
                {
                    return;
                }
                LogDebug($"hub_resources request perpage={intPerPage} location='{locationFilter ?? "<null>"}' paytype='{paytypeFilter ?? "<null>"}' category='{categoryFilter ?? "<null>"}' username='{usernameFilter ?? "<null>"}' tags='{tagsFilter ?? "<null>"}' search='{searchFilter ?? "<null>"}' sort='{sort}' page={page}");
                string response = await GetResourcesAsync(intPerPage, locationFilter, paytypeFilter, categoryFilter, usernameFilter, tagsFilter, searchFilter, sort, page);
                if (string.IsNullOrEmpty(response))
                {
                    LogBackendLine("error: hub_resources returned empty response");
                    return;
                }
                LogDebug($"hub_resources raw length={response.Length}");
                LogDebug($"hub_resources raw preview={TrimForLog(response, 200)}");
                RefreshResource(response, genePages);
                lastQuerySignature = signature;
            }
            catch (Exception ex)
            {
                LogBackendLine($"error: GenerateHabItemsAsync failed: {ex.Message}");
            }
            finally
            {
                refreshInProgress = false;
                if (refreshQueued)
                {
                    bool queuedGenePages = refreshQueuedGenePages;
                    refreshQueued = false;
                    refreshQueuedGenePages = false;
                    await GenerateHabItemsAsync(queuedGenePages);
                }
            }
        }

        private async Task<bool> GetInfoListAsync()
        {
            try
            {
                var result = await RunBackendJobAsync("hub_info", null);
                if (!result.Succeeded)
                {
                    LogBackendLine($"error: hub_info job failed status={result.Job.Status} error={result.Job.Error ?? "unknown"}");
                }
                if (!result.Result.HasValue)
                {
                    LogBackendLine("error: hub_info returned no result");
                    return false;
                }
                string raw = result.Result.Value.GetRawText();
                LogDebug($"hub_info raw length={raw.Length}");
                LogDebug($"hub_info raw preview={TrimForLog(raw, 200)}");
                JSONNode jsonResult = JSON.Parse(raw);

                if (jsonResult == null)
                {
                    LogBackendLine("error: Failed to parse hub_info JSON response");
                    return false;
                }

                JSONArray jArray = jsonResult["category"] as JSONArray;
                listPayType = new List<string>();
                if (jArray != null)
                {
                    foreach (var item in jArray.Childs)
                    {
                        listPayType.Add(item.Value);
                    }
                }

                jArray = jsonResult["location"] as JSONArray;
                listLocation = new List<string>();
                if (jArray != null)
                {
                    foreach (var item in jArray.Childs)
                    {
                        listLocation.Add(item.Value);
                    }
                }

                jArray = jsonResult["type"] as JSONArray;
                listCategory = new List<string>();
                if (jArray != null)
                {
                    foreach (var item in jArray.Childs)
                    {
                        listCategory.Add(item.Value);
                    }
                }

                jArray = jsonResult["sort"] as JSONArray;
                listSort = new List<string>();
                if (jArray != null)
                {
                    foreach (var item in jArray.Childs)
                    {
                        listSort.Add(item.Value);
                    }
                }

                JSONClass jClass = jsonResult["tags"] as JSONClass;
                listTags = new List<string>();
                if (jClass != null)
                {
                    foreach (var item in jClass.Keys)
                    {
                        listTags.Add(item);
                    }
                }

                jClass = jsonResult["users"] as JSONClass;
                listCreator = new List<string>();
                if (jClass != null)
                {
                    foreach (var item in jClass.Keys)
                    {
                        listCreator.Add(item);
                    }
                }
                LogDebug($"hub_info counts location={listLocation.Count} paytype={listPayType.Count} category={listCategory.Count} sort={listSort.Count} tags={listTags.Count} users={listCreator.Count}");
                return true;
            }
            catch (Exception ex)
            {
                LogBackendLine($"error: GetInfoListAsync failed: {ex.Message}");
                return false;
            }
        }

        private void buttonFirstPage_Click(object sender, EventArgs e)
        {
            if (comboBoxPages.SelectedIndex > 0) comboBoxPages.SelectedIndex = 0;
        }

        private void buttonPrevPage_Click(object sender, EventArgs e)
        {
            if (comboBoxPages.SelectedIndex > 0) comboBoxPages.SelectedIndex--;
        }

        private void buttonNextPage_Click(object sender, EventArgs e)
        {
            if (comboBoxPages.SelectedIndex < comboBoxPages.Items.Count - 1) comboBoxPages.SelectedIndex++;
        }

        private void buttonLastPage_Click(object sender, EventArgs e)
        {
            if (comboBoxPages.SelectedIndex < comboBoxPages.Items.Count - 1) comboBoxPages.SelectedIndex = comboBoxPages.Items.Count - 1;
        }

        private void buttonRefresh_Click(object sender, EventArgs e)
        {
            _ = GenerateHabItemsAsync(force: true);
        }

        private async Task<string> GetResourcesAsync(int perpage = intPerPage,
            string? location = null, string? paytype = null,
            string? category = null, string? username = null, string? tags = null, string? search = null,
            string sort = "Latest Update",
            int page = 1)
        {
            var result = await RunBackendJobAsync("hub_resources", new
            {
                perpage = perpage,
                location = location,
                paytype = paytype,
                category = category,
                username = username,
                tags = tags,
                search = search,
                sort = sort,
                page = page
            });
            if (!result.Succeeded)
            {
                LogBackendLine($"error: hub_resources job failed status={result.Job.Status} error={result.Job.Error ?? "unknown"}");
            }
            return result.Result.HasValue ? result.Result.Value.GetRawText() : string.Empty;
        }

        public delegate void InvokeRefreshResource(string response, bool rebuildPages);

        private void buttonClearFilters_Click(object sender, EventArgs e)
        {
            DisableFilterEvent();
            ClearFilter();
            EnableFilterEvent();
            _ = GenerateHabItemsAsync(force: true);
        }

        private void buttonEmptySearch_Click(object sender, EventArgs e)
        {
            textBoxSearch.Text = "Search...";
            textBoxSearch.ForeColor = SystemColors.GrayText;
        }

        private void buttonScanHubUpdate_Click(object sender, EventArgs e)
        {
            string message = "Scan Hub For Packages With Updates.A download link list that will be generated. You must be logged in at hub.virtamate.com before you can download these links, It is recommended to use Chrono for Chrome to download.";

            const string caption = "AllMissingDepends";
            var result = MessageBox.Show(message, caption,
                                         MessageBoxButtons.YesNo,
                                         MessageBoxIcon.Question,
                                         MessageBoxDefaultButton.Button1);
            if (result == DialogResult.Yes)
            {
                UpdatAllPackages();
            }
        }
        struct PackVerDownID
        {
            public int ver;
            public string downloadid;

            public PackVerDownID(int ver, string downloadid)
            {
                this.ver = ver;
                this.downloadid = downloadid;
            }
        }
        private async void UpdatAllPackages()
        {
            this.BeginInvoke(addlog, new Object[] { "Search for upgradable vars...", LogLevel.INFO });
            try
            {
                var result = await RunBackendJobAsync("hub_updates_scan", null);
                var payload = DeserializeResult<HubDownloadList>(result);
                downloadUrls = payload?.DownloadUrls ?? new Dictionary<string, string>();
                if (payload != null)
                {
                    foreach (var kvp in payload.DownloadUrlsNoVersion)
                    {
                        if (!downloadUrls.ContainsKey(kvp.Key))
                        {
                            downloadUrls[kvp.Key] = kvp.Value;
                        }
                    }
                }
                NormalizeDownloadUrls();
                if (form1 != null)
                {
                    downloadUrls = downloadUrls
                        .Where(kvp => !form1.FindByvarName(kvp.Key))
                        .ToDictionary(kvp => kvp.Key, kvp => kvp.Value);
                    NormalizeDownloadUrls();
                }
                if (downloadUrls.Count > 0)
                {
                    this.BeginInvoke(addlog, new Object[] { $"Total {downloadUrls.Count} updatable download links found", LogLevel.INFO });
                    ShowDownList();
                    DrawDownloadListView();
                }
                else
                {
                    this.BeginInvoke(addlog, new Object[] { "No download link found", LogLevel.WARNING });
                }
            }
            catch (Exception ex)
            {
                this.BeginInvoke(addlog, new Object[] { $"Hub update scan failed: {ex.Message}", LogLevel.ERROR });
            }
        }

     

        private static async Task<string> GetHubPackages()
        {
            string url = "https://s3cdn.virtamate.com/data/packages.json";
            
            using (var client = new HttpClient())
            {
                var response = await client.GetAsync(url);
                string reponse = response.Content.ReadAsStringAsync().Result;
                return reponse;
            }
        }

        private void ShowDownList()
        {
            if (downlistHide)
            {
                int splitterDistance = splitContainer1.Size.Width - 500;
                if (splitterDistance < 80) splitterDistance = 80;
                splitContainer1.SplitterDistance = splitterDistance;
                downlistHide = false;
            }
        }

        private void HideDownLoadList(object sender, EventArgs e)
        {
            if (!downlistHide)
            {
                splitContainer1.SplitterDistance = splitContainer1.Size.Width - 80;
                downlistHide = true;
            }
        }

        private void textBoxSearch_Enter(object sender, EventArgs e)
        {
            if(textBoxSearch.Text=="Search...")
            {
                textBoxSearch.Text = "";
            }
            textBoxSearch.ForeColor = SystemColors.WindowText;
        }

        private void textBoxSearch_Leave(object sender, EventArgs e)
        {
            if (string.IsNullOrWhiteSpace(textBoxSearch.Text)||textBoxSearch.Text == "Search...")
            {
                textBoxSearch.Text = "Search...";
                textBoxSearch.ForeColor = SystemColors.GrayText;
            }
        }

        private void DownList_MouseEnter(object sender, EventArgs e)
        {
            ShowDownList();
        }

        private void buttonCopytoClip_Click(object sender, EventArgs e)
        {
            if (downloadUrls.Count > 0)
            {
                Clipboard.SetText(string.Join("\r\n", downloadUrls.Values));
                MessageBox.Show("Copied to clipboard, you can paste to chrono for chrome(edge) to download");
            }
        }
        
        // Assuming downloadUrls is a member of FormHub, populated elsewhere
        // private Dictionary<string, string> downloadUrls = new Dictionary<string, string>(); 
        // Add the new button click event handler
        private async void buttonDownloadAll_Click(object sender, EventArgs e)
        {
            // 1. Collect all unique download URLs from the downloadUrls dictionary
            HashSet<string> allUrlsToDownload = new HashSet<string>();
            if (downloadUrls != null) // Ensure downloadUrls is not null
            {
                foreach (var url in downloadUrls.Values)
                {
                    if (!string.IsNullOrEmpty(url) && url != "null")
                    {
                        allUrlsToDownload.Add(url);
                    }
                }
            }
            // 2. Check if there are any URLs
            if (allUrlsToDownload.Count == 0)
            {
                MessageBox.Show("No download links available. Please ensure data has been loaded and contains download links.",
                                "Information", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            try
            {
                this.buttonDownloadAll.Enabled = false;
                this.buttonCopytoClip.Enabled = false;
                this.button1.Enabled = false; // Assuming button1 is the Clear button
                await RunBackendJobAsync("hub_download_all", new { urls = allUrlsToDownload.ToList() });
                MessageBox.Show($"All {allUrlsToDownload.Count} items have been queued for download.\n" +
                                "Download process complete.",
                                "Download All Complete", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"An error occurred during the Download All process: {ex.Message}",
                                "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                // Re-enable buttons
                this.buttonDownloadAll.Enabled = true;
                this.buttonCopytoClip.Enabled = true;
                this.button1.Enabled = true;
            }
        }

        private void button1_Click(object sender, EventArgs e)
        {
            downloadUrls.Clear();
            downloadUrlsByUrl.Clear();
            DrawDownloadListView();
        }

        private void buttonClose_Click(object sender, EventArgs e)
        {
            this.Close(); 
        }

        private void FormHub_FormClosing(object sender, FormClosingEventArgs e)
        {
            if (listViewDownList.Items.Count > 0)
            {
                if (MessageBox.Show("Download list data will be lost, confirm exit?", "Warning",
                    MessageBoxButtons.YesNo, MessageBoxIcon.Warning, MessageBoxDefaultButton.Button2) == DialogResult.No)
                {
                    e.Cancel = true;
                }
            }
        }

        public void RefreshResource(string response, bool rebuildPages = true)
        {
            try
            {
                if (string.IsNullOrEmpty(response))
                {
                    LogBackendLine("error: RefreshResource received empty response");
                    return;
                }

                JSONNode jsonResult = JSON.Parse(response);
                if (jsonResult == null)
                {
                    LogBackendLine("error: Failed to parse hub_resources JSON response");
                    return;
                }

                JSONClass pagination = jsonResult["pagination"] as JSONClass;
                if (pagination == null)
                {
                    LogBackendLine("error: hub_resources response missing pagination field");
                    return;
                }

                int totalFound = 0;
                if (pagination["total_found"] != null)
                {
                    int.TryParse(pagination["total_found"].Value, out totalFound);
                }
                labelTotal.Text = $"Total: {totalFound}";

                int totalPages = 0;
                if (pagination["total_pages"] != null)
                {
                    int.TryParse(pagination["total_pages"].Value, out totalPages);
                }

                int curPage = 1;
                if (pagination["page"] != null)
                {
                    int.TryParse(pagination["page"].Value, out curPage);
                }

                if (rebuildPages)
                {
                    if (curPage > totalPages) curPage = totalPages;
                    if (curPage < 1) curPage = 1;
                    comboBoxPages.SelectedIndexChanged -= ComboBoxSelectedChanged;
                    comboBoxPages.Items.Clear();
                    for (int i = 0; i < totalPages; i++)
                    {
                        comboBoxPages.Items.Add($"{i + 1 } of {totalPages}");
                    }
                    if (comboBoxPages.Items.Count > 0)
                        comboBoxPages.SelectedIndex = curPage - 1;
                    comboBoxPages.SelectedIndexChanged += ComboBoxSelectedChanged;
                }

                var resources = jsonResult["resources"]?.AsArray;
                LogDebug($"hub_resources pagination total_found={totalFound} total_pages={totalPages} page={curPage} resources={(resources != null ? resources.Count : 0)}");
                if (resources == null)
                {
                    LogBackendLine("error: hub_resources response missing resources field");
                    // Hide all items if no resources
                    for (int index = 0; index < intPerPage; index++)
                    {
                        HubItem hubItem = (HubItem)flowLayoutPanelHubItems.Controls[index];
                        hubItem.Visible = false;
                    }
                    return;
                }

                for (int index = 0; index < intPerPage; index++)
                {
                    HubItem hubItem = (HubItem)flowLayoutPanelHubItems.Controls[index];
                    if (resources.Count > index)
                    {
                        hubItem.Visible = true;
                        JSONClass resource = resources[index] as JSONClass;
                        if (resource == null)
                        {
                            hubItem.Visible = false;
                            continue;
                        }
                        hubItem.SetResource(resource);
                        string inRepository = "Unknown Status";
                        if (resource.HasKey("hubFiles"))
                        {
                            var hubfiles = resource["hubFiles"]?.AsArray;
                            if (hubfiles != null && hubfiles.Count > 0)
                            {
                                int inrepons = -1;
                                //JSONClass hubfile = hubfiles[0] as JSONClass;
                                foreach (JSONClass hubfile in hubfiles)
                                {
                                    if (hubfile == null || hubfile["filename"] == null) continue;
                                    string filename = hubfile["filename"].Value;
                                    if (filename.EndsWith(".var"))
                                        filename = filename.Substring(0, filename.Length - 4);
                                    hubItem.PackageName = filename;
                                    //int splitindex = filename.LastIndexOf('.');
                                    string[] filenameparts = filename.Split(('.'));
                                    if (filenameparts.Length >= 2)
                                    {
                                        string hubpackageName = filenameparts[0] + "." + filenameparts[1];
                                        int hubversion = 1;
                                        if (filenameparts.Length >= 3)
                                            int.TryParse(filenameparts[2], out hubversion);
                                        string varlastname = form1.VarExistName(hubpackageName + ".latest");
                                        if (varlastname != "missing")
                                        {
                                            int lastversion = int.Parse(varlastname.Substring(filename.LastIndexOf('.') + 1));
                                            if (lastversion >= hubversion)
                                            {
                                                if (inrepons < 0)
                                                {
                                                    inRepository = "In Repository";
                                                    inrepons = 0;
                                                }
                                            }
                                            else
                                            {
                                                if (inrepons < 1)
                                                {
                                                    inRepository = $"{lastversion} Upgrade to {hubversion}";
                                                    inrepons = 1;
                                                }
                                            }

                                        }
                                        else
                                        {
                                            inRepository = "Generate Download List";
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                        else
                        {
                            if (resource.HasKey("download_url"))
                            {
                                inRepository = "Go To Download";
                            }
                        }
                        hubItem.InRepository = inRepository;
                        hubItem.RefreshItem();
                    }
                    else
                        hubItem.Visible = false;
                }
            }
            catch (Exception ex)
            {
                LogBackendLine($"error: RefreshResource failed: {ex.Message}\n{ex.StackTrace}");
            }
        }
        private void ResponseTask(Task<string> responseTask)
        {
            try
            {
                InvokeRefreshResource refreshResource = new InvokeRefreshResource(RefreshResource);
                string response = responseTask.Result;
                this.BeginInvoke(refreshResource, new Object[] { response, true });
            }
            catch (Exception) { }
        }

        private static async Task<string> GetResponse(string url, StringContent data)
        {
            //using (var client = new HttpClient())
            //{
            string strresponse = "";
            httpClient.Timeout = TimeSpan.FromSeconds(60);
            try
            {
                var response = await httpClient.PostAsync(url, data, cancellationToken);

                strresponse = response.Content.ReadAsStringAsync().Result;
            }
            catch
            {

            }
            return strresponse;
            //}
        }

        private static async Task<string> GetInfo()
        {
            string url = "https://hub.virtamate.com/citizenx/api.php";

            JSONClass jns = new JSONClass();
            jns.Add("source", "VaM");
            jns.Add("action", "getInfo");
            var data = new StringContent(jns.ToString(), Encoding.UTF8, "application/json");
            return await GetResponse(url, data);
        }

        private void buttonExit_Click(object sender, EventArgs e)
        {
            this.Close();
        }
    }
}
