//using OfficeOpenXml;

namespace App.Extensions
{
    /*
    public static class EPPlusExtensions
    {
        public static IEnumerable<T> ConvertSheetToObjects<T>(this ExcelWorksheet worksheet) where T : new()
        {
            Func<CustomAttributeData, bool> columnOnly = y => y.AttributeType == typeof(EppExcelColumnAttribute);

            var columns = typeof(T)
                    .GetProperties()
                    .Where(x => x.CustomAttributes.Any(columnOnly))
            .Select(p => new
            {
                Property = p,
                Column = p.GetCustomAttributes<EppExcelColumnAttribute>().First().ColumnIndex //safe because if where above
            }).ToList();


            var rows = worksheet.Cells
                .Select(cell => cell.Start.Row)
                .Distinct()
                .OrderBy(x => x);

            List<T> result = new List<T>();

            foreach (var row in rows.Skip(1))
            {
                var tnew = new T();
                foreach (var col in columns)
                {
                    //This is the real wrinkle to using reflection - Excel stores all numbers as double including int
                    var val = worksheet.Cells[row, col.Column];

                    //If it is numeric it is a double since that is how excel stores all numbers
                    if (val.Value == null)
                    {
                        col.Property.SetValue(tnew, null);
                        continue;
                    }
                    if (col.Property.PropertyType == typeof(int))
                    {
                        col.Property.SetValue(tnew, val.GetValue<int>());
                        continue;
                    }
                    if (col.Property.PropertyType == typeof(double))
                    {
                        col.Property.SetValue(tnew, val.GetValue<double>());
                        continue;
                    }
                    if (col.Property.PropertyType == typeof(DateTime?))
                    {
                        col.Property.SetValue(tnew, val.GetValue<DateTime?>());
                        continue;
                    }
                    if (col.Property.PropertyType == typeof(DateTime))
                    {
                        col.Property.SetValue(tnew, val.GetValue<DateTime>());
                        continue;
                    }
                    //Its a string
                    col.Property.SetValue(tnew, val.GetValue<string>());
                }

                result.Add(tnew);
            }

            //Send it back
            return result;
        }
    }
    */
}
