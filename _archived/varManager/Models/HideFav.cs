using System.ComponentModel.DataAnnotations;

namespace varManager.Models
{
    public class HideFav
    {
        [Key]
        public int ID { get; set; }
        
        [StringLength(255)]
        public string? VarName { get; set; }
        
        public bool Hide { get; set; }
        
        public bool Fav { get; set; }
    }
}