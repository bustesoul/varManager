using System;
using System.Windows.Forms;
using varManager.Data;

namespace varManager
{
    static class Program
    {
        /// <summary>
        /// 应用程序的主入口点。
        /// </summary>
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            VarManagerContext.EnsureCreatedOnce();
            Application.Run(new Form1());
        }
    }
}
