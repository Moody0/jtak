namespace App.ApiModels.Admin
{
    public class ProductsBulkImport
    {
        public string File { get; set; }
    }
    public class BulkImportDesc
    {
        public int ImportedCat1 { get; set; }
        public int ImportedCat2 { get; set; }
        public int ImportedProds { get; set; }
    }
}
