
namespace varManager
{
    partial class Form1
    {
        /// <summary>
        /// 必需的设计器变量。
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// 清理所有正在使用的资源。
        /// </summary>
        /// <param name="disposing">如果应释放托管资源，为 true；否则为 false。</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                if (components != null)
                {
                    components.Dispose();
                }
                _dbContext?.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows 窗体设计器生成的代码

        /// <summary>
        /// 设计器支持所需的方法 - 不要修改
        /// 使用代码编辑器修改此方法的内容。
        /// </summary>
        private void InitializeComponent()
        {
            components = new System.ComponentModel.Container();
            DataGridViewCellStyle dataGridViewCellStyle1 = new DataGridViewCellStyle();
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(Form1));
            buttonSetting = new Button();
            tableLayoutPanel1 = new TableLayoutPanel();
            listBoxLog = new ListBox();
            panel1 = new Panel();
            buttonFixPreview = new Button();
            groupBoxSwitch = new GroupBox();
            comboBoxPacksSwitch = new ComboBox();
            buttonPacksDelete = new Button();
            buttonPacksRename = new Button();
            buttonPacksAdd = new Button();
            buttonFixRebuildLink = new Button();
            groupBox1 = new GroupBox();
            buttonMissingDepends = new Button();
            buttonFilteredMissingDepends = new Button();
            buttonAllMissingDepends = new Button();
            buttonFixSavesDepend = new Button();
            contextMenuStripPrepareSave = new ContextMenuStrip(components);
            prepareFormSavesToolStripMenuItem = new ToolStripMenuItem();
            buttonScenesManager = new Button();
            buttonStaleVars = new Button();
            buttonUpdDB = new Button();
            buttonStartVam = new Button();
            tableLayoutPanel2 = new TableLayoutPanel();
            progressBar1 = new ProgressBar();
            labelProgress = new Label();
            splitContainer1 = new SplitContainer();
            varsViewDataGridView = new DataGridView();
            varNamedataGridViewTextBoxColumn = new DataGridViewTextBoxColumn();
            installedDataGridViewCheckBoxColumn = new DataGridViewCheckBoxColumn();
            ColumnDetail = new DataGridViewButtonColumn();
            fsize = new DataGridViewTextBoxColumn();
            varPathDataGridViewTextBoxColumn = new DataGridViewTextBoxColumn();
            creatorNameDataGridViewTextBoxColumn = new DataGridViewTextBoxColumn();
            packageNameDataGridViewTextBoxColumn = new DataGridViewTextBoxColumn();
            versionDataGridViewTextBoxColumn = new DataGridViewTextBoxColumn();
            metaDateDataGridViewTextBoxColumn = new DataGridViewTextBoxColumn();
            varDateDataGridViewTextBoxColumn = new DataGridViewTextBoxColumn();
            scenesDataGridViewTextBoxColumn = new DataGridViewTextBoxColumn();
            looksDataGridViewTextBoxColumn = new DataGridViewTextBoxColumn();
            clothingDataGridViewTextBoxColumn = new DataGridViewTextBoxColumn();
            hairstyleDataGridViewTextBoxColumn = new DataGridViewTextBoxColumn();
            pluginsDataGridViewTextBoxColumn = new DataGridViewTextBoxColumn();
            assetsDataGridViewTextBoxColumn = new DataGridViewTextBoxColumn();
            morphs = new DataGridViewTextBoxColumn();
            pose = new DataGridViewTextBoxColumn();
            skin = new DataGridViewTextBoxColumn();
            disabledDataGridViewCheckBoxColumn = new DataGridViewCheckBoxColumn();
            varsViewBindingSource = new BindingSource(components);
            flowLayoutPanel2 = new FlowLayoutPanel();
            buttonInstall = new Button();
            buttonUninstallSels = new Button();
            buttonDelete = new Button();
            buttonMove = new Button();
            buttonExpInsted = new Button();
            buttonInstFormTxt = new Button();
            buttonHub = new Button();
            buttonClearLog = new Button();
            flowLayoutPanel1 = new FlowLayoutPanel();
            varsBindingNavigator = new BindingNavigator(components);
            bindingNavigatorCountItem = new ToolStripLabel();
            bindingNavigatorMoveFirstItem = new ToolStripButton();
            bindingNavigatorMovePreviousItem = new ToolStripButton();
            bindingNavigatorSeparator = new ToolStripSeparator();
            bindingNavigatorPositionItem = new ToolStripTextBox();
            bindingNavigatorSeparator1 = new ToolStripSeparator();
            bindingNavigatorMoveNextItem = new ToolStripButton();
            bindingNavigatorMoveLastItem = new ToolStripButton();
            bindingNavigatorSeparator2 = new ToolStripSeparator();
            label1 = new Label();
            comboBoxCreater = new ComboBox();
            label2 = new Label();
            textBoxFilter = new TextBox();
            checkBoxInstalled = new CheckBox();
            buttonResetFilter = new Button();
            tableLayoutPanelPreview = new TableLayoutPanel();
            pictureBoxPreview = new PictureBox();
            labelPreviewVarName = new Label();
            buttonLocate = new Button();
            panel3 = new Panel();
            buttonLoad = new Button();
            checkBoxForMale = new CheckBox();
            checkBoxIgnoreGender = new CheckBox();
            groupBoxPersonOrder = new GroupBox();
            radioButtonPersonOrder6 = new RadioButton();
            radioButtonPersonOrder8 = new RadioButton();
            radioButtonPersonOrder7 = new RadioButton();
            radioButtonPersonOrder5 = new RadioButton();
            radioButtonPersonOrder4 = new RadioButton();
            radioButtonPersonOrder3 = new RadioButton();
            radioButtonPersonOrder2 = new RadioButton();
            radioButtonPersonOrder1 = new RadioButton();
            checkBoxMerge = new CheckBox();
            buttonClearCache = new Button();
            buttonAnalysis = new Button();
            buttonpreviewinstall = new Button();
            listViewPreviewPics = new ListView();
            imageListPreviewPics = new ImageList(components);
            flowLayoutPanel3 = new FlowLayoutPanel();
            toolStripPreview = new ToolStrip();
            toolStripButtonPreviewFirst = new ToolStripButton();
            toolStripButtonPreviewPrev = new ToolStripButton();
            toolStripLabelPreviewItemIndex = new ToolStripLabel();
            toolStripLabelPreviewCountItem = new ToolStripLabel();
            toolStripButtonPreviewNext = new ToolStripButton();
            toolStripButtonPreviewLast = new ToolStripButton();
            label4 = new Label();
            comboBoxPreviewType = new ComboBox();
            checkBoxPreviewTypeLoadable = new CheckBox();
            backgroundWorkerInstall = new System.ComponentModel.BackgroundWorker();
            toolTip1 = new ToolTip(components);
            backgroundWorkerPreview = new System.ComponentModel.BackgroundWorker();
            folderBrowserDialogMove = new FolderBrowserDialog();
            openFileDialogInstByTXT = new OpenFileDialog();
            saveFileDialogExportInstalled = new SaveFileDialog();
            varsBindingSource = new BindingSource(components);
            dependenciesBindingSource = new BindingSource(components);
            installStatusBindingSource = new BindingSource(components);
            scenesBindingSource = new BindingSource(components);
            tableLayoutPanel1.SuspendLayout();
            panel1.SuspendLayout();
            groupBoxSwitch.SuspendLayout();
            groupBox1.SuspendLayout();
            contextMenuStripPrepareSave.SuspendLayout();
            tableLayoutPanel2.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)splitContainer1).BeginInit();
            splitContainer1.Panel1.SuspendLayout();
            splitContainer1.Panel2.SuspendLayout();
            splitContainer1.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)varsViewDataGridView).BeginInit();
            ((System.ComponentModel.ISupportInitialize)varsViewBindingSource).BeginInit();
            flowLayoutPanel2.SuspendLayout();
            flowLayoutPanel1.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)varsBindingNavigator).BeginInit();
            varsBindingNavigator.SuspendLayout();
            tableLayoutPanelPreview.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)pictureBoxPreview).BeginInit();
            panel3.SuspendLayout();
            groupBoxPersonOrder.SuspendLayout();
            flowLayoutPanel3.SuspendLayout();
            toolStripPreview.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)varsBindingSource).BeginInit();
            ((System.ComponentModel.ISupportInitialize)dependenciesBindingSource).BeginInit();
            ((System.ComponentModel.ISupportInitialize)installStatusBindingSource).BeginInit();
            ((System.ComponentModel.ISupportInitialize)scenesBindingSource).BeginInit();
            SuspendLayout();
            // 
            // buttonSetting
            // 
            buttonSetting.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
            buttonSetting.Location = new Point(33, 749);
            buttonSetting.Name = "buttonSetting";
            buttonSetting.Size = new Size(89, 48);
            buttonSetting.TabIndex = 0;
            buttonSetting.Text = "Settings";
            buttonSetting.UseVisualStyleBackColor = true;
            buttonSetting.Click += buttonSetting_Click;
            // 
            // tableLayoutPanel1
            // 
            tableLayoutPanel1.ColumnCount = 2;
            tableLayoutPanel1.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            tableLayoutPanel1.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 159F));
            tableLayoutPanel1.Controls.Add(listBoxLog, 0, 1);
            tableLayoutPanel1.Controls.Add(panel1, 1, 0);
            tableLayoutPanel1.Controls.Add(tableLayoutPanel2, 0, 2);
            tableLayoutPanel1.Controls.Add(splitContainer1, 0, 0);
            tableLayoutPanel1.Dock = DockStyle.Fill;
            tableLayoutPanel1.Location = new Point(0, 0);
            tableLayoutPanel1.Name = "tableLayoutPanel1";
            tableLayoutPanel1.RowCount = 3;
            tableLayoutPanel1.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
            tableLayoutPanel1.RowStyles.Add(new RowStyle(SizeType.Absolute, 245F));
            tableLayoutPanel1.RowStyles.Add(new RowStyle(SizeType.Absolute, 26F));
            tableLayoutPanel1.Size = new Size(1540, 829);
            tableLayoutPanel1.TabIndex = 2;
            // 
            // listBoxLog
            // 
            listBoxLog.Dock = DockStyle.Fill;
            listBoxLog.FormattingEnabled = true;
            listBoxLog.ItemHeight = 21;
            listBoxLog.Location = new Point(3, 561);
            listBoxLog.Name = "listBoxLog";
            listBoxLog.Size = new Size(1375, 239);
            listBoxLog.TabIndex = 2;
            toolTip1.SetToolTip(listBoxLog, "Log");
            // 
            // panel1
            // 
            panel1.AutoScroll = true;
            panel1.Controls.Add(buttonFixPreview);
            panel1.Controls.Add(groupBoxSwitch);
            panel1.Controls.Add(buttonFixRebuildLink);
            panel1.Controls.Add(groupBox1);
            panel1.Controls.Add(buttonScenesManager);
            panel1.Controls.Add(buttonStaleVars);
            panel1.Controls.Add(buttonUpdDB);
            panel1.Controls.Add(buttonStartVam);
            panel1.Controls.Add(buttonSetting);
            panel1.Dock = DockStyle.Fill;
            panel1.Location = new Point(1384, 3);
            panel1.Name = "panel1";
            tableLayoutPanel1.SetRowSpan(panel1, 3);
            panel1.Size = new Size(153, 823);
            panel1.TabIndex = 5;
            // 
            // buttonFixPreview
            // 
            buttonFixPreview.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            buttonFixPreview.Location = new Point(17, 568);
            buttonFixPreview.Name = "buttonFixPreview";
            buttonFixPreview.Size = new Size(118, 29);
            buttonFixPreview.TabIndex = 1;
            buttonFixPreview.Text = "Fix Preview";
            toolTip1.SetToolTip(buttonFixPreview, "Re-extract the lost preview images");
            buttonFixPreview.UseVisualStyleBackColor = true;
            buttonFixPreview.Click += buttonFixPreview_Click;
            // 
            // groupBoxSwitch
            // 
            groupBoxSwitch.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            groupBoxSwitch.Controls.Add(comboBoxPacksSwitch);
            groupBoxSwitch.Controls.Add(buttonPacksDelete);
            groupBoxSwitch.Controls.Add(buttonPacksRename);
            groupBoxSwitch.Controls.Add(buttonPacksAdd);
            groupBoxSwitch.Location = new Point(9, 10);
            groupBoxSwitch.Name = "groupBoxSwitch";
            groupBoxSwitch.Size = new Size(235, 149);
            groupBoxSwitch.TabIndex = 6;
            groupBoxSwitch.TabStop = false;
            groupBoxSwitch.Text = "AddonPacks Switch";
            // 
            // comboBoxPacksSwitch
            // 
            comboBoxPacksSwitch.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            comboBoxPacksSwitch.DropDownStyle = ComboBoxStyle.DropDownList;
            comboBoxPacksSwitch.FormattingEnabled = true;
            comboBoxPacksSwitch.Location = new Point(8, 34);
            comboBoxPacksSwitch.Name = "comboBoxPacksSwitch";
            comboBoxPacksSwitch.Size = new Size(118, 29);
            comboBoxPacksSwitch.TabIndex = 0;
            toolTip1.SetToolTip(comboBoxPacksSwitch, "Switching AddonPackagess");
            comboBoxPacksSwitch.SelectedIndexChanged += comboBoxPacksSwitch_SelectedIndexChanged;
            comboBoxPacksSwitch.Enter += SwitchControl_Enter;
            // 
            // buttonPacksDelete
            // 
            buttonPacksDelete.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            buttonPacksDelete.ForeColor = Color.OrangeRed;
            buttonPacksDelete.Location = new Point(72, 65);
            buttonPacksDelete.Name = "buttonPacksDelete";
            buttonPacksDelete.Size = new Size(54, 35);
            buttonPacksDelete.TabIndex = 2;
            buttonPacksDelete.Text = "Del";
            toolTip1.SetToolTip(buttonPacksDelete, "Delete current AddonPackages");
            buttonPacksDelete.UseVisualStyleBackColor = true;
            buttonPacksDelete.Click += buttonPacksDelete_Click;
            buttonPacksDelete.Enter += SwitchControl_Enter;
            // 
            // buttonPacksRename
            // 
            buttonPacksRename.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            buttonPacksRename.ForeColor = Color.Maroon;
            buttonPacksRename.Location = new Point(29, 106);
            buttonPacksRename.Name = "buttonPacksRename";
            buttonPacksRename.Size = new Size(84, 35);
            buttonPacksRename.TabIndex = 3;
            buttonPacksRename.Text = "Rename";
            toolTip1.SetToolTip(buttonPacksRename, "Rename current AddonPackages");
            buttonPacksRename.UseVisualStyleBackColor = true;
            buttonPacksRename.Click += buttonPacksRename_Click;
            buttonPacksRename.Enter += SwitchControl_Enter;
            // 
            // buttonPacksAdd
            // 
            buttonPacksAdd.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            buttonPacksAdd.ForeColor = SystemColors.HotTrack;
            buttonPacksAdd.Location = new Point(8, 65);
            buttonPacksAdd.Name = "buttonPacksAdd";
            buttonPacksAdd.Size = new Size(54, 35);
            buttonPacksAdd.TabIndex = 1;
            buttonPacksAdd.Text = "Add";
            toolTip1.SetToolTip(buttonPacksAdd, "Add AddonPackages");
            buttonPacksAdd.UseVisualStyleBackColor = true;
            buttonPacksAdd.Click += buttonPacksAdd_Click;
            buttonPacksAdd.Enter += SwitchControl_Enter;
            // 
            // buttonFixRebuildLink
            // 
            buttonFixRebuildLink.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            buttonFixRebuildLink.Location = new Point(17, 534);
            buttonFixRebuildLink.Name = "buttonFixRebuildLink";
            buttonFixRebuildLink.Size = new Size(118, 28);
            buttonFixRebuildLink.TabIndex = 1;
            buttonFixRebuildLink.Text = "Rebuild symlink";
            toolTip1.SetToolTip(buttonFixRebuildLink, "When your Vars source directory changes, you need to rebuild symlinks");
            buttonFixRebuildLink.UseVisualStyleBackColor = true;
            buttonFixRebuildLink.Click += buttonFixRebuildLink_Click;
            // 
            // groupBox1
            // 
            groupBox1.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            groupBox1.Controls.Add(buttonMissingDepends);
            groupBox1.Controls.Add(buttonFilteredMissingDepends);
            groupBox1.Controls.Add(buttonAllMissingDepends);
            groupBox1.Controls.Add(buttonFixSavesDepend);
            groupBox1.ForeColor = Color.SaddleBrown;
            groupBox1.Location = new Point(9, 264);
            groupBox1.Name = "groupBox1";
            groupBox1.Size = new Size(235, 233);
            groupBox1.TabIndex = 5;
            groupBox1.TabStop = false;
            groupBox1.Text = "Depends Analysis";
            // 
            // buttonMissingDepends
            // 
            buttonMissingDepends.Location = new Point(24, 24);
            buttonMissingDepends.Name = "buttonMissingDepends";
            buttonMissingDepends.Size = new Size(89, 28);
            buttonMissingDepends.TabIndex = 0;
            buttonMissingDepends.Text = "Installed Packages";
            toolTip1.SetToolTip(buttonMissingDepends, "Analyzing dependencies from Installed Vars");
            buttonMissingDepends.UseVisualStyleBackColor = true;
            buttonMissingDepends.Click += buttonMissingDepends_Click;
            // 
            // buttonFilteredMissingDepends
            // 
            buttonFilteredMissingDepends.Location = new Point(24, 179);
            buttonFilteredMissingDepends.Name = "buttonFilteredMissingDepends";
            buttonFilteredMissingDepends.Size = new Size(89, 28);
            buttonFilteredMissingDepends.TabIndex = 1;
            buttonFilteredMissingDepends.Text = "Filtered Packages";
            toolTip1.SetToolTip(buttonFilteredMissingDepends, "Analyzing dependencies from filtered list on the leftside of form");
            buttonFilteredMissingDepends.UseVisualStyleBackColor = true;
            buttonFilteredMissingDepends.Click += buttonFilteredMissingDepends_Click;
            // 
            // buttonAllMissingDepends
            // 
            buttonAllMissingDepends.Location = new Point(24, 126);
            buttonAllMissingDepends.Name = "buttonAllMissingDepends";
            buttonAllMissingDepends.Size = new Size(89, 28);
            buttonAllMissingDepends.TabIndex = 1;
            buttonAllMissingDepends.Text = "All Packages";
            toolTip1.SetToolTip(buttonAllMissingDepends, "Analyzing dependencies from All Vars");
            buttonAllMissingDepends.UseVisualStyleBackColor = true;
            buttonAllMissingDepends.Click += buttonAllMissingDepends_Click;
            // 
            // buttonFixSavesDepend
            // 
            buttonFixSavesDepend.ContextMenuStrip = contextMenuStripPrepareSave;
            buttonFixSavesDepend.Location = new Point(24, 75);
            buttonFixSavesDepend.Name = "buttonFixSavesDepend";
            buttonFixSavesDepend.Size = new Size(89, 28);
            buttonFixSavesDepend.TabIndex = 1;
            buttonFixSavesDepend.Text = "\"Saves\" JsonFile";
            toolTip1.SetToolTip(buttonFixSavesDepend, "Analyzing dependencies from json files in \"Saves\" folder and vap files in \"Custom\" folder\r\n");
            buttonFixSavesDepend.UseVisualStyleBackColor = true;
            buttonFixSavesDepend.Click += buttonFixSavesDepend_Click;
            // 
            // contextMenuStripPrepareSave
            // 
            contextMenuStripPrepareSave.ImageScalingSize = new Size(20, 20);
            contextMenuStripPrepareSave.Items.AddRange(new ToolStripItem[] { prepareFormSavesToolStripMenuItem });
            contextMenuStripPrepareSave.Name = "contextMenuStripPrepareSave";
            contextMenuStripPrepareSave.Size = new Size(250, 34);
            // 
            // prepareFormSavesToolStripMenuItem
            // 
            prepareFormSavesToolStripMenuItem.Name = "prepareFormSavesToolStripMenuItem";
            prepareFormSavesToolStripMenuItem.Size = new Size(249, 30);
            prepareFormSavesToolStripMenuItem.Text = "Prepare Form Saves";
            prepareFormSavesToolStripMenuItem.Click += prepareFormSavesToolStripMenuItem_Click;
            // 
            // buttonScenesManager
            // 
            buttonScenesManager.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            buttonScenesManager.Font = new Font("Cambria", 9F, FontStyle.Bold, GraphicsUnit.Point);
            buttonScenesManager.ForeColor = Color.RoyalBlue;
            buttonScenesManager.Location = new Point(17, 637);
            buttonScenesManager.Name = "buttonScenesManager";
            buttonScenesManager.Size = new Size(118, 28);
            buttonScenesManager.TabIndex = 3;
            buttonScenesManager.Text = "Hide| |Fav";
            toolTip1.SetToolTip(buttonScenesManager, "Batch hide or favorite Scenes and Presets,");
            buttonScenesManager.UseVisualStyleBackColor = true;
            buttonScenesManager.Click += buttonScenesManager_Click;
            // 
            // buttonStaleVars
            // 
            buttonStaleVars.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            buttonStaleVars.Location = new Point(17, 603);
            buttonStaleVars.Name = "buttonStaleVars";
            buttonStaleVars.Size = new Size(118, 28);
            buttonStaleVars.TabIndex = 2;
            buttonStaleVars.Text = "Stale Vars";
            toolTip1.SetToolTip(buttonStaleVars, "Move old version packages are not dependent on other packages to ___VarTidied___ dirtory");
            buttonStaleVars.UseVisualStyleBackColor = true;
            buttonStaleVars.Click += buttonStaleVars_Click;
            // 
            // buttonUpdDB
            // 
            buttonUpdDB.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            buttonUpdDB.Font = new Font("Cambria", 9F, FontStyle.Bold, GraphicsUnit.Point);
            buttonUpdDB.ForeColor = Color.RoyalBlue;
            buttonUpdDB.Location = new Point(17, 164);
            buttonUpdDB.Name = "buttonUpdDB";
            buttonUpdDB.Size = new Size(118, 29);
            buttonUpdDB.TabIndex = 0;
            buttonUpdDB.Text = "UPD_DB";
            toolTip1.SetToolTip(buttonUpdDB, "Organize vars, extract preview images,update DB.");
            buttonUpdDB.UseVisualStyleBackColor = true;
            buttonUpdDB.Click += buttonUpdDB_Click;
            // 
            // buttonStartVam
            // 
            buttonStartVam.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            buttonStartVam.Font = new Font("Cambria", 9F, FontStyle.Bold, GraphicsUnit.Point);
            buttonStartVam.ForeColor = Color.RoyalBlue;
            buttonStartVam.Location = new Point(17, 199);
            buttonStartVam.Name = "buttonStartVam";
            buttonStartVam.Size = new Size(118, 32);
            buttonStartVam.TabIndex = 7;
            buttonStartVam.Text = "Start VAM";
            toolTip1.SetToolTip(buttonStartVam, "Start VAM application");
            buttonStartVam.UseVisualStyleBackColor = true;
            buttonStartVam.Click += buttonStartVam_Click;
            // 
            // tableLayoutPanel2
            // 
            tableLayoutPanel2.ColumnCount = 2;
            tableLayoutPanel2.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 160F));
            tableLayoutPanel2.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            tableLayoutPanel2.Controls.Add(progressBar1, 1, 0);
            tableLayoutPanel2.Controls.Add(labelProgress, 0, 0);
            tableLayoutPanel2.Dock = DockStyle.Fill;
            tableLayoutPanel2.Location = new Point(3, 806);
            tableLayoutPanel2.Name = "tableLayoutPanel2";
            tableLayoutPanel2.RowCount = 1;
            tableLayoutPanel2.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
            tableLayoutPanel2.Size = new Size(1375, 20);
            tableLayoutPanel2.TabIndex = 7;
            // 
            // progressBar1
            // 
            progressBar1.Dock = DockStyle.Fill;
            progressBar1.Location = new Point(163, 3);
            progressBar1.Name = "progressBar1";
            progressBar1.Size = new Size(1209, 14);
            progressBar1.TabIndex = 4;
            // 
            // labelProgress
            // 
            labelProgress.Anchor = AnchorStyles.None;
            labelProgress.AutoSize = true;
            labelProgress.Location = new Point(60, 0);
            labelProgress.Name = "labelProgress";
            labelProgress.Size = new Size(39, 20);
            labelProgress.TabIndex = 5;
            labelProgress.Text = "0/0";
            // 
            // splitContainer1
            // 
            splitContainer1.Dock = DockStyle.Fill;
            splitContainer1.Location = new Point(3, 3);
            splitContainer1.Name = "splitContainer1";
            // 
            // splitContainer1.Panel1
            // 
            splitContainer1.Panel1.AutoScroll = true;
            splitContainer1.Panel1.Controls.Add(varsViewDataGridView);
            splitContainer1.Panel1.Controls.Add(flowLayoutPanel2);
            splitContainer1.Panel1.Controls.Add(flowLayoutPanel1);
            // 
            // splitContainer1.Panel2
            // 
            splitContainer1.Panel2.Controls.Add(tableLayoutPanelPreview);
            splitContainer1.Panel2.Controls.Add(listViewPreviewPics);
            splitContainer1.Panel2.Controls.Add(flowLayoutPanel3);
            splitContainer1.Size = new Size(1375, 552);
            splitContainer1.SplitterDistance = 836;
            splitContainer1.TabIndex = 8;
            // 
            // varsViewDataGridView
            // 
            varsViewDataGridView.AllowUserToAddRows = false;
            varsViewDataGridView.AllowUserToDeleteRows = false;
            varsViewDataGridView.AutoGenerateColumns = false;
            varsViewDataGridView.ColumnHeadersHeightSizeMode = DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            varsViewDataGridView.Columns.AddRange(new DataGridViewColumn[] { varNamedataGridViewTextBoxColumn, installedDataGridViewCheckBoxColumn, ColumnDetail, fsize, varPathDataGridViewTextBoxColumn, creatorNameDataGridViewTextBoxColumn, packageNameDataGridViewTextBoxColumn, versionDataGridViewTextBoxColumn, metaDateDataGridViewTextBoxColumn, varDateDataGridViewTextBoxColumn, scenesDataGridViewTextBoxColumn, looksDataGridViewTextBoxColumn, clothingDataGridViewTextBoxColumn, hairstyleDataGridViewTextBoxColumn, pluginsDataGridViewTextBoxColumn, assetsDataGridViewTextBoxColumn, morphs, pose, skin, disabledDataGridViewCheckBoxColumn });
            varsViewDataGridView.DataSource = varsViewBindingSource;
            varsViewDataGridView.Dock = DockStyle.Fill;
            varsViewDataGridView.Location = new Point(0, 70);
            varsViewDataGridView.Name = "varsViewDataGridView";
            varsViewDataGridView.ReadOnly = true;
            varsViewDataGridView.RowHeadersWidth = 20;
            varsViewDataGridView.RowTemplate.Height = 27;
            varsViewDataGridView.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
            varsViewDataGridView.ShowCellToolTips = false;
            varsViewDataGridView.Size = new Size(836, 434);
            varsViewDataGridView.TabIndex = 6;
            toolTip1.SetToolTip(varsViewDataGridView, "Multiple selectable,Right click column header for advanced filter");
            varsViewDataGridView.CellContentClick += varsViewDataGridView_CellContentClick;
            varsViewDataGridView.DataError += varsViewDataGridView_DataError;
            // 
            // varNamedataGridViewTextBoxColumn
            // 
            varNamedataGridViewTextBoxColumn.DataPropertyName = "varName";
            varNamedataGridViewTextBoxColumn.HeaderText = "varName";
            varNamedataGridViewTextBoxColumn.MinimumWidth = 6;
            varNamedataGridViewTextBoxColumn.Name = "varNamedataGridViewTextBoxColumn";
            varNamedataGridViewTextBoxColumn.ReadOnly = true;
            varNamedataGridViewTextBoxColumn.Width = 180;
            // 
            // installedDataGridViewCheckBoxColumn
            // 
            installedDataGridViewCheckBoxColumn.DataPropertyName = "Installed";
            installedDataGridViewCheckBoxColumn.HeaderText = "Installed";
            installedDataGridViewCheckBoxColumn.MinimumWidth = 6;
            installedDataGridViewCheckBoxColumn.Name = "installedDataGridViewCheckBoxColumn";
            installedDataGridViewCheckBoxColumn.ReadOnly = true;
            installedDataGridViewCheckBoxColumn.Width = 68;
            // 
            // ColumnDetail
            // 
            ColumnDetail.HeaderText = "Detail";
            ColumnDetail.MinimumWidth = 6;
            ColumnDetail.Name = "ColumnDetail";
            ColumnDetail.ReadOnly = true;
            ColumnDetail.Text = "Detail";
            ColumnDetail.UseColumnTextForButtonValue = true;
            ColumnDetail.Width = 60;
            // 
            // fsize
            // 
            fsize.DataPropertyName = "fsize";
            dataGridViewCellStyle1.Format = "N2";
            dataGridViewCellStyle1.NullValue = null;
            fsize.DefaultCellStyle = dataGridViewCellStyle1;
            fsize.HeaderText = "fsize(MB)";
            fsize.MinimumWidth = 6;
            fsize.Name = "fsize";
            fsize.ReadOnly = true;
            fsize.Width = 70;
            // 
            // varPathDataGridViewTextBoxColumn
            // 
            varPathDataGridViewTextBoxColumn.DataPropertyName = "varPath";
            varPathDataGridViewTextBoxColumn.HeaderText = "varPath";
            varPathDataGridViewTextBoxColumn.MinimumWidth = 6;
            varPathDataGridViewTextBoxColumn.Name = "varPathDataGridViewTextBoxColumn";
            varPathDataGridViewTextBoxColumn.ReadOnly = true;
            varPathDataGridViewTextBoxColumn.Visible = false;
            varPathDataGridViewTextBoxColumn.Width = 125;
            // 
            // creatorNameDataGridViewTextBoxColumn
            // 
            creatorNameDataGridViewTextBoxColumn.DataPropertyName = "creatorName";
            creatorNameDataGridViewTextBoxColumn.HeaderText = "creatorName";
            creatorNameDataGridViewTextBoxColumn.MinimumWidth = 6;
            creatorNameDataGridViewTextBoxColumn.Name = "creatorNameDataGridViewTextBoxColumn";
            creatorNameDataGridViewTextBoxColumn.ReadOnly = true;
            creatorNameDataGridViewTextBoxColumn.Visible = false;
            creatorNameDataGridViewTextBoxColumn.Width = 125;
            // 
            // packageNameDataGridViewTextBoxColumn
            // 
            packageNameDataGridViewTextBoxColumn.DataPropertyName = "packageName";
            packageNameDataGridViewTextBoxColumn.HeaderText = "packageName";
            packageNameDataGridViewTextBoxColumn.MinimumWidth = 6;
            packageNameDataGridViewTextBoxColumn.Name = "packageNameDataGridViewTextBoxColumn";
            packageNameDataGridViewTextBoxColumn.ReadOnly = true;
            packageNameDataGridViewTextBoxColumn.Visible = false;
            packageNameDataGridViewTextBoxColumn.Width = 125;
            // 
            // versionDataGridViewTextBoxColumn
            // 
            versionDataGridViewTextBoxColumn.DataPropertyName = "version";
            versionDataGridViewTextBoxColumn.HeaderText = "version";
            versionDataGridViewTextBoxColumn.MinimumWidth = 6;
            versionDataGridViewTextBoxColumn.Name = "versionDataGridViewTextBoxColumn";
            versionDataGridViewTextBoxColumn.ReadOnly = true;
            versionDataGridViewTextBoxColumn.Visible = false;
            versionDataGridViewTextBoxColumn.Width = 125;
            // 
            // metaDateDataGridViewTextBoxColumn
            // 
            metaDateDataGridViewTextBoxColumn.DataPropertyName = "metaDate";
            metaDateDataGridViewTextBoxColumn.HeaderText = "Date";
            metaDateDataGridViewTextBoxColumn.MinimumWidth = 6;
            metaDateDataGridViewTextBoxColumn.Name = "metaDateDataGridViewTextBoxColumn";
            metaDateDataGridViewTextBoxColumn.ReadOnly = true;
            metaDateDataGridViewTextBoxColumn.Width = 105;
            // 
            // varDateDataGridViewTextBoxColumn
            // 
            varDateDataGridViewTextBoxColumn.DataPropertyName = "varDate";
            varDateDataGridViewTextBoxColumn.HeaderText = "VarDate";
            varDateDataGridViewTextBoxColumn.MinimumWidth = 6;
            varDateDataGridViewTextBoxColumn.Name = "varDateDataGridViewTextBoxColumn";
            varDateDataGridViewTextBoxColumn.ReadOnly = true;
            varDateDataGridViewTextBoxColumn.Width = 105;
            // 
            // scenesDataGridViewTextBoxColumn
            // 
            scenesDataGridViewTextBoxColumn.DataPropertyName = "scenes";
            scenesDataGridViewTextBoxColumn.HeaderText = "scenes";
            scenesDataGridViewTextBoxColumn.MinimumWidth = 6;
            scenesDataGridViewTextBoxColumn.Name = "scenesDataGridViewTextBoxColumn";
            scenesDataGridViewTextBoxColumn.ReadOnly = true;
            scenesDataGridViewTextBoxColumn.Width = 45;
            // 
            // looksDataGridViewTextBoxColumn
            // 
            looksDataGridViewTextBoxColumn.DataPropertyName = "looks";
            looksDataGridViewTextBoxColumn.HeaderText = "looks";
            looksDataGridViewTextBoxColumn.MinimumWidth = 6;
            looksDataGridViewTextBoxColumn.Name = "looksDataGridViewTextBoxColumn";
            looksDataGridViewTextBoxColumn.ReadOnly = true;
            looksDataGridViewTextBoxColumn.Width = 45;
            // 
            // clothingDataGridViewTextBoxColumn
            // 
            clothingDataGridViewTextBoxColumn.DataPropertyName = "clothing";
            clothingDataGridViewTextBoxColumn.HeaderText = "clothes";
            clothingDataGridViewTextBoxColumn.MinimumWidth = 6;
            clothingDataGridViewTextBoxColumn.Name = "clothingDataGridViewTextBoxColumn";
            clothingDataGridViewTextBoxColumn.ReadOnly = true;
            clothingDataGridViewTextBoxColumn.Width = 45;
            // 
            // hairstyleDataGridViewTextBoxColumn
            // 
            hairstyleDataGridViewTextBoxColumn.DataPropertyName = "hairstyle";
            hairstyleDataGridViewTextBoxColumn.HeaderText = "hairs";
            hairstyleDataGridViewTextBoxColumn.MinimumWidth = 6;
            hairstyleDataGridViewTextBoxColumn.Name = "hairstyleDataGridViewTextBoxColumn";
            hairstyleDataGridViewTextBoxColumn.ReadOnly = true;
            hairstyleDataGridViewTextBoxColumn.Width = 45;
            // 
            // pluginsDataGridViewTextBoxColumn
            // 
            pluginsDataGridViewTextBoxColumn.DataPropertyName = "plugins";
            pluginsDataGridViewTextBoxColumn.HeaderText = "plugins";
            pluginsDataGridViewTextBoxColumn.MinimumWidth = 6;
            pluginsDataGridViewTextBoxColumn.Name = "pluginsDataGridViewTextBoxColumn";
            pluginsDataGridViewTextBoxColumn.ReadOnly = true;
            pluginsDataGridViewTextBoxColumn.Width = 45;
            // 
            // assetsDataGridViewTextBoxColumn
            // 
            assetsDataGridViewTextBoxColumn.DataPropertyName = "assets";
            assetsDataGridViewTextBoxColumn.HeaderText = "assets";
            assetsDataGridViewTextBoxColumn.MinimumWidth = 6;
            assetsDataGridViewTextBoxColumn.Name = "assetsDataGridViewTextBoxColumn";
            assetsDataGridViewTextBoxColumn.ReadOnly = true;
            assetsDataGridViewTextBoxColumn.Width = 45;
            // 
            // morphs
            // 
            morphs.DataPropertyName = "morphs";
            morphs.HeaderText = "morphs";
            morphs.MinimumWidth = 6;
            morphs.Name = "morphs";
            morphs.ReadOnly = true;
            morphs.Width = 45;
            // 
            // pose
            // 
            pose.DataPropertyName = "pose";
            pose.HeaderText = "pose";
            pose.MinimumWidth = 6;
            pose.Name = "pose";
            pose.ReadOnly = true;
            pose.Width = 45;
            // 
            // skin
            // 
            skin.DataPropertyName = "skin";
            skin.HeaderText = "skin";
            skin.MinimumWidth = 6;
            skin.Name = "skin";
            skin.ReadOnly = true;
            skin.Width = 45;
            // 
            // disabledDataGridViewCheckBoxColumn
            // 
            disabledDataGridViewCheckBoxColumn.DataPropertyName = "Disabled";
            disabledDataGridViewCheckBoxColumn.HeaderText = "Disabled";
            disabledDataGridViewCheckBoxColumn.MinimumWidth = 6;
            disabledDataGridViewCheckBoxColumn.Name = "disabledDataGridViewCheckBoxColumn";
            disabledDataGridViewCheckBoxColumn.ReadOnly = true;
            disabledDataGridViewCheckBoxColumn.Visible = false;
            disabledDataGridViewCheckBoxColumn.Width = 68;
            // 
            // varsViewBindingSource
            // 
            varsViewBindingSource.DataMember = "varsView";
            // DataSource will be set in code using EF Core
            // varsViewBindingSource.Sort = "metaDate Desc"; // Moved to Form1_Load to avoid .NET 9 initialization issues
            // 
            // flowLayoutPanel2
            // 
            flowLayoutPanel2.AutoScroll = true;
            flowLayoutPanel2.AutoSize = true;
            flowLayoutPanel2.AutoSizeMode = AutoSizeMode.GrowAndShrink;
            flowLayoutPanel2.Controls.Add(buttonInstall);
            flowLayoutPanel2.Controls.Add(buttonUninstallSels);
            flowLayoutPanel2.Controls.Add(buttonDelete);
            flowLayoutPanel2.Controls.Add(buttonMove);
            flowLayoutPanel2.Controls.Add(buttonExpInsted);
            flowLayoutPanel2.Controls.Add(buttonInstFormTxt);
            flowLayoutPanel2.Controls.Add(buttonHub);
            flowLayoutPanel2.Controls.Add(buttonClearLog);
            flowLayoutPanel2.Dock = DockStyle.Bottom;
            flowLayoutPanel2.ForeColor = SystemColors.ActiveCaptionText;
            flowLayoutPanel2.Location = new Point(0, 504);
            flowLayoutPanel2.Name = "flowLayoutPanel2";
            flowLayoutPanel2.Size = new Size(836, 48);
            flowLayoutPanel2.TabIndex = 9;
            // 
            // buttonInstall
            // 
            buttonInstall.Font = new Font("Cambria", 9F, FontStyle.Regular, GraphicsUnit.Point);
            buttonInstall.ForeColor = SystemColors.Highlight;
            buttonInstall.Location = new Point(3, 3);
            buttonInstall.Name = "buttonInstall";
            buttonInstall.Size = new Size(70, 42);
            buttonInstall.TabIndex = 0;
            buttonInstall.Text = "Install Selected";
            toolTip1.SetToolTip(buttonInstall, "Install Selected vars and Dependencies ");
            buttonInstall.UseVisualStyleBackColor = true;
            buttonInstall.Click += buttonInstall_Click;
            // 
            // buttonUninstallSels
            // 
            buttonUninstallSels.Font = new Font("Cambria", 9F, FontStyle.Regular, GraphicsUnit.Point);
            buttonUninstallSels.ForeColor = Color.IndianRed;
            buttonUninstallSels.Location = new Point(79, 3);
            buttonUninstallSels.Name = "buttonUninstallSels";
            buttonUninstallSels.Size = new Size(70, 42);
            buttonUninstallSels.TabIndex = 1;
            buttonUninstallSels.Text = "UnInst Selected";
            toolTip1.SetToolTip(buttonUninstallSels, "Uninstall Selected vars and Dependent impact items");
            buttonUninstallSels.UseVisualStyleBackColor = true;
            buttonUninstallSels.Click += buttonUninstallSels_Click;
            // 
            // buttonDelete
            // 
            buttonDelete.BackColor = Color.Red;
            buttonDelete.Font = new Font("Cambria", 9F, FontStyle.Regular, GraphicsUnit.Point);
            buttonDelete.ForeColor = Color.Yellow;
            buttonDelete.Location = new Point(155, 3);
            buttonDelete.Name = "buttonDelete";
            buttonDelete.Size = new Size(70, 42);
            buttonDelete.TabIndex = 2;
            buttonDelete.Text = "Delete Selected";
            toolTip1.SetToolTip(buttonDelete, "Delete Selected vars and Dependent impact items");
            buttonDelete.UseVisualStyleBackColor = false;
            buttonDelete.Click += buttonDelete_Click;
            // 
            // buttonMove
            // 
            buttonMove.Font = new Font("Cambria", 9F, FontStyle.Regular, GraphicsUnit.Point);
            buttonMove.Location = new Point(231, 3);
            buttonMove.Name = "buttonMove";
            buttonMove.Size = new Size(70, 42);
            buttonMove.TabIndex = 3;
            buttonMove.Text = "Move SeleLinks To SubDir";
            buttonMove.UseVisualStyleBackColor = false;
            buttonMove.Click += buttonMove_Click;
            // 
            // buttonExpInsted
            // 
            buttonExpInsted.Font = new Font("Cambria", 9F, FontStyle.Regular, GraphicsUnit.Point);
            buttonExpInsted.Location = new Point(307, 3);
            buttonExpInsted.Name = "buttonExpInsted";
            buttonExpInsted.Size = new Size(70, 42);
            buttonExpInsted.TabIndex = 4;
            buttonExpInsted.Text = "Export Insted";
            toolTip1.SetToolTip(buttonExpInsted, "Export Installed vars to text file.");
            buttonExpInsted.UseVisualStyleBackColor = false;
            buttonExpInsted.Click += buttonExpInsted_Click;
            // 
            // buttonInstFormTxt
            // 
            buttonInstFormTxt.Font = new Font("Cambria", 9F, FontStyle.Regular, GraphicsUnit.Point);
            buttonInstFormTxt.Location = new Point(383, 3);
            buttonInstFormTxt.Name = "buttonInstFormTxt";
            buttonInstFormTxt.Size = new Size(70, 42);
            buttonInstFormTxt.TabIndex = 5;
            buttonInstFormTxt.Text = "Install By TXT";
            toolTip1.SetToolTip(buttonInstFormTxt, "install vars from txt file.");
            buttonInstFormTxt.UseVisualStyleBackColor = true;
            buttonInstFormTxt.Click += buttonInstFormTxt_Click;
            // 
            // buttonHub
            // 
            buttonHub.BackColor = Color.DarkSlateGray;
            buttonHub.Font = new Font("Cambria", 9F, FontStyle.Regular, GraphicsUnit.Point);
            buttonHub.ForeColor = SystemColors.HighlightText;
            buttonHub.Image = Properties.Resources.vam_logo_hub;
            buttonHub.Location = new Point(459, 3);
            buttonHub.Name = "buttonHub";
            buttonHub.Size = new Size(118, 42);
            buttonHub.TabIndex = 5;
            buttonHub.Text = "Brow";
            buttonHub.TextAlign = ContentAlignment.MiddleRight;
            buttonHub.TextImageRelation = TextImageRelation.ImageBeforeText;
            toolTip1.SetToolTip(buttonHub, "Hub browsing, combined with analysis of all the var files you have.");
            buttonHub.UseVisualStyleBackColor = false;
            buttonHub.Click += buttonHub_Click;
            // 
            // buttonClearLog
            // 
            buttonClearLog.Font = new Font("Cambria", 9F, FontStyle.Regular, GraphicsUnit.Point);
            buttonClearLog.Location = new Point(583, 3);
            buttonClearLog.Name = "buttonClearLog";
            buttonClearLog.Size = new Size(90, 42);
            buttonClearLog.TabIndex = 6;
            buttonClearLog.Text = "ClearLog";
            toolTip1.SetToolTip(buttonClearLog, "Clear the log list.");
            buttonClearLog.UseVisualStyleBackColor = true;
            buttonClearLog.Click += buttonClearLog_Click;
            // 
            // flowLayoutPanel1
            // 
            flowLayoutPanel1.AutoScroll = true;
            flowLayoutPanel1.AutoSize = true;
            flowLayoutPanel1.Controls.Add(varsBindingNavigator);
            flowLayoutPanel1.Controls.Add(label1);
            flowLayoutPanel1.Controls.Add(comboBoxCreater);
            flowLayoutPanel1.Controls.Add(label2);
            flowLayoutPanel1.Controls.Add(textBoxFilter);
            flowLayoutPanel1.Controls.Add(checkBoxInstalled);
            flowLayoutPanel1.Controls.Add(buttonResetFilter);
            flowLayoutPanel1.Dock = DockStyle.Top;
            flowLayoutPanel1.Location = new Point(0, 0);
            flowLayoutPanel1.Name = "flowLayoutPanel1";
            flowLayoutPanel1.Size = new Size(836, 70);
            flowLayoutPanel1.TabIndex = 6;
            // 
            // varsBindingNavigator
            // 
            varsBindingNavigator.AddNewItem = null;
            varsBindingNavigator.Anchor = AnchorStyles.Left;
            varsBindingNavigator.BindingSource = varsViewBindingSource;
            varsBindingNavigator.CountItem = bindingNavigatorCountItem;
            varsBindingNavigator.DeleteItem = null;
            varsBindingNavigator.Dock = DockStyle.None;
            varsBindingNavigator.ImageScalingSize = new Size(20, 20);
            varsBindingNavigator.Items.AddRange(new ToolStripItem[] { bindingNavigatorMoveFirstItem, bindingNavigatorMovePreviousItem, bindingNavigatorSeparator, bindingNavigatorPositionItem, bindingNavigatorCountItem, bindingNavigatorSeparator1, bindingNavigatorMoveNextItem, bindingNavigatorMoveLastItem, bindingNavigatorSeparator2 });
            varsBindingNavigator.Location = new Point(0, 3);
            varsBindingNavigator.MoveFirstItem = bindingNavigatorMoveFirstItem;
            varsBindingNavigator.MoveLastItem = bindingNavigatorMoveLastItem;
            varsBindingNavigator.MoveNextItem = bindingNavigatorMoveNextItem;
            varsBindingNavigator.MovePreviousItem = bindingNavigatorMovePreviousItem;
            varsBindingNavigator.Name = "varsBindingNavigator";
            varsBindingNavigator.PositionItem = bindingNavigatorPositionItem;
            varsBindingNavigator.Size = new Size(281, 29);
            varsBindingNavigator.TabIndex = 0;
            varsBindingNavigator.Text = "bindingNavigator1";
            // 
            // bindingNavigatorCountItem
            // 
            bindingNavigatorCountItem.Name = "bindingNavigatorCountItem";
            bindingNavigatorCountItem.Size = new Size(55, 24);
            bindingNavigatorCountItem.Text = "of {0}";
            bindingNavigatorCountItem.ToolTipText = "Total number";
            // 
            // bindingNavigatorMoveFirstItem
            // 
            bindingNavigatorMoveFirstItem.DisplayStyle = ToolStripItemDisplayStyle.Image;
            bindingNavigatorMoveFirstItem.Image = (Image)resources.GetObject("bindingNavigatorMoveFirstItem.Image");
            bindingNavigatorMoveFirstItem.Name = "bindingNavigatorMoveFirstItem";
            bindingNavigatorMoveFirstItem.RightToLeftAutoMirrorImage = true;
            bindingNavigatorMoveFirstItem.Size = new Size(34, 24);
            bindingNavigatorMoveFirstItem.Text = "First";
            // 
            // bindingNavigatorMovePreviousItem
            // 
            bindingNavigatorMovePreviousItem.DisplayStyle = ToolStripItemDisplayStyle.Image;
            bindingNavigatorMovePreviousItem.Image = (Image)resources.GetObject("bindingNavigatorMovePreviousItem.Image");
            bindingNavigatorMovePreviousItem.Name = "bindingNavigatorMovePreviousItem";
            bindingNavigatorMovePreviousItem.RightToLeftAutoMirrorImage = true;
            bindingNavigatorMovePreviousItem.Size = new Size(34, 24);
            bindingNavigatorMovePreviousItem.Text = "Previous";
            // 
            // bindingNavigatorSeparator
            // 
            bindingNavigatorSeparator.Name = "bindingNavigatorSeparator";
            bindingNavigatorSeparator.Size = new Size(6, 29);
            // 
            // bindingNavigatorPositionItem
            // 
            bindingNavigatorPositionItem.AccessibleName = "位置";
            bindingNavigatorPositionItem.AutoSize = false;
            bindingNavigatorPositionItem.Name = "bindingNavigatorPositionItem";
            bindingNavigatorPositionItem.Size = new Size(50, 27);
            bindingNavigatorPositionItem.Text = "0";
            bindingNavigatorPositionItem.ToolTipText = "Current";
            // 
            // bindingNavigatorSeparator1
            // 
            bindingNavigatorSeparator1.Name = "bindingNavigatorSeparator1";
            bindingNavigatorSeparator1.Size = new Size(6, 29);
            // 
            // bindingNavigatorMoveNextItem
            // 
            bindingNavigatorMoveNextItem.DisplayStyle = ToolStripItemDisplayStyle.Image;
            bindingNavigatorMoveNextItem.Image = (Image)resources.GetObject("bindingNavigatorMoveNextItem.Image");
            bindingNavigatorMoveNextItem.Name = "bindingNavigatorMoveNextItem";
            bindingNavigatorMoveNextItem.RightToLeftAutoMirrorImage = true;
            bindingNavigatorMoveNextItem.Size = new Size(34, 24);
            bindingNavigatorMoveNextItem.Text = "Next";
            // 
            // bindingNavigatorMoveLastItem
            // 
            bindingNavigatorMoveLastItem.DisplayStyle = ToolStripItemDisplayStyle.Image;
            bindingNavigatorMoveLastItem.Image = (Image)resources.GetObject("bindingNavigatorMoveLastItem.Image");
            bindingNavigatorMoveLastItem.Name = "bindingNavigatorMoveLastItem";
            bindingNavigatorMoveLastItem.RightToLeftAutoMirrorImage = true;
            bindingNavigatorMoveLastItem.Size = new Size(34, 24);
            bindingNavigatorMoveLastItem.Text = "Last";
            // 
            // bindingNavigatorSeparator2
            // 
            bindingNavigatorSeparator2.Name = "bindingNavigatorSeparator2";
            bindingNavigatorSeparator2.Size = new Size(6, 29);
            // 
            // label1
            // 
            label1.Anchor = AnchorStyles.Left;
            label1.AutoSize = true;
            label1.Location = new Point(284, 7);
            label1.Name = "label1";
            label1.Size = new Size(73, 21);
            label1.TabIndex = 1;
            label1.Text = "Creator:";
            // 
            // comboBoxCreater
            // 
            comboBoxCreater.AllowDrop = true;
            comboBoxCreater.Anchor = AnchorStyles.Left;
            comboBoxCreater.DropDownStyle = ComboBoxStyle.DropDownList;
            comboBoxCreater.FormattingEnabled = true;
            comboBoxCreater.Location = new Point(363, 3);
            comboBoxCreater.Name = "comboBoxCreater";
            comboBoxCreater.Size = new Size(179, 29);
            comboBoxCreater.Sorted = true;
            comboBoxCreater.TabIndex = 2;
            toolTip1.SetToolTip(comboBoxCreater, "Filter by creator");
            comboBoxCreater.SelectedIndexChanged += comboBoxCreater_SelectedIndexChanged;
            // 
            // label2
            // 
            label2.Anchor = AnchorStyles.Left;
            label2.AutoSize = true;
            label2.Location = new Point(548, 7);
            label2.Name = "label2";
            label2.Size = new Size(123, 21);
            label2.TabIndex = 3;
            label2.Text = "packageName:";
            // 
            // textBoxFilter
            // 
            textBoxFilter.Anchor = AnchorStyles.Left;
            textBoxFilter.Location = new Point(677, 3);
            textBoxFilter.Name = "textBoxFilter";
            textBoxFilter.Size = new Size(75, 29);
            textBoxFilter.TabIndex = 4;
            toolTip1.SetToolTip(textBoxFilter, "Filter by packageName");
            textBoxFilter.TextChanged += textBoxFilter_TextChanged;
            // 
            // checkBoxInstalled
            // 
            checkBoxInstalled.Anchor = AnchorStyles.Left;
            checkBoxInstalled.AutoSize = true;
            checkBoxInstalled.Checked = true;
            checkBoxInstalled.CheckState = CheckState.Indeterminate;
            checkBoxInstalled.Location = new Point(3, 40);
            checkBoxInstalled.Name = "checkBoxInstalled";
            checkBoxInstalled.Size = new Size(104, 25);
            checkBoxInstalled.TabIndex = 5;
            checkBoxInstalled.Text = "Installed";
            checkBoxInstalled.ThreeState = true;
            toolTip1.SetToolTip(checkBoxInstalled, "Filter by installation status");
            checkBoxInstalled.UseVisualStyleBackColor = true;
            checkBoxInstalled.CheckStateChanged += checkBoxInstalled_CheckStateChanged;
            // 
            // buttonResetFilter
            // 
            buttonResetFilter.Location = new Point(113, 38);
            buttonResetFilter.Name = "buttonResetFilter";
            buttonResetFilter.Size = new Size(94, 29);
            buttonResetFilter.TabIndex = 6;
            buttonResetFilter.Text = "Reset";
            buttonResetFilter.UseVisualStyleBackColor = true;
            buttonResetFilter.Click += buttonResetFilter_Click;
            // 
            // tableLayoutPanelPreview
            // 
            tableLayoutPanelPreview.Anchor = AnchorStyles.Left;
            tableLayoutPanelPreview.CellBorderStyle = TableLayoutPanelCellBorderStyle.Inset;
            tableLayoutPanelPreview.ColumnCount = 3;
            tableLayoutPanelPreview.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 80F));
            tableLayoutPanelPreview.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            tableLayoutPanelPreview.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 130F));
            tableLayoutPanelPreview.Controls.Add(pictureBoxPreview, 0, 0);
            tableLayoutPanelPreview.Controls.Add(labelPreviewVarName, 1, 1);
            tableLayoutPanelPreview.Controls.Add(buttonLocate, 0, 1);
            tableLayoutPanelPreview.Controls.Add(panel3, 0, 2);
            tableLayoutPanelPreview.Controls.Add(buttonpreviewinstall, 2, 1);
            tableLayoutPanelPreview.Location = new Point(6, 62);
            tableLayoutPanelPreview.Name = "tableLayoutPanelPreview";
            tableLayoutPanelPreview.RowCount = 3;
            tableLayoutPanelPreview.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
            tableLayoutPanelPreview.RowStyles.Add(new RowStyle(SizeType.Absolute, 37F));
            tableLayoutPanelPreview.RowStyles.Add(new RowStyle(SizeType.Absolute, 85F));
            tableLayoutPanelPreview.Size = new Size(540, 238);
            tableLayoutPanelPreview.TabIndex = 1;
            tableLayoutPanelPreview.Visible = false;
            // 
            // pictureBoxPreview
            // 
            pictureBoxPreview.BackgroundImageLayout = ImageLayout.Stretch;
            tableLayoutPanelPreview.SetColumnSpan(pictureBoxPreview, 3);
            pictureBoxPreview.Dock = DockStyle.Fill;
            pictureBoxPreview.Location = new Point(5, 5);
            pictureBoxPreview.Name = "pictureBoxPreview";
            pictureBoxPreview.Size = new Size(530, 102);
            pictureBoxPreview.SizeMode = PictureBoxSizeMode.Zoom;
            pictureBoxPreview.TabIndex = 1;
            pictureBoxPreview.TabStop = false;
            pictureBoxPreview.Click += pictureBoxPreview_Click;
            // 
            // labelPreviewVarName
            // 
            labelPreviewVarName.Dock = DockStyle.Fill;
            labelPreviewVarName.Font = new Font("Cambria", 10.5F, FontStyle.Regular, GraphicsUnit.Point);
            labelPreviewVarName.ForeColor = SystemColors.ControlText;
            labelPreviewVarName.Location = new Point(87, 112);
            labelPreviewVarName.Name = "labelPreviewVarName";
            labelPreviewVarName.Size = new Size(316, 37);
            labelPreviewVarName.TabIndex = 2;
            labelPreviewVarName.Text = "a.a.1";
            labelPreviewVarName.TextAlign = ContentAlignment.MiddleCenter;
            // 
            // buttonLocate
            // 
            buttonLocate.Dock = DockStyle.Fill;
            buttonLocate.ForeColor = SystemColors.ControlText;
            buttonLocate.Location = new Point(5, 115);
            buttonLocate.Name = "buttonLocate";
            buttonLocate.Size = new Size(74, 31);
            buttonLocate.TabIndex = 0;
            buttonLocate.Text = "Locate";
            toolTip1.SetToolTip(buttonLocate, "Locate the current var file in Explorer");
            buttonLocate.UseVisualStyleBackColor = true;
            buttonLocate.Click += buttonLocate_Click;
            // 
            // panel3
            // 
            tableLayoutPanelPreview.SetColumnSpan(panel3, 3);
            panel3.Controls.Add(buttonLoad);
            panel3.Controls.Add(checkBoxForMale);
            panel3.Controls.Add(checkBoxIgnoreGender);
            panel3.Controls.Add(groupBoxPersonOrder);
            panel3.Controls.Add(checkBoxMerge);
            panel3.Controls.Add(buttonClearCache);
            panel3.Controls.Add(buttonAnalysis);
            panel3.Dock = DockStyle.Fill;
            panel3.ForeColor = SystemColors.ActiveCaption;
            panel3.Location = new Point(5, 154);
            panel3.Name = "panel3";
            panel3.Size = new Size(530, 79);
            panel3.TabIndex = 0;
            // 
            // buttonLoad
            // 
            buttonLoad.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
            buttonLoad.ForeColor = Color.SeaGreen;
            buttonLoad.Location = new Point(438, 34);
            buttonLoad.Name = "buttonLoad";
            buttonLoad.Size = new Size(83, 40);
            buttonLoad.TabIndex = 0;
            buttonLoad.Text = "Load";
            toolTip1.SetToolTip(buttonLoad, "Load to VAM,Add loadscene.cs as session plugin in VAM first.");
            buttonLoad.UseVisualStyleBackColor = true;
            buttonLoad.Click += buttonLoad_Click;
            // 
            // checkBoxForMale
            // 
            checkBoxForMale.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
            checkBoxForMale.ForeColor = Color.SeaGreen;
            checkBoxForMale.Location = new Point(358, 31);
            checkBoxForMale.Name = "checkBoxForMale";
            checkBoxForMale.Size = new Size(118, 21);
            checkBoxForMale.TabIndex = 15;
            checkBoxForMale.Text = "For Male";
            toolTip1.SetToolTip(checkBoxForMale, "Load to male atom.");
            checkBoxForMale.UseVisualStyleBackColor = true;
            // 
            // checkBoxIgnoreGender
            // 
            checkBoxIgnoreGender.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
            checkBoxIgnoreGender.ForeColor = Color.SeaGreen;
            checkBoxIgnoreGender.Location = new Point(358, 7);
            checkBoxIgnoreGender.Name = "checkBoxIgnoreGender";
            checkBoxIgnoreGender.Size = new Size(118, 21);
            checkBoxIgnoreGender.TabIndex = 14;
            checkBoxIgnoreGender.Text = "Ignore gender";
            toolTip1.SetToolTip(checkBoxIgnoreGender, "futa are seen as female in this preset and VAM.");
            checkBoxIgnoreGender.UseVisualStyleBackColor = true;
            // 
            // groupBoxPersonOrder
            // 
            groupBoxPersonOrder.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
            groupBoxPersonOrder.Controls.Add(radioButtonPersonOrder6);
            groupBoxPersonOrder.Controls.Add(radioButtonPersonOrder8);
            groupBoxPersonOrder.Controls.Add(radioButtonPersonOrder7);
            groupBoxPersonOrder.Controls.Add(radioButtonPersonOrder5);
            groupBoxPersonOrder.Controls.Add(radioButtonPersonOrder4);
            groupBoxPersonOrder.Controls.Add(radioButtonPersonOrder3);
            groupBoxPersonOrder.Controls.Add(radioButtonPersonOrder2);
            groupBoxPersonOrder.Controls.Add(radioButtonPersonOrder1);
            groupBoxPersonOrder.ForeColor = Color.SeaGreen;
            groupBoxPersonOrder.Location = new Point(200, 3);
            groupBoxPersonOrder.Name = "groupBoxPersonOrder";
            groupBoxPersonOrder.Size = new Size(153, 72);
            groupBoxPersonOrder.TabIndex = 13;
            groupBoxPersonOrder.TabStop = false;
            groupBoxPersonOrder.Text = "Person Order";
            toolTip1.SetToolTip(groupBoxPersonOrder, "Person atom order in VAM");
            // 
            // radioButtonPersonOrder6
            // 
            radioButtonPersonOrder6.AutoSize = true;
            radioButtonPersonOrder6.Location = new Point(44, 45);
            radioButtonPersonOrder6.Name = "radioButtonPersonOrder6";
            radioButtonPersonOrder6.Size = new Size(45, 25);
            radioButtonPersonOrder6.TabIndex = 13;
            radioButtonPersonOrder6.Text = "6";
            radioButtonPersonOrder6.UseVisualStyleBackColor = true;
            // 
            // radioButtonPersonOrder8
            // 
            radioButtonPersonOrder8.AutoSize = true;
            radioButtonPersonOrder8.Location = new Point(117, 45);
            radioButtonPersonOrder8.Name = "radioButtonPersonOrder8";
            radioButtonPersonOrder8.Size = new Size(45, 25);
            radioButtonPersonOrder8.TabIndex = 13;
            radioButtonPersonOrder8.Text = "8";
            radioButtonPersonOrder8.UseVisualStyleBackColor = true;
            // 
            // radioButtonPersonOrder7
            // 
            radioButtonPersonOrder7.AutoSize = true;
            radioButtonPersonOrder7.Location = new Point(82, 45);
            radioButtonPersonOrder7.Name = "radioButtonPersonOrder7";
            radioButtonPersonOrder7.Size = new Size(45, 25);
            radioButtonPersonOrder7.TabIndex = 13;
            radioButtonPersonOrder7.Text = "7";
            radioButtonPersonOrder7.UseVisualStyleBackColor = true;
            // 
            // radioButtonPersonOrder5
            // 
            radioButtonPersonOrder5.AutoSize = true;
            radioButtonPersonOrder5.Location = new Point(6, 45);
            radioButtonPersonOrder5.Name = "radioButtonPersonOrder5";
            radioButtonPersonOrder5.Size = new Size(45, 25);
            radioButtonPersonOrder5.TabIndex = 13;
            radioButtonPersonOrder5.Text = "5";
            radioButtonPersonOrder5.UseVisualStyleBackColor = true;
            // 
            // radioButtonPersonOrder4
            // 
            radioButtonPersonOrder4.AutoSize = true;
            radioButtonPersonOrder4.Location = new Point(117, 20);
            radioButtonPersonOrder4.Name = "radioButtonPersonOrder4";
            radioButtonPersonOrder4.Size = new Size(45, 25);
            radioButtonPersonOrder4.TabIndex = 13;
            radioButtonPersonOrder4.Text = "4";
            radioButtonPersonOrder4.UseVisualStyleBackColor = true;
            // 
            // radioButtonPersonOrder3
            // 
            radioButtonPersonOrder3.AutoSize = true;
            radioButtonPersonOrder3.Location = new Point(82, 20);
            radioButtonPersonOrder3.Name = "radioButtonPersonOrder3";
            radioButtonPersonOrder3.Size = new Size(45, 25);
            radioButtonPersonOrder3.TabIndex = 13;
            radioButtonPersonOrder3.Text = "3";
            radioButtonPersonOrder3.UseVisualStyleBackColor = true;
            // 
            // radioButtonPersonOrder2
            // 
            radioButtonPersonOrder2.AutoSize = true;
            radioButtonPersonOrder2.Location = new Point(44, 20);
            radioButtonPersonOrder2.Name = "radioButtonPersonOrder2";
            radioButtonPersonOrder2.Size = new Size(45, 25);
            radioButtonPersonOrder2.TabIndex = 13;
            radioButtonPersonOrder2.Text = "2";
            radioButtonPersonOrder2.UseVisualStyleBackColor = true;
            // 
            // radioButtonPersonOrder1
            // 
            radioButtonPersonOrder1.AutoSize = true;
            radioButtonPersonOrder1.Checked = true;
            radioButtonPersonOrder1.Location = new Point(6, 20);
            radioButtonPersonOrder1.Name = "radioButtonPersonOrder1";
            radioButtonPersonOrder1.Size = new Size(45, 25);
            radioButtonPersonOrder1.TabIndex = 13;
            radioButtonPersonOrder1.TabStop = true;
            radioButtonPersonOrder1.Text = "1";
            radioButtonPersonOrder1.UseVisualStyleBackColor = true;
            // 
            // checkBoxMerge
            // 
            checkBoxMerge.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
            checkBoxMerge.ForeColor = Color.SeaGreen;
            checkBoxMerge.Location = new Point(358, 55);
            checkBoxMerge.Name = "checkBoxMerge";
            checkBoxMerge.Size = new Size(118, 21);
            checkBoxMerge.TabIndex = 3;
            checkBoxMerge.Text = "Merge";
            toolTip1.SetToolTip(checkBoxMerge, "Merge Load");
            checkBoxMerge.UseVisualStyleBackColor = true;
            // 
            // buttonClearCache
            // 
            buttonClearCache.Anchor = AnchorStyles.Bottom | AnchorStyles.Left;
            buttonClearCache.ForeColor = Color.Red;
            buttonClearCache.Location = new Point(92, 34);
            buttonClearCache.Name = "buttonClearCache";
            buttonClearCache.Size = new Size(102, 40);
            buttonClearCache.TabIndex = 0;
            buttonClearCache.Text = "Clear Cache";
            buttonClearCache.UseVisualStyleBackColor = true;
            buttonClearCache.Click += buttonClearCache_Click;
            // 
            // buttonAnalysis
            // 
            buttonAnalysis.Anchor = AnchorStyles.Bottom | AnchorStyles.Left;
            buttonAnalysis.ForeColor = SystemColors.HotTrack;
            buttonAnalysis.Location = new Point(3, 34);
            buttonAnalysis.Name = "buttonAnalysis";
            buttonAnalysis.Size = new Size(83, 40);
            buttonAnalysis.TabIndex = 0;
            buttonAnalysis.Text = "Analysis";
            toolTip1.SetToolTip(buttonAnalysis, "Analyze the atoms in the scene and load to running VAM,Add loadscene.cs as session plugin in VAM first.");
            buttonAnalysis.UseVisualStyleBackColor = true;
            buttonAnalysis.Click += buttonAnalysis_Click;
            // 
            // buttonpreviewinstall
            // 
            buttonpreviewinstall.Dock = DockStyle.Fill;
            buttonpreviewinstall.ForeColor = SystemColors.ControlText;
            buttonpreviewinstall.Location = new Point(411, 115);
            buttonpreviewinstall.Name = "buttonpreviewinstall";
            buttonpreviewinstall.Size = new Size(124, 31);
            buttonpreviewinstall.TabIndex = 0;
            buttonpreviewinstall.Text = "Install";
            toolTip1.SetToolTip(buttonpreviewinstall, "Install var and Dependencies ");
            buttonpreviewinstall.UseVisualStyleBackColor = true;
            buttonpreviewinstall.Click += buttonpreviewinstall_Click;
            // 
            // listViewPreviewPics
            // 
            listViewPreviewPics.Dock = DockStyle.Fill;
            listViewPreviewPics.LargeImageList = imageListPreviewPics;
            listViewPreviewPics.Location = new Point(0, 35);
            listViewPreviewPics.MultiSelect = false;
            listViewPreviewPics.Name = "listViewPreviewPics";
            listViewPreviewPics.Size = new Size(535, 517);
            listViewPreviewPics.TabIndex = 0;
            toolTip1.SetToolTip(listViewPreviewPics, "Preview of selected vars,click to display a larger image");
            listViewPreviewPics.UseCompatibleStateImageBehavior = false;
            listViewPreviewPics.VirtualMode = true;
            listViewPreviewPics.RetrieveVirtualItem += listViewPreviewPics_RetrieveVirtualItem;
            listViewPreviewPics.Click += listViewPreviewPics_Click;
            // 
            // imageListPreviewPics
            // 
            imageListPreviewPics.ColorDepth = ColorDepth.Depth32Bit;
            imageListPreviewPics.ImageSize = new Size(128, 128);
            imageListPreviewPics.TransparentColor = Color.Transparent;
            // 
            // flowLayoutPanel3
            // 
            flowLayoutPanel3.AutoScroll = true;
            flowLayoutPanel3.AutoSize = true;
            flowLayoutPanel3.AutoSizeMode = AutoSizeMode.GrowAndShrink;
            flowLayoutPanel3.Controls.Add(toolStripPreview);
            flowLayoutPanel3.Controls.Add(label4);
            flowLayoutPanel3.Controls.Add(comboBoxPreviewType);
            flowLayoutPanel3.Controls.Add(checkBoxPreviewTypeLoadable);
            flowLayoutPanel3.Dock = DockStyle.Top;
            flowLayoutPanel3.Location = new Point(0, 0);
            flowLayoutPanel3.Name = "flowLayoutPanel3";
            flowLayoutPanel3.Size = new Size(535, 35);
            flowLayoutPanel3.TabIndex = 10;
            // 
            // toolStripPreview
            // 
            toolStripPreview.Dock = DockStyle.None;
            toolStripPreview.ImageScalingSize = new Size(20, 20);
            toolStripPreview.Items.AddRange(new ToolStripItem[] { toolStripButtonPreviewFirst, toolStripButtonPreviewPrev, toolStripLabelPreviewItemIndex, toolStripLabelPreviewCountItem, toolStripButtonPreviewNext, toolStripButtonPreviewLast });
            toolStripPreview.Location = new Point(0, 0);
            toolStripPreview.Name = "toolStripPreview";
            toolStripPreview.Size = new Size(228, 29);
            toolStripPreview.TabIndex = 0;
            toolStripPreview.Text = "toolStrip1";
            // 
            // toolStripButtonPreviewFirst
            // 
            toolStripButtonPreviewFirst.DisplayStyle = ToolStripItemDisplayStyle.Image;
            toolStripButtonPreviewFirst.Image = (Image)resources.GetObject("toolStripButtonPreviewFirst.Image");
            toolStripButtonPreviewFirst.Name = "toolStripButtonPreviewFirst";
            toolStripButtonPreviewFirst.RightToLeftAutoMirrorImage = true;
            toolStripButtonPreviewFirst.Size = new Size(34, 24);
            toolStripButtonPreviewFirst.Text = "First";
            toolStripButtonPreviewFirst.Click += toolStripButtonPreviewFirst_Click;
            // 
            // toolStripButtonPreviewPrev
            // 
            toolStripButtonPreviewPrev.DisplayStyle = ToolStripItemDisplayStyle.Image;
            toolStripButtonPreviewPrev.Image = (Image)resources.GetObject("toolStripButtonPreviewPrev.Image");
            toolStripButtonPreviewPrev.Name = "toolStripButtonPreviewPrev";
            toolStripButtonPreviewPrev.RightToLeftAutoMirrorImage = true;
            toolStripButtonPreviewPrev.Size = new Size(34, 24);
            toolStripButtonPreviewPrev.Text = "Move to previous";
            toolStripButtonPreviewPrev.Click += toolStripButtonPreviewPrev_Click;
            // 
            // toolStripLabelPreviewItemIndex
            // 
            toolStripLabelPreviewItemIndex.Name = "toolStripLabelPreviewItemIndex";
            toolStripLabelPreviewItemIndex.Size = new Size(33, 24);
            toolStripLabelPreviewItemIndex.Text = "{0}";
            // 
            // toolStripLabelPreviewCountItem
            // 
            toolStripLabelPreviewCountItem.Name = "toolStripLabelPreviewCountItem";
            toolStripLabelPreviewCountItem.Size = new Size(41, 24);
            toolStripLabelPreviewCountItem.Text = "/{0}";
            // 
            // toolStripButtonPreviewNext
            // 
            toolStripButtonPreviewNext.DisplayStyle = ToolStripItemDisplayStyle.Image;
            toolStripButtonPreviewNext.Image = (Image)resources.GetObject("toolStripButtonPreviewNext.Image");
            toolStripButtonPreviewNext.Name = "toolStripButtonPreviewNext";
            toolStripButtonPreviewNext.RightToLeftAutoMirrorImage = true;
            toolStripButtonPreviewNext.Size = new Size(34, 24);
            toolStripButtonPreviewNext.Text = "Next";
            toolStripButtonPreviewNext.Click += toolStripButtonPreviewNext_Click;
            // 
            // toolStripButtonPreviewLast
            // 
            toolStripButtonPreviewLast.DisplayStyle = ToolStripItemDisplayStyle.Image;
            toolStripButtonPreviewLast.Image = (Image)resources.GetObject("toolStripButtonPreviewLast.Image");
            toolStripButtonPreviewLast.Name = "toolStripButtonPreviewLast";
            toolStripButtonPreviewLast.RightToLeftAutoMirrorImage = true;
            toolStripButtonPreviewLast.Size = new Size(34, 24);
            toolStripButtonPreviewLast.Text = "Last";
            toolStripButtonPreviewLast.Click += toolStripButtonPreviewLast_Click;
            // 
            // label4
            // 
            label4.Anchor = AnchorStyles.Left;
            label4.AutoSize = true;
            label4.Location = new Point(231, 7);
            label4.Name = "label4";
            label4.Size = new Size(117, 21);
            label4.TabIndex = 1;
            label4.Text = "PreviewType:";
            label4.TextAlign = ContentAlignment.MiddleCenter;
            // 
            // comboBoxPreviewType
            // 
            comboBoxPreviewType.Anchor = AnchorStyles.Left;
            comboBoxPreviewType.DropDownStyle = ComboBoxStyle.DropDownList;
            comboBoxPreviewType.FormattingEnabled = true;
            comboBoxPreviewType.Items.AddRange(new object[] { "_All", "scenes", "looks", "clothing", "hairstyle", "assets", "morphs", "pose", "skin" });
            comboBoxPreviewType.Location = new Point(354, 3);
            comboBoxPreviewType.Name = "comboBoxPreviewType";
            comboBoxPreviewType.Size = new Size(59, 29);
            comboBoxPreviewType.TabIndex = 2;
            comboBoxPreviewType.SelectedIndexChanged += toolStripComboBoxPreviewType_SelectedIndexChanged;
            // 
            // checkBoxPreviewTypeLoadable
            // 
            checkBoxPreviewTypeLoadable.Anchor = AnchorStyles.Left;
            checkBoxPreviewTypeLoadable.AutoSize = true;
            checkBoxPreviewTypeLoadable.Checked = true;
            checkBoxPreviewTypeLoadable.CheckState = CheckState.Checked;
            checkBoxPreviewTypeLoadable.Location = new Point(419, 5);
            checkBoxPreviewTypeLoadable.Name = "checkBoxPreviewTypeLoadable";
            checkBoxPreviewTypeLoadable.Size = new Size(108, 25);
            checkBoxPreviewTypeLoadable.TabIndex = 3;
            checkBoxPreviewTypeLoadable.Text = "Loadable";
            toolTip1.SetToolTip(checkBoxPreviewTypeLoadable, "Filter Loadabled Scene,Looks etc");
            checkBoxPreviewTypeLoadable.UseVisualStyleBackColor = true;
            checkBoxPreviewTypeLoadable.CheckedChanged += checkBoxPreviewTypeLoadable_CheckedChanged;
            // 
            // backgroundWorkerInstall
            // 
            backgroundWorkerInstall.WorkerReportsProgress = true;
            backgroundWorkerInstall.DoWork += backgroundWorkerInstall_DoWork;
            backgroundWorkerInstall.RunWorkerCompleted += backgroundWorkerInstall_RunWorkerCompleted;
            // 
            // backgroundWorkerPreview
            // 
            backgroundWorkerPreview.WorkerReportsProgress = true;
            backgroundWorkerPreview.WorkerSupportsCancellation = true;
            // 
            // openFileDialogInstByTXT
            // 
            openFileDialogInstByTXT.DefaultExt = "txt";
            openFileDialogInstByTXT.FileName = "installedvars";
            openFileDialogInstByTXT.Filter = "text file|*.txt";
            // 
            // saveFileDialogExportInstalled
            // 
            saveFileDialogExportInstalled.DefaultExt = "txt";
            saveFileDialogExportInstalled.FileName = "installedvars";
            saveFileDialogExportInstalled.Filter = "text file|*.txt";
            // 
            // varsBindingSource
            // 
            varsBindingSource.DataMember = "vars";
            // DataSource will be set in code using EF Core
            // 
            // dependenciesBindingSource
            // 
            dependenciesBindingSource.DataMember = "dependencies";
            // DataSource will be set in code using EF Core
            // 
            // installStatusBindingSource
            // 
            installStatusBindingSource.DataMember = "installStatus";
            // DataSource will be set in code using EF Core
            // 
            // scenesBindingSource
            // 
            scenesBindingSource.DataMember = "scenes";
            // DataSource will be set in code using EF Core
            // 
            // Form1
            // 
            AutoScaleDimensions = new SizeF(10F, 21F);
            AutoScaleMode = AutoScaleMode.Font;
            ClientSize = new Size(1540, 829);
            Controls.Add(tableLayoutPanel1);
            Font = new Font("Cambria", 9F, FontStyle.Regular, GraphicsUnit.Point);
            Icon = (Icon)resources.GetObject("$this.Icon");
            Name = "Form1";
            Text = "Var Manager";
            WindowState = FormWindowState.Maximized;
            Load += Form1_Load;
            tableLayoutPanel1.ResumeLayout(false);
            panel1.ResumeLayout(false);
            groupBoxSwitch.ResumeLayout(false);
            groupBox1.ResumeLayout(false);
            contextMenuStripPrepareSave.ResumeLayout(false);
            tableLayoutPanel2.ResumeLayout(false);
            tableLayoutPanel2.PerformLayout();
            splitContainer1.Panel1.ResumeLayout(false);
            splitContainer1.Panel1.PerformLayout();
            splitContainer1.Panel2.ResumeLayout(false);
            splitContainer1.Panel2.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)splitContainer1).EndInit();
            splitContainer1.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)varsViewDataGridView).EndInit();
            ((System.ComponentModel.ISupportInitialize)varsViewBindingSource).EndInit();
            flowLayoutPanel2.ResumeLayout(false);
            flowLayoutPanel1.ResumeLayout(false);
            flowLayoutPanel1.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)varsBindingNavigator).EndInit();
            varsBindingNavigator.ResumeLayout(false);
            varsBindingNavigator.PerformLayout();
            tableLayoutPanelPreview.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)pictureBoxPreview).EndInit();
            panel3.ResumeLayout(false);
            groupBoxPersonOrder.ResumeLayout(false);
            groupBoxPersonOrder.PerformLayout();
            flowLayoutPanel3.ResumeLayout(false);
            flowLayoutPanel3.PerformLayout();
            toolStripPreview.ResumeLayout(false);
            toolStripPreview.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)varsBindingSource).EndInit();
            ((System.ComponentModel.ISupportInitialize)dependenciesBindingSource).EndInit();
            ((System.ComponentModel.ISupportInitialize)installStatusBindingSource).EndInit();
            ((System.ComponentModel.ISupportInitialize)scenesBindingSource).EndInit();
            ResumeLayout(false);
        }

        #endregion

        private System.Windows.Forms.Button buttonSetting;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel1;
        private System.Windows.Forms.ListBox listBoxLog;
        private System.Windows.Forms.Panel panel1;
        private System.Windows.Forms.Button buttonUpdDB;
        private System.Windows.Forms.Button buttonStartVam;
        private System.Windows.Forms.Button buttonFixRebuildLink;
        private System.ComponentModel.BackgroundWorker backgroundWorkerInstall;
        private System.Windows.Forms.ComboBox comboBoxCreater;
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.SplitContainer splitContainer1;
        private System.Windows.Forms.ListView listViewPreviewPics;
        private System.Windows.Forms.ImageList imageListPreviewPics;
        private System.Windows.Forms.Button buttonStaleVars;
        private System.Windows.Forms.FlowLayoutPanel flowLayoutPanel1;
        private System.Windows.Forms.BindingNavigator varsBindingNavigator;
        private System.Windows.Forms.ToolStripLabel bindingNavigatorCountItem;
        private System.Windows.Forms.ToolStripButton bindingNavigatorMoveFirstItem;
        private System.Windows.Forms.ToolStripButton bindingNavigatorMovePreviousItem;
        private System.Windows.Forms.ToolStripSeparator bindingNavigatorSeparator;
        private System.Windows.Forms.ToolStripTextBox bindingNavigatorPositionItem;
        private System.Windows.Forms.ToolStripSeparator bindingNavigatorSeparator1;
        private System.Windows.Forms.ToolStripButton bindingNavigatorMoveNextItem;
        private System.Windows.Forms.ToolStripButton bindingNavigatorMoveLastItem;
        private System.Windows.Forms.ToolStripSeparator bindingNavigatorSeparator2;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.TextBox textBoxFilter;
        private System.Windows.Forms.BindingSource dependenciesBindingSource;

        private System.Windows.Forms.CheckBox checkBoxInstalled;
        private System.Windows.Forms.Button buttonInstall;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanelPreview;
        private System.Windows.Forms.Panel panel3;
        private System.Windows.Forms.Button buttonpreviewinstall;
        private System.Windows.Forms.PictureBox pictureBoxPreview;
        private System.Windows.Forms.ToolStrip toolStripPreview;
        private System.Windows.Forms.Button buttonScenesManager;
        private System.Windows.Forms.BindingSource scenesBindingSource;
        private System.Windows.Forms.ToolStripLabel toolStripLabelPreviewCountItem;
        private System.Windows.Forms.GroupBox groupBox1;
        private System.Windows.Forms.ToolTip toolTip1;
        private System.Windows.Forms.Button buttonFixSavesDepend;
        private System.Windows.Forms.Button buttonUninstallSels;
        private System.ComponentModel.BackgroundWorker backgroundWorkerPreview;
        private System.Windows.Forms.Button buttonDelete;
        private System.Windows.Forms.Button buttonMissingDepends;
        private System.Windows.Forms.DataGridView varsViewDataGridView;
        private System.Windows.Forms.BindingSource varsViewBindingSource;
        private System.Windows.Forms.Button buttonMove;
        private System.Windows.Forms.FolderBrowserDialog folderBrowserDialogMove;
        private System.Windows.Forms.FlowLayoutPanel flowLayoutPanel2;
        private System.Windows.Forms.Button buttonExpInsted;
        private System.Windows.Forms.Button buttonInstFormTxt;
        private System.Windows.Forms.OpenFileDialog openFileDialogInstByTXT;
        private System.Windows.Forms.SaveFileDialog saveFileDialogExportInstalled;
        private System.Windows.Forms.GroupBox groupBoxSwitch;
        private System.Windows.Forms.ComboBox comboBoxPacksSwitch;
        private System.Windows.Forms.Button buttonPacksDelete;
        private System.Windows.Forms.Button buttonPacksAdd;
        private System.Windows.Forms.Button buttonPacksRename;
        private System.Windows.Forms.Button buttonLoad;
        private System.Windows.Forms.CheckBox checkBoxMerge;
        private System.Windows.Forms.FlowLayoutPanel flowLayoutPanel3;
        private System.Windows.Forms.ToolStripButton toolStripButtonPreviewFirst;
        private System.Windows.Forms.Label label4;
        private System.Windows.Forms.ComboBox comboBoxPreviewType;
        private System.Windows.Forms.ToolStripButton toolStripButtonPreviewPrev;
        private System.Windows.Forms.ToolStripButton toolStripButtonPreviewNext;
        private System.Windows.Forms.ToolStripButton toolStripButtonPreviewLast;
        private System.Windows.Forms.CheckBox checkBoxPreviewTypeLoadable;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel2;
        private System.Windows.Forms.ProgressBar progressBar1;
        private System.Windows.Forms.Label labelProgress;
        private System.Windows.Forms.Button buttonLocate;
        private System.Windows.Forms.ToolStripLabel toolStripLabelPreviewItemIndex;
        private System.Windows.Forms.Button buttonAnalysis;
        private System.Windows.Forms.Button buttonResetFilter;
        private System.Windows.Forms.Button buttonFixPreview;
        private System.Windows.Forms.Button buttonAllMissingDepends;
        private System.Windows.Forms.Button buttonHub;
        private System.Windows.Forms.Button buttonClearLog;
        private System.Windows.Forms.DataGridViewButtonColumn ColumnDetail;
        private System.Windows.Forms.DataGridViewTextBoxColumn fsize;
        private System.Windows.Forms.DataGridViewTextBoxColumn morphs;
        private System.Windows.Forms.DataGridViewTextBoxColumn pose;
        private System.Windows.Forms.DataGridViewTextBoxColumn skin;
        private System.Windows.Forms.CheckBox checkBoxIgnoreGender;
        private System.Windows.Forms.GroupBox groupBoxPersonOrder;
        private System.Windows.Forms.RadioButton radioButtonPersonOrder6;
        private System.Windows.Forms.RadioButton radioButtonPersonOrder8;
        private System.Windows.Forms.RadioButton radioButtonPersonOrder7;
        private System.Windows.Forms.RadioButton radioButtonPersonOrder5;
        private System.Windows.Forms.RadioButton radioButtonPersonOrder4;
        private System.Windows.Forms.RadioButton radioButtonPersonOrder3;
        private System.Windows.Forms.RadioButton radioButtonPersonOrder2;
        private System.Windows.Forms.RadioButton radioButtonPersonOrder1;
        private System.Windows.Forms.Label labelPreviewVarName;
        private System.Windows.Forms.CheckBox checkBoxForMale;
        private System.Windows.Forms.ContextMenuStrip contextMenuStripPrepareSave;
        private System.Windows.Forms.ToolStripMenuItem prepareFormSavesToolStripMenuItem;
        private System.Windows.Forms.Button buttonFilteredMissingDepends;
        private System.Windows.Forms.DataGridViewTextBoxColumn varNamedataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewCheckBoxColumn installedDataGridViewCheckBoxColumn;
        private System.Windows.Forms.DataGridViewTextBoxColumn varPathDataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewTextBoxColumn creatorNameDataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewTextBoxColumn packageNameDataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewTextBoxColumn versionDataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewTextBoxColumn metaDateDataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewTextBoxColumn varDateDataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewTextBoxColumn scenesDataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewTextBoxColumn looksDataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewTextBoxColumn clothingDataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewTextBoxColumn hairstyleDataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewTextBoxColumn pluginsDataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewTextBoxColumn assetsDataGridViewTextBoxColumn;
        private System.Windows.Forms.DataGridViewCheckBoxColumn disabledDataGridViewCheckBoxColumn;
        private System.Windows.Forms.Button buttonClearCache;
        private System.Windows.Forms.BindingSource varsBindingSource;
        private System.Windows.Forms.BindingSource installStatusBindingSource;
    }
}

