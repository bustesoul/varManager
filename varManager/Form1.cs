using DgvFilterPopup;
using ICSharpCode.SharpZipLib.Zip;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Drawing;
using System.IO;
//using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using varManager.Backend;
using varManager.Data;
using varManager.Models;
using varManager.Properties;
using SimpleJSON;
using static SimpleLogger;

namespace varManager
{
    public partial class Form1 : Form
    {
        private record PreviewUninstallResult(List<string> var_list, List<string> requested, List<string> implicated);

        private static readonly byte[] s_creatorNameUtf8 = Encoding.UTF8.GetBytes("creatorName");
        //private static ReadOnlySpan<byte> Utf8Bom => new byte[] { 0xEF, 0xBB, 0xBF };
        private static SimpleLogger simpLog = new SimpleLogger();
        private static string tidiedDirName = "___VarTidied___";
        private static string redundantDirName = "___VarRedundant___";
        private static string notComplyRuleDirName = "___VarnotComplyRule___";
        private static string previewpicsDirName = "___PreviewPics___";
        private static string staleVarsDirName = "___StaleVars___";
        private static string oldVersionVarsDirName = "___OldVersionVars___";
        private static string deleVarsDirName = "___DeletedVars___";

        private static string addonPacksSwitch = "___AddonPacksSwitch ___";

        private static string installLinkDirName = "___VarsLink___";
        private static string missingVarLinkDirName = "___MissingVarLink___";
        private static string tempVarLinkDirName = "___TempVarLink___";
        private InvokeAddLoglist addlog;
        private readonly CancellationTokenSource backendCts = new CancellationTokenSource();
        private readonly ThreadLocal<VarManagerContext> _dbContext =
            new ThreadLocal<VarManagerContext>(() => new VarManagerContext(), true);
        private VarManagerContext dbContext => _dbContext.Value!;
        public Form1()
        {
            InitializeComponent();
            addlog = new InvokeAddLoglist(UpdateAddLoglist);
        }

        private void buttonSetting_Click(object sender, EventArgs e)
        {
            OpenSetting();
        }

        private static void OpenSetting()
        {
            using FormSettings formSettings = new FormSettings();
            formSettings.ShowDialog();
        }

        public static bool ComplyVarFile(string varfile)
        {
            string varfilename = Path.GetFileNameWithoutExtension(varfile);
            return ComplyVarName(varfilename);
        }

        public static bool ComplyVarName(string varname)
        {
            string[] varnamepart = varname.Split('.');

            if (varnamepart.Length == 3)
            {
                //int version = 0;
                if (Regex.IsMatch(varnamepart[2], "^[0-9]+$"))
                //if (int.TryParse(varnamepart[2], out version))
                {
                    return true;
                }
            }
            return false;
        }

        private List<string> varsForInstall = new List<string>();
        private void TidyVars()
        {
            List<string> vars = GetVarspathVars();
            List<string> varsUsed = GetAddonpackagesVars();
            varsForInstall.Clear();
            if (File.Exists("varsForInstall.txt"))
                varsForInstall.AddRange(File.ReadAllLines("varsForInstall.txt"));
            foreach (var varins in varsUsed)
            {
                if (ComplyVarFile(varins))
                    varsForInstall.Add(Path.GetFileNameWithoutExtension(varins));
            }
            File.Delete("varsForInstall.txt");
            varsForInstall = varsForInstall.Distinct().ToList();
            File.WriteAllLines("varsForInstall.txt", varsForInstall);

            vars.AddRange(varsUsed);

            TidyVars(vars);
            // System.Diagnostics.Process.Start(tidypath);
        }

  
        private void TidyVars(List<string> vars)
        {
            string tidypath = Path.Combine(Settings.Default.varspath, tidiedDirName);
            if (!Directory.Exists(tidypath))
                Directory.CreateDirectory(tidypath);
            string redundantpath = Path.Combine(Settings.Default.varspath, redundantDirName);
            if (!Directory.Exists(redundantpath))
                Directory.CreateDirectory(redundantpath);
            string notComplRulepath = Path.Combine(Settings.Default.varspath, notComplyRuleDirName);
            if (!Directory.Exists(notComplRulepath))
                Directory.CreateDirectory(notComplRulepath);
            InvokeProgress mi = new InvokeProgress(UpdateProgress);
            this.BeginInvoke(addlog, new Object[] { "Tidy Vars...", LogLevel.INFO });
            int curVarfile = 0;
            foreach (string varfile in vars)
            {
                if (!File.Exists(varfile))
                {
                    this.BeginInvoke(mi, new Object[] { curVarfile, vars.Count() });
                    curVarfile++;
                    continue;
                }
                if (ComplyVarFile(varfile))
                {
                    FileInfo pathInfo = new FileInfo(varfile);
                    string varfilename = Path.GetFileNameWithoutExtension(varfile);
                    //if (pathInfo.Attributes.HasFlag(FileAttributes.ReparsePoint))
                    //{
                    //string errlog = $"{varfile} is a symlink,Please check and process it appropriately";
                    //this.BeginInvoke(addlog, new Object[] { errlog,LogLevel.ERROR });
                    //varsForInstall.Remove(varfilename);
                    //continue;
                    //}

                    string[] varnamepart = varfilename.Split('.');
                    string createrpath = Path.Combine(tidypath, varnamepart[0]);
                    if (!Directory.Exists(createrpath))
                        Directory.CreateDirectory(createrpath);
                    string destvarfilename = Path.Combine(createrpath, Path.GetFileName(varfile));
                    if (File.Exists(destvarfilename))
                    {
                        string errlog = $"{varfile} has same filename in tidy directory,moved into the {redundantDirName} directory";
                        this.BeginInvoke(addlog, new Object[] { errlog ,LogLevel.WARNING});
                        string redundantfilename = Path.Combine(redundantpath, Path.GetFileName(varfile));

                        int count = 1;

                        string fileNameOnly = Path.GetFileNameWithoutExtension(redundantfilename);
                        string extension = Path.GetExtension(redundantfilename);
                        string path = Path.GetDirectoryName(redundantfilename);

                        while (File.Exists(redundantfilename))
                        {
                            string tempFileName = string.Format("{0}({1})", fileNameOnly, count++);
                            redundantfilename = Path.Combine(path, tempFileName + extension);
                        }

                        try
                        {
                            File.Move(varfile, redundantfilename);
                        }
                        catch (Exception ex)
                        {
                            this.BeginInvoke(addlog, new Object[] { $"move {varfile} failed, {ex.Message}", LogLevel.ERROR });
                        }
                    }
                    else
                    {
                        try
                        {
                            File.Move(varfile, destvarfilename);
                        }
                        catch (Exception ex)
                        {
                            this.BeginInvoke(addlog, new Object[] { $"move {varfile} failed, {ex.Message}" ,LogLevel.ERROR });
                        }
                        //OpenAsZip(destvarfilename);
                    }
                }
                else
                {
                    string errlog = $"{varfile} not comply Var filename rule, move into {notComplyRuleDirName} directory";
                    this.BeginInvoke(addlog, new Object[] { errlog, LogLevel.ERROR });
                    string notComplRulefilename = Path.Combine(notComplRulepath, Path.GetFileName(varfile));

                    int count = 1;

                    string fileNameOnly = Path.GetFileNameWithoutExtension(notComplRulefilename);
                    string extension = Path.GetExtension(notComplRulefilename);
                    string path = Path.GetDirectoryName(notComplRulefilename);

                    while (File.Exists(notComplRulefilename))
                    {
                        string tempFileName = string.Format("{0}({1})", fileNameOnly, count++);
                        notComplRulefilename = Path.Combine(path, tempFileName + extension);
                    }
                    try
                    {
                        File.Move(varfile, notComplRulefilename);
                    }
                    catch (Exception ex)
                    {
                        this.BeginInvoke(addlog, new Object[] { $"move {varfile} failed, {ex.Message}", LogLevel.ERROR });
                    }
                }
                this.BeginInvoke(mi, new Object[] { curVarfile, vars.Count() });
                curVarfile++;
            }
        }

        private static List<string> GetVarspathVars()
        {
            List<string> varspathVars = new List<string>();
            foreach (var varins in Directory.GetFiles(Settings.Default.varspath, "*.var", SearchOption.AllDirectories)
                           .Where(q => q.IndexOf(tidiedDirName) == -1
                           && q.IndexOf(redundantDirName) == -1
                           && q.IndexOf(notComplyRuleDirName) == -1
                           && q.IndexOf(staleVarsDirName) == -1
                           && q.IndexOf(oldVersionVarsDirName) == -1
                           && q.IndexOf(deleVarsDirName) == -1))
            {
                FileInfo pathInfo = new FileInfo(varins);
                if (!pathInfo.Attributes.HasFlag(FileAttributes.ReparsePoint))
                {
                    varspathVars.Add(varins);
                }
            }
            return varspathVars;
        }

        private static bool ExistAddonpackagesVar()
        {
            string installlinkdir = Path.Combine(Settings.Default.vampath, "AddonPackages", installLinkDirName);

            bool exist = false;
            foreach (var varins in Directory.GetFiles(Path.Combine(Settings.Default.vampath, "AddonPackages"), "*.var", SearchOption.AllDirectories)
                          .Where(q => q.IndexOf(installlinkdir) == -1 && q.IndexOf(missingVarLinkDirName) == -1 && q.IndexOf(tempVarLinkDirName) == -1))
            {
                FileInfo pathInfo = new FileInfo(varins);
                if (!pathInfo.Attributes.HasFlag(FileAttributes.ReparsePoint))
                {
                    exist = true;
                    break;
                }
            }
            return exist;
        }

        private static List<string> GetAddonpackagesVars()
        {
            string installlinkdir = Path.Combine(Settings.Default.vampath, "AddonPackages", installLinkDirName);

            List<string> varsUsed = new List<string>();
            foreach (var varins in Directory.GetFiles(Path.Combine(Settings.Default.vampath, "AddonPackages"), "*.var", SearchOption.AllDirectories)
                          .Where(q => q.IndexOf(installlinkdir) == -1 && q.IndexOf(missingVarLinkDirName) == -1 && q.IndexOf(tempVarLinkDirName) == -1))
            {
                FileInfo pathInfo = new FileInfo(varins);
                if (!pathInfo.Attributes.HasFlag(FileAttributes.ReparsePoint))
                {
                    varsUsed.Add(varins);
                }
            }
            return varsUsed;
        }

        private List<string> Getdependencies(string jsonstring)
        {
            string dependencies = "";
            List<string> dependenciesList = new List<string>();
            try
            {
                //JsonDocument jsondoc = JsonDocument.Parse(jsonstring);
                // dependencies = jsondoc.RootElement.GetProperty("dependencies").GetRawText().ToString();
                dependencies = jsonstring;
                Regex regexObj = new Regex(@"\x22(([^\r\n\x22\x3A\x2E]{1,60})\x2E([^\r\n\x22\x3A\x2E]{1,80})\x2E(\d+|latest))(\x22?\s*)\x3A", RegexOptions.IgnoreCase | RegexOptions.Singleline);
                Match matchResults = regexObj.Match(dependencies);
                while (matchResults.Success)
                {
                    Group groupObj = matchResults.Groups[1];
                    if (groupObj.Success)
                    {
                        string depstr = groupObj.Value;
                        if (depstr.IndexOf('/') > 0)
                            depstr = depstr.Substring(depstr.IndexOf('/') + 1);
                        dependenciesList.Add(depstr);
                        // match start: groupObj.Index
                        // match length: groupObj.Length
                    }

                    matchResults = matchResults.NextMatch();
                }
                dependenciesList = dependenciesList.Distinct().ToList();
            }
            catch
            {
                throw;
            }
            return dependenciesList;
        }
        
        private bool Varislatest(string varname)
        {
            var parts = varname.Split('.');
            if (parts.Length != 3) return true;
            if (!int.TryParse(parts[2], out var version)) return true;

            var versions = dbContext.Vars
                .Where(q => q.CreatorName == parts[0] && q.PackageName == parts[1])
                .Select(q => q.Version)
                .ToList()
                .Where(v => int.TryParse(v, out _))
                .Select(v => int.Parse(v));

            if (!versions.Any()) return true;

            return version >= versions.Max();
        }
        private int VarCountVersion(string varname)
        {
            int countversion = 0;
            string[] varnamepart = varname.Split('.');
            if (varnamepart.Length == 3)
            {
                countversion = dbContext.Vars.Where(q => q.CreatorName == varnamepart[0] && q.PackageName == varnamepart[1]).Count();

            }
            return countversion;
        }

        private List<string> ImplicatedVar(string varname)
        {
            List<string> varnames = new List<string>();
            if (VarCountVersion(varname) <= 1)
            {
                if (Varislatest(varname))
                {
                    string latest = varname.Substring(0, varname.LastIndexOf('.')) + ".latest";
                    foreach (var row in dbContext.Dependencies.Where(q => q.DependencyName == varname || q.DependencyName == latest))
                    {
                        varnames.Add(row.VarName!);
                    }
                }
                else
                {
                    foreach (var row in dbContext.Dependencies.Where(q => q.DependencyName == varname))
                    {
                        varnames.Add(row.VarName!);
                    }
                }
            }
            return varnames;
        }

        private List<string> DependentVars(string varname)
        {
            List<string> varnames = new List<string>();

            if (Varislatest(varname))
            {
                string latest = varname.Substring(0, varname.LastIndexOf('.')) + ".latest";
                foreach (var row in dbContext.Dependencies.Where(q => q.DependencyName == varname || q.DependencyName == latest))
                {
                    varnames.Add(row.VarName!);
                }
            }
            else
            {
                foreach (var row in dbContext.Dependencies.Where(q => q.DependencyName == varname))
                {
                    varnames.Add(row.VarName!);
                }
            }
            
            return varnames;
        }
        private List<string> DependentSaved(string varname)
        {
            List<string> saveds = new List<string>();
            
            if (Varislatest(varname))
            {
                string latest = varname.Substring(0, varname.LastIndexOf('.')) + ".latest";
                var savedDepsLatest = dbContext.SavedDependencies
                    .Where(q => q.DependencyName == latest)
                    .ToList();
                foreach (var row in savedDepsLatest)
                {
                    saveds.Add(row.VarName!);
                }
            }

            var savedDeps = dbContext.SavedDependencies
                .Where(q => q.DependencyName == varname)
                .ToList();
            foreach (var row in savedDeps)
            {
                saveds.Add(row.VarName!);
            }
            saveds = saveds.Distinct().ToList();
            return saveds;
        }
        private List<string> ImplicatedVars(List<string> varnames)
        {
            List<string> varnameexist = new List<string>();
            List<string> varsProccessed = new List<string>();
            List<string> varimplics = new List<string>();
            foreach (string varname in varnames)
            {
                if (varname[varname.Length - 1] == '^')
                    varsProccessed.Add(varname.Substring(0, varname.Length - 1));
                else
                    varnameexist.Add(varname);
            }

            foreach (string varname in varnameexist)
            {
                varimplics.AddRange(ImplicatedVar(varname));
            }
            varsProccessed.AddRange(varnameexist);
            varimplics = varimplics.Distinct().Except(varsProccessed).ToList();
            if (varimplics.Count() > 0)
            {
                foreach (string varname in varsProccessed)
                {
                    varimplics.Add(varname + "^");
                }
                return ImplicatedVars(varimplics);
            }
            else
            {
                varsProccessed = varsProccessed.Select(q => q.Trim('^')).Distinct().ToList();
                return varsProccessed;
            }
        }

        private void DelePreviewPics(string varname)
        {
            string[] typenames = { "scenes", "looks", "hairstyle", "clothing", "assets","morphs","skin","pose"};
            foreach (string typename in typenames)
            {
                string typepath = Path.Combine(Settings.Default.varspath, previewpicsDirName, typename, varname);
                if (Directory.Exists(typepath))
                {
                    try
                    {
                        Directory.Delete(typepath, true);
                    }
                    catch
                    {
                        throw;
                    }
                }
            }
        }

        private void UnintallVars(List<string> varnames)
        {
            //FillInstalledDependencies();
            List<string> varimplics = ImplicatedVars(varnames);

            FormUninstallVars formUninstallVars = new FormUninstallVars();
            formUninstallVars.previewpicsDirName = previewpicsDirName;
            foreach (string varname in varimplics)
            {
                foreach (var row in dbContext.VarsView.Where(q => q.VarName == varname && q.Installed))
                {
                    // Convert to appropriate format for the uninstall form
                    // This will need to be adapted based on FormUninstallVars requirements
                }
            }
            if (formUninstallVars.ShowDialog() == DialogResult.OK)
            {
                var installedvars = GetInstalledVars();
                foreach (string varname in varimplics)
                {
                    string linkvar;
                    if (installedvars.TryGetValue(varname, out linkvar))
                        if (File.Exists(linkvar))
                        {
                            File.Delete(linkvar);
                            this.BeginInvoke(addlog, new Object[] { $"{varname} is uninstalled.", LogLevel.INFO });

                        }
                }
            }
        }
        public string getVarFilePath(string varname)
        {
            string varfilepath = "";
            var varRow = dbContext.Vars.FirstOrDefault(v => v.VarName == varname);
            if (varRow != null)
            {
                varfilepath = Path.Combine(Settings.Default.varspath, varRow.VarPath!, varRow.VarName + ".var");
            }
            return varfilepath;
        }

        private void DeleteVars(List<string> varnames)
        {
            // FillInstalledDependencies();
            List<string> varimplics = ImplicatedVars(varnames);

            FormUninstallVars formUninstallVars = new FormUninstallVars();
            formUninstallVars.operationType = "delete";
            formUninstallVars.deleVarsDirName = deleVarsDirName;
            formUninstallVars.previewpicsDirName = previewpicsDirName;
            foreach (string varname in varimplics)
            {
                foreach (var row in dbContext.VarsView.Where(q => q.VarName == varname))
                {
                    // Convert to appropriate format for the uninstall form
                    // This will need to be adapted based on FormUninstallVars requirements
                }
            }
            if (formUninstallVars.ShowDialog() == DialogResult.OK)
            {
                string delevarspath = Path.Combine(Settings.Default.varspath, deleVarsDirName);
                if (!Directory.Exists(delevarspath))
                    Directory.CreateDirectory(delevarspath);

                var installedvars = GetInstalledVars();
                foreach (string varname in varimplics)
                {
                    string linkvar;
                    if (installedvars.TryGetValue(varname, out linkvar))
                        if (File.Exists(linkvar))
                            File.Delete(linkvar);

                    var row = dbContext.Vars.FirstOrDefault(v => v.VarName == varname);
                    if (row == null)
                    {
                        this.BeginInvoke(addlog, new Object[] { $"{varname} record not found, skip delete.", LogLevel.WARNING });
                        continue;
                    }
                    string operav = Path.Combine(Settings.Default.varspath, row.VarPath!, varname + ".var");
                    string deletedv = Path.Combine(delevarspath, varname + ".var");
                    try
                    {
                        File.Move(operav, deletedv);
                        CleanVar(varname);
                    }
                    catch (Exception ex)
                    {
                        this.BeginInvoke(addlog, new Object[] { $"{operav} move failed,{ex.Message}", LogLevel.ERROR });
                    }
                }
            }

        }
        private DataTable CreateVarsViewDataTable()
        {
            var dataTable = new DataTable("varsView");
            
            // Add columns matching the VarsView entity properties
            dataTable.Columns.Add("varName", typeof(string));
            dataTable.Columns.Add("Installed", typeof(bool));
            dataTable.Columns.Add("fsize", typeof(double));
            dataTable.Columns.Add("varPath", typeof(string));
            dataTable.Columns.Add("creatorName", typeof(string));
            dataTable.Columns.Add("packageName", typeof(string));
            dataTable.Columns.Add("version", typeof(string));
            dataTable.Columns.Add("metaDate", typeof(DateTime));
            dataTable.Columns.Add("varDate", typeof(DateTime));
            dataTable.Columns.Add("scenes", typeof(int));
            dataTable.Columns.Add("looks", typeof(int));
            dataTable.Columns.Add("clothing", typeof(int));
            dataTable.Columns.Add("hairstyle", typeof(int));
            dataTable.Columns.Add("plugins", typeof(int));
            dataTable.Columns.Add("assets", typeof(int));
            dataTable.Columns.Add("morphs", typeof(int));
            dataTable.Columns.Add("pose", typeof(int));
            dataTable.Columns.Add("skin", typeof(int));
            dataTable.Columns.Add("Disabled", typeof(bool));
            
            // Fill with data from EF Core
            var varsViewData = dbContext.VarsView.ToList();
            foreach (var item in varsViewData)
            {
                dataTable.Rows.Add(
                    item.VarName,
                    item.Installed,
                    item.Fsize,
                    item.VarPath,
                    item.CreatorName,
                    item.PackageName,
                    item.Version,
                    item.MetaDate,
                    item.VarDate,
                    item.Scenes,
                    item.Looks,
                    item.Clothing,
                    item.Hairstyle,
                    item.Plugins,
                    item.Assets,
                    item.Morphs,
                    item.Pose,
                    item.Skin,
                    item.Disabled
                );
            }
            
            return dataTable;
        }

        private DataSet CreateVarsDataSet()
        {
            var dataSet = new DataSet();
            dataSet.Tables.Add(CreateVarsViewDataTable());
            return dataSet;
        }
        private DgvFilterManager dgvFilterManager;
        private Dictionary<string, string> GetInstalledVars()
        {
            Dictionary<string, string> installedVars = new Dictionary<string, string>();
            DirectoryInfo dilink = Directory.CreateDirectory(Path.Combine(Settings.Default.vampath, "AddonPackages", installLinkDirName));
            foreach (string varfile in Directory.GetFiles(Path.Combine(Settings.Default.vampath, "AddonPackages", installLinkDirName), "*.var", SearchOption.AllDirectories))
            {
                FileInfo fileInfo = new FileInfo(varfile);
                if (fileInfo.Attributes.HasFlag(FileAttributes.ReparsePoint))
                {
                    installedVars[Path.GetFileNameWithoutExtension(varfile)] = varfile;
                }
            }
            foreach (string varfile in Directory.GetFiles(Path.Combine(Settings.Default.vampath, "AddonPackages"), "*.var", SearchOption.TopDirectoryOnly))
            {
                FileInfo fileInfo = new FileInfo(varfile);
                if (fileInfo.Attributes.HasFlag(FileAttributes.ReparsePoint))
                {
                    installedVars[Path.GetFileNameWithoutExtension(varfile)] = varfile;
                }
            }
            return installedVars;
        }
        private void UpdateVarsInstalled()
        {
            bool mutexAcquired = false;
            try
            {
                // Ensure DbContext is properly initialized
                if (dbContext.Database.CanConnect())
                {
                    // Clear existing install status data using EF Core
                    dbContext.InstallStatuses.RemoveRange(dbContext.InstallStatuses);
                    
                    mutex.WaitOne();
                    mutexAcquired = true;
                    
                    foreach (string varfile in GetInstalledVars().Values)
                    {
                        string varName = Path.GetFileNameWithoutExtension(varfile);
                        if (dbContext.Vars.Any(v => v.VarName == varName))
                        {
                            bool isdisable = File.Exists(varfile + ".disabled");
                            dbContext.InstallStatuses.Add(new InstallStatus 
                            { 
                                VarName = varName, 
                                Installed = true, 
                                Disabled = isdisable 
                            });
                        }
                    }

                    dbContext.SaveChanges();
                    
                    InvokeUpdateVarsViewDataGridView invokeUpdateVarsViewDataGridView = new InvokeUpdateVarsViewDataGridView(UpdateVarsViewDataGridView);
                    this.BeginInvoke(invokeUpdateVarsViewDataGridView);
                    //varsViewDataGridView.Update();
                }
            }
            catch (Exception ex)
            {
                this.BeginInvoke(addlog, new Object[] { $"Error updating vars installed: {ex.Message}", LogLevel.ERROR });
            }
            finally
            {
                if (mutexAcquired)
                {
                    mutex.ReleaseMutex();
                }
            }
        }

        private Mutex mutex;
        private System.Threading.Mutex mut = new Mutex();

        
        private async void Form1_Load(object sender, EventArgs e)
        {
            this.Text = "VarManager  v" + Assembly.GetEntryAssembly().GetName().Version.ToString();
            UseWaitCursor = true;
            Enabled = false;
            if (!await EnsureBackendReadyAsync().ConfigureAwait(true))
            {
                Close();
                return;
            }
            UseWaitCursor = false;
            Enabled = true;

            if (string.IsNullOrWhiteSpace(Settings.Default.vampath) ||
                string.IsNullOrWhiteSpace(Settings.Default.varspath))
            {
                MessageBox.Show("后端配置缺少 varspath 或 vampath，请编辑 config.json 后重启。");
                OpenSetting();
                Close();
                return;
            }

            if (!File.Exists(Path.Combine(Settings.Default.vampath, "VaM.exe")))
            {
                MessageBox.Show("vampath 无效，请编辑 config.json 后重启。");
                OpenSetting();
                Close();
                return;
            }
            mutex = new System.Threading.Mutex();

            var (dbPath, provider) = VarManagerContext.GetDatabaseInfo();
            this.BeginInvoke(addlog, new Object[] { $"DB config: {dbPath} | Provider: {provider}", LogLevel.INFO });
            this.BeginInvoke(addlog, new Object[] { $"Backend config: varspath={Settings.Default.varspath}, vampath={Settings.Default.vampath}", LogLevel.INFO });
            
            // Set the sort after data source initialization to avoid .NET 9 issues
            try
            {
                if (varsViewBindingSource.DataSource != null)
                {
                    varsViewBindingSource.Sort = "metaDate Desc";
                }
            }
            catch { /* Ignore sorting errors during initialization */ }
            
            backgroundWorkerInstall.RunWorkerAsync("FillDataTables");
            //
            string varspath = new DirectoryInfo(Settings.Default.varspath).FullName.ToLower();
            string packpath = new DirectoryInfo(Path.Combine(Settings.Default.vampath, "AddonPackages")).FullName;

            string packsSwitchpath = new DirectoryInfo(Path.Combine(Settings.Default.vampath, addonPacksSwitch)).FullName.ToLower();
            if (varspath == packpath)
            {
                MessageBox.Show("Vars Path can't be {VamInstallDir}\\AddonPackages");
                OpenSetting();
            }
            comboBoxPreviewType.SelectedIndex = 0;
           


            DirectoryInfo dipacksswitch = Directory.CreateDirectory(packsSwitchpath);
            DirectoryInfo[] packswitchdirs = dipacksswitch.GetDirectories("*", SearchOption.TopDirectoryOnly);
            List<string> packnames = new List<string>();
            foreach (DirectoryInfo dipack in packswitchdirs)
            {
                packnames.Add(dipack.Name);
            }
            if (packnames.IndexOf("default") == -1)
            {
                Directory.CreateDirectory(Path.Combine(packsSwitchpath, "default"));
                packnames.Add("default");
            }
            comboBoxPacksSwitch.Items.Add("default");
            foreach (string packname in packnames)
            {
                if (packname != "default")
                    comboBoxPacksSwitch.Items.Add(packname);
            }

            string currentSwitch = "default";
            try
            {
                DirectoryInfo diswitch = new DirectoryInfo(Comm.ReparsePoint(packpath));
                if (diswitch.Exists)
                {
                    currentSwitch = diswitch.Name;
                }
            }
            catch (Exception ex)
            {
                this.BeginInvoke(addlog, new Object[] { $"Warning: {ex.Message}", LogLevel.INFO });
            }

            if (comboBoxPacksSwitch.Items.IndexOf(currentSwitch) >= 0)
            {
                comboBoxPacksSwitch.SelectedItem = currentSwitch;
            }
            else
            {
                comboBoxPacksSwitch.SelectedItem = "default";
            }

            try
            {
                RunBackendJob("refresh_install_status", null);
            }
            catch (Exception ex)
            {
                this.BeginInvoke(addlog, new Object[] { $"刷新安装状态失败: {ex.Message}", LogLevel.ERROR });
            }
            comboBoxCreater.Items.Add("____ALL");
            var creators = dbContext.Vars
                .GroupBy(v => v.CreatorName)
                .Select(g => g.Key)
                .OrderBy(c => c)
                .ToList();
            foreach (var creator in creators)
            {
                comboBoxCreater.Items.Add(creator);
            }
            comboBoxCreater.SelectedIndex = 0;
            //  FillDataTables();
            //TimeSpan ts6 = DateTime.Now - dtstart;
            //dtstart = DateTime.Now;
            //MessageBox.Show($"{ts1.TotalSeconds},{ts2.TotalSeconds},{ts3.TotalSeconds},{ts4.TotalSeconds},{ts5.TotalSeconds},{ts6.TotalSeconds}");
            
            // Initialize DataSource with DataSet for DgvFilterManager compatibility
            var dataSet = CreateVarsDataSet();
            varsViewBindingSource.DataSource = dataSet;
            varsViewBindingSource.DataMember = "varsView";
            dgvFilterManager = new DgvFilterManager(varsViewDataGridView);
            RefreshVarsViewUi();
            if (ExistAddonpackagesVar())
            {
                MessageBox.Show("There are unorganized var files in the current switch, please run UPD_DB first");
                buttonUpdDB.Focus();
            }
        }
        
        private void FillDataTables()
        {
            this.BeginInvoke(addlog, new Object[] { $"load vars...", LogLevel.INFO });
            // EF Core automatically loads data when needed - no explicit Fill required
            
            this.BeginInvoke(addlog, new Object[] { $"load scenes...", LogLevel.INFO });
            // EF Core automatically loads data when needed - no explicit Fill required
            
            this.BeginInvoke(addlog, new Object[] { $"load dependencies...", LogLevel.INFO });
            // EF Core automatically loads data when needed - no explicit Fill required
            
            // Pre-load some critical data for performance
            _ = dbContext.Vars.Count(); // This will initialize the connection
            _ = dbContext.Scenes.Count();
            _ = dbContext.Dependencies.Count();
        }

        public delegate void InvokeUpdateVarsViewDataGridView();
        
        public void UpdateVarsViewDataGridView()
        {
            List<string> selectedRowList = new List<string>();
            foreach (DataGridViewRow item in varsViewDataGridView.SelectedRows)
            {
                selectedRowList.Add(item.Cells[0].Value.ToString());
            }
            varsViewDataGridView.SelectionChanged -= new System.EventHandler(this.varsDataGridView_SelectionChanged);
            
            // Refresh the data by recreating the DataSet for DgvFilterManager compatibility
            var dataSet = CreateVarsDataSet();
            varsViewBindingSource.DataSource = dataSet;
            varsViewBindingSource.DataMember = "varsView";
            varsViewDataGridView.Update();

            int firstindex = int.MaxValue;
            varsViewDataGridView.ClearSelection();
            foreach (DataGridViewRow row in varsViewDataGridView.Rows)
            {
                string varname = row.Cells["varNamedataGridViewTextBoxColumn"].Value.ToString();
                if (selectedRowList.Contains(varname))
                {
                    row.Selected = true;
                    if (row.Index < firstindex) firstindex = row.Index;
                }
            }
            if (firstindex == int.MaxValue) firstindex = 0;
            if (varsViewDataGridView.SelectedRows.Count > 0)
            {
                varsViewDataGridView.FirstDisplayedScrollingRowIndex = firstindex;
            }
            varsViewDataGridView.SelectionChanged += new System.EventHandler(this.varsDataGridView_SelectionChanged);

            mutex.WaitOne();
            UpdatePreviewPics();
            mutex.ReleaseMutex();
            tableLayoutPanelPreview.Visible = false;
        }
        public delegate void InvokeAddLoglist(string message, LogLevel logLevel);

        public void UpdateAddLoglist(string message, LogLevel logLevel)
        {
            string msg = simpLog.WriteFormattedLog(logLevel, message);
            listBoxLog.Items.Add(msg);
            listBoxLog.TopIndex = listBoxLog.Items.Count - 1;
        }

        private async Task<bool> EnsureBackendReadyAsync()
        {
            try
            {
                await BackendSession.EnsureStartedAsync(LogBackendLine, backendCts.Token).ConfigureAwait(true);
                return true;
            }
            catch (Exception ex)
            {
                BeginInvoke(addlog, new Object[] { $"后端启动失败: {ex.Message}", LogLevel.ERROR });
                MessageBox.Show($"后端启动失败: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return false;
            }
        }

        private void LogBackendLine(string line)
        {
            LogLevel level = LogLevel.INFO;
            if (line.StartsWith("error:", StringComparison.OrdinalIgnoreCase))
            {
                level = LogLevel.ERROR;
            }
            BeginInvoke(addlog, new Object[] { line, level });
        }

        private BackendJobResult RunBackendJob(string kind, object? args)
        {
            return BackendSession.RunJob(kind, args, LogBackendLine, backendCts.Token);
        }

        private Task<BackendJobResult> RunBackendJobAsync(string kind, object? args)
        {
            return BackendSession.RunJobAsync(kind, args, LogBackendLine, backendCts.Token);
        }

        private T? DeserializeResult<T>(BackendJobResult result)
        {
            if (!result.Result.HasValue)
            {
                return default;
            }
            return JsonSerializer.Deserialize<T>(result.Result.Value.GetRawText());
        }

        private void ResetDbContext()
        {
            if (_dbContext.IsValueCreated)
            {
                _dbContext.Value?.Dispose();
            }
            _dbContext.Value = new VarManagerContext();
        }

        private void RefreshVarsViewUi()
        {
            ResetDbContext();
            UpdateVarsViewDataGridView();
        }

        private sealed class MissingDepsResult
        {
            [JsonPropertyName("scope")]
            public string Scope { get; set; } = string.Empty;

            [JsonPropertyName("missing")]
            public List<string> Missing { get; set; } = new List<string>();

            [JsonPropertyName("installed")]
            public List<string> Installed { get; set; } = new List<string>();

            [JsonPropertyName("install_failed")]
            public List<string> InstallFailed { get; set; } = new List<string>();

            [JsonPropertyName("dependency_count")]
            public int DependencyCount { get; set; }
        }

        private sealed class DepsJobResult
        {
            [JsonPropertyName("missing")]
            public List<string> Missing { get; set; } = new List<string>();

            [JsonPropertyName("installed")]
            public List<string> Installed { get; set; } = new List<string>();

            [JsonPropertyName("dependency_count")]
            public int DependencyCount { get; set; }
        }

        private sealed class SceneAnalyzeResult
        {
            [JsonPropertyName("var_name")]
            public string VarName { get; set; } = string.Empty;

            [JsonPropertyName("entry_name")]
            public string EntryName { get; set; } = string.Empty;

            [JsonPropertyName("cache_dir")]
            public string CacheDir { get; set; } = string.Empty;

            [JsonPropertyName("character_gender")]
            public string CharacterGender { get; set; } = string.Empty;
        }

        private void buttonClearLog_Click(object sender, EventArgs e)
        {
            listBoxLog.Items.Clear();
        }
        
        public delegate void InvokeProgress(int cur, int total);

        public void UpdateProgress(int cur, int total)
        {
            labelProgress.Text = string.Format("{0}/{1}", cur, total);
            if (total != 0)
            {
                int progressvalue = (int)((float)cur * 100 / (float)total);
                if (progressvalue < 0) progressvalue = 0;
                if (progressvalue >100) progressvalue = 100;

                progressBar1.Value = progressvalue;
            }
               
        }

        public delegate void InvokeShowformMissingVars(List<string> missingvars);

        public void ShowformMissingVars(List<string> missingvars)
        {
            if (missingvars.Count > 0)
            {
                FormMissingVars formMissingVars = new FormMissingVars();
                formMissingVars.form1 = this;
                formMissingVars.MissingVars = missingvars;
                formMissingVars.Show();
            }
        }
        private void buttonUpdDB_Click(object sender, EventArgs e)
        {
            string message = "Will organize vars, extract preview images,update DB. It will take some time, please be patient.";

            const string caption = "UpdateDB";
            var result = MessageBox.Show(message, caption,
                                         MessageBoxButtons.YesNo,
                                         MessageBoxIcon.Question,
                                         MessageBoxDefaultButton.Button1);
            if (result == DialogResult.Yes)
                backgroundWorkerInstall.RunWorkerAsync("UpdDB");
        }
        
        private void buttonStartVam_Click(object sender, EventArgs e)
        {
            string message = "Will start the VAM application. Do you want to continue?";
            const string caption = "Start VAM";
            var result = MessageBox.Show(message, caption,
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question,
                MessageBoxDefaultButton.Button1);
            
            if (result == DialogResult.Yes)
            {
                try
                {
                    RunBackendJob("vam_start", null);
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Failed to start application. Error: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
        }

        private void UpdDB(string destvarfilename)
        {
            try
            {
                string basename = Path.GetFileNameWithoutExtension(destvarfilename);
                string curpath = Path.GetDirectoryName(destvarfilename);
                curpath = Comm.MakeRelativePath(Settings.Default.varspath, curpath);

                var varsrow = dbContext.Vars.FirstOrDefault(v => v.VarName == basename);
                if (varsrow == null)
                {
                    using (ZipFile varzipfile = new ZipFile(destvarfilename))
                    {
                    // Create new Var entity
                    varsrow = new Var
                    {
                        VarName = basename
                    };
                    
                    string[] varnamepart = basename.Split('.');
                    if (varnamepart.Length == 3)
                    {
                        FileInfo finfo = new FileInfo(destvarfilename);
                        varsrow.Filesize = finfo.Length;
                        varsrow.CreatorName = varnamepart[0];
                        varsrow.PackageName = varnamepart[1];
                        varsrow.VarDate = finfo.LastWriteTime;
                        int version;
                        if (!int.TryParse(varnamepart[2], out version))
                            version = 1;
                        varsrow.Version = version.ToString();
                        varsrow.VarPath = curpath;
                        //ZipFile zipFile = new ZipFile(destvarfilename);


                        var metajson = varzipfile.GetEntry("meta.json");

                        if (metajson == null)
                        {
                            string notComplRulefilename = Path.Combine(Settings.Default.varspath, notComplyRuleDirName, Path.GetFileName(destvarfilename));
                            string errlog = $"{basename}, Invalid var package structure, move into {notComplyRuleDirName} directory";
                            //string errorMessage = destvarfilename + " is invalid,please check";
                            this.BeginInvoke(addlog, new Object[] { errlog, LogLevel.WARNING });
                            File.Move(destvarfilename, notComplRulefilename);
                            return;
                        }
                        varsrow.MetaDate = metajson.DateTime;
                        int countscene = 0, countlook = 0, countclothing = 0, counthair = 0, countplugincs = 0, countplugincslist = 0, countasset = 0, countmorphs = 0, countpose = 0, countskin = 0;
                        var newScenes = new List<Scene>();
                        //foreach (var zfile in varzipfile.Entries)
                        //varzipfile
                        foreach (ZipEntry zfile in varzipfile)
                        {
                            string typename = "";
                            bool isPreset = false;
                            try
                            {
                                if (Regex.IsMatch(zfile.Name, @"saves/scene/.*?\x2e(?:json)", RegexOptions.IgnoreCase | RegexOptions.Singleline))
                                {
                                    typename = "scenes";
                                    countscene++;
                                }
                                if (Regex.IsMatch(zfile.Name, @"saves/person/appearance/.*?\x2e(?:json|vac)", RegexOptions.IgnoreCase | RegexOptions.Singleline))
                                {
                                    typename = "looks";
                                    isPreset = zfile.Name.EndsWith(".json");
                                    countlook++;
                                }
                                if (Regex.IsMatch(zfile.Name, @"custom/atom/person/(?:general|appearance)/.*?\x2e(?:json|vap)", RegexOptions.IgnoreCase | RegexOptions.Singleline))
                                {
                                    typename = "looks";
                                    isPreset = true;
                                    countlook++;
                                }
                                if (Regex.IsMatch(zfile.Name, @"custom/clothing/.*?\x2e(?:vam|vap)", RegexOptions.IgnoreCase | RegexOptions.Singleline))
                                {
                                    typename = "clothing";
                                    isPreset = false;
                                    countclothing++;
                                }
                                if (Regex.IsMatch(zfile.Name, @"custom/atom/person/clothing/.*?\x2e(?:vam|vap)", RegexOptions.IgnoreCase | RegexOptions.Singleline))
                                {
                                    typename = "clothing";
                                    isPreset = zfile.Name.EndsWith(".vap");
                                    countclothing++;
                                }
                                if (Regex.IsMatch(zfile.Name, @"custom/hair/.*?\x2e(?:vam|vap)", RegexOptions.IgnoreCase | RegexOptions.Singleline))
                                {
                                    typename = "hairstyle";
                                    isPreset = false;
                                    counthair++;
                                }
                                if (Regex.IsMatch(zfile.Name, @"custom/atom/person/hair/.*?\x2e(?:vam|vap)", RegexOptions.IgnoreCase | RegexOptions.Singleline))
                                {
                                    typename = "hairstyle";
                                    isPreset = zfile.Name.EndsWith(".vap");
                                    counthair++;
                                }
                                if (Regex.IsMatch(zfile.Name, @"custom/scripts/.*?\x2e(?:cs)", RegexOptions.IgnoreCase | RegexOptions.Singleline))
                                {
                                    countplugincs++;
                                }
                                if (Regex.IsMatch(zfile.Name, @"custom/atom/person/scripts/.*?\x2e(?:cs)", RegexOptions.IgnoreCase | RegexOptions.Singleline))
                                {
                                    countplugincs++;
                                }
                                if (Regex.IsMatch(zfile.Name, @"custom/scripts/.*?\x2e(?:cslist)", RegexOptions.IgnoreCase | RegexOptions.Singleline))
                                {
                                    countplugincslist++;
                                }
                                if (Regex.IsMatch(zfile.Name, @"custom/atom/person/scripts/.*?\x2e(?:cslist)", RegexOptions.IgnoreCase | RegexOptions.Singleline))
                                {
                                    countplugincslist++;
                                }
                                if (Regex.IsMatch(zfile.Name, @"custom/assets/.*?\x2e(?:assetbundle)", RegexOptions.IgnoreCase | RegexOptions.Singleline))
                                {
                                    typename = "assets";
                                    countasset++;
                                }
                                if (Regex.IsMatch(zfile.Name, @"custom/atom/person/morphs/.*?\x2e(?:vmi|vap)", RegexOptions.IgnoreCase | RegexOptions.Singleline))
                                {
                                    typename = "morphs";
                                    isPreset = zfile.Name.EndsWith(".vap");
                                    countmorphs++;
                                }
                                if (Regex.IsMatch(zfile.Name, @"custom/atom/person/pose/.*?\x2e(?:vap)", RegexOptions.IgnoreCase | RegexOptions.Singleline))
                                {
                                    typename = "pose";
                                    isPreset = true;
                                    countpose++;
                                }
                                if (Regex.IsMatch(zfile.Name, @"saves/person/pose/.*?\x2e(?:json|vac)", RegexOptions.IgnoreCase | RegexOptions.Singleline))
                                {
                                    typename = "pose";
                                    isPreset = zfile.Name.EndsWith(".json");
                                    countpose++;
                                }
                                if (Regex.IsMatch(zfile.Name, @"custom/atom/person/skin/.*?\x2e(?:vap)", RegexOptions.IgnoreCase | RegexOptions.Singleline))
                                {
                                    typename = "skin";
                                    isPreset = true;
                                    countskin++;
                                }
                                if (typename != "")
                                {
                                    int jpgcount = 0;
                                    switch (typename)
                                    {
                                        case "scenes": jpgcount = countscene; break;
                                        case "looks": jpgcount = countlook; break;
                                        case "clothing": jpgcount = countclothing; break;
                                        case "hairstyle": jpgcount = counthair; break;
                                        case "assets": jpgcount = countasset; break;
                                        case "morphs": jpgcount = countmorphs; break;
                                        case "pose": jpgcount = countpose; break;
                                        case "skin": jpgcount = countskin; break;
                                    }
                                    string jpgfile = zfile.Name.Substring(0, zfile.Name.LastIndexOf('.')) + ".jpg";
                                    var jpg = varzipfile.GetEntry(jpgfile);
                                    string jpgname = "";
                                    if (jpg != null)
                                    {
                                        string namejpg = Path.GetFileNameWithoutExtension(jpg.Name).ToLower();

                                        string typepath = Path.Combine(Settings.Default.varspath, previewpicsDirName, typename, Path.GetFileNameWithoutExtension(destvarfilename));
                                        if (!Directory.Exists(typepath))
                                            Directory.CreateDirectory(typepath);
                                        jpgname = typename + jpgcount.ToString("000") + "_" + namejpg + ".jpg";
                                        string jpgextratname = Path.Combine(typepath, typename + jpgcount.ToString("000") + "_" + namejpg + ".jpg");
                                        if (!File.Exists(jpgextratname))
                                        {
                                            using (var sr = varzipfile.GetInputStream(jpg))
                                            using (var streamWriter = File.Create(jpgextratname))
                                            {
                                                sr.CopyTo(streamWriter);
                                            }
                                        }
                                    }
                                    // string ext = zfile.FullName.Substring(zfile.FullName.LastIndexOf('.')).ToLower();
                                    // if (ext == ".vap" || ext == ".json")
                                    if (typename == "scenes" || typename == "looks" || typename == "clothing" || typename == "hairstyle" || typename == "morphs" || typename == "pose" || typename == "skin")
                                    {
                                        // Collect scenes for a single bulk insert
                                        newScenes.Add(new Scene
                                        {
                                            VarName = basename,
                                            AtomType = typename,
                                            IsPreset = isPreset,
                                            ScenePath = zfile.Name,
                                            PreviewPic = jpgname
                                        });
                                    }
                                }

                            }
                            catch (ArgumentException ex)
                            {
                                this.BeginInvoke(addlog, new Object[] { zfile.Name + " " + ex.Message, LogLevel.ERROR });
                            }
                        }
                        if (newScenes.Count > 0)
                        {
                            dbContext.Scenes.AddRange(newScenes);
                        }
                        
                        varsrow.Scenes = countscene;
                        varsrow.Looks = countlook;
                        varsrow.Clothing = countclothing;
                        varsrow.Hairstyle = counthair;
                        varsrow.Morphs = countmorphs;
                        varsrow.Pose = countpose;
                        varsrow.Skin = countskin;
                        if (countplugincslist > 0)
                            varsrow.Plugins = countplugincslist;
                        else
                        varsrow.Plugins = countplugincs;
                        varsrow.Assets = countasset;
                        
                        // Add var to context
                        dbContext.Vars.Add(varsrow);


                        List<string> dependencies = new List<string>();

                        string jsonstring;
                        using (var metajsonsteam = new StreamReader(varzipfile.GetInputStream(metajson)))
                        {
                            jsonstring = metajsonsteam.ReadToEnd();
                        }
                        try
                        {
                            dependencies = Getdependencies(jsonstring);
                        }
                        catch (Exception ex)
                        {
                            this.BeginInvoke(addlog, new Object[] { destvarfilename + " get dependencies failed " + ex.Message, LogLevel.ERROR });
                        }
                        // Remove existing dependencies for this var
                        var existingDeps = dbContext.Dependencies.Where(d => d.VarName == basename).ToList();
                        if (existingDeps.Count > 0)
                        {
                            dbContext.Dependencies.RemoveRange(existingDeps);
                        }
                        
                        // Add new dependencies
                        if (dependencies.Count > 0)
                        {
                            var newDeps = new List<Dependency>(dependencies.Count);
                            foreach (string dependencie in dependencies)
                            {
                                newDeps.Add(new Dependency
                                {
                                    VarName = basename,
                                    DependencyName = dependencie
                                });
                            }
                            dbContext.Dependencies.AddRange(newDeps);
                        }
                        dbContext.SaveChanges();
                        dbContext.ChangeTracker.Clear();
                    }
                    }
                }
                else
                {
                    if (varsrow.VarPath != curpath)
                    {
                        varsrow.VarPath = curpath;
                        dbContext.SaveChanges();
                        dbContext.ChangeTracker.Clear();
                    }
                }

            }
            catch (Exception ex)
            {
                this.BeginInvoke(addlog, new Object[] { destvarfilename + " " + ex.Message, LogLevel.ERROR });
            }
        }
        private bool UpdDB()
        {
            InvokeProgress mi = new InvokeProgress(UpdateProgress);
            this.BeginInvoke(addlog, new Object[] { "Analyze Var files, extract preview images, save info to DB", LogLevel.INFO });
            string[] vars = Directory.GetFiles(Path.Combine(Settings.Default.varspath, tidiedDirName), "*.var", SearchOption.AllDirectories);
            if (vars.Length <= 0)
            {
                MessageBox.Show("No VAR file found, please check if the path setting is wrong!");
                return false;
            }
            List<string> existVars = new List<string>();
            int curVarfile = 0;
            foreach (string varfile in vars)
            {
                existVars.Add(Path.GetFileNameWithoutExtension(varfile));
                UpdDB(varfile);
                curVarfile++;
                this.BeginInvoke(mi, new Object[] { curVarfile, vars.Length });
            }

            List<string> deletevars = new List<string>();


            foreach (var row in dbContext.Vars)
            {
                if (!existVars.Contains(row.VarName))
                {
                    this.BeginInvoke(addlog, new Object[] { $"{row.VarName} The target VAR file is not found and the record will be deleted", LogLevel.WARNING });
                    deletevars.Add(row.VarName);
                }
            }
            deletevars = deletevars.Distinct().ToList();
            if (deletevars.Count > 0)
                CleanVars(deletevars);

            return true;
        }
        private bool CleanVars(List<string> deletevars)
        {
            try
            {
                this.BeginInvoke(addlog, new Object[] { $"Cleanup dependencies table...", LogLevel.INFO });
                var dependencierows = dbContext.Dependencies.Where(q => deletevars.Contains(q.VarName)).ToList();
                dbContext.Dependencies.RemoveRange(dependencierows);
                dbContext.SaveChanges();
                this.BeginInvoke(addlog, new Object[] { $"Cleanup dependencies table completed.", LogLevel.INFO });

                this.BeginInvoke(addlog, new Object[] { $"Cleanup scenes table...", LogLevel.INFO });
                var scenes = dbContext.Scenes.Where(q => deletevars.Contains(q.VarName)).ToList();
                dbContext.Scenes.RemoveRange(scenes);
                dbContext.SaveChanges();
                this.BeginInvoke(addlog, new Object[] { $"Cleanup scenes table completed.", LogLevel.INFO });

                this.BeginInvoke(addlog, new Object[] { $"Cleanup vars table...", LogLevel.INFO });
                var varrows = dbContext.Vars.Where(q => deletevars.Contains(q.VarName)).ToList();
                dbContext.Vars.RemoveRange(varrows);
                dbContext.SaveChanges();
                this.BeginInvoke(addlog, new Object[] { $"Cleanup vars table completed.", LogLevel.INFO });

                this.BeginInvoke(addlog, new Object[] { $"Cleanup PreviewPics...", LogLevel.INFO });
                foreach (string deletevar in deletevars)
                    DelePreviewPics(deletevar);
                FixPreview();
                this.BeginInvoke(addlog, new Object[] { $"Cleanup PreviewPics completed.", LogLevel.INFO });

            }
            catch (Exception ex)
            {
                this.BeginInvoke(addlog, new Object[] { "delete record or preview error, " + ex.Message, LogLevel.ERROR });
                return false;
            }
            return true;
        }
        private bool CleanVar(string deletevar)
        {
            try
            {
                var dependencierows = dbContext.Dependencies.Where(q => q.VarName == deletevar).ToList();
                dbContext.Dependencies.RemoveRange(dependencierows);
                dbContext.SaveChanges();

                var scenes = dbContext.Scenes.Where(q => q.VarName == deletevar).ToList();
                dbContext.Scenes.RemoveRange(scenes);
                dbContext.SaveChanges();

                var row = dbContext.Vars.FirstOrDefault(v => v.VarName == deletevar);
                if (row != null)
                {
                    dbContext.Vars.Remove(row);
                    dbContext.SaveChanges();
                }

                DelePreviewPics(deletevar);

            }
            catch (Exception ex)
            {
                this.BeginInvoke(addlog, new Object[] { deletevar + ",delete record or preview error, " + ex.Message, LogLevel.ERROR });
            }
            return true;
        }

        /// <summary>
        /// varInstall
        /// </summary>
        /// <param name="varName"></param>
        /// <param name="bTemp"></param>
        /// <param name="operate"></param>
        /// <returns>0:faile,1:success，2：installed</returns>
        private int VarInstall(string varName, bool bTemp = false, int operate = 1)
        {
            int success = 0;
            if (operate >= 1)
            {
                var varsrow = dbContext.Vars.FirstOrDefault(v => v.VarName == varName);
                if (varsrow != null)
                {
                    //string[] varexist = Directory.GetFiles(Path.Combine(Settings.Default.vampath, "AddonPackages"), varName + ".var");
                    string linkvar = Path.Combine(Settings.Default.vampath, "AddonPackages", installLinkDirName, varName + ".var");
                    if (bTemp) linkvar = Path.Combine(Settings.Default.vampath, "AddonPackages", tempVarLinkDirName, varName + ".var");
                    if (File.Exists(linkvar + ".disabled") && operate == 1)
                        File.Delete(linkvar + ".disabled");
                    if (File.Exists(linkvar))
                        return 2;

                    string destvarfile = Path.Combine(Settings.Default.varspath, varsrow.VarPath, varsrow.VarName + ".var");

                    if (!Comm.CreateSymbolicLink(linkvar, destvarfile, Comm.SYMBOLIC_LINK_FLAG.File))
                    {
                        MessageBox.Show("Error: Unable to create symbolic link. " +
                                "(Error Code: " + Marshal.GetLastWin32Error() + ")");
                        return 0;
                    }
                    if (operate == 2)
                    {
                        using (File.Create(linkvar + ".disabled")) { }
                    }
                    Comm.SetSymboLinkFileTime(linkvar, File.GetCreationTime(destvarfile), File.GetLastWriteTime(destvarfile));
                    this.BeginInvoke(addlog, new Object[] { $"{varName}  Installed", LogLevel.INFO });
                    success = 1;
                }
            }
            return success;
        }

        private void backgroundWorkerInstall_DoWork(object sender, DoWorkEventArgs e)
        {
            mutex.WaitOne();
            try
            {
                string arg = (string)e.Argument;
                if (arg == "FillDataTables")
                {
                    FillDataTables();
                    return;
                }
                if (arg == "UpdDB")
                {
                    RunBackendJob("update_db", null);
                    BeginInvoke(new Action(RefreshVarsViewUi));
                    return;
                }
                if (arg == "rebuildLink")
                {
                    RunBackendJob("rebuild_links", new { include_missing = true });
                    return;
                }
                if (arg == "fixPreview")
                {
                    RunBackendJob("fix_previews", null);
                    BeginInvoke(new Action(() => MessageBox.Show("Fix preview finish")));
                    BeginInvoke(new Action(RefreshVarsViewUi));
                    return;
                }
                if (arg == "savesDepend")
                {
                    var result = RunBackendJob("saves_deps", null);
                    var payload = DeserializeResult<DepsJobResult>(result);
                    if (payload != null && payload.Missing.Count > 0)
                    {
                        BeginInvoke(new InvokeShowformMissingVars(ShowformMissingVars), payload.Missing);
                    }
                    RunBackendJob("rescan_packages", null);
                    BeginInvoke(new Action(RefreshVarsViewUi));
                    return;
                }
                if (arg == "LogAnalysis")
                {
                    var result = RunBackendJob("log_deps", null);
                    var payload = DeserializeResult<DepsJobResult>(result);
                    if (payload != null && payload.Missing.Count > 0)
                    {
                        BeginInvoke(new InvokeShowformMissingVars(ShowformMissingVars), payload.Missing);
                    }
                    RunBackendJob("rescan_packages", null);
                    BeginInvoke(new Action(RefreshVarsViewUi));
                    return;
                }
                if (arg == "MissingDepends")
                {
                    var result = RunBackendJob("missing_deps", new { scope = "installed" });
                    var payload = DeserializeResult<MissingDepsResult>(result);
                    if (payload != null && payload.Missing.Count > 0)
                    {
                        BeginInvoke(new InvokeShowformMissingVars(ShowformMissingVars), payload.Missing);
                    }
                    else
                    {
                        BeginInvoke(new Action(() =>
                            MessageBox.Show("No missing dependencies found", "INFO",
                                MessageBoxButtons.OK, MessageBoxIcon.Information)));
                    }
                    RunBackendJob("rescan_packages", null);
                    BeginInvoke(new Action(RefreshVarsViewUi));
                    return;
                }
                if (arg == "AllMissingDepends")
                {
                    var result = RunBackendJob("missing_deps", new { scope = "all" });
                    var payload = DeserializeResult<MissingDepsResult>(result);
                    if (payload != null && payload.Missing.Count > 0)
                    {
                        BeginInvoke(new InvokeShowformMissingVars(ShowformMissingVars), payload.Missing);
                    }
                    return;
                }
                if (arg == "FilteredMissingDepends")
                {
                    var varNames = new List<string>();
                    System.Collections.IList listDatarow = varsViewBindingSource.List;
                    foreach (DataRowView varrowview in listDatarow)
                    {
                        varNames.Add(varrowview.Row.Field<string>("varName"));
                    }
                    var result = RunBackendJob("missing_deps", new { scope = "filtered", var_names = varNames });
                    var payload = DeserializeResult<MissingDepsResult>(result);
                    if (payload != null && payload.Missing.Count > 0)
                    {
                        BeginInvoke(new InvokeShowformMissingVars(ShowformMissingVars), payload.Missing);
                    }
                    return;
                }
                if (arg == "StaleVars")
                {
                    RunBackendJob("stale_vars", null);
                    BeginInvoke(new Action(RefreshVarsViewUi));
                    return;
                }
                if (arg == "OldVersionVars")
                {
                    RunBackendJob("old_version_vars", null);
                    BeginInvoke(new Action(RefreshVarsViewUi));
                    return;
                }
            }
            catch (Exception ex)
            {
                BeginInvoke(addlog, new Object[] { $"后端作业失败: {ex.Message}", LogLevel.ERROR });
            }
            finally
            {
                mutex.ReleaseMutex();
            }
        }

        private void backgroundWorkerInstall_RunWorkerCompleted(object sender, RunWorkerCompletedEventArgs e)
        {

        }

        private void buttonMissingDepends_Click(object sender, EventArgs e)
        {
            string message = "Analyzing dependencies from Installed Vars, if it is found in the repository it will be installed, otherwise a processing window will be opened.";

            const string caption = "MissingDepends";
            var result = MessageBox.Show(message, caption,
                                         MessageBoxButtons.YesNo,
                                         MessageBoxIcon.Question,
                                         MessageBoxDefaultButton.Button1);
            if (result == DialogResult.Yes)
            {
                backgroundWorkerInstall.RunWorkerAsync("MissingDepends");
            }
        }
        
        private void MissingDepends()
        {
            this.BeginInvoke(addlog, new Object[] { "Search for dependencies...", LogLevel.INFO });
            List<string> dependencies = new List<string>();
            foreach (var varrow in dbContext.VarsView.Where(q => q.Installed == true))
            {
                var varDependencies = dbContext.Dependencies.Where(q => q.VarName == varrow.VarName).Select(q => q.DependencyName);
                foreach (var dep in varDependencies)
                {
                    if (!string.IsNullOrEmpty(dep))
                        dependencies.Add(dep);
                }
            }
            dependencies = dependencies.Distinct().ToList();
            List<string> missingvars = new List<string>();
            foreach (string varname in dependencies)
            {
                string varexistname = VarExistName(varname);
                if (varexistname.EndsWith("$"))
                {
                    varexistname = varexistname.Substring(0, varexistname.Length - 1);
                    missingvars.Add(varname+"$");
                    this.BeginInvoke(addlog, new Object[] { varname + " missing version", LogLevel.INFO });
                }
                if (varexistname != "missing")
                {
                    VarInstall(varexistname);
                    //this.BeginInvoke(addlog, new Object[] { varexistname + " installed" ,LogLevel.ERROR});
                }
                else
                {
                    missingvars.Add(varname);
                    this.BeginInvoke(addlog, new Object[] { varname + " missing", LogLevel.INFO });
                }
            }
            if (missingvars.Count > 0)
            {
                InvokeShowformMissingVars showformMissingVars = new InvokeShowformMissingVars(ShowformMissingVars);
                this.BeginInvoke(showformMissingVars, missingvars);
            }
            else
            {
                MessageBox.Show("No missing dependencies found", "INFO", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }

        }

        private void FilteredMissingDepends()
        {
            this.BeginInvoke(addlog, new Object[] { "Search for dependencies...", LogLevel.INFO });
            List<string> dependencies = new List<string>();
            System.Collections.IList listDatarow = varsViewBindingSource.List;
            
            foreach (DataRowView varrowview in listDatarow)
            {
                dependencies.AddRange(dbContext.Dependencies.Where(q => q.VarName == varrowview.Row.Field<string>("varName")).Select(q => q.DependencyName));
            }
            
            dependencies = dependencies.Distinct().ToList();
            List<string> missingvars = new List<string>();
            foreach (string varname in dependencies)
            {
                string varexistname = VarExistName(varname);
                if (varexistname.EndsWith("$"))
                {
                    varexistname = varexistname.Substring(0, varexistname.Length - 1);
                    missingvars.Add(varname+"$");
                    this.BeginInvoke(addlog, new Object[] { varname + " missing version", LogLevel.INFO });
                }
                if (varexistname != "missing")
                {
                    //VarInstall(varexistname);
                    //this.BeginInvoke(addlog, new Object[] { varexistname + " installed" ,LogLevel.ERROR});
                }
                else
                {
                    missingvars.Add(varname);
                    this.BeginInvoke(addlog, new Object[] { varname + " missing", LogLevel.INFO });
                }
            }
            if (missingvars.Count > 0)
            {
                InvokeShowformMissingVars showformMissingVars = new InvokeShowformMissingVars(ShowformMissingVars);
                this.BeginInvoke(showformMissingVars, missingvars);
            }

        }

        private void buttonAllMissingDepends_Click(object sender, EventArgs e)
        {
            string message = "Analyzing dependencies from All organized vars, a processing window will be opened.";

            const string caption = "AllMissingDepends";
            var result = MessageBox.Show(message, caption,
                                         MessageBoxButtons.YesNo,
                                         MessageBoxIcon.Question,
                                         MessageBoxDefaultButton.Button1);
            if (result == DialogResult.Yes)
            {
                backgroundWorkerInstall.RunWorkerAsync("AllMissingDepends");
            }
        }
        public  void AllMissingDepends()
        {
            this.BeginInvoke(addlog, new Object[] { "Search for dependencies...", LogLevel.INFO });

            List<string> missingvars = MissingDependencies();
            if (missingvars.Count > 0)
            {
                this.BeginInvoke(addlog, new Object[] { $"Total { missingvars.Count } dependencies missing", LogLevel.INFO });
                InvokeShowformMissingVars showformMissingVars = new InvokeShowformMissingVars(ShowformMissingVars);
                this.BeginInvoke(showformMissingVars, missingvars);
            }
        }

        public List<string> MissingDependencies()
        {
            List<string> dependencies = new List<string>();

            dependencies.AddRange(dbContext.Dependencies.Select(q => q.DependencyName));

            dependencies = dependencies.Distinct().ToList();
            List<string> missingvars = new List<string>();
            foreach (string varname in dependencies)
            {
                string varexistname = VarExistName(varname);
                if (varexistname.EndsWith("$"))
                {
                    varexistname = varexistname.Substring(0, varexistname.Length - 1);
                    missingvars.Add(varname + "$");
                    //this.BeginInvoke(addlog, new Object[] { varname + " missing version" ,LogLevel.ERROR});
                }
                if (varexistname != "missing")
                {
                    //VarInstall(varexistname);
                    //this.BeginInvoke(addlog, new Object[] { varexistname + " installed" ,LogLevel.ERROR});
                }
                else
                {
                    missingvars.Add(varname);

                }
            }

            return missingvars;
        }

        private void FixRebuildLink()
        {
            this.BeginInvoke(addlog, new Object[] { "Check Installed symlink", LogLevel.INFO });
            //List<string> varfiles = Directory.GetFiles(Path.Combine(Settings.Default.vampath, "AddonPackages", installLinkDirName), "*.var", SearchOption.AllDirectories).ToList();
            List<string> varfiles = GetInstalledVars().Values.ToList();
            if (Directory.Exists(Path.Combine(Settings.Default.vampath, "AddonPackages", missingVarLinkDirName)))
                varfiles.AddRange(Directory.GetFiles(Path.Combine(Settings.Default.vampath, "AddonPackages", missingVarLinkDirName), "*.var", SearchOption.AllDirectories));

            foreach (string linkvar in varfiles)
            {
                try
                {
                    FileInfo pathInfo = new FileInfo(linkvar);
                    if (pathInfo.Attributes.HasFlag(FileAttributes.ReparsePoint))
                    {
                        string destfilename = Comm.ReparsePoint(linkvar);
                        this.BeginInvoke(addlog, new Object[] { $"symlink {linkvar} rebuilding ...", LogLevel.INFO });
                        var varsrow = dbContext.Vars.FirstOrDefault(v => v.VarName == Path.GetFileNameWithoutExtension(destfilename));
                        File.Delete(linkvar);
                        if (varsrow != null)
                        {
                            string destvarfile = Path.Combine(Settings.Default.varspath, varsrow.VarPath, varsrow.VarName + ".var");
                            Comm.CreateSymbolicLink(linkvar, destvarfile, Comm.SYMBOLIC_LINK_FLAG.File);
                            Comm.SetSymboLinkFileTime(linkvar, File.GetCreationTime(destvarfile), File.GetLastWriteTime(destvarfile));
                        }
                    }
                }
                catch (Exception ex)
                {
                    this.BeginInvoke(addlog, new Object[] { linkvar + " rebuild symlink failed. " + ex.Message, LogLevel.ERROR });
                }
            }

            MessageBox.Show("fix finish");
        }

        private bool ReExtractedPreview(Scene scenerow)
        {
            bool success = false;
            var varsrow = dbContext.Vars.FirstOrDefault(v => v.VarName == scenerow.VarName);
            if (varsrow != null)
            {
                string destvarfile = Path.Combine(Settings.Default.varspath, varsrow.VarPath!, varsrow.VarName + ".var");
                if (File.Exists(destvarfile))
                {
                    //using (ZipArchive varzipfile = ZipFile.OpenRead(destvarfile))
                    using (ZipFile varzipfile = new  ZipFile(destvarfile))
                    {
                        string jpgfile = scenerow.ScenePath!.Substring(0, scenerow.ScenePath.LastIndexOf('.')) + ".jpg";
                        var jpg = varzipfile.GetEntry(jpgfile);
                        if (jpg != null)
                        {
                            string picpath = Path.Combine(Settings.Default.varspath, previewpicsDirName, scenerow.AtomType!, scenerow.VarName, scenerow.PreviewPic!);

                            string jpgdirectory = Path.GetDirectoryName(picpath);
                            if(!Directory.Exists(jpgdirectory))
                                Directory.CreateDirectory(jpgdirectory);
                            if (!File.Exists(picpath))
                            {
                                using (var sr = varzipfile.GetInputStream(jpg))
                                using (var streamWriter = File.Create(picpath))
                                {
                                    sr.CopyTo(streamWriter);
                                }
                            }
                            success = true;
                        }
                    }
                }
            }
            return success;
        }
        private void FixPreview()
        {
            foreach (var scenerow in dbContext.Scenes.Where(q => !string.IsNullOrEmpty(q.PreviewPic)))
            {
                string picpath = Path.Combine(Settings.Default.varspath, previewpicsDirName, scenerow.AtomType!, scenerow.VarName, scenerow.PreviewPic!);
                if (!File.Exists(picpath))
                {
                    if (ReExtractedPreview(scenerow))
                    {
                        this.BeginInvoke(addlog, new Object[] { $"missing {picpath} is fixed.", LogLevel.INFO });
                    }
                    else
                    {
                        this.BeginInvoke(addlog, new Object[] { $"{picpath} is missing and the repair failed", LogLevel.WARNING });
                    }
                }
            }
           
        }
        private void FixSavseDependencies()
        {
            List<string> dependencies = new List<string>();
            this.BeginInvoke(addlog, new Object[] { "Analyze the *.json files in the 'Save' directory and  the *.vap files in the 'Custom' directory ", LogLevel.INFO });
            // Clear and reload saved dependencies
            dbContext.SavedDependencies.RemoveRange(dbContext.SavedDependencies);
            dbContext.SaveChanges();
            List<string> savefiles = Directory.GetFiles(Path.Combine(Settings.Default.vampath, "Saves"), "*.json", SearchOption.AllDirectories).ToList();
            savefiles.AddRange(Directory.GetFiles(Path.Combine(Settings.Default.vampath, "Custom"), "*.vap", SearchOption.AllDirectories));
            foreach (string jsonfile in savefiles)
            {
                FileInfo fi = new FileInfo(jsonfile);
                string savepath = jsonfile.Substring(Settings.Default.vampath.Length);
                if (savepath.Length > 255) savepath = savepath.Substring(savepath.Length - 255);

                this.BeginInvoke(addlog, new Object[] { $"Analyze { Path.GetFileName(jsonfile)} ...", LogLevel.INFO });

                var rows = dbContext.SavedDependencies.Where(q => q.SavePath == savepath && q.ModiDate.HasValue && Math.Abs((q.ModiDate.Value - fi.LastWriteTime).TotalSeconds) <= 2).ToList();

                if (rows.Any())
                {
                    // Dependencies already exist for this file, no need to reprocess
                }
                else
                {
                    try
                    {
                        string jsonstring;
                        using (var metajsonsteam = new StreamReader(jsonfile))
                        {
                            jsonstring = metajsonsteam.ReadToEnd();
                        }
                        foreach (string dependency in Getdependencies(jsonstring))
                        {
                            dbContext.SavedDependencies.Add(new SavedDependency
                            {
                                SavePath = savepath,
                                ModiDate = fi.LastWriteTime,
                                DependencyName = dependency
                            });
                        }
                    }
                    catch (Exception ex)
                    {
                        this.BeginInvoke(addlog, new Object[] { jsonfile + " Get dependencies failed " + ex.Message, LogLevel.ERROR });
                    }
                }
            }
            // Save all changes
            dbContext.SaveChanges();
            dependencies = dbContext.SavedDependencies.Select(q => q.DependencyName).Distinct().ToList();
            //dependencies = dependencies.Distinct().ToList();
            var dependencies2 = VarsDependencies(dependencies);
            dependencies = dependencies.Concat(dependencies2).Distinct().OrderBy(q => q).ToList();

            //List<string> varinstalled = new List<string>();
            //foreach (string varfile in Directory.GetFiles(Path.Combine(Settings.Default.vampath, "AddonPackages", installLinkDirName), "*.var", SearchOption.AllDirectories))
            //{
            //    varinstalled.Add(Path.GetFileNameWithoutExtension(varfile));
            //}
            //foreach (string varfile in Directory.GetFiles(Path.Combine(Settings.Default.vampath, "AddonPackages", missingVarLinkDirName), "*.var", SearchOption.AllDirectories))
            //{
            //    varinstalled.Add(Path.GetFileNameWithoutExtension(varfile));
            //}
            List<string> varinstalled = GetInstalledVars().Keys.ToList();
            dependencies = dependencies.Except(varinstalled).ToList();
            this.BeginInvoke(addlog, new Object[] { $"{dependencies.Count()} var files will be installed", LogLevel.INFO });
            List<string> missingvars = new List<string>();
            foreach (string varname in dependencies)
            {
                string varexistname = VarExistName(varname);
                if (varexistname.EndsWith("$"))
                {
                    varexistname = varexistname.Substring(0, varexistname.Length - 1);
                    missingvars.Add(varname + "$");
                }
                if (varexistname != "missing")
                {
                    VarInstall(varexistname);
                    this.BeginInvoke(addlog, new Object[] { varexistname + " installed", LogLevel.INFO });
                }
                else
                {
                    missingvars.Add(varname);
                }
            }
            missingvars = missingvars.Distinct().ToList();
            if (missingvars.Count > 0)
            {
                InvokeShowformMissingVars showformMissingVars = new InvokeShowformMissingVars(ShowformMissingVars);
                this.BeginInvoke(showformMissingVars, missingvars);
            }
            else
                MessageBox.Show("fix finish");
        }

        private void buttonFixRebuildLink_Click(object sender, EventArgs e)
        {
            string message = "will analyze and repair symlinks in the AddonPackages folder, if your var file repository changes location";

            const string caption = "RebuildLink";
            var result = MessageBox.Show(message, caption,
                                         MessageBoxButtons.YesNo,
                                         MessageBoxIcon.Question,
                                         MessageBoxDefaultButton.Button1);
            if (result == DialogResult.Yes)
                backgroundWorkerInstall.RunWorkerAsync("rebuildLink");
        }

        private void buttonFixSavesDepend_Click(object sender, EventArgs e)
        {
            string message = "Analyzing dependencies from json files in \"Saves\" folder";

            const string caption = "SavesDependencies";
            var result = MessageBox.Show(message, caption,
                                         MessageBoxButtons.YesNo,
                                         MessageBoxIcon.Question,
                                         MessageBoxDefaultButton.Button1);
            if (result == DialogResult.Yes)
                backgroundWorkerInstall.RunWorkerAsync("savesDepend");
        }

        private void comboBoxCreater_SelectedIndexChanged(object sender, EventArgs e)
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
                strFilter += " AND varName Like '%" + textBoxFilter.Text.Trim().Replace("'", "''") + "%'";
            }
            if (checkBoxInstalled.CheckState == CheckState.Checked)
            {
                strFilter += " AND installed";
            }
            if (checkBoxInstalled.CheckState == CheckState.Unchecked)
            {
                strFilter += " AND (NOT installed OR installed Is Null )";
            }

            this.comboBoxCreater.SelectedIndexChanged -= new System.EventHandler(this.comboBoxCreater_SelectedIndexChanged);
            var creators = dbContext.Vars
                .Where(v => string.IsNullOrEmpty(textBoxFilter.Text.Trim()) || v.VarName!.ToLower().Contains(textBoxFilter.Text.Trim().ToLower()))
                .GroupBy(v => v.CreatorName)
                .Select(g => g.Key)
                .OrderBy(c => c)
                .ToList();
            string curcreator = comboBoxCreater.Text;
            comboBoxCreater.Items.Clear();
            comboBoxCreater.Items.Add("____ALL");
            foreach (var creator in creators)
            {
                comboBoxCreater.Items.Add(creator);
            }
            if (comboBoxCreater.Items.Contains(curcreator))
                comboBoxCreater.SelectedItem = curcreator;
            else
                comboBoxCreater.SelectedIndex = 0;
            this.comboBoxCreater.SelectedIndexChanged += new System.EventHandler(this.comboBoxCreater_SelectedIndexChanged);

            varsViewBindingSource.Filter = strFilter;
            varsViewDataGridView.Update();
        }
        public string VarExistName(string varname)
        {
            string varrealver = "missing";
            string[] varnamepart = varname.Split('.');
            if (varnamepart.Length == 3)
            {
                if (varnamepart[2].ToLower() == "latest")
                {
                    var packs = dbContext.Vars.Where(q => q.CreatorName == varnamepart[0] && q.PackageName == varnamepart[1]);
                    if (packs.Any())
                    {
                        var packsList = packs.ToList(); // Execute query first
                        var latestPack = packsList
                            .Where(p => int.TryParse(p.Version, out _)) // Filter valid versions
                            .OrderByDescending(p => int.TryParse(p.Version, out int ver) ? ver : 0)
                            .FirstOrDefault();
                        varrealver = latestPack?.VarName ?? "missing";
                    }
                }
                else
                {
                    var varsrow = dbContext.Vars.FirstOrDefault(v => v.VarName == varname);
                    if (varsrow != null)
                        varrealver = varname;
                    else
                    {
                        if (int.TryParse(varnamepart[2], out int requestedVersion))
                        {
                            string closestver = GetClosestMatchingPackageVersion(varnamepart[0], varnamepart[1], requestedVersion);
                            if (closestver != "missing")
                                varrealver = closestver + "$";
                        }
                    }
                }
            }
            return varrealver;
        }
        public string GetClosestMatchingPackageVersion(string creatorName,string packageName,int requestVersion)
        {
            var packs = dbContext.Vars.Where(q => q.CreatorName == creatorName && q.PackageName == packageName)
                                    .ToList() // Execute query first
                                    .Where(q => int.TryParse(q.Version, out _)) // Filter only valid integer versions
                                    .OrderBy(q => int.TryParse(q.Version, out int ver) ? ver : 0);
            if (packs.Any())
            {
                foreach (var pack in packs)
                {
                    if (int.TryParse(pack.Version, out int packVersion) && packVersion >= requestVersion)
                    {
                        return pack.VarName!;
                    }
                }
                return packs.Last().VarName!;
            }
            return "missing";
        }
        private List<string> VarsDependencies(string varname)
        {
            List<string> depens = new List<string>();
            foreach (var depenrow in dbContext.Dependencies.Where(q => q.VarName == varname))
                depens.Add(depenrow.DependencyName!);
            return depens;

        }

        private List<string> VarsDependencies(List<string> varnames)
        {
            List<string> varnameexist = new List<string>();
            List<string> varsProccessed = new List<string>();
            List<string> vardeps = new List<string>();
            foreach (string varname in varnames)
            {
                if (varname[varname.Length - 1] == '^')
                    varsProccessed.Add(varname.Substring(0, varname.Length - 1));
                else
                {
                    string varexistname = VarExistName(varname);
                    if (varexistname.EndsWith("$"))
                    {
                        varexistname = varexistname.Substring(0, varexistname.Length - 1);
                    }
                    if (varexistname != "missing")
                        varnameexist.Add(varexistname);
                }
            }

            varnameexist = varnameexist.Distinct().Except(varsProccessed).ToList();
            foreach (string varname in varnameexist)
            {
                vardeps.AddRange(VarsDependencies(varname));
            }
            varsProccessed.AddRange(varnameexist);
            varsProccessed = varsProccessed.Distinct().ToList();

            vardeps = vardeps.Distinct().Except(varsProccessed).ToList();
            if (vardeps.Count() > 0)
            {
                foreach (string varname in varsProccessed)
                {
                    vardeps.Add(varname + "^");
                }
                return VarsDependencies(vardeps);
            }
            else
            {
                varsProccessed = varsProccessed.Select(q => q.Trim('^')).Distinct().ToList();
                return varsProccessed;
            }
        }

        private void varsDataGridView_SelectionChanged(object sender, EventArgs e)
        {
            UpdatePreviewPics();
            tableLayoutPanelPreview.Visible = false;
        }

        public struct Previewpic
        {
            public Previewpic(string varname, string atomtype, string picpath, bool installed, string scenePath, bool ispreset)
            {
                Varname = varname;
                Atomtype = atomtype;
                Picpath = picpath;
                Installed = installed;
                ScenePath = scenePath;
                IsPreset = ispreset;

            }
            public string Varname { get; }
            public string Atomtype { get; }
            public string Picpath { get; }
            public bool Installed { get; }
            public string ScenePath { get; }
            public bool IsPreset { get; }
        }

        private List<Previewpic> previewpics = new List<Previewpic>();

        private List<Previewpic> previewpicsfilter = new List<Previewpic>();

        private void UpdatePreviewPics()
        {
            if (IsDisposed) return;
            
            previewpics.Clear();
            foreach (DataGridViewRow row in varsViewDataGridView.SelectedRows)
            {
                string varName = row.Cells["varNameDataGridViewTextBoxColumn"].Value.ToString();
                var installedCell = row.Cells["installedDataGridViewCheckBoxColumn"];
                bool installed = false;

                if (true.Equals(installedCell.Value))
                {
                    installed = true;
                }
                foreach (var scenerow in dbContext.Scenes.Where(q => q.VarName == varName))
                {
                    previewpics.Add(new Previewpic(varName, scenerow.AtomType!, scenerow.PreviewPic!, installed, scenerow.ScenePath!, scenerow.IsPreset));
                }
            }
            PreviewInitType();
        }

        private void PreviewInitType()
        {
            if (IsDisposed || mut == null) return;
            
            try
            {
                mut.WaitOne();
                previewpicsfilter = previewpics;
                if (checkBoxPreviewTypeLoadable.CheckState == CheckState.Checked)
                    previewpicsfilter = previewpicsfilter.Where(q => q.IsPreset || q.Atomtype == "scenes").ToList();
                string previewtype = "all";
                if (new string[8] { "scenes", "looks", "clothing", "hairstyle", "assets", "morphs", "pose", "skin" }.Contains(comboBoxPreviewType.Text))
                    previewtype = comboBoxPreviewType.Text;
                if (previewtype != "all")
                    previewpicsfilter = previewpicsfilter.Where(q => q.Atomtype == previewtype).ToList();
                mut.ReleaseMutex();
                
                if (!IsDisposed)
                {
                    listViewPreviewPics.VirtualListSize = previewpicsfilter.Count;
                    listViewPreviewPics.Invalidate();
                    toolStripLabelPreviewCountItem.Text = "/" + previewpicsfilter.Count.ToString();
                }
            }
            catch (ObjectDisposedException)
            {
                return;
            }
            catch (Exception)
            {
                try { mut.ReleaseMutex(); } catch { }
                throw;
            }
            /*
            toolStripComboBoxPreviewPage.SelectedIndexChanged -= new System.EventHandler(this.toolStripComboBoxPreviewPage_SelectedIndexChanged); toolStripComboBoxPreviewPage.Items.Clear();
            previewPages = (previewpicsfilter.Count + maxpicxPerpage - 1) / maxpicxPerpage;
            toolStripLabelPreviewCountItem.Text = "/" + previewpicsfilter.Count.ToString();
            toolStripComboBoxPreviewPage.Items.Clear();
            if (previewPages >= 1)
            {
                for (int page = 0; page < previewPages; page++)
                {
                    int min = page * maxpicxPerpage + 1;
                    int max = (page + 1) * maxpicxPerpage;
                    if (max > previewpicsfilter.Count) max = previewpicsfilter.Count;

                    string strpage = min.ToString("000") + " - " + max.ToString("000");
                    toolStripComboBoxPreviewPage.Items.Add(strpage);
                }
                toolStripComboBoxPreviewPage.SelectedIndex = 0;
                //PreviewPage();
            }
            else
            {
                imageListPreviewPics.Images.Clear();
                listViewPreviewPics.Items.Clear();
            }
            toolStripComboBoxPreviewPage.SelectedIndexChanged += new System.EventHandler(this.toolStripComboBoxPreviewPage_SelectedIndexChanged);
            if (previewPages >= 1)
                PreviewPage();
            */
        }


        public delegate void InvokePreviewPics(string varname,
                                                string picpath,
                                                bool installed,
                                                string typename,
                                                string scenepath,
                                                bool ispreset);
        public void PreviewPics(string varname,
                                string picpath,
                                bool installed,
                                string typename,
                                string scenepath,
                                bool ispreset)
        {
            if (varname == "clear")
            {
                imageListPreviewPics.Images.Clear();
                listViewPreviewPics.Items.Clear();
            }
            else
            {
                if (string.IsNullOrWhiteSpace(picpath))
                {
                    imageListPreviewPics.Images.Add(Image.FromFile("vam.png"));
                }
                else
                {
                    picpath = Path.Combine(Settings.Default.varspath, previewpicsDirName, typename, varname, picpath);
                    if (File.Exists(picpath))
                    {
                        imageListPreviewPics.Images.Add(Image.FromFile(picpath));
                    }
                    else
                    {
                        imageListPreviewPics.Images.Add(Image.FromFile("vam.png"));
                    }
                }
                var item = listViewPreviewPics.Items.Add(Path.GetFileNameWithoutExtension(picpath), imageListPreviewPics.Images.Count - 1);
                item.SubItems.Add(varname);
                item.SubItems.Add(picpath);
                item.SubItems.Add(installed.ToString());
                item.SubItems.Add(typename);
                item.SubItems.Add(scenepath);
                item.SubItems.Add(ispreset.ToString());
            }
        }

        private void listViewPreviewPics_RetrieveVirtualItem(object sender, RetrieveVirtualItemEventArgs e)
        {
            var curpriviewpic = previewpicsfilter[e.ItemIndex];
            string key = "vam.png";
            if (!string.IsNullOrWhiteSpace(curpriviewpic.Picpath))
            {
                string picpath= Path.Combine(Settings.Default.varspath, previewpicsDirName, curpriviewpic.Atomtype, curpriviewpic.Varname, curpriviewpic.Picpath);
                if (File.Exists(picpath))
                    key = picpath;
                else
                {
                    this.BeginInvoke(addlog, new Object[] { $"{picpath} is missing,Please run 'fix preview'", LogLevel.WARNING });
                    buttonFixPreview.Focus();
                }

            }
            if (!imageListPreviewPics.Images.ContainsKey(key))
            {
                imageListPreviewPics.Images.Add(key, Image.FromFile(key));
                if (imageListPreviewPics.Images.Count > 20) imageListPreviewPics.Images.RemoveAt(0);
            }
            string itemname = Path.GetFileNameWithoutExtension(curpriviewpic.Picpath);
            if(string.IsNullOrEmpty(itemname))
            {
                itemname = curpriviewpic.Atomtype + "_" + Path.GetFileNameWithoutExtension(curpriviewpic.ScenePath);
            }
            e.Item = new ListViewItem(itemname, imageListPreviewPics.Images.IndexOfKey(key));
            e.Item.SubItems.Add(curpriviewpic.Varname);
            e.Item.SubItems.Add(key);
            e.Item.SubItems.Add(curpriviewpic.Installed.ToString());
            e.Item.SubItems.Add(curpriviewpic.Atomtype);
            e.Item.SubItems.Add(curpriviewpic.ScenePath);
            e.Item.SubItems.Add(curpriviewpic.IsPreset.ToString());

        }
        /*
        private void backgroundWorkerPreview_DoWork(object sender, DoWorkEventArgs e)
        {
            InvokePreviewPics previewpics = new InvokePreviewPics(PreviewPics);
            int startpic = maxpicxPerpage * previewCurPage;
            listViewPreviewPics.BeginInvoke(previewpics, "clear", "", true, "", "", true);
            for (int i = 0; i < maxpicxPerpage; i++)
            {
                Thread.Sleep(5);
                if (backgroundWorkerPreview.CancellationPending)
                {
                    //Tell the Backgroundworker you are canceling and exit the for-loop
                    e.Cancel = true;
                    return;
                }
                mutex.Wait();
                if (previewpicsfilter.Count > startpic + i)
                {
                    this.BeginInvoke(previewpics,
                                        previewpicsfilter[startpic + i].Varname,
                                        previewpicsfilter[startpic + i].Picpath,
                                        previewpicsfilter[startpic + i].Installed,
                                        previewpicsfilter[startpic + i].Atomtype,
                                        previewpicsfilter[startpic + i].ScenePath,
                                        previewpicsfilter[startpic + i].IsPreset
                                                );

                }
                mutex.Release();
            }
        }
        */

        private void toolStripComboBoxPreviewType_SelectedIndexChanged(object sender, EventArgs e)
        {
            PreviewInitType();
        }
        /*
        private void toolStripComboBoxPreviewPage_SelectedIndexChanged(object sender, EventArgs e)
        {
            PreviewPage();
        }

        private void PreviewPage()
        {
            previewCurPage = toolStripComboBoxPreviewPage.SelectedIndex;
            while (backgroundWorkerPreview.IsBusy)
            {
                backgroundWorkerPreview.CancelAsync();
                // Keep UI messages moving, so the form remains 
                // responsive during the asynchronous operation.
                Application.DoEvents();
            }
            backgroundWorkerPreview.RunWorkerAsync();
        }
        */
        private void toolStripButtonPreviewFirst_Click(object sender, EventArgs e)
        {
            int selectindex = 0;
            listViewPreviewPics.Items[selectindex].Selected = true;
            listViewPreviewPics.EnsureVisible(selectindex);
           // if (toolStripComboBoxPreviewPage.SelectedIndex > 0) toolStripComboBoxPreviewPage.SelectedIndex = 0;
        }

        private void toolStripButtonPreviewPrev_Click(object sender, EventArgs e)
        {
            int selectindex = 0;
            if (listViewPreviewPics.SelectedIndices.Count >= 1)
            {
                int index = listViewPreviewPics.SelectedIndices[0];
                if (index > 0) selectindex = index - 1;
            }

            listViewPreviewPics.Items[selectindex].Selected = true;
            listViewPreviewPics.EnsureVisible(selectindex);
            // if (toolStripComboBoxPreviewPage.SelectedIndex > 0) toolStripComboBoxPreviewPage.SelectedIndex--;
        }

        private void toolStripButtonPreviewNext_Click(object sender, EventArgs e)
        {
            int selectindex = listViewPreviewPics.Items.Count-1;
            if (listViewPreviewPics.SelectedIndices.Count >= 1)
            {
                int index = listViewPreviewPics.SelectedIndices[0];
                if (index < listViewPreviewPics.Items.Count - 1) selectindex = index + 1;
            }

            listViewPreviewPics.Items[selectindex].Selected = true;
            listViewPreviewPics.EnsureVisible(selectindex);
            // if (toolStripComboBoxPreviewPage.SelectedIndex < toolStripComboBoxPreviewPage.Items.Count - 1) toolStripComboBoxPreviewPage.SelectedIndex++;
        }

        private void toolStripButtonPreviewLast_Click(object sender, EventArgs e)
        {
            int selectindex = listViewPreviewPics.Items.Count - 1;
            listViewPreviewPics.Items[selectindex].Selected = true;
            listViewPreviewPics.EnsureVisible(selectindex);
            // if (toolStripComboBoxPreviewPage.SelectedIndex < toolStripComboBoxPreviewPage.Items.Count - 1) toolStripComboBoxPreviewPage.SelectedIndex = toolStripComboBoxPreviewPage.Items.Count - 1;

        }

        private void buttonStaleVars_Click(object sender, EventArgs e)
        {
            /*
            string message = $"Stale var means:\r\n1,The version is not the latest.\r\n2,Not depended by other var.\r\nThey will be moved to the {staleVarsDirName} directory";

            const string caption = "StaleVars";
            var result = MessageBox.Show(message, caption,
                                         MessageBoxButtons.YesNo,
                                         MessageBoxIcon.Question,
                                         MessageBoxDefaultButton.Button1);
            */
            FormStaleVars formStaleVars = new FormStaleVars();
            if (formStaleVars.ShowDialog() == DialogResult.OK)
            {
                if (formStaleVars.removeOldVersion)
                    backgroundWorkerInstall.RunWorkerAsync("OldVersionVars");
                else
                    backgroundWorkerInstall.RunWorkerAsync("StaleVars");
            }
        }

        void StaleVars()
        {
            var varsData = dbContext.Vars.ToList(); // Execute query first
            var query = varsData.GroupBy(g => g.CreatorName + "." + g.PackageName)
                               .Select(group => new
                               {
                                   Key = group.Key,
                                   Count = group.Count(),
                                   MaxVersion = group.Where(v => int.TryParse(v.Version, out _))
                                                    .Select(v => int.TryParse(v.Version, out int ver) ? ver : 0)
                                                    .DefaultIfEmpty(0)
                                                    .Max(),
                                   Vars = group.ToList()
                               });
            List<string> listOldvar = new List<string>();
            foreach (var result in query)
            {
                if (result.Count > 1)
                {
                    foreach (var oldvar in result.Vars.Where(v => (int.TryParse(v.Version, out int ver) ? ver : 0) != result.MaxVersion))
                    {
                        listOldvar.Add(oldvar.VarName!);
                    }
                }
            }
            string stalepath = Path.Combine(Settings.Default.varspath, staleVarsDirName);
            if (!Directory.Exists(stalepath))
                Directory.CreateDirectory(stalepath);
            var installedvars = GetInstalledVars();
            foreach (var oldvar in listOldvar)
            {
                if (dbContext.Dependencies.Count(q => q.DependencyName == oldvar) == 0)
                {
                    if (installedvars.ContainsKey(oldvar))
                    {
                        File.Delete(installedvars[oldvar]);
                    }
                    var varsrow = dbContext.Vars.FirstOrDefault(v => v.VarName == oldvar);
                    if (varsrow != null)
                    {
                        string oldv = Path.Combine(Settings.Default.varspath, varsrow.VarPath!, oldvar + ".var");
                        string stalev = Path.Combine(stalepath, oldvar + ".var");
                        try
                        {
                            this.BeginInvoke(addlog, new Object[] { $"move {oldv} to {stalepath}.", LogLevel.INFO });
                            File.Move(oldv, stalev);
                            CleanVar(oldvar);
                        }
                        catch (Exception ex)
                        {
                            this.BeginInvoke(addlog, new Object[] { $"{oldv} move failed,{ex.Message}", LogLevel.ERROR });
                        }
                    }
                }
            }
            System.Diagnostics.Process.Start(stalepath);
        }

        void OldVersionVars()
        {
            var varsData = dbContext.Vars.Where(q => q.Plugins <= 0 || q.Scenes > 0 || q.Looks > 0).ToList();
            var versionLastest = varsData.GroupBy(g => g.CreatorName + "." + g.PackageName)
                                        .Select(group => new
                                        {
                                            Key = group.Key,
                                            Count = group.Count(),
                                            MaxVersion = group.Where(v => int.TryParse(v.Version, out _))
                                                             .Select(v => int.TryParse(v.Version, out int ver) ? ver : 0)
                                                             .DefaultIfEmpty(0)
                                                             .Max(),
                                            Vars = group.ToList()
                                        });
            List<string> listOldvar = new List<string>();
            foreach (var result in versionLastest)
            {
                if (result.Count > 1)
                {
                    foreach (var oldvar in result.Vars.Where(v => (int.TryParse(v.Version, out int ver) ? ver : 0) != result.MaxVersion))
                    {
                        listOldvar.Add(oldvar.VarName!);
                    }
                }
            }
            string oldversionpath = Path.Combine(Settings.Default.varspath, oldVersionVarsDirName);
            if (!Directory.Exists(oldversionpath))
                Directory.CreateDirectory(oldversionpath);
            var installedvars = GetInstalledVars();
            foreach (var oldvar in listOldvar)
            {
                if (installedvars.ContainsKey(oldvar))
                {
                    string basename = oldvar.Substring(0, oldvar.LastIndexOf("."));
                    string varlastest = basename + "." + versionLastest.Where(q => q.Key == basename).First().MaxVersion.ToString();
                    File.Delete(installedvars[oldvar]);
                    VarInstall(varlastest);
                }
                var varsrow = dbContext.Vars.FirstOrDefault(v => v.VarName == oldvar);
                if (varsrow != null)
                {
                    string oldv = Path.Combine(Settings.Default.varspath, varsrow.VarPath!, oldvar + ".var");
                    string oldversionv = Path.Combine(oldversionpath, oldvar + ".var");
                    try
                    {
                        this.BeginInvoke(addlog, new Object[] { $"move {oldv} to {oldversionpath}.", LogLevel.INFO });
                        File.Move(oldv, oldversionv);
                        CleanVar(oldvar);
                    }
                    catch (Exception ex)
                    {
                        this.BeginInvoke(addlog, new Object[] { $"{oldv} move failed,{ex.Message}", LogLevel.ERROR });
                    }
                }
            }
            System.Diagnostics.Process.Start(oldversionpath);
        }

        private void textBoxFilter_TextChanged(object sender, EventArgs e)
        {
            FilterVars();
        }

        private void checkBoxInstalled_CheckStateChanged(object sender, EventArgs e)
        {
            FilterVars();
        }

        private void varsViewDataGridView_CellContentClick(object sender, DataGridViewCellEventArgs e)
        {
            if (varsViewDataGridView.Columns[e.ColumnIndex].Name == "installedDataGridViewCheckBoxColumn" && e.RowIndex >= 0)
            {
                string varName = varsViewDataGridView.Rows[e.RowIndex].Cells["varNameDataGridViewTextBoxColumn"].Value.ToString();
                bool installed = false;
                var row = dbContext.InstallStatuses.FirstOrDefault(i => i.VarName == varName);
                if (row != null)
                {
                    installed = row.Installed;
                }
                if (installed)
                {
                    string message = varName + " will be removed, are you sure?";
                    string caption = "Remove Var";
                    var result = MessageBox.Show(message, caption,
                                          MessageBoxButtons.YesNo,
                                          MessageBoxIcon.Question,
                                          MessageBoxDefaultButton.Button2);
                    if (result == DialogResult.Yes)
                    {
                        try
                        {
                            RunBackendJob("vars_toggle_install", new { var_name = varName, include_dependencies = true, include_implicated = true });
                            RefreshVarsViewUi();
                            RunBackendJob("rescan_packages", null);
                        }
                        catch (Exception ex)
                        {
                            BeginInvoke(addlog, new Object[] { $"卸载失败: {ex.Message}", LogLevel.ERROR });
                        }
                    }

                }
                else
                {
                    string message = varName + "  will be installed, are you sure?";
                    string caption = "Install Var";
                    var result = MessageBox.Show(message, caption,
                                          MessageBoxButtons.YesNo,
                                          MessageBoxIcon.Question,
                                          MessageBoxDefaultButton.Button2);
                    if (result == DialogResult.Yes)
                    {
                        try
                        {
                            RunBackendJob("vars_toggle_install", new { var_name = varName, include_dependencies = true, include_implicated = true });
                            RefreshVarsViewUi();
                            RunBackendJob("rescan_packages", null);
                        }
                        catch (Exception ex)
                        {
                            BeginInvoke(addlog, new Object[] { $"安装失败: {ex.Message}", LogLevel.ERROR });
                        }
                    }
                }
            }
            if (varsViewDataGridView.Columns[e.ColumnIndex].Name == "ColumnDetail" && e.RowIndex >= 0)
            {
                string varName = varsViewDataGridView.Rows[e.RowIndex].Cells["varNameDataGridViewTextBoxColumn"].Value.ToString();
                VarDetail(varName);
            }
        }

        public bool IsVarInstalled(string varName)
        {
            var installstatusrow = dbContext.InstallStatuses.FirstOrDefault(i => i.VarName == varName);
            if (installstatusrow != null)
                return installstatusrow.Installed;
            else
                return false;
        }
        private void VarDetail(string varName)
        {
            FormVarDetail formVarDetail = new FormVarDetail();
            formVarDetail.form1 = this;
            formVarDetail.strVarName = varName;

            formVarDetail.dependencies = new Dictionary<string, string>();
            foreach(var dependrow in dbContext.Dependencies.Where(q => q.VarName == varName))
            {
                string existName = VarExistName(dependrow.DependencyName!);
                if (existName.EndsWith("$"))
                {
                    existName = existName.Substring(0, existName.Length - 1);
                }
                formVarDetail.dependencies[dependrow.DependencyName!] = existName;
            }
            formVarDetail.DependentVarList = DependentVars(varName);
            formVarDetail.DependentJsonList = DependentSaved(varName);
            if (formVarDetail.ShowDialog() == DialogResult.OK)
            {
                if (formVarDetail.strAction == "filter")
                {
                    string creator = varName.Substring(0, varName.IndexOf("."));
                    comboBoxCreater.Text = creator;
                }
            }
        }

        private void buttonInstall_Click(object sender, EventArgs e)
        {
            List<string> varNames = new List<string>();
            foreach (DataGridViewRow row in varsViewDataGridView.SelectedRows)
            {
                string varName = row.Cells["varNameDataGridViewTextBoxColumn"].Value.ToString();
                bool install = false;
                var varsrow = dbContext.InstallStatuses.FirstOrDefault(i => i.VarName == varName);
                if (varsrow != null)
                {
                    if (varsrow.Installed)
                    {
                        install = true; ;
                    }
                }
                if (!install)
                {
                    varNames.Add(varName);
                }
            }
            if (varNames.Count <= 0) return;
            int max = 500;
            if (varNames.Count > max)
            {
                MessageBox.Show($"Please do not install more than {max} files at once");
                return;
            }
            string message = $"There are {varNames.Count} vars and their dependencies will be installed, are you sure?";
            string caption = "Install Var";
            var result = MessageBox.Show(message, caption,
                                  MessageBoxButtons.YesNo,
                                  MessageBoxIcon.Question,
                                  MessageBoxDefaultButton.Button2);
            if (result == DialogResult.Yes)
            {
                try
                {
                    RunBackendJob("install_vars", new { var_names = varNames, include_dependencies = true });
                    RefreshVarsViewUi();
                }
                catch (Exception ex)
                {
                    BeginInvoke(addlog, new Object[] { $"安装失败: {ex.Message}", LogLevel.ERROR });
                }
            }
        }
        public List<string> GetDependents(string dependName)
        {
            List<string> result = new List<string>();
            foreach (var dependrow in dbContext.Dependencies.Where(q => q.DependencyName == dependName))
            {
                result.Add(dependrow.VarName!);
            }
            foreach (var dependrow in dbContext.SavedDependencies.Where(q => q.DependencyName == dependName))
            {
                result.Add(dependrow.SavePath!);
            }
            return result;

        }

        private void buttonpreviewback_Click(object sender, EventArgs e)
        {
            tableLayoutPanelPreview.Visible = false;
        }

        private void buttonScenesManager_Click(object sender, EventArgs e)
        {
            FormScenes formScenes = new FormScenes();
            formScenes.form1 = this;
            formScenes.Show();
        }

        private void pictureBoxPreview_Click(object sender, EventArgs e)
        {
            tableLayoutPanelPreview.Visible = false;
        }
        private string curVarName = "",curEntryName="";
        private JSONClass jsonLoadScene;
        private void listViewPreviewPics_Click(object sender, EventArgs e)
        {
            if (listViewPreviewPics.SelectedIndices.Count >= 1)
            {
                tableLayoutPanelPreview.Dock = DockStyle.Fill;
                tableLayoutPanelPreview.Visible = true;
                int index = listViewPreviewPics.SelectedIndices[0];
                toolStripLabelPreviewItemIndex.Text = index.ToString();
                var item = listViewPreviewPics.Items[index];
                if (item != null)
                {
                    curVarName = item.SubItems[1].Text;
                    curEntryName = item.SubItems[5].Text;
                    labelPreviewVarName.Text = curVarName;
                    if (string.IsNullOrEmpty(item.SubItems[2].Text))
                        pictureBoxPreview.Image = pictureBoxPreview.Image = Image.FromFile("vam.png");
                    else
                        pictureBoxPreview.Image = Image.FromFile(item.SubItems[2].Text);

                    if (item.SubItems[3].Text.ToLower() == "true")
                    {
                        buttonpreviewinstall.Text = "Uninstall";
                        buttonpreviewinstall.ForeColor = Color.Red;
                    }

                    else
                    {
                        buttonpreviewinstall.Text = "Install";
                        buttonpreviewinstall.ForeColor = Color.DarkBlue;
                    }

                    if (item.SubItems[4].Text.ToLower() == "scenes" || item.SubItems[6].Text.ToLower() == "true")
                    {
                        buttonLoad.Visible = true;
                        checkBoxMerge.Visible = true;
                        checkBoxMerge.Checked = false;
                        buttonLoad.Text = "Load " + item.SubItems[4].Text;
                        string rescan = "false";
                        if (item.SubItems[3].Text.ToLower() == "false")
                            rescan = "true";

                        jsonLoadScene = new JSONClass();
                        jsonLoadScene.Add("rescan", rescan);

                        jsonLoadScene.Add("resources", new JSONArray());
                        JSONArray resources = jsonLoadScene["resources"].AsArray;
                        resources.Add(new JSONClass());
                        JSONClass resource = (JSONClass)resources[resources.Count - 1];
                        resource.Add("type", item.SubItems[4].Text.ToLower());
                        resource.Add("saveName", curVarName + ":/" + curEntryName.Replace('\\', '/'));
                        UpdateButtonClearCache();

                        if (item.SubItems[4].Text.ToLower() == "scenes" || item.SubItems[4].Text.ToLower() == "looks")
                        {
                            buttonAnalysis.Visible = true;
                        }
                        else
                        {
                            buttonAnalysis.Visible = false;
                        }
                        if (item.SubItems[4].Text.ToLower() == "looks" || item.SubItems[4].Text.ToLower() == "clothing" ||
                           item.SubItems[4].Text.ToLower() == "morphs" || item.SubItems[4].Text.ToLower() == "hairstyle" ||
                           item.SubItems[4].Text.ToLower() == "skin" || item.SubItems[4].Text.ToLower() == "pose")
                        {
                            groupBoxPersonOrder.Visible = true;
                            checkBoxIgnoreGender.Visible = true;
                        }
                        else
                        {
                            groupBoxPersonOrder.Visible = false;
                            checkBoxIgnoreGender.Visible = false;
                        }
                        if (item.SubItems[4].Text.ToLower() == "morphs" ||
                           item.SubItems[4].Text.ToLower() == "skin" ||
                           item.SubItems[4].Text.ToLower() == "pose")
                        {
                            checkBoxForMale.Visible = true;
                        }
                        else
                        {
                            checkBoxForMale.Visible = false;
                        }
                    }
                    else
                    {
                        buttonLoad.Visible = false;
                        checkBoxMerge.Visible = false;
                        buttonAnalysis.Visible = false;
                    }
                }
            }
        }

        private void UpdateButtonClearCache()
        {
            string sceneCacheFolderName = Path.Combine(Directory.GetCurrentDirectory(), "Cache",
               Comm.ValidFileName(curVarName), Comm.ValidFileName(curEntryName.Replace('\\', '_').Replace('/', '_')));
            if (Directory.Exists(sceneCacheFolderName))
            {
                buttonClearCache.Visible = true;
            }
            else
            {
                buttonClearCache.Visible = false;
            }
        }

        private static string GetKnownFolderPath(Guid knownFolderId)
        {
            IntPtr pszPath = IntPtr.Zero;
            try
            {
                int hr = SHGetKnownFolderPath(knownFolderId, 0, IntPtr.Zero, out pszPath);
                if (hr >= 0)
                    return Marshal.PtrToStringAuto(pszPath);
                throw Marshal.GetExceptionForHR(hr);
            }
            finally
            {
                if (pszPath != IntPtr.Zero)
                    Marshal.FreeCoTaskMem(pszPath);
            }
        }

        [DllImport("shell32.dll")]
        static extern int SHGetKnownFolderPath([MarshalAs(UnmanagedType.LPStruct)] Guid rfid, uint dwFlags, IntPtr hToken, out IntPtr pszPath);

        private void buttonLogAnalysis_Click(object sender, EventArgs e)
        {
            string message = "Analyzing dependencies from log file, otherwise a processing window will be opened.\r\nThis feature requires the game to be closed";

            const string caption = "LogAnalysis";
            var result = MessageBox.Show(message, caption,
                                         MessageBoxButtons.YesNo,
                                         MessageBoxIcon.Question,
                                         MessageBoxDefaultButton.Button1);
            if (result == DialogResult.Yes)
            {
                backgroundWorkerInstall.RunWorkerAsync("LogAnalysis");
            }
        }

        private void LogAnalysis()
        {
            Guid localLowId = new Guid("A520A1A4-1780-4FF6-BD18-167343C5AF16");
            string appdataPath = GetKnownFolderPath(localLowId);
            string logfile = Path.Combine(appdataPath, "MeshedVR\\VaM\\output_log.txt");
            if (File.Exists(logfile))
            {
                string logstring;
                using (var metajsonsteam = new StreamReader(logfile))
                {
                    logstring = metajsonsteam.ReadToEnd();
                }
                System.Diagnostics.Process.Start(logfile);
                List<string> dependencies = new List<string>();
                try
                {
                    Regex regexObj = new Regex(@"Missing\s+addon\s+package\s+(?<depens>[^\x3A\x2E]{1,60}\x2E[^\x3A\x2E]{1,80}\x2E(?:\d+|latest))\s+that\s+package(?<package>[^\x3A\x2E]{1,60}\x2E[^\x3A\x2E]{1,80}\x2E\d+)", RegexOptions.IgnoreCase | RegexOptions.Singleline);
                    Match matchResult = regexObj.Match(logstring);
                    while (matchResult.Success)
                    {
                        dependencies.Add(matchResult.Groups["depens"].Value);
                        matchResult = matchResult.NextMatch();
                    }
                }
                catch (ArgumentException ex)
                {
                    this.BeginInvoke(addlog, new Object[] { "LogAnalysis failed" + ex.Message, LogLevel.ERROR });
                }
                dependencies = dependencies.Distinct().ToList();
                List<string> missingvars = new List<string>();
                foreach (string varname in dependencies)
                {
                    string varexistname = VarExistName(varname);
                    if (varexistname.EndsWith("$"))
                    {
                        varexistname = varexistname.Substring(0, varexistname.Length - 1);
                        missingvars.Add(varname + "$");
                    }
                    if (varexistname != "missing")
                    {
                        VarInstall(varexistname);
                        this.BeginInvoke(addlog, new Object[] { varexistname + " installed", LogLevel.INFO });
                    }
                    else
                    {
                        missingvars.Add(varname);
                    }
                }
                if (missingvars.Count > 0)
                {
                    InvokeShowformMissingVars showformMissingVars = new InvokeShowformMissingVars(ShowformMissingVars);
                    this.BeginInvoke(showformMissingVars, missingvars);
                }
            }
        }

        private void varsViewDataGridView_DataError(object sender, DataGridViewDataErrorEventArgs e)
        {
            this.BeginInvoke(addlog, new Object[] { $"varsViewDataGridView_DataError, {e.Exception.Message}", LogLevel.ERROR });
        }

        private void buttonUninstallSels_Click(object sender, EventArgs e)
        {
            List<string> varNames = new List<string>();
            foreach (DataGridViewRow row in varsViewDataGridView.SelectedRows)
            {
                string varName = row.Cells["varNameDataGridViewTextBoxColumn"].Value.ToString();
                var varsrow = dbContext.InstallStatuses.FirstOrDefault(i => i.VarName == varName);
                if (varsrow != null)
                {
                    if (varsrow.Installed)
                    {
                        varNames.Add(varName);
                    }
                }
            }
            if (varNames.Count <= 0)
            {
                return;
            }
            int max = 500;
            if (varNames.Count > max)
            {
                MessageBox.Show($"Please do not uninstall more than {max} files at once");
                return;
            }

            // Step 1: Call preview_uninstall API to get the full list
            BackendJobResult previewResult;
            try
            {
                previewResult = RunBackendJob("preview_uninstall", new { var_names = varNames, include_implicated = true });
            }
            catch (Exception ex)
            {
                BeginInvoke(addlog, new Object[] { $"预览卸载列表失败: {ex.Message}", LogLevel.ERROR });
                return;
            }

            if (!previewResult.Succeeded)
            {
                BeginInvoke(addlog, new Object[] { "预览卸载列表失败", LogLevel.ERROR });
                return;
            }

            var preview = DeserializeResult<PreviewUninstallResult>(previewResult);
            if (preview == null || preview.var_list == null)
            {
                BeginInvoke(addlog, new Object[] { "无法解析预览结果", LogLevel.ERROR });
                return;
            }

            // Step 2: Show preview window if there are implicated vars
            if (preview.implicated.Count > 0)
            {
                FormUninstallVars formUninstallVars = new FormUninstallVars();
                formUninstallVars.previewpicsDirName = previewpicsDirName;
                formUninstallVars.Text = "Uninstall Vars Preview";
                formUninstallVars.VarsToUninstall = preview.var_list;

                if (formUninstallVars.ShowDialog() != DialogResult.OK)
                {
                    return;
                }
            }
            else
            {
                // No implicated vars, show simple confirmation dialog
                string message = $"There are {varNames.Count} vars will be uninstalled, are you sure?";
                string caption = "Uninstall Vars";
                var result = MessageBox.Show(message, caption,
                                      MessageBoxButtons.YesNo,
                                      MessageBoxIcon.Question,
                                      MessageBoxDefaultButton.Button2);
                if (result != DialogResult.Yes)
                {
                    return;
                }
            }

            // Step 3: Execute uninstall
            try
            {
                RunBackendJob("uninstall_vars", new { var_names = varNames, include_implicated = true });
                RefreshVarsViewUi();
                RunBackendJob("rescan_packages", null);
            }
            catch (Exception ex)
            {
                BeginInvoke(addlog, new Object[] { $"卸载失败: {ex.Message}", LogLevel.ERROR });
            }
        }

        private void buttonDelete_Click(object sender, EventArgs e)
        {
            List<string> varNames = new List<string>();
            foreach (DataGridViewRow row in varsViewDataGridView.SelectedRows)
            {
                string varName = row.Cells["varNameDataGridViewTextBoxColumn"].Value.ToString();

                varNames.Add(varName);
            }
            if (varNames.Count <= 0) return;
            int max = 50;
            if (varNames.Count > max)
            {
                MessageBox.Show($"Please do not delete more than {max} files at once");
                return;
            }
            string message = $"There are {varNames.Count} vars and their dependencies will be delete, are you sure?";
            string caption = "Delete Vars";
            var result = MessageBox.Show(message, caption,
                                  MessageBoxButtons.YesNo,
                                  MessageBoxIcon.Question,
                                  MessageBoxDefaultButton.Button2);
            if (result == DialogResult.Yes)
            {
                try
                {
                    RunBackendJob("delete_vars", new { var_names = varNames, include_implicated = true });
                    RefreshVarsViewUi();
                    RunBackendJob("rescan_packages", null);
                }
                catch (Exception ex)
                {
                    BeginInvoke(addlog, new Object[] { $"删除失败: {ex.Message}", LogLevel.ERROR });
                }
            }
        }

        private void buttonMove_Click(object sender, EventArgs e)
        {
            List<string> varNames = new List<string>();
            foreach (DataGridViewRow row in varsViewDataGridView.SelectedRows)
            {
                string varName = row.Cells["varNameDataGridViewTextBoxColumn"].Value.ToString();
                var varsrow = dbContext.InstallStatuses.FirstOrDefault(i => i.VarName == varName);
                if (varsrow != null)
                {
                    if (varsrow.Installed)
                    {
                        varNames.Add(varName);
                    }
                }
            }
            if (varNames.Count <= 0) return;
            FormVarsMove fvm = new FormVarsMove();
            fvm.VarlinkDirName = installLinkDirName;
            fvm.VarsToMove = varNames;
            if (fvm.ShowDialog() == DialogResult.OK)
            {
                try
                {
                    RunBackendJob("links_move", new { var_names = varNames, target_dir = fvm.MovetoDirName });
                }
                catch (Exception ex)
                {
                    BeginInvoke(addlog, new Object[] { $"移动失败: {ex.Message}", LogLevel.ERROR });
                }
            }

        }

        private void buttonExpInsted_Click(object sender, EventArgs e)
        {
            if (saveFileDialogExportInstalled.ShowDialog() == DialogResult.OK)
            {
                try
                {
                    RunBackendJob("vars_export_installed", new { path = saveFileDialogExportInstalled.FileName });
                }
                catch (Exception ex)
                {
                    BeginInvoke(addlog, new Object[] { $"导出失败: {ex.Message}", LogLevel.ERROR });
                }
            }
        }

        private void buttonInstFormTxt_Click(object sender, EventArgs e)
        {
            if (openFileDialogInstByTXT.ShowDialog() == DialogResult.OK)
            {
                try
                {
                    RunBackendJob("vars_install_batch", new { path = openFileDialogInstByTXT.FileName });
                    RunBackendJob("rescan_packages", null);
                    RefreshVarsViewUi();
                }
                catch (Exception ex)
                {
                    BeginInvoke(addlog, new Object[] { $"批量安装失败: {ex.Message}", LogLevel.ERROR });
                }
            }
        }

        private void comboBoxPacksSwitch_SelectedIndexChanged(object sender, EventArgs e)
        {
            
            string sw = (string)comboBoxPacksSwitch.SelectedItem;
            if (!string.IsNullOrEmpty(sw))
            {
                buttonPacksDelete.Enabled = (sw != "default");
                varpacksSwitch(sw);

            }
            else
            {
                buttonPacksDelete.Enabled = false;
            }
        }

        private void varpacksSwitch(string sw)
        {
            this.BeginInvoke(addlog, new Object[] { $"Point the Addonpackages symbo-link to '{sw}'", LogLevel.INFO });
            try
            {
                RunBackendJob("packswitch_set", new { name = sw });
                RefreshVarsViewUi();
            }
            catch (Exception ex)
            {
                BeginInvoke(addlog, new Object[] { $"切换失败: {ex.Message}", LogLevel.ERROR });
            }
        }

        private static void RescanPackages()
        {
            var vamproc = Process.GetProcessesByName("vam");
            if (vamproc.Length > 0)
            {
                string loadscenefile = Path.Combine(Settings.Default.vampath, "Custom\\PluginData\\feelfar\\loadscene.json");
                if (File.Exists(loadscenefile)) File.Delete(loadscenefile);
                Directory.CreateDirectory(Path.Combine(Settings.Default.vampath, "Custom\\PluginData\\feelfar"));
                JSONClass jc = new JSONClass();
                jc["rescan"] = "true";
                using (StreamWriter swLoad = new StreamWriter(loadscenefile))
                {
                    swLoad.Write(jc.ToString());
                }
            }
        }

        private void buttonPacksAdd_Click(object sender, EventArgs e)
        {
            FormSwitchAdd formSwitchAdd = new FormSwitchAdd();
            if (formSwitchAdd.ShowDialog() == DialogResult.OK)
            {
                try
                {
                    RunBackendJob("packswitch_add", new { name = formSwitchAdd.SwitchName });
                    if (comboBoxPacksSwitch.Items.IndexOf(formSwitchAdd.SwitchName) < 0)
                    {
                        comboBoxPacksSwitch.Items.Add(formSwitchAdd.SwitchName);
                    }
                    comboBoxPacksSwitch.SelectedItem = formSwitchAdd.SwitchName;
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Switch create failed: {ex.Message}");
                }
            }
        }

        private void buttonPacksDelete_Click(object sender, EventArgs e)
        {
            string curswitch = (string)comboBoxPacksSwitch.SelectedItem;
            if (!string.IsNullOrEmpty(curswitch) && curswitch != "default")
            {
                if (MessageBox.Show($"Will delete {curswitch} AddonPackagesSwitch, sure?", "delete switch", MessageBoxButtons.YesNo) == DialogResult.Yes)
                {
                    try
                    {
                        RunBackendJob("packswitch_delete", new { name = curswitch });
                        comboBoxPacksSwitch.Items.Remove(curswitch);
                        comboBoxPacksSwitch.SelectedItem = "default";
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Switch delete failed: {ex.Message}");
                    }
                }
            }

        }

        private void buttonPacksRename_Click(object sender, EventArgs e)
        {
            string curswitch = (string)comboBoxPacksSwitch.SelectedItem;
            if (!string.IsNullOrEmpty(curswitch) && curswitch != "default")
            {
                FormSwitchRename formSwitchRename = new FormSwitchRename();
                formSwitchRename.OldName = curswitch;
                if (formSwitchRename.ShowDialog() == DialogResult.OK)
                {
                    string newName = formSwitchRename.NewName;
                    try
                    {
                        RunBackendJob("packswitch_rename", new { old_name = curswitch, new_name = newName });
                        comboBoxPacksSwitch.Items[comboBoxPacksSwitch.SelectedIndex] = newName;
                        comboBoxPacksSwitch.SelectedItem = newName;
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Switch rename failed: {ex.Message}");
                    }
                }
            }
        }
        private (string,string) SaveNameSplit(string saveName)
        {
            string varname = "save", entryname = saveName;
            if (saveName.IndexOf(":/") > 1)
            {
                string[] savenamesplit = saveName.Split(new string[] { ":/" }, StringSplitOptions.RemoveEmptyEntries);
                if (savenamesplit.Length >= 2)
                {
                    varname = savenamesplit[0];
                    entryname = savenamesplit[1];
                }
            }
            return (varname, entryname);
        }
        private void buttonLoad_Click(object sender, EventArgs e)
        {
            bool merge = false;
            if (checkBoxMerge.Checked) merge = true;
            bool ignoreGender = false;
            if (checkBoxIgnoreGender.Checked) ignoreGender = true;
            string characterGender = "unknown";
            if (checkBoxForMale.Visible)
            {
                if (checkBoxForMale.Checked) characterGender = "male";
                else characterGender = "female";
            }
            int personOrder = 1;
            foreach (RadioButton rbperson in groupBoxPersonOrder.Controls)
            {
                if (rbperson.Checked)
                {
                    personOrder = int.Parse(rbperson.Text);
                    break;
                }
            }
            tableLayoutPanelPreview.Visible = false;
            Cursor = Cursors.WaitCursor;
            try
            {
                LoadScene(jsonLoadScene, merge, ignoreGender, characterGender, personOrder);
            }
            catch (Exception ex)
            {
                BeginInvoke(addlog, new Object[] { $"Load scene failed: {ex.Message}", LogLevel.ERROR });
            }
            Cursor = Cursors.Arrow;
            UpdateButtonClearCache();
        }

        public void LoadScene(JSONClass jc,bool merge, bool ignoreGender, string characterGender, int personOrder)
        {
            var jsonElement = JsonSerializer.Deserialize<JsonElement>(jc.ToString());
            RunBackendJob("scene_load", new
            {
                json = jsonElement,
                merge = merge,
                ignore_gender = ignoreGender,
                character_gender = characterGender,
                person_order = personOrder
            });
        }

        public bool FindByvarName(string varName)
        {
            bool inRepository = false;
            if (varName.EndsWith(".var"))
                varName = varName.Substring(0, varName.Length - 4);
            if (dbContext.Vars.Any(v => v.VarName == varName))
            {
                inRepository = true;
            }
            return inRepository;
        }
        public void GenLoadscenetxt(JSONClass jsonLS,bool merge, List<string> dependVars,string characterGender="female", bool ignoreGender = false,int personOrder=1 )
        {
            JSONClass jsonls = (JSONClass)JSONNode.Parse(jsonLS.ToString());
            List<string> deletetempfiles = new List<string>();
            JSONArray resources = jsonls["resources"].AsArray;
            foreach (JSONClass resource in resources)
            {
                if (!resource.HasKey("merge"))
                    resource["merge"] = merge.ToString().ToLower();
                if (!resource.HasKey("characterGender"))
                    resource["characterGender"] = characterGender;
                if (!resource.HasKey("ignoreGender"))
                    resource["ignoreGender"] = ignoreGender.ToString().ToLower();
                if (!resource.HasKey("personOrder"))
                    resource["personOrder"] = personOrder.ToString();
                if (resource.HasKey("type"))
                {
                    if (resource["type"].Value == "scenes")
                    {
                        deletetempfiles = AddDeleteTemp();
                        break;
                    }
                }
            }

            // if (jsonls["rescan"].AsBool)
            //{
            //List<string> varnames = new List<string>();
            if (dependVars == null)
            {
                dependVars = new List<string>();
                foreach (JSONClass resource in resources)
                {
                    string saveName = resource["saveName"].Value;
                    dependVars.Add(saveName.Substring(0, saveName.IndexOf(":/")));
                }
            }
            bool rescan = false;
            var installtemplist = InstallTemp(dependVars.ToArray(), ref rescan);
            jsonls["rescan"] = rescan.ToString();
            foreach (var installtemp in installtemplist)
                deletetempfiles.Remove(installtemp.ToLower() + ".var");
            // }
            string loadscenefile = Path.Combine(Settings.Default.vampath, "Custom\\PluginData\\feelfar\\loadscene.json");
            if (File.Exists(loadscenefile)) File.Delete(loadscenefile);
            Directory.CreateDirectory(Path.Combine(Settings.Default.vampath, "Custom\\PluginData\\feelfar"));
            //StreamWriter sw = new StreamWriter(loadscenefile);
            

            string strLS = jsonls.ToString("\t");
            using (FileStream fileStream = File.OpenWrite(loadscenefile))
            {
                fileStream.SetLength(0);
                StreamWriter sw = new StreamWriter(fileStream);
                sw.Write(strLS);
                sw.Close();
            }
            // jsonLS.SaveToFile(loadscenefile);
            //sw.Write(jsonLS);
            //sw.Close();
            if (deletetempfiles.Count > 0)
            {
                Thread thread = new Thread(DeleteTempThread);
                thread.Start(deletetempfiles);
            }
        }

        public static List<string> AddDeleteTemp()
        {
            DirectoryInfo templinkdirinfo = Directory.CreateDirectory(Path.Combine(Settings.Default.vampath, "AddonPackages", tempVarLinkDirName));

            List<string> tempfiles = new List<string>();
            foreach (FileInfo tempfinfo in templinkdirinfo.GetFiles())
            {
                if (tempfinfo.Attributes.HasFlag(FileAttributes.ReparsePoint))
                    tempfiles.Add(tempfinfo.Name.ToLower());
                    //tempfinfo.Delete();
            }
            return tempfiles;
        }

        public static void DeleteTempThread(object data)
        {
            List<string> tempfiles = data as List<string>;
            string loadscenefile = Path.Combine(Settings.Default.vampath, "Custom\\PluginData\\feelfar\\loadscene.json");

            while (true)
            {
                Thread.Sleep(2000);
                if (File.Exists(loadscenefile))
                {
                    continue;
                }
                else
                {
                    Thread.Sleep(20000);
                    foreach (string tempf in tempfiles)
                    {
                        try
                        {
                            if (File.Exists(Path.Combine(Settings.Default.vampath, "AddonPackages", tempVarLinkDirName, tempf)))
                                File.Delete(Path.Combine(Settings.Default.vampath, "AddonPackages", tempVarLinkDirName, tempf));
                        }
                        catch { }
                    }
                    break;
                }
            }
        }

        public List<string> InstallTemp(string[] varNames,ref bool rescan)
        {
            rescan = false;
            List<string> varnames = new List<string>();
            varnames.AddRange(varNames);
            varnames = VarsDependencies(varnames);
            varnames = varnames.Except(GetInstalledVars().Keys).ToList();
            DirectoryInfo templinkdirinfo = Directory.CreateDirectory(Path.Combine(Settings.Default.vampath, "AddonPackages", tempVarLinkDirName));

            foreach (string varname in varnames)
            {
                var rows = dbContext.VarsView.Where(q => q.VarName == varname);
                if (rows.Any())
                {
                    if (!rows.First().Installed)
                        if (VarInstall(varname, true) == 1) 
                            rescan = true;
                }
                else
                {
                    this.BeginInvoke(addlog, new Object[] { string.Format("missing var:{0},install failed", varname), LogLevel.INFO });
                }
            }
            return varnames;
        }

        private void checkBoxPreviewTypeLoadable_CheckedChanged(object sender, EventArgs e)
        {
            PreviewInitType();
        }

        private void buttonLocate_Click(object sender, EventArgs e)
        {
            string varName = labelPreviewVarName.Text;
            LocateVar(varName);
        }

        public void LocateVar(string varName)
        {
            try
            {
                RunBackendJob("vars_locate", new { var_name = varName });
            }
            catch (Exception ex)
            {
                BeginInvoke(addlog, new Object[] { $"定位失败: {ex.Message}", LogLevel.ERROR });
            }
        }

        private void buttonpreviewinstall_Click(object sender, EventArgs e)
        {
            string varName = labelPreviewVarName.Text;
            this.BeginInvoke(addlog, new Object[] { $"[debug] Preview install toggle clicked: var={varName}", LogLevel.INFO });
            bool isInstalled = dbContext.InstallStatuses.Any(q => q.VarName == varName && q.Installed);
            this.BeginInvoke(addlog, new Object[] { $"[debug] Preview install toggle state: installed={isInstalled}", LogLevel.INFO });
            if (isInstalled)
            {
                string message = varName + "  will be remove, are you sure?";
                string caption = "Remove Var";
                this.BeginInvoke(addlog, new Object[] { "[debug] Preview uninstall showing confirm dialog", LogLevel.INFO });
                var result = MessageBox.Show(message, caption,
                                      MessageBoxButtons.YesNo,
                                      MessageBoxIcon.Question,
                                      MessageBoxDefaultButton.Button2);
                this.BeginInvoke(addlog, new Object[] { $"[debug] Preview uninstall confirm result: {result}", LogLevel.INFO });
                if (result == DialogResult.Yes)
                {
                    try
                    {
                        this.BeginInvoke(addlog, new Object[] { "[debug] Preview uninstall start job: vars_toggle_install include_implicated=true include_dependencies=true", LogLevel.INFO });
                        RunBackendJob("vars_toggle_install", new { var_name = varName, include_dependencies = true, include_implicated = true });
                    }
                    catch (Exception ex)
                    {
                        BeginInvoke(addlog, new Object[] { $"卸载失败: {ex.Message}", LogLevel.ERROR });
                        return;
                    }
                }
            }
            else
            {
                string message = varName + "  will install, are you sure?";
                string caption = "Install Var";
                this.BeginInvoke(addlog, new Object[] { "[debug] Preview install showing confirm dialog", LogLevel.INFO });
                var result = MessageBox.Show(message, caption,
                                      MessageBoxButtons.YesNo,
                                      MessageBoxIcon.Question,
                                      MessageBoxDefaultButton.Button2);
                this.BeginInvoke(addlog, new Object[] { $"[debug] Preview install confirm result: {result}", LogLevel.INFO });
                if (result == DialogResult.Yes)
                {
                    try
                    {
                        this.BeginInvoke(addlog, new Object[] { "[debug] Preview install start job: vars_toggle_install include_dependencies=true include_implicated=true", LogLevel.INFO });
                        RunBackendJob("vars_toggle_install", new { var_name = varName, include_dependencies = true, include_implicated = true });
                    }
                    catch (Exception ex)
                    {
                        BeginInvoke(addlog, new Object[] { $"安装失败: {ex.Message}", LogLevel.ERROR });
                        return;
                    }
                }
            }
            RefreshVarsViewUi();
            try
            {
                RunBackendJob("rescan_packages", null);
            }
            catch (Exception ex)
            {
                BeginInvoke(addlog, new Object[] { $"Rescan failed: {ex.Message}", LogLevel.ERROR });
            }
        }

        private void buttonAnalysis_Click(object sender, EventArgs e)
        {
            string characterGender = "female";
            if (checkBoxForMale.Visible)
            {
                characterGender = checkBoxForMale.Checked ? "male" : "female";
            }
            Analysisscene(jsonLoadScene, characterGender);
            UpdateButtonClearCache();
        }

        public void Analysisscene(JSONClass jsonLS, string characterGender = "female")
        {
            JSONClass jsonls = (JSONClass)JSONNode.Parse(jsonLS.ToString());
            JSONArray resources = jsonls["resources"].AsArray;
            string saveName = "";
            if (resources.Count > 0)
            {
                JSONClass resource = (JSONClass)resources[0];
                saveName = resource["saveName"].Value;
            }
            if (string.IsNullOrEmpty(saveName))
            {
                return;
            }

            BackendJobResult result;
            try
            {
                result = RunBackendJob("scene_analyze", new
                {
                    save_name = saveName,
                    character_gender = characterGender
                });
            }
            catch (Exception ex)
            {
                BeginInvoke(addlog, new Object[] { $"分析失败: {ex.Message}", LogLevel.ERROR });
                return;
            }
            var payload = DeserializeResult<SceneAnalyzeResult>(result);
            if (payload == null)
            {
                return;
            }

            FormAnalysis formAnalysis = new FormAnalysis();
            formAnalysis.form1 = this;
            formAnalysis.VarName = payload.VarName;
            formAnalysis.EntryName = payload.EntryName;
            formAnalysis.CharacterGender = payload.CharacterGender;
            formAnalysis.ShowDialog();
        }
        public static string GetCharacterGender(string character)
        {
            string isMale = "Female";
            character = character.ToLower();
            // If the peson atom is not "On", then we cant determine their gender it seems as GetComponentInChildren<DAZCharacter> just returns null
            if (character.StartsWith("male") ||
                    character.StartsWith("lee") ||
                    character.StartsWith("jarlee") ||
                    character.StartsWith("julian") ||
                    character.StartsWith("jarjulian"))
            {
                isMale = "Male";
            }
            if (character.StartsWith("futa"))
            {
                isMale = "Futa";
            }
            return (isMale);
        }

        private static string GetAtomID(JSONNode atomitem,bool isPerson=false)
        {
            if (isPerson)
            {
                string charGender = "unknown";
                JSONArray storablesArray = atomitem["storables"].AsArray;
                foreach (JSONNode storablesitem in storablesArray)
                {
                    if (storablesitem["id"].Value == "geometry")
                    {
                        charGender = GetCharacterGender(storablesitem["character"].Value);
                        break;
                    }
                }
                return string.Format("({1}){0}", atomitem["id"], charGender);
            }
            else
                return atomitem["id"].Value;
        }

        public bool ReadSaveName(string saveName,string characterGender,bool analysis=false)
        {
            UseWaitCursor = true;
            string jsonscene = "";
            List<string> depends = new List<string>();
            (string varName, string entryName) = SaveNameSplit(saveName);
            if (varName!="save")
            {
                depends.Add(varName);
                var varsrow = dbContext.Vars.FirstOrDefault(v => v.VarName == varName);
                string destvarfile = Path.Combine(Settings.Default.varspath, varsrow!.VarPath!, varsrow.VarName + ".var");
                using (ZipFile varzipfile = new ZipFile(destvarfile))
                {
                    var entry = varzipfile.GetEntry(entryName);
                    var entryStream = new StreamReader(varzipfile.GetInputStream(entry));
                    jsonscene = entryStream.ReadToEnd();
                }
            }
            else
            {
                string jsonfile = Path.Combine(Settings.Default.vampath, saveName);
                if (File.Exists(jsonfile))
                {
                    using (StreamReader sr = new StreamReader(jsonfile))
                    {
                        jsonscene = sr.ReadToEnd();
                    }
                }
            }

            if (characterGender == "unknown")
            {
                characterGender = "male";

                if (jsonscene.IndexOf("/Female/") > 0|| saveName.IndexOf("/Female/") > 0)
                {
                    characterGender = "female";
                }
            }

            depends.AddRange(Getdependencies(jsonscene));
            string sceneFolder = Path.Combine(Directory.GetCurrentDirectory(), "Cache",
                Comm.ValidFileName(varName), Comm.ValidFileName(entryName.Replace('\\', '_').Replace('/', '_')));
            Directory.CreateDirectory(sceneFolder);
            string dependFilename = Path.Combine(sceneFolder, "depend.txt");
            using (StreamWriter swdepend = new StreamWriter(dependFilename))
                depends.ForEach(x => swdepend.WriteLine(x));

            string genderFilename = Path.Combine(sceneFolder, "gender.txt");
            using (StreamWriter swgender = new StreamWriter(genderFilename))
                swgender.WriteLine(characterGender);

            if (analysis)
            {
                jsonscene = jsonscene.Replace("\"SELF:/", "\"" + varName + ":/");
                AnalysisAtoms(jsonscene, sceneFolder,true);
            }
            UseWaitCursor = false;
            return true;
        }
        private static string[] sceneBaseAtoms = { "CoreControl", "PlayerNavigationPanel", "VRController", "WindowCamera" };

        private static void AnalysisAtoms(string jsonscene, string sceneFolder,bool isperson)
        {
            JSONClass jsonnode =(JSONClass) JSON.Parse(jsonscene);
            if (!jsonnode.HasKey("atoms")) 
            {
                if (isperson)
                {
                    string atomID = GetAtomID(jsonnode, true);
                    string atomtypefolder = Path.Combine(sceneFolder, "atoms", "Person");
                    Directory.CreateDirectory(atomtypefolder);
                    string atomfilename = Path.Combine(sceneFolder, "atoms", "Person", Comm.ValidFileName(atomID + ".bin"));
                    jsonnode.SaveToFile(atomfilename);
                    /*using (StreamWriter sw = new StreamWriter(atomfilename))
                    {
                        jsonnode.SaveToStream(sw.BaseStream);
                        //sw.Write(jsonnode.ToString());
                    }*/
                }
                else
                {
                    string atomID = GetAtomID(jsonnode, false);
                    string atomfilename = Path.Combine(sceneFolder, Comm.ValidFileName(atomID + ".bin"));
                    jsonnode.SaveToFile(atomfilename);
                    /* using (StreamWriter sw = new StreamWriter(atomfilename))
                     {
                         jsonnode.SaveToStream(sw.BaseStream);
                         //sw.Write(jsonnode.ToString());
                     }*/
                }
                return;
            }
            JSONClass posinfo = new JSONClass();
            foreach (KeyValuePair<string, JSONNode> keyvaluejson in jsonnode as JSONClass)
            {
                if (keyvaluejson.Key != "atoms")
                {
                    posinfo.Add(keyvaluejson.Key, keyvaluejson.Value);
                }
            }

            string posinfoFilename = Path.Combine(sceneFolder, "posinfo.bin");
            posinfo.SaveToFile(posinfoFilename);
            /*using (StreamWriter sw = new StreamWriter(posinfoFilename))
            {
                sw.Write(posinfo.ToString());
            }*/

            List<string> ListAtomtype = new List<string>();
            JSONArray atomArray = jsonnode["atoms"].AsArray;
           
            Dictionary<string, List<string>> parentAtoms=new Dictionary<string, List<string>>();
            if (atomArray.Count > 0)
            {
                foreach (JSONClass atomitem in atomArray)
                {
                    string atomtype = atomitem["type"];
                    if (sceneBaseAtoms.Contains(atomtype))
                    {
                        atomtype = "(base)" + atomtype;
                    }
                    if (atomtype != "")
                    {
                        if (!ListAtomtype.Contains(atomtype))
                        {
                            ListAtomtype.Add(atomtype);
                            string atomtypefolder = Path.Combine(sceneFolder, "atoms", atomtype);
                            Directory.CreateDirectory(atomtypefolder);
                        }
                        if (atomtype == "SubScene")
                        {
                            string subscenefolder = Path.Combine(sceneFolder, "atoms", atomtype);
                            AnalysisAtoms(atomitem.ToString(), subscenefolder, false);
                        }
                        else
                        {
                            string atomID = GetAtomID(atomitem, atomtype == "Person");
                            if (atomitem.HasKey("parentAtom"))
                            {
                                if (!string.IsNullOrEmpty(atomitem["parentAtom"]))
                                {
                                    string parentAtom = Comm.ValidFileName(atomitem["parentAtom"]);
                                    if (parentAtoms.ContainsKey(parentAtom))
                                    {
                                        parentAtoms[parentAtom].Add(Comm.ValidFileName(atomID));
                                    }
                                    else
                                    {
                                        parentAtoms.Add(parentAtom, new List<string> { Comm.ValidFileName(atomID) });
                                    }
                                }
                            }
                            string atomfilename = Path.Combine(sceneFolder, "atoms", atomtype, Comm.ValidFileName(atomID + ".bin"));
                            atomitem.SaveToFile(atomfilename);
                            /*using (StreamWriter sw = new StreamWriter(atomfilename))
                            {
                                sw.Write(atomitem.ToString());
                            }*/
                        }
                    }
                }
                if(parentAtoms.Count > 0)
                {
                    string parentAtomFilename = Path.Combine(sceneFolder, "parentAtom.txt");
                    using(StreamWriter sw= new StreamWriter(parentAtomFilename))
                    {
                        foreach(var pa in parentAtoms)
                        {
                            sw.WriteLine(pa.Key + "\t" + string.Join(",", pa.Value));
                        }
                        
                    }
                }
                
            }
        }

        private void buttonResetFilter_Click(object sender, EventArgs e)
        {
            ResetFilter();
        }

        private void ResetFilter()
        {
            comboBoxCreater.SelectedItem = "____ALL";
            textBoxFilter.Text = "";
            dgvFilterManager.ActivateAllFilters(false);
        }

        private void SwitchControl_Enter(object sender, EventArgs e)
        {
            if (ExistAddonpackagesVar())
            {
                if (MessageBox.Show("There are unorganized var files in the current switch, please run UPD_DB first", "warning", MessageBoxButtons.OKCancel) == DialogResult.OK)
                    buttonUpdDB.Focus();
            }
        }

        private void buttonFixPreview_Click(object sender, EventArgs e)
        {
            string message = "Missing preview images will be detected and re-extracted.";

            const string caption = "RebuildLink";
            var result = MessageBox.Show(message, caption,
                                         MessageBoxButtons.YesNo,
                                         MessageBoxIcon.Question,
                                         MessageBoxDefaultButton.Button1);
            if (result == DialogResult.Yes)
                backgroundWorkerInstall.RunWorkerAsync("fixPreview");
        }

        private void buttonHub_Click(object sender, EventArgs e)
        {
            FormHub formhub = new FormHub();
            formhub.form1 = this;
            formhub.Show();
        }
        public void SelectVarInList(string varname)
        {
            ResetFilter();

            int firstindex = int.MaxValue;
            varsViewDataGridView.ClearSelection();
            foreach (DataGridViewRow row in varsViewDataGridView.Rows)
            {
                string varnameinrow = row.Cells["varNamedataGridViewTextBoxColumn"].Value.ToString();
                if (varname== varnameinrow)
                {
                    row.Selected = true;
                    if (row.Index < firstindex) firstindex = row.Index;
                }
            }
            if (firstindex == int.MaxValue) firstindex = 0;
            if (varsViewDataGridView.SelectedRows.Count > 0)
            {
                varsViewDataGridView.FirstDisplayedScrollingRowIndex = firstindex;
            }
            this.WindowState = FormWindowState.Normal;
            //this.Activate();
        }

        private void prepareFormSavesToolStripMenuItem_Click(object sender, EventArgs e)
        {
            PrepareSaves prepareSaves = new PrepareSaves();
            prepareSaves.form1 = this;
            prepareSaves.ShowDialog();
        }

        private void buttonFilteredMissingDepends_Click(object sender, EventArgs e)
        {
            int varscount= varsViewDataGridView.Rows.Count;
            string message =String.Format( "Analyzing dependencies from {0} vars on the leftside of form, a processing window will be opened.",varscount);

            const string caption = "FilteredMissingDepends";
            var result = MessageBox.Show(message, caption,
                                         MessageBoxButtons.YesNo,
                                         MessageBoxIcon.Question,
                                         MessageBoxDefaultButton.Button1);
            if (result == DialogResult.Yes)
            {
                backgroundWorkerInstall.RunWorkerAsync("FilteredMissingDepends");
            }
        }

        private void buttonClearCache_Click(object sender, EventArgs e)
        {
            if (MessageBox.Show("The cache can improve the speed of secondary analysis, normally you don't need to clear it, unless you modify the scene file. This operation only clears the cache of the current scene, if you need to clear all the cache, please delete the cache directory manually.", "Clear Cache", MessageBoxButtons.YesNo) == DialogResult.Yes)
            {
                try
                {
                    RunBackendJob("cache_clear", new { var_name = curVarName, entry_name = curEntryName });
                }
                catch (Exception ex)
                {
                    BeginInvoke(addlog, new Object[] { $"清理缓存失败: {ex.Message}", LogLevel.ERROR });
                }
                UpdateButtonClearCache();
            }
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            backendCts.Cancel();
            try
            {
                BackendSession.ShutdownAsync(LogBackendLine, CancellationToken.None).GetAwaiter().GetResult();
            }
            catch
            {
            }
            base.OnFormClosing(e);
        }
    }
}
