using TodoApi.Models;
using TodoApi.Contexts;

namespace TodoApi.Common{
    public static class Utils
    {
        public static bool TodoItemExists(TodoContext context, long id)
        {
            return context.TodoItems.Any(e => e.Id == id);
        }

        public static TodoItemDTO ItemToDTO(TodoItem todoItem) =>
            new TodoItemDTO
            {
                Id = todoItem.Id,
                Name = todoItem.Name,
                IsComplete = todoItem.IsComplete,
                AssignedTo = todoItem.AssignedTo
            };
    }
}