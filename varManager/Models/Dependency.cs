using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace varManager.Models
{
    public class Dependency
    {
        [Key]
        public int ID { get; set; }
        
        [StringLength(255)]
        public string? VarName { get; set; }
        
        [StringLength(255)]
        public string? DependencyName { get; set; }
    }
}