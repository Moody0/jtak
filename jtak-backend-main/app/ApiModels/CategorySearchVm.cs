namespace App.ApiModels
{
    public class CategorySearchVm
    {
        public int Take { get; set; } = 10;
        public int Page { get; set; }
        public string q { get; set; }
    }
}
