using NameApp.Models;

namespace NameApp.Services
{
    public interface INameService
    {
        Task<IEnumerable<Name>> GetAllNamesAsync();
        Task<Name?> GetNameByIdAsync(string id);
        Task AddNameAsync(Name name);
        Task DeleteNameAsync(string id);
    }
}