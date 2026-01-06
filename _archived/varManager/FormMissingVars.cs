using SimpleJSON;
using System;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.RegularExpressions;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using varManager.Backend;
using varManager.Properties;
using varManager.Data;
using varManager.Models;
using static SimpleLogger;

namespace varManager
{
    public partial class FormMissingVars : Form
    {
        private static string missingVarLinkDirName = "___MissingVarLink___";
        private List<string> missingVars;
        public Form1 form1;
        private VarManagerContext dbContext;
        Dictionary<string, string> downloadUrls = new Dictionary<string, string>();
        Dictionary<string, string> downloadUrlsNoVersion = new Dictionary<string, string>();
        
        static string vam_download_exe = "vam_downloader.exe";
        static string vam_download_path = Path.Combine(".\\plugin\\", vam_download_exe);
        static string vam_download_save_path = Path.Combine(Settings.Default.vampath, "AddonPackages");

        private void LogBackendLine(string line)
        {
            if (form1 == null)
            {
                return;
            }
            LogLevel level = LogLevel.INFO;
            if (line.StartsWith("error:", StringComparison.OrdinalIgnoreCase))
            {
                level = LogLevel.ERROR;
            }
            form1.BeginInvoke(new Form1.InvokeAddLoglist(form1.UpdateAddLoglist), new object[] { line, level });
        }

        private Task<BackendJobResult> RunBackendJobAsync(string kind, object? args)
        {
            return BackendSession.RunJobAsync(kind, args, LogBackendLine, CancellationToken.None);
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
        
        public FormMissingVars()
        {
            InitializeComponent();
            dbContext = new VarManagerContext();
        }

        public List<string> MissingVars { get => missingVars; set => missingVars = value; }
        public static string MissingVarLinkDirName { get => missingVarLinkDirName; set => missingVarLinkDirName = value; }

        private void FormMissingVars_Load(object sender, EventArgs e)
        {
            Directory.CreateDirectory(Path.Combine(Settings.Default.vampath, "AddonPackages", missingVarLinkDirName));
            // Load data using EF Core instead of TableAdapter
            toolStripComboBoxIgnoreVersion.SelectedIndex = 0;
            FillMissVarGridView();
        }
        
        // Assuming these are class members, populated by FillColumnDownloadText
        // Dictionary<string, string> downloadUrls = new Dictionary<string, string>();
        // Dictionary<string, string> downloadUrlsNoVersion = new Dictionary<string, string>();
        // string vam_download_path = "path_to_your_downloader.exe"; // Make sure this is set
        // string vam_download_save_path = "path_to_save_downloads"; // Make sure this is set
        private async void toolStripButtonDownloadAll_Click(object sender, EventArgs e)
        {
            // 1. Collect all unique download URLs
            HashSet<string> allUrlsToDownload = new HashSet<string>();
            foreach (var url in downloadUrls.Values)
            {
                if (!string.IsNullOrEmpty(url) && url != "null")
                {
                    allUrlsToDownload.Add(url);
                }
            }
            foreach (var url in downloadUrlsNoVersion.Values)
            {
                if (!string.IsNullOrEmpty(url) && url != "null")
                {
                    // It's possible some URLs are already in downloadUrls, HashSet handles duplicates
                    allUrlsToDownload.Add(url);
                }
            }
            // 2. Check if there are any URLs
            if (allUrlsToDownload.Count == 0)
            {
                MessageBox.Show("No download links found. Please click 'Fetch Download' try to fetch download var links.",
                                "Information", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            try
            {
                await RunBackendJobAsync("hub_download_all", new { urls = allUrlsToDownload.ToList() });
                MessageBox.Show($"All {allUrlsToDownload.Count} items have been queued for download.\n" +
                                "Download process complete. Please click the 'UPD_DB' button to update the database after downloads finish.",
                                "Download All Complete", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"An error occurred during the Download All process: {ex.Message}",
                                "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
        
        private void toolStripButtonFillDownloadText_Click(object sender, EventArgs e)
        {
            // It's good practice to disable UI elements that shouldn't be clicked during an async operation
            this.toolStripButtonFetchDownload.Enabled = false;
            this.toolStripButtonDownloadAll.Enabled = false; 
            try
            {
                FillColumnDownloadText();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error fetching download info: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                this.toolStripButtonFetchDownload.Enabled = true;
                this.toolStripButtonDownloadAll.Enabled = true;
            }
        }
        
        private async void FillColumnDownloadText()
        {
            var result = await RunBackendJobAsync("hub_find_packages", new { packages = missingVars });
            var payload = DeserializeResult<HubDownloadList>(result);
            downloadUrls = payload?.DownloadUrls ?? new Dictionary<string, string>();
            downloadUrlsNoVersion = payload?.DownloadUrlsNoVersion ?? new Dictionary<string, string>();

            if (form1 != null)
            {
                downloadUrls = downloadUrls
                    .Where(kvp => !form1.FindByvarName(kvp.Key))
                    .ToDictionary(kvp => kvp.Key, kvp => kvp.Value);
                downloadUrlsNoVersion = downloadUrlsNoVersion
                    .Where(kvp => !form1.FindByvarName(kvp.Key))
                    .ToDictionary(kvp => kvp.Key, kvp => kvp.Value);
            }

            foreach (DataGridViewRow row in dataGridViewMissingVars.Rows)
            {
                string rowVarName = row.Cells["ColumnVarName"].Value.ToString();
                if (downloadUrls.ContainsKey(rowVarName))
                {
                    row.Cells["ColumnDownload"].Value = rowVarName;
                    row.Cells["ColumnDownload"].Style.SelectionBackColor = Color.LightGreen;
                    row.Cells["ColumnDownload"].Style.BackColor = Color.SkyBlue;
                }
                else if (downloadUrlsNoVersion.ContainsKey(rowVarName.Substring(0, rowVarName.LastIndexOf('.'))))
                {
                    row.Cells["ColumnDownload"].Value = rowVarName;
                    row.Cells["ColumnDownload"].Style.SelectionBackColor = Color.Orange;
                    row.Cells["ColumnDownload"].Style.BackColor = Color.Yellow;
                }
                else
                {
                    row.Cells["ColumnDownload"].Value = "";
                }
            }
            MessageBox.Show("Fetch Download From Hub Complete!", "Info", MessageBoxButtons.OK, MessageBoxIcon.Information);
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

        private void FillMissVarGridView()
        {
            if (missingVars != null)
            {
                dataGridViewMissingVars.Rows.Clear();
                foreach (string missingvar in missingVars)
                {
                    string missingvarname = missingvar;
                    if(missingvarname.EndsWith("$"))
                    {
                        if (toolStripComboBoxIgnoreVersion.SelectedIndex == 1)
                        {
                            missingvarname = missingvarname.Substring(0, missingvarname.Length - 1);
                        }
                        else
                            continue;
                    }
                    if (missingvarname.LastIndexOf('/') > 1)
                        missingvarname = missingvarname.Substring(missingvarname.LastIndexOf('/') + 1);
                    string searchPattern = missingvarname + ".var";
                    if (missingvarname.IndexOf(".latest") > 0)
                        searchPattern = missingvarname.Substring(0, missingvarname.LastIndexOf('.') + 1) + "*.var";
                    var files = Directory.GetFiles(Path.Combine(Settings.Default.vampath, "AddonPackages", missingVarLinkDirName), searchPattern, SearchOption.AllDirectories).OrderByDescending(q => Path.GetFileNameWithoutExtension(q)).ToArray();
                    if (files.Length == 0)
                        dataGridViewMissingVars.Rows.Add(new string[] { missingvarname, "", "UnLink", "Google", "" });
                    else
                    {
                        string destfilename = Path.GetFileNameWithoutExtension(Comm.ReparsePoint(files[0]));
                        dataGridViewMissingVars.Rows.Add(new string[] { missingvarname, destfilename, "UnLink", "Google", "" });
                    }

                }
                bindingNavigatorCountItem.Text = "/" + dataGridViewMissingVars.Rows.Count;
            }
        }

        private void textBoxFilter_TextChanged(object sender, EventArgs e)
        {
            FilterVars();
        }

        private void FilterVars()
        {
            string strFilter = "1=1";
            if (comboBoxCreater.SelectedItem != null)
                if (comboBoxCreater.SelectedItem.ToString() != "____ALL")
                    strFilter += " AND creatorName = '" + comboBoxCreater.SelectedItem.ToString() + "'";
            if (textBoxFilter.Text.Trim() != "")
            {
                strFilter += " AND varName Like '%" + Regex.Replace(Regex.Replace(textBoxFilter.Text.Trim(), @"[\x5B\x5D]", "[$0]", RegexOptions.Multiline), @"[\x27]", @"\x27\x27", RegexOptions.Multiline) + "*'";
            }

            this.comboBoxCreater.SelectedIndexChanged -= new System.EventHandler(this.comboBoxCreater_SelectedIndexChanged);
            var creators = dbContext.Vars.GroupBy(g => g.CreatorName);
            if (textBoxFilter.Text.Trim() != "")
                creators = dbContext.Vars.Where(q => q.VarName.ToLower().IndexOf(textBoxFilter.Text.Trim().ToLower()) >= 0).GroupBy(g => g.CreatorName);
            string curcreator = comboBoxCreater.Text;
            comboBoxCreater.Items.Clear();
            comboBoxCreater.Items.Add("____ALL");
            foreach (var creator in creators)
            {
                comboBoxCreater.Items.Add(creator.Key);
            }
            if (comboBoxCreater.Items.Contains(curcreator))
                comboBoxCreater.SelectedItem = curcreator;
            else
                comboBoxCreater.SelectedIndex = 0;
            this.comboBoxCreater.SelectedIndexChanged += new System.EventHandler(this.comboBoxCreater_SelectedIndexChanged);

            varsBindingSource.Filter = strFilter;
            varsDataGridView.Update();
        }

        private void comboBoxCreater_SelectedIndexChanged(object sender, EventArgs e)
        {
            FilterVars();
        }

        private void varsDataGridView_SelectionChanged(object sender, EventArgs e)
        {
            if (varsDataGridView.SelectedRows.Count > 0)
                textBoxLinkVar.Text = varsDataGridView.SelectedRows[0].Cells[0].Value.ToString();
        }

        private void dataGridViewMissingVars_SelectionChanged(object sender, EventArgs e)
        {
            if (dataGridViewMissingVars.SelectedRows.Count > 0)
            {
                string missingVarName = dataGridViewMissingVars.SelectedRows[0].Cells[0].Value.ToString();
                string missingvarnamepart = missingVarName.Split('.')[1];
                textBoxMissingVar.Text = missingVarName;
                textBoxFilter.Text = missingvarnamepart;

                List<string> depends = form1.GetDependents(missingVarName);
                dataGridViewDependent.Rows.Clear();
                foreach (string depend in depends)
                {
                    dataGridViewDependent.Rows.Add(depend, "locate");
                }
            }
        }

        private void buttonLinkto_Click(object sender, EventArgs e)
        {
            string missingvar = textBoxMissingVar.Text;
            string linkvar = textBoxLinkVar.Text;
            foreach (DataGridViewRow row in dataGridViewMissingVars.Rows)
            {
                if (row.Cells[0].Value.ToString() == missingvar)
                {
                    row.Cells[1].Value = linkvar;
                    break;
                }
            }
        }

        private async void dataGridViewMissingVars_CellContentClick(object sender, DataGridViewCellEventArgs e)
        {
            if (e.ColumnIndex == 2)
            {
                dataGridViewMissingVars.Rows[e.RowIndex].Cells[1].Value = "";
            }
            if (e.ColumnIndex == 3)
            {
                string varname = dataGridViewMissingVars.Rows[e.RowIndex].Cells[0].Value.ToString().Replace(".latest", ".1");
                string url = "https://www.google.com/search?q=" + varname + " var";
                try
                {
                    await RunBackendJobAsync("open_url", new { url = url });
                }
                catch (Exception ex)
                {
                    MessageBox.Show("An error occurred trying to open url: " + ex.Message);
                }
            }
            if (e.ColumnIndex == 4)
            {
                string varname = dataGridViewMissingVars.Rows[e.RowIndex].Cells[0].Value.ToString();
                string varnameNoVersion = varname.Substring(0, varname.LastIndexOf('.'));
                if (downloadUrls.TryGetValue(varname, out var var_url))
                {
                    try
                    {
                        await RunBackendJobAsync("hub_download_all", new { urls = new List<string> { var_url } });
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Download {varname} failed: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    }
                }
                else if (downloadUrlsNoVersion.TryGetValue(varnameNoVersion, out var var_noversion_url))
                {
                    try
                    {
                        await RunBackendJobAsync("hub_download_all", new { urls = new List<string> { var_noversion_url } });
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Download {varnameNoVersion} failed: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    }
                }
                else
                {
                    // For Debug
                    // var allUrls = string.Join("\n", downloadUrls.Select(kvp => $"Key: {kvp.Key}, Value: {kvp.Value}"));
                    // var allUrlsNoVersion = string.Join("\n", downloadUrlsNoVersion.Select(kvp => $"Key: {kvp.Key}, Value: {kvp.Value}"));
                    // MessageBox.Show("Download URLs:\n" + allUrls + "\n" + allUrlsNoVersion);
                    MessageBox.Show("No download url found for " + varname);
                }
            }
        }

        private async void buttonOK_Click(object sender, EventArgs e)
        {
            var links = new List<object>();
            foreach (DataGridViewRow row in dataGridViewMissingVars.Rows)
            {
                string missingvarname = row.Cells[0].Value.ToString();
                string destvarname = row.Cells[1].Value.ToString();
                if (!string.IsNullOrEmpty(missingvarname) && !string.IsNullOrEmpty(destvarname))
                {
                    links.Add(new { missing_var = missingvarname, dest_var = destvarname });
                }
            }

            try
            {
                await RunBackendJobAsync("links_missing_create", new { links = links });
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Create link failed: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            this.Close();
        }

        private void Createlink()
        {
            foreach (DataGridViewRow row in dataGridViewMissingVars.Rows)
            {
                string missingvarname = row.Cells[0].Value.ToString();
                string destvarname = row.Cells[1].Value.ToString();
                string searchPattern = missingvarname + ".var";
                if (missingvarname.IndexOf(".latest") > 0)
                    searchPattern = missingvarname.Substring(0, missingvarname.LastIndexOf('.') + 1) + "*.var";
                var files = Directory.GetFiles(Path.Combine(Settings.Default.vampath, "AddonPackages", missingVarLinkDirName), searchPattern, SearchOption.AllDirectories).OrderByDescending(q => Path.GetFileNameWithoutExtension(q)).ToArray();
                if (files.Length > 0)
                {
                    File.Delete(files[0]);
                    if (File.Exists(files[0] + ".disabled"))
                        File.Delete(files[0] + ".disabled");
                }

                if (!string.IsNullOrEmpty(destvarname))
                {
                    var varsrow = dbContext.Vars.FirstOrDefault(v => v.VarName == destvarname);
                    if (missingvarname.Substring(missingvarname.LastIndexOf('.')) == ".latest")
                    {
                        missingvarname = missingvarname.Substring(0, missingvarname.LastIndexOf('.')) + destvarname.Substring(destvarname.LastIndexOf('.'));
                    }
                    if (varsrow != null)
                    {
                        string missingvar = Path.Combine(Settings.Default.vampath, "AddonPackages", missingVarLinkDirName, missingvarname + ".var");
                        string destvarfile = Path.Combine(Settings.Default.varspath, varsrow.VarPath!, varsrow.VarName + ".var");
                        Comm.CreateSymbolicLink(missingvar, destvarfile, Comm.SYMBOLIC_LINK_FLAG.File);
                        Comm.SetSymboLinkFileTime(missingvar, File.GetCreationTime(destvarfile), File.GetLastWriteTime(destvarfile));
                        //File.SetCreationTime(missingvar, File.GetCreationTime(destvarfile));
                        //File.SetLastWriteTime(missingvar, File.GetLastWriteTime(destvarfile));
                    }
                }
            }
        }

        private void buttonCancel_Click(object sender, EventArgs e)
        {
            this.Close();
        }

        private void dataGridViewMissingVars_RowEnter(object sender, DataGridViewCellEventArgs e)
        {
            bindingNavigatorPositionItem.Text = (e.RowIndex + 1).ToString();
        }

        private void bindingNavigatorMoveNextItem_Click(object sender, EventArgs e)
        {
            int nRow = dataGridViewMissingVars.CurrentCell.RowIndex;
            if (nRow < dataGridViewMissingVars.RowCount - 1)
            {
                dataGridViewMissingVars.CurrentCell = dataGridViewMissingVars.Rows[++nRow].Cells[0];
            }
        }

        private void bindingNavigatorMovePreviousItem_Click(object sender, EventArgs e)
        {
            int nRow = dataGridViewMissingVars.CurrentCell.RowIndex;
            if (nRow > 0)
            {
                dataGridViewMissingVars.CurrentCell = dataGridViewMissingVars.Rows[--nRow].Cells[0];
            }
        }

        private void bindingNavigatorMoveLastItem_Click(object sender, EventArgs e)
        {
            int nRow = dataGridViewMissingVars.CurrentCell.RowIndex;
            if (nRow < dataGridViewMissingVars.RowCount - 1)
            {
                dataGridViewMissingVars.CurrentCell = dataGridViewMissingVars.Rows[dataGridViewMissingVars.RowCount - 1].Cells[0];
            }
        }

        private void bindingNavigatorMoveFirstItem_Click(object sender, EventArgs e)
        {
            int nRow = dataGridViewMissingVars.CurrentCell.RowIndex;
            if (nRow > 0)
            {
                dataGridViewMissingVars.CurrentCell = dataGridViewMissingVars.Rows[0].Cells[0];
            }
        }

        private void buttonSave_Click(object sender, EventArgs e)
        {
            if (saveFileDialogSaveTxt.ShowDialog() == DialogResult.OK)
            {
                try
                {
                    BackendSession.RunJob("vars_export_installed", new { path = saveFileDialogSaveTxt.FileName }, LogBackendLine, CancellationToken.None);
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Export failed: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
        }
        private void buttonSaveTxt_Click(object sender, EventArgs e)
        {
            if (saveFileDialogSaveTxt.ShowDialog() == DialogResult.OK)
            {
                List<string> varlinktoList = new List<string>();
                foreach (DataGridViewRow row in dataGridViewMissingVars.Rows)
                {
                    string missingvarname = row.Cells[0].Value.ToString();
                    string destvarname = row.Cells[1].Value.ToString();
                    if (!string.IsNullOrEmpty(destvarname))
                    {
                        varlinktoList.Add($"{missingvarname}|{destvarname}");
                    }
                }

                File.WriteAllLines(saveFileDialogSaveTxt.FileName, varlinktoList.ToArray());
            }
        }
        private void buttonLoadTxt_Click(object sender, EventArgs e)
        {
            if (openFileDialogLoadTXT.ShowDialog() == DialogResult.OK)
            {
                Dictionary<string, string> varlinktoDict = new Dictionary<string, string>();
                foreach (string varlinkto in File.ReadAllLines(openFileDialogLoadTXT.FileName))
                {
                    string[] varlinktos = varlinkto.Split(new char[] { '|' }, StringSplitOptions.RemoveEmptyEntries);
                    if (varlinktos.Length == 2)
                    {
                        varlinktoDict[varlinktos[0]] = varlinktos[1];
                    }
                }
                foreach (DataGridViewRow row in dataGridViewMissingVars.Rows)
                {
                    string missingvarname = row.Cells[0].Value.ToString();
                    if (varlinktoDict.ContainsKey(missingvarname))
                    {
                        row.Cells[1].Value = varlinktoDict[missingvarname];
                    }
                }
            }

        }

        private void toolStripComboBoxIgnoreVersion_SelectedIndexChanged(object sender, EventArgs e)
        {
            FillMissVarGridView();
        }

        private void dataGridViewDependent_CellContentClick(object sender, DataGridViewCellEventArgs e)
        {
            if (dataGridViewDependent.Columns[e.ColumnIndex].Name == "ColumnLocate" && e.RowIndex >= 0)
            {
                string dependentName = dataGridViewDependent.Rows[e.RowIndex].Cells["ColumnDependentName"].Value.ToString();
                if (dependentName.StartsWith("\\"))
                {
                    dependentName = dependentName.Substring(1);
                    try
                    {
                        BackendSession.RunJob("vars_locate", new { path = dependentName.Replace('/', '\\') }, LogBackendLine, CancellationToken.None);
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Locate failed: {ex.Message}");
                    }
                }
                else
                {
                    if (Form1.ComplyVarName(dependentName))
                    {
                        form1.LocateVar(dependentName);
                        form1.SelectVarInList(dependentName);
                        form1.Activate();
                    }
                }

            }
        }

        private void varsDataGridView_CellContentClick(object sender, DataGridViewCellEventArgs e)
        {
            if (varsDataGridView.Columns[e.ColumnIndex].Name == "ColumnLocateExistVar" && e.RowIndex >= 0)
            {
                string varName = varsDataGridView.Rows[e.RowIndex].Cells["dataGridViewTextBoxColumnvarName"].Value.ToString();
                form1.LocateVar(varName);
                form1.SelectVarInList(varName);
               
                form1.Activate();
            }
        }
    }
}
