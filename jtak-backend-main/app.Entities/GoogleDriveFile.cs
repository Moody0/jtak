using URF.Core.EF.Trackable;

namespace App.Shared.Entities
{
    public class GoogleDriveFile : Entity
    {
        public string Id { get; set; }
        public string Name { get; set; }
        //public long? Size { get; set; }
    }
}
