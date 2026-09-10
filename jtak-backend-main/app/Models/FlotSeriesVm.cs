namespace App.Models
{
    public class FlotSeriesVm<T>
    {
        public string label { get; set; }
        public string color { get; set; }
        public T[][] data { get; set; }
    }
}
