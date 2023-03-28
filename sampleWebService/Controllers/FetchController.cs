using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TodoApi.Models;
using TodoApi.Contexts;
using TodoApi.Common;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Linq;

namespace TodoApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class FetchController : ControllerBase
    {
        private readonly TodoContext _context;

        public FetchController(TodoContext context)
        {
            _context = context;
        }

        [HttpPost]
        public async Task<ActionResult<IEnumerable<TodoItemDTO>>> GetTodoItemsForUser(TodoItemDTO todoItemDTO)
        {
            return await _context.TodoItems
                .Where(e => e.AssignedTo == todoItemDTO.AssignedTo)
                .Select(e => Utils.ItemToDTO(e))
                .ToListAsync();
        }
    }
}