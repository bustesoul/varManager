using System.ComponentModel.DataAnnotations;

namespace varManager.Models
{
    public class SavedDependency
    {
        [Key]
        public int ID { get; set; }
        
        [StringLength(255)]
        public string? VarName { get; set; }
        
        [StringLength(255)]
        public string? DependencyName { get; set; }
        
        [StringLength(500)]
        public string? SavePath { get; set; }
        
        public DateTime? ModiDate { get; set; }
    }
}