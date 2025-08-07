using System.ComponentModel.DataAnnotations;

namespace varManager.Models
{
    public class Scene
    {
        [Key]
        public int ID { get; set; }
        
        [StringLength(255)]
        public string? VarName { get; set; }
        
        [StringLength(255)]
        public string? AtomType { get; set; }
        
        [StringLength(255)]
        public string? PreviewPic { get; set; }
        
        [StringLength(255)]
        public string? ScenePath { get; set; }
        
        public bool IsPreset { get; set; }
        
        public bool IsLoadable { get; set; }
    }
}