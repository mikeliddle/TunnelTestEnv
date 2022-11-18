namespace TodoApi.Models
{
    public class TodoItemDTO
    {
        public long Id { get; set; }
        public string? Name { get; set; }
        public string? AssignedTo { get; set; }
        public bool IsComplete { get; set; }
    }
}