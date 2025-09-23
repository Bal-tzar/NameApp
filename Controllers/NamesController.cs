using Microsoft.AspNetCore.Mvc;
using NameApp.Models;

namespace NameApp.Controllers
{
    public class NamesController : Controller
    {
        // Temporary in-memory storage for now
        private static List<Name> _names = new List<Name>();

        // GET: Names
        public IActionResult Index()
        {
            var names = _names.OrderByDescending(n => n.DateAdded).ToList();
            return View(names);
        }

        // GET: Names/Create
        public IActionResult Create()
        {
            return View();
        }

        // POST: Names/Create
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Create(Name name)
        {
            if (ModelState.IsValid)
            {
                name.Id = Guid.NewGuid().ToString();
                name.DateAdded = DateTime.UtcNow;
                _names.Add(name);
                
                TempData["SuccessMessage"] = "Name added successfully!";
                return RedirectToAction(nameof(Index));
            }
            
            return View(name);
        }

        // GET: Names/Delete/5
        public IActionResult Delete(string id)
        {
            if (string.IsNullOrEmpty(id))
            {
                return NotFound();
            }

            var name = _names.FirstOrDefault(n => n.Id == id);
            if (name == null)
            {
                return NotFound();
            }

            return View(name);
        }

        // POST: Names/Delete/5
        [HttpPost, ActionName("Delete")]
        [ValidateAntiForgeryToken]
        public IActionResult DeleteConfirmed(string id)
        {
            var name = _names.FirstOrDefault(n => n.Id == id);
            if (name != null)
            {
                _names.Remove(name);
                TempData["SuccessMessage"] = "Name deleted successfully!";
            }
            
            return RedirectToAction(nameof(Index));
        }
    }
}