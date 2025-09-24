using Microsoft.AspNetCore.Mvc;
using NameApp.Models;
using NameApp.Services;

namespace NameApp.Controllers
{
    public class NamesController : Controller
    {
        private readonly INameService _nameService;

        public NamesController(INameService nameService)
        {
            _nameService = nameService;
        }

        // GET: Names
        public async Task<IActionResult> Index()
        {
            try
            {
                var names = await _nameService.GetAllNamesAsync();
                return View(names);
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = "Error loading names. Please try again.";
                // Log the exception (implement logging as needed)
                return View(new List<Name>());
            }
        }

        // GET: Names/Create
        public IActionResult Create()
        {
            return View();
        }

        // POST: Names/Create
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(Name name)
        {
            if (ModelState.IsValid)
            {
                try
                {
                    name.Id = Guid.NewGuid().ToString();
                    name.DateAdded = DateTime.UtcNow;
                    
                    await _nameService.AddNameAsync(name);
                    
                    TempData["SuccessMessage"] = "Name added successfully!";
                    return RedirectToAction(nameof(Index));
                }
                catch (Exception ex)
                {
                    TempData["ErrorMessage"] = "Error adding name. Please try again.";
                    // Log the exception (implement logging as needed)
                }
            }
            
            return View(name);
        }

        // GET: Names/Delete/5
        public async Task<IActionResult> Delete(string id)
        {
            if (string.IsNullOrEmpty(id))
            {
                return NotFound();
            }

            try
            {
                var name = await _nameService.GetNameByIdAsync(id);
                if (name == null)
                {
                    return NotFound();
                }

                return View(name);
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = "Error loading name details.";
                return RedirectToAction(nameof(Index));
            }
        }

        // POST: Names/Delete/5
        [HttpPost, ActionName("Delete")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DeleteConfirmed(string id)
        {
            try
            {
                await _nameService.DeleteNameAsync(id);
                TempData["SuccessMessage"] = "Name deleted successfully!";
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = "Error deleting name. Please try again.";
                // Log the exception (implement logging as needed)
            }
            
            return RedirectToAction(nameof(Index));
        }
    }
}