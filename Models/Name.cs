using System.ComponentModel.DataAnnotations;

namespace NameApp.Models
{
    public class Name
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        
        [Required(ErrorMessage = "Name is required")]
        [StringLength(100, MinimumLength = 1, ErrorMessage = "Name must be between 1 and 100 characters")]
        [Display(Name = "Full Name")]
        public string FullName { get; set; } = string.Empty;
        
        public DateTime DateAdded { get; set; } = DateTime.UtcNow;
    }
}