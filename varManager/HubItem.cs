using SimpleJSON;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Globalization;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using varManager.Backend;

namespace varManager
{
    
    public partial class HubItem : UserControl
    {
        private JSONClass resource;
        private string paytype, category, title, version, tagLine, imageUrl, creatorName, creatorIcon, resource_id,download_url,packageName;
        private double ratingAvg;
        private int ratingCount,downloads;
        private DateTime lastUpdated;
        private string inRepository = "";

        public string InRepository { get => inRepository; set => inRepository = value; }
        public string PackageName { get => packageName; set => packageName = value; }
        public Action<string>? LogSink { get; set; }

        private void LogBackendLine(string line)
        {
            LogSink?.Invoke(line);
        }

        private void LogDebug(string message)
        {
            LogBackendLine($"debug: {message}");
        }

        private T? DeserializeResult<T>(BackendJobResult result)
        {
            if (!result.Result.HasValue)
            {
                return default;
            }
            return JsonSerializer.Deserialize<T>(result.Result.Value.GetRawText());
        }

        private int ParseInt(JSONClass json, string key, int defaultValue = 0)
        {
            string raw = json[key].Value;
            if (string.IsNullOrWhiteSpace(raw) || raw.Equals("null", StringComparison.OrdinalIgnoreCase))
            {
                LogDebug($"HubItem parse int empty key={key} resource_id='{resource_id}' title='{title}'");
                return defaultValue;
            }
            if (int.TryParse(raw, NumberStyles.Integer, CultureInfo.InvariantCulture, out int value))
            {
                return value;
            }
            LogDebug($"HubItem parse int failed key={key} value='{raw}' resource_id='{resource_id}' title='{title}'");
            return defaultValue;
        }

        private long ParseLong(JSONClass json, string key, long defaultValue = 0)
        {
            string raw = json[key].Value;
            if (string.IsNullOrWhiteSpace(raw) || raw.Equals("null", StringComparison.OrdinalIgnoreCase))
            {
                LogDebug($"HubItem parse long empty key={key} resource_id='{resource_id}' title='{title}'");
                return defaultValue;
            }
            if (long.TryParse(raw, NumberStyles.Integer, CultureInfo.InvariantCulture, out long value))
            {
                return value;
            }
            LogDebug($"HubItem parse long failed key={key} value='{raw}' resource_id='{resource_id}' title='{title}'");
            return defaultValue;
        }

        private double ParseDouble(JSONClass json, string key, double defaultValue = 0)
        {
            string raw = json[key].Value;
            if (string.IsNullOrWhiteSpace(raw) || raw.Equals("null", StringComparison.OrdinalIgnoreCase))
            {
                LogDebug($"HubItem parse double empty key={key} resource_id='{resource_id}' title='{title}'");
                return defaultValue;
            }
            if (double.TryParse(raw, NumberStyles.Float, CultureInfo.InvariantCulture, out double value))
            {
                return value;
            }
            LogDebug($"HubItem parse double failed key={key} value='{raw}' resource_id='{resource_id}' title='{title}'");
            return defaultValue;
        }

        private sealed class HubDownloadList
        {
            [JsonPropertyName("download_urls")]
            public Dictionary<string, string> DownloadUrls { get; set; } = new Dictionary<string, string>();

            [JsonPropertyName("download_urls_no_version")]
            public Dictionary<string, string> DownloadUrlsNoVersion { get; set; } = new Dictionary<string, string>();
        }

        public HubItem()
        {
            InitializeComponent();
        }

        private void HubItem_Load(object sender, EventArgs e)
        {
            RefreshItem();
        }
        private bool GetResourceDetail()
        {
            try
            {
                var result = BackendSession.RunJob("hub_resource_detail", new { resource_id = resource_id }, LogBackendLine, CancellationToken.None);
                if (!result.Succeeded)
                {
                    LogBackendLine($"error: hub_resource_detail job failed status={result.Job.Status} error={result.Job.Error ?? "unknown"}");
                }
                var payload = DeserializeResult<HubDownloadList>(result);
                if (payload == null)
                {
                    LogDebug($"hub_resource_detail result empty resource_id='{resource_id}'");
                    return false;
                }
                LogDebug($"hub_resource_detail resource_id='{resource_id}' urls={payload.DownloadUrls.Count} urls_no_version={payload.DownloadUrlsNoVersion.Count}");
                Dictionary<string, string> varDownloadUrl = new Dictionary<string, string>();
                foreach (var kvp in payload.DownloadUrls)
                {
                    if (!string.IsNullOrEmpty(kvp.Value))
                    {
                        varDownloadUrl[kvp.Key] = kvp.Value;
                    }
                }
                foreach (var kvp in payload.DownloadUrlsNoVersion)
                {
                    if (!string.IsNullOrEmpty(kvp.Value) && !varDownloadUrl.ContainsKey(kvp.Key))
                    {
                        varDownloadUrl[kvp.Key] = kvp.Value;
                    }
                }
                RaiseGenLinkListFilterEvent(varDownloadUrl);
                return true;
            }
            catch (Exception ex)
            {
                LogBackendLine($"error: GetResourceDetail failed: {ex.Message}");
                return false;
            }
        }
        private static async Task<string> GetResourceDetail(string resourceid)
        {
            string url = "https://hub.virtamate.com/citizenx/api.php";

            JSONClass jns = new JSONClass();
            jns.Add("source", "VaM");
            jns.Add("action", "getResourceDetail");
            jns.Add("latest_image", "Y");
            jns.Add("resource_id",  resourceid);
             
            var data = new StringContent(jns.ToString(), Encoding.UTF8, "application/json");
            return await GetResponse(url, data);
        }
        private static async Task<string> GetResponse(string url, StringContent data)
        {
            //using (var client = new HttpClient())
            //{
            string strresponse = "";
            HttpClient httpClient = new HttpClient();
            httpClient.Timeout = TimeSpan.FromSeconds(60);
            try
            {
                var response = await httpClient.PostAsync(url, data);

                strresponse = response.Content.ReadAsStringAsync().Result;
            }
            catch
            {

            }
            return strresponse;
            //}
        }
        private void buttonInRepository_Click(object sender, EventArgs e)
        {
            if (buttonInRepository.Text.Contains("Generate Download List")|| buttonInRepository.Text.Contains("Upgrade to")) 
            {
                GetResourceDetail();
            }
            if (buttonInRepository.Text.Contains("In Repository"))
            {
                RaisePackageNameEvent(packageName);
            }
            if (buttonInRepository.Text.StartsWith("Go To "))
            {
                if (!string.IsNullOrEmpty(download_url))
                {
                    try
                    {
                        BackendSession.RunJob("open_url", new { url = download_url }, LogBackendLine, CancellationToken.None);
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Open url failed: {ex.Message}");
                    }
                }
            }
        }
        void RaiseGenLinkListFilterEvent(Dictionary<string, string> varDownloadUrl)
        {
            DownloadLinkListEventArgs newEventArgs =
                    new DownloadLinkListEventArgs();
            newEventArgs.DownloadLinks = varDownloadUrl;
            if (GenLinkList != null)
                GenLinkList(this, newEventArgs);
        } 
        
        public delegate void GenLinkListHandle(object sender, DownloadLinkListEventArgs e);
        //Event name 
        public event GenLinkListHandle GenLinkList;

        public delegate void ClickFilterHandle(object sender, HubItemFilterEventArgs e);
        //Event name 
        public event ClickFilterHandle ClickFilter;

        public delegate void RetPackageNameHandle(object sender, PackageNameEventArgs e);
        //Event name 
        public event RetPackageNameHandle RetPackageName;
        public void RefreshItem()
        {
            buttonType.Text = $"{paytype} {category}";
            labelTitle.Text = title;
            labelVersion.Text = version;
            labelTagLine.Text = tagLine;
            PictureBox[] ratingCtls = { picRating1, picRating2, picRating3, picRating4, picRating5 };
            double rating = ratingAvg + 1;
            foreach (PictureBox rctl in ratingCtls)
            {
                toolTip1.SetToolTip(rctl, $"{ratingAvg}/5");
                rating--;
                if (rating < 0.125)
                {
                    rctl.Image = global::varManager.Properties.Resources.starEmpty;
                    continue;
                }
                if (rating < 0.375)
                {
                    rctl.Image = global::varManager.Properties.Resources.starOneQuarter;
                    continue;
                }
                if (rating < 0.625)
                {
                    rctl.Image = global::varManager.Properties.Resources.starHalf;
                    continue;
                }
                if (rating < 0.875)
                {
                    rctl.Image = global::varManager.Properties.Resources.starTriQuarter;
                    continue;
                }
                rctl.Image = global::varManager.Properties.Resources.starFull;
            }
            labelRatingCount.Text = $"{ratingCount} ratings";
            labelDownloads.Text = $"{downloads}";
            labelLastUpdated.Text = $"{lastUpdated.ToString("MMM d,yyyy", CultureInfo.CreateSpecificCulture("en-US"))}";
            try
            {
                if (!string.IsNullOrEmpty(imageUrl))
                    pictureBoxImage.LoadAsync(imageUrl);
            }
            catch
            {

            }
            try
            {
                if (!string.IsNullOrEmpty(creatorIcon))
                    pictureBoxUser.LoadAsync(creatorIcon);
            }
            catch
            {

            }
            buttonUser.Text = creatorName;
            buttonInRepository.Text = inRepository;
            switch (inRepository)
            {
                case "In Repository":
                    buttonInRepository.BackColor = Color.DarkCyan;
                    toolTip1.SetToolTip(buttonInRepository, "You already own this package, click to locate it in the main window");
                    break; 
                case "Go To Download":
                    buttonInRepository.BackColor = Color.MediumOrchid;
                    toolTip1.SetToolTip(buttonInRepository, "Clicking will open the download page with your browser");
                    break;
                default:
                    buttonInRepository.BackColor = Color.SteelBlue;
                    if (buttonInRepository.Text.Contains("Generate Download List") || buttonInRepository.Text.Contains("Upgrade to"))
                    {
                        toolTip1.SetToolTip(buttonInRepository, "A list of downloads will be generated");
                    }
                     break;

                   
            }
          
        }

        private void pictureBoxImage_Click(object sender, EventArgs e)
        {
            // Construct the URL to open based on the resource_id
            string urlToOpen = $"https://hub.virtamate.com/resources/{resource_id}/";
            try
            {
                BackendSession.RunJob("open_url", new { url = urlToOpen }, LogBackendLine, CancellationToken.None);
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    $"An unexpected error occurred while trying to open the link: {ex.Message}\nLink: {urlToOpen}",
                    "Open Link Error",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
            }
        }

        void RaiseClickFilterEvent(string filterType,string payType,string category,string  creator)
        {
            HubItemFilterEventArgs newEventArgs =
                    new HubItemFilterEventArgs();
            newEventArgs.FilterType = filterType;
            newEventArgs.PayType = payType;
            newEventArgs.Category = category;   
            newEventArgs.Creator = creator; 
            if (ClickFilter!=null)
               ClickFilter(this,newEventArgs);
        }

        void RaisePackageNameEvent(string packageName)
        {
            PackageNameEventArgs newEventArgs = new PackageNameEventArgs();
            newEventArgs.PackageName = packageName;
            if (RetPackageName != null)
                RetPackageName(this, newEventArgs);
        }

        private void buttonType_Click(object sender, EventArgs e)
        {
            RaiseClickFilterEvent("category", paytype, category, creatorName);
        }

        private void buttonUser_Click(object sender, EventArgs e)
        {
            RaiseClickFilterEvent("creator", paytype, category, creatorName);
        }

        private void pictureBoxUser_Click(object sender, EventArgs e)
        {
            RaiseClickFilterEvent("creator", paytype, category, creatorName);
        }


        public void SetResource(JSONClass json) 
        {
            this.resource = json;
            this.resource_id = resource["resource_id"].Value;
            this.title = resource["title"].Value;
            this.paytype = resource["category"].Value;
            this.category = resource["type"].Value;
            this.version = resource["version_string"].Value;
            this.tagLine = resource["tag_line"].Value;
            this.imageUrl = resource["image_url"].Value;
            this.creatorIcon = resource["icon_url"].Value;
            this.creatorName = resource["username"].Value;
            this.download_url = resource["download_url"].Value;
            this.ratingAvg = ParseDouble(resource, "rating_avg");
            this.ratingCount = ParseInt(resource, "rating_count");
            this.downloads = ParseInt(resource, "download_count");
            long unixTimeStamp = ParseLong(resource, "last_update");
            DateTime dt1 = new DateTime(1970, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc);
            this.lastUpdated = dt1.AddSeconds(unixTimeStamp).ToLocalTime();
        }
    }
    public class HubItemFilterEventArgs : EventArgs
    {
        private string filterType,payType,category,creator;
        public string FilterType { get => filterType; set => filterType = value; }
        public string PayType { get => payType; set => payType = value; }
        public string Category { get => category; set => category = value; }
        public string Creator { get => creator; set => creator = value; }
    }
    public class DownloadLinkListEventArgs : EventArgs
    {
        private Dictionary<string, string>  downloadLinks;

        public Dictionary<string, string>  DownloadLinks { get => downloadLinks; set => downloadLinks = value; }
    }

    public class GotoDownloadEventArgs : EventArgs
    {
        private string gotoDownload;

        public string GotoDownload { get => gotoDownload; set => gotoDownload = value; }
    }
    public class PackageNameEventArgs : EventArgs
    {
        private string packageName;

        public string PackageName { get => packageName; set => packageName = value; }
    }
}
