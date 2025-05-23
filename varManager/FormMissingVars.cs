﻿using SimpleJSON;
using System;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows.Forms;
using varManager.Properties;

namespace varManager
{
    public partial class FormMissingVars : Form
    {
        private static string missingVarLinkDirName = "___MissingVarLink___";
        private List<string> missingVars;
        public Form1 form1;
        Dictionary<string, string> downloadUrls = new Dictionary<string, string>();
        Dictionary<string, string> downloadUrlsNoVersion = new Dictionary<string, string>();
        
        static string vam_download_exe = "vam_downloader.exe";
        static string vam_download_path = Path.Combine(".\\plugin\\", vam_download_exe);
        static string vam_download_save_path = Path.Combine(Settings.Default.vampath, "AddonPackages");
        
        public FormMissingVars()
        {
            InitializeComponent();
        }

        public List<string> MissingVars { get => missingVars; set => missingVars = value; }
        public static string MissingVarLinkDirName { get => missingVarLinkDirName; set => missingVarLinkDirName = value; }

        private void FormMissingVars_Load(object sender, EventArgs e)
        {
            Directory.CreateDirectory(Path.Combine(Settings.Default.vampath, "AddonPackages", missingVarLinkDirName));
            // TODO: 这行代码将数据加载到表“varManagerDataSet.vars”中。您可以根据需要移动或删除它。
            this.varsTableAdapter.Fill(this.varManagerDataSet.vars);
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
            // 3. Create a temporary file to store URLs
            string tempFilePath = string.Empty;
            try
            {
                tempFilePath = Path.GetTempFileName(); // Creates a 0-byte file with a unique name
                File.WriteAllLines(tempFilePath, allUrlsToDownload);
                // 4. Prepare to call the external downloader
                string execPath = vam_download_path; // Your downloader executable path
                if (!File.Exists(execPath))
                {
                    MessageBox.Show($"Downloader executable not found: {execPath}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }
                // The downloader now takes the temp file path as the "URL" argument
                // The second argument is still the save path
                string arguments = $"\"{tempFilePath}\" \"{vam_download_save_path}\"";
                // 5. Execute the downloader process
                var startInfo = new System.Diagnostics.ProcessStartInfo
                {
                    FileName = execPath,
                    Arguments = arguments,
                    WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory, // Or specify another working directory if needed
                    // UseShellExecute = false, // Set to true if you want to see the downloader's window and it's a GUI app
                    // CreateNoWindow = true,  // Set to false if UseShellExecute is true or you want to see a console window
                };
                
                // Decide on UseShellExecute based on your downloader.
                // If it's a console app and you want to hide it and manage output, UseShellExecute = false.
                // If it's a GUI app or you want Windows to handle opening it, UseShellExecute = true.
                // For simplicity and consistency with your single download, let's assume it can run visibly or non-visibly.
                // If your single download code has specific settings for RedirectStandardOutput etc., mirror them if appropriate.
                // For now, let's assume a simple launch.
                
                using (var process = System.Diagnostics.Process.Start(startInfo))
                {
                    // You might want to make this asynchronous if downloads take a long time
                    // For now, we wait synchronously
                    process.WaitForExit(); 
                    if (process.ExitCode == 0)
                    {
                        MessageBox.Show($"All {allUrlsToDownload.Count} items have been queued for download.\n" +
                                        "Download process complete. Please click the 'UPD_DB' button to update the database after downloads finish.",
                                        "Download All Complete, Don't Need Repeat Download", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    }
                    else
                    {
                        MessageBox.Show($"Download All process failed with exit code: {process.ExitCode}.\n" +
                                        $"Arguments: {arguments}",
                                        "Download Occur Error, But there may has particular var file download success, you need manually check it !", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"An error occurred during the Download All process: {ex.Message}",
                                "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                // 6. Clean up the temporary file
                if (!string.IsNullOrEmpty(tempFilePath) && File.Exists(tempFilePath))
                {
                    try
                    {
                        File.Delete(tempFilePath);
                    }
                    catch (IOException ioEx)
                    {
                        // Log or inform user that temp file couldn't be deleted
                        Console.WriteLine($"Warning: Could not delete temporary file {tempFilePath}: {ioEx.Message}");
                    }
                }
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
            string packages = string.Join(",", missingVars);
            var reponse = await FindPackages(packages);
            JSONNode jsonResult = JSON.Parse(reponse);
            JSONClass packageArray = jsonResult["packages"] as JSONClass;
            if (packageArray.Count > 0)
            {
                foreach (var package in packageArray.Childs)
                {
                    string downloadurl = package["downloadUrl"];
                    string filename = package["filename"];
                    if (!string.IsNullOrEmpty(downloadurl) && downloadurl != "null")
                    {
                        int fileIndex = downloadurl.IndexOf("?file=");
                        if (fileIndex == -1 || (fileIndex != -1 && downloadurl.Length > fileIndex + 6))
                        {
                            if (!string.IsNullOrEmpty(filename) && filename != "null")
                            {
                                filename = filename.Substring(0, filename.IndexOf(".var"));
                                if (!form1.FindByvarName(filename))
                                {
                                    //if (!downloadUrls.ContainsKey(filename))
                                    downloadUrls[filename] = downloadurl;
                                    downloadUrlsNoVersion[filename.Substring(0, filename.LastIndexOf('.'))] = downloadurl;
                                }
                            }
                        }
                    }
                }
                //downloadurls = downloadurls.Distinct();
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
            var creators = this.varManagerDataSet.vars.GroupBy(g => g.creatorName);
            if (textBoxFilter.Text.Trim() != "")
                creators = this.varManagerDataSet.vars.Where(q => q.varName.ToLower().IndexOf(textBoxFilter.Text.Trim().ToLower()) >= 0).GroupBy(g => g.creatorName);
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

        private void dataGridViewMissingVars_CellContentClick(object sender, DataGridViewCellEventArgs e)
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
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = url,
                        UseShellExecute = true
                    };
                    Process.Start(psi);
                }
                catch (Exception ex)
                {
                    MessageBox.Show("An error occurred trying to start process: " + ex.Message);
                }
            }
            if (e.ColumnIndex == 4)
            {
                string varname = dataGridViewMissingVars.Rows[e.RowIndex].Cells[0].Value.ToString();
                string varnameNoVersion = varname.Substring(0, varname.LastIndexOf('.'));
                string execPath = vam_download_path;
                
                if (!File.Exists(execPath))
                {
                    MessageBox.Show($"Executable not found: {execPath}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }
                
                if (downloadUrls.TryGetValue(varname, out var var_url))
                {
                    // // For Debug
                    // MessageBox.Show("All has "+downloadUrls.Count+" Missing var, Now find this :\n" 
                    //                 + varname + " fetch link: " + var_url);
                    string arguments = $"\"{var_url}\" \"{vam_download_save_path}\"";

                    try
                    {
                        var startInfo = new System.Diagnostics.ProcessStartInfo
                        {
                            FileName = execPath,
                            Arguments = arguments,
                            WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory,
                            // RedirectStandardOutput = true,
                            // RedirectStandardError = true,
                            // UseShellExecute = false,
                            // CreateNoWindow = false
                        };

                        using (var process = System.Diagnostics.Process.Start(startInfo))
                        {
                            process.WaitForExit();

                            if (process.ExitCode != 0)
                            {
                                MessageBox.Show($"Download {varname} from:\n{var_url}\nto {vam_download_save_path} failed with exit code: {process.ExitCode}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Failed to start application. ExecPath: {execPath}, Arguments: {arguments}, Error: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    }
                }
                else if (downloadUrlsNoVersion.TryGetValue(varnameNoVersion, out var var_noversion_url))
                {
                    // // For Debug
                    // MessageBox.Show("All has "+downloadUrlsNoVersion.Count+" Missing var, Now find this (version NOT same) :\n" 
                    //                 + varnameNoVersion + " fetch link: " + var_noversion_url);
                    string arguments = $"\"{var_noversion_url}\" \"{vam_download_save_path}\"";

                    try
                    {
                        var startInfo = new System.Diagnostics.ProcessStartInfo
                        {
                            FileName = execPath,
                            Arguments = arguments,
                            WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory,
                            // RedirectStandardOutput = true,
                            // RedirectStandardError = true,
                            // UseShellExecute = false,
                            // CreateNoWindow = false
                        };

                        using (var process = System.Diagnostics.Process.Start(startInfo))
                        {
                            process.WaitForExit();

                            if (process.ExitCode != 0)
                            {
                                MessageBox.Show($"Download {varnameNoVersion} from:\n{var_noversion_url}\nto {vam_download_save_path} failed with exit code: {process.ExitCode}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Failed to start application. ExecPath: {execPath}, Arguments: {arguments}, Error: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
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

        private void buttonOK_Click(object sender, EventArgs e)
        {
            Createlink();

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
                    varManagerDataSet.varsRow varsrow = varManagerDataSet.vars.FindByvarName(destvarname);
                    if (missingvarname.Substring(missingvarname.LastIndexOf('.')) == ".latest")
                    {
                        missingvarname = missingvarname.Substring(0, missingvarname.LastIndexOf('.')) + destvarname.Substring(destvarname.LastIndexOf('.'));
                    }
                    if (varsrow != null)
                    {
                        string missingvar = Path.Combine(Settings.Default.vampath, "AddonPackages", missingVarLinkDirName, missingvarname + ".var");
                        string destvarfile = Path.Combine(Settings.Default.varspath, varsrow.varPath, varsrow.varName + ".var");
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
                List<string> varNames = new List<string>();
                foreach (var varstatus in this.varManagerDataSet.installStatus)
                {
                    if (varstatus.Installed) varNames.Add(varstatus.varName);
                }
                File.WriteAllLines(saveFileDialogSaveTxt.FileName, varNames.ToArray());
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
                    string destsavedfile = Path.Combine(Settings.Default.vampath, dependentName);
                    Comm.LocateFile(destsavedfile);

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
