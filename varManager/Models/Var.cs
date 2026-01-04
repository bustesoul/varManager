using System.ComponentModel.DataAnnotations;

namespace varManager.Models
{
    public class Var
    {
        [Key]
        [StringLength(255)]
        public string VarName { get; set; } = string.Empty;
        
        [StringLength(255)]
        public string? CreatorName { get; set; }
        
        [StringLength(255)]
        public string? PackageName { get; set; }
        
        public DateTime? MetaDate { get; set; }
        
        public DateTime? VarDate { get; set; }
        
        [StringLength(50)]
        public string? Version { get; set; }
        
        public string? Description { get; set; }
        
        // Map to existing database columns
        public int? Morph { get; set; }
        public int? Cloth { get; set; }
        public int? Hair { get; set; }
        public int? Skin { get; set; }
        public int? Pose { get; set; }
        public int? Scene { get; set; }
        public int? Script { get; set; }
        public int? Plugin { get; set; }
        public int? Asset { get; set; }
        public int? Texture { get; set; }
        public int? Look { get; set; }
        public int? SubScene { get; set; }
        public int? Appearance { get; set; }
        public int? DependencyCnt { get; set; }
        public double? Fsize { get; set; }

        // Compatibility properties for existing code (not mapped to database)
        [System.ComponentModel.DataAnnotations.Schema.NotMapped]
        public string? VarPath { get => ""; set { } } // Not available in existing schema

        [System.ComponentModel.DataAnnotations.Schema.NotMapped]
        public long? Filesize { get => Fsize.HasValue ? (long?)(Fsize.Value * 1024 * 1024) : null; set { } }
        
        [System.ComponentModel.DataAnnotations.Schema.NotMapped]
        public int? Scenes { get => Scene; set => Scene = value; }
        
        [System.ComponentModel.DataAnnotations.Schema.NotMapped]
        public int? Looks { get => Look; set => Look = value; }
        
        [System.ComponentModel.DataAnnotations.Schema.NotMapped]
        public int? Clothing { get => Cloth; set => Cloth = value; }
        
        [System.ComponentModel.DataAnnotations.Schema.NotMapped]
        public int? Hairstyle { get => Hair; set => Hair = value; }
        
        [System.ComponentModel.DataAnnotations.Schema.NotMapped]
        public int? Plugins { get => Plugin; set => Plugin = value; }
        
        [System.ComponentModel.DataAnnotations.Schema.NotMapped]
        public int? Assets { get => Asset; set => Asset = value; }
        
        [System.ComponentModel.DataAnnotations.Schema.NotMapped]
        public int? Morphs { get => Morph; set => Morph = value; }
    }
}