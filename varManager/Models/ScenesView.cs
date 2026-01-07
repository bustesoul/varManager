using System.ComponentModel.DataAnnotations;

namespace varManager.Models
{
    public class ScenesView
    {
        public string? VarName { get; set; }
        public string? AtomType { get; set; }
        public bool IsPreset { get; set; }
        public string? ScenePath { get; set; }
        public string? PreviewPic { get; set; }
        public string? CreatorName { get; set; }
        public string? PackageName { get; set; }
        public DateTime? MetaDate { get; set; }
        public DateTime? VarDate { get; set; }
        public string? Version { get; set; }
        public bool Installed { get; set; }
        public bool Disabled { get; set; }
        public bool Hide { get; set; }
        public bool Fav { get; set; }
        public int HideFav { get; set; }
        public string? Location { get; set; }
    }
}
