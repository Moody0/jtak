namespace App.Services
{
    public interface ISluggableService<ISluggable>
    {
        string GenerateSlug(string title, int? currentId = null);
    }
}