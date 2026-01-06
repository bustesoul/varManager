using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Threading;
using varManager.Backend;
using static SimpleLogger;
using varManager.Properties;

namespace varManager
{
    public partial class FormVarDetail : Form
    {
        public string strVarName;
        public Form1 form1;
        public string strAction;
        public Dictionary<string,string> dependencies;
        public List<string> DependentVarList;
        public List<string> DependentJsonList;
        private Size _layoutClientSize;

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

        private BackendJobResult RunBackendJob(string kind, object? args)
        {
            return BackendSession.RunJob(kind, args, LogBackendLine, CancellationToken.None);
        }
        public FormVarDetail()
        {
            InitializeComponent();
            _layoutClientSize = ClientSize;
            AutoScroll = true;
            AutoScrollMinSize = _layoutClientSize;
        }

        private void FormVarDetail_Load(object sender, EventArgs e)
        {
            textBoxVarName.Text = strVarName;

            foreach (var dep in dependencies)
            {
                if (dep.Value == "missing")
                    dataGridViewDependency.Rows.Add("search", dep.Key);
                else
                    dataGridViewDependency.Rows.Add("locate", dep.Key);
            }
            foreach (DataGridViewRow deprow in dataGridViewDependency.Rows)
            {

                string dependName = (string)deprow.Cells["ColumnDependName"].Value;
                string dependVar = dependencies[dependName];
                if (dependVar == "missing")
                {
                    deprow.DefaultCellStyle.BackColor = Color.Red;
                }
                else if (!dependName.ToLower().EndsWith("latest"))
                {
                    if (dependName.ToLower() != dependVar.ToLower())
                        deprow.DefaultCellStyle.BackColor = Color.Yellow;
                }

            }
            foreach (string dependentvar in DependentVarList)
            {
                dataGridViewDependentVar.Rows.Add("locate", dependentvar);
            }
            foreach (DataGridViewRow deprow in dataGridViewDependentVar.Rows)
            {

                string dependentVar = (string)deprow.Cells["ColumnDependentVar"].Value;
               
                if (form1.IsVarInstalled(dependentVar))
                {
                    deprow.DefaultCellStyle.BackColor = Color.Green;
                }

            }
            foreach (string dependentsaved in DependentJsonList)
            {
                dataGridViewDependentSaved.Rows.Add("locate", dependentsaved);
            }

            FitToWorkingArea();
        }

        private void FitToWorkingArea()
        {
            var workingArea = Screen.FromControl(this).WorkingArea;
            var nonClientSize = new Size(Width - ClientSize.Width, Height - ClientSize.Height);
            var maxClientWidth = workingArea.Width - nonClientSize.Width;
            var maxClientHeight = workingArea.Height - nonClientSize.Height;
            var targetClientWidth = Math.Min(_layoutClientSize.Width, maxClientWidth);
            var targetClientHeight = Math.Min(_layoutClientSize.Height, maxClientHeight);
            if (targetClientWidth < _layoutClientSize.Width || targetClientHeight < _layoutClientSize.Height)
            {
                ClientSize = new Size(
                    Math.Max(200, targetClientWidth),
                    Math.Max(200, targetClientHeight));
            }

            var bounds = Bounds;
            var x = Math.Max(workingArea.Left, Math.Min(bounds.Left, workingArea.Right - bounds.Width));
            var y = Math.Max(workingArea.Top, Math.Min(bounds.Top, workingArea.Bottom - bounds.Height));
            Location = new Point(x, y);
        }

        private void buttonLocate_Click(object sender, EventArgs e)
        {
            try
            {
                RunBackendJob("vars_locate", new { var_name = strVarName });
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Locate failed: {ex.Message}");
            }
        }

        private void buttonFilter_Click(object sender, EventArgs e)
        {
            strAction = "filter";
            DialogResult = DialogResult.OK;
            this.Close();
        }

        private void dataGridViewDependency_CellContentClick(object sender, DataGridViewCellEventArgs e)
        {
            if (dataGridViewDependency.Columns[e.ColumnIndex].Name == "ColumnAction1" && e.RowIndex >= 0)
            {
                string dependName = dataGridViewDependency.Rows[e.RowIndex].Cells["ColumnDependName"].Value.ToString();
                string dependVar = dependencies[dependName];
                if (dependVar == "missing")
                {
                    string varname = dependName.Replace(".latest", ".1");
                    try
                    {
                        RunBackendJob("open_url", new { url = "https://www.google.com/search?q=" + varname + " var" });
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Open url failed: {ex.Message}");
                    }
                }
                else
                {
                    form1.SelectVarInList(dependVar);
                    form1.Activate();
                }
            }
        }

        private void dataGridViewDependentVar_CellContentClick(object sender, DataGridViewCellEventArgs e)
        {
            if (dataGridViewDependentVar.Columns[e.ColumnIndex].Name == "ColumnAction2" && e.RowIndex >= 0)
            {
                string varName = dataGridViewDependentVar.Rows[e.RowIndex].Cells["ColumnDependentVar"].Value.ToString();

                form1.SelectVarInList(varName);
                form1.Activate();
            }
        }

        private void dataGridViewDependentSaved_CellContentClick(object sender, DataGridViewCellEventArgs e)
        {
            if (dataGridViewDependentSaved.Columns[e.ColumnIndex].Name == "ColumnAction3" && e.RowIndex >= 0)
            {
                string saved = dataGridViewDependentSaved.Rows[e.RowIndex].Cells["ColumnDependentSaved"].Value.ToString();
                if(saved.StartsWith("\\"))
                    saved = saved.Substring(1);

                try
                {
                    RunBackendJob("vars_locate", new { path = saved.Replace('/', '\\') });
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Locate failed: {ex.Message}");
                }

            }
        }
    }
}
