using System.ComponentModel.DataAnnotations;

namespace varManager.Models
{
    public class InstallStatus
    {
        [Key]
        [StringLength(255)]
        public string VarName { get; set; } = string.Empty;
        
        public bool Installed { get; set; }
        
        public bool Disabled { get; set; }
    }
}