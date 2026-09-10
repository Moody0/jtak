using System;

namespace App.Extensions
{
    [AttributeUsage(AttributeTargets.All)]
    public class EppExcelColumnAttribute : System.Attribute
    {
        public int ColumnIndex { get; set; }


        public EppExcelColumnAttribute(int column)
        {
            ColumnIndex = column;
        }
    }
}
