using System;
using System.IO;
using System.Threading;
using System.Windows.Forms;
using varManager.Backend;
using varManager.Properties;

namespace varManager
{
    public partial class FormSettings : Form
    {
        public FormSettings()
        {
            InitializeComponent();
        }

        private void buttonVarspath_Click(object sender, EventArgs e)
        {
            folderBrowserDialogVars.SelectedPath = textBoxVarspath.Text;
            folderBrowserDialogVars.ShowDialog();
            textBoxVarspath.Text = folderBrowserDialogVars.SelectedPath;
        }

        private void buttonVamPath_Click(object sender, EventArgs e)
        {
            folderBrowserDialogVam.SelectedPath = textBoxVamPath.Text;
            folderBrowserDialogVam.ShowDialog();
            textBoxVamPath.Text = folderBrowserDialogVam.SelectedPath;
        }

        private void buttonExec_Click(object sender, EventArgs e)
        {
            openFileDialogExec.InitialDirectory = Path.GetDirectoryName(textBoxExec.Text);
            openFileDialogExec.FileName = Path.GetFileName(textBoxExec.Text);
            if (openFileDialogExec.ShowDialog() == DialogResult.OK)
            {
                textBoxExec.Text = Path.GetFileName(openFileDialogExec.FileName); // 只获取文件名
            }
        }

        private async void FormSettings_Load(object sender, EventArgs e)
        {
            try
            {
                await BackendSession.EnsureStartedAsync(null, CancellationToken.None).ConfigureAwait(true);
            }
            catch
            {
            }

            var cfg = BackendSession.Config;
            textBoxVarspath.Text = cfg?.Varspath ?? Properties.Settings.Default.varspath;
            textBoxVamPath.Text = cfg?.Vampath ?? Properties.Settings.Default.vampath;
            textBoxExec.Text = cfg?.VamExec ?? Properties.Settings.Default.defaultVamExec;

            SetReadOnlyUi();
        }

        private void SetReadOnlyUi()
        {
            textBoxVarspath.ReadOnly = true;
            textBoxVamPath.ReadOnly = true;
            textBoxExec.ReadOnly = true;
            buttonVarspath.Enabled = false;
            buttonVamPath.Enabled = false;
            buttonExec.Enabled = false;
            buttonSave.Text = "Close";
        }

        private void buttonSave_Click(object sender, EventArgs e)
        {
            MessageBox.Show("配置由后端管理，请编辑 config.json 后重启。");
            this.DialogResult = DialogResult.OK;
            this.Close();
        }

        private void FormSettings_FormClosing(object sender, FormClosingEventArgs e)
        {
            if (this.DialogResult == DialogResult.None)
                e.Cancel = true;
        }
    }
}
