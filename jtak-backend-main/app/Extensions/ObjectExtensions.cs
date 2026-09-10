using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace App.Extensions
{
    public static class ObjectExtensions
    {
        public static T ToObject<T>(this IDictionary<string, object> source)
            where T : class, new()
        {
            var someObject = new T();
            var someObjectType = someObject.GetType();

            foreach (var item in source)
            {
                someObjectType
                    .GetProperty(item.Key)
                    .SetValue(someObject, item.Value, null);
            }

            return someObject;
        }

        public static IDictionary<string, object> AsDictionary(this object source, BindingFlags bindingAttr = BindingFlags.DeclaredOnly | BindingFlags.Public | BindingFlags.Instance)
        {
            return source.GetType().GetProperties(bindingAttr).ToDictionary
            (
                propInfo => propInfo.Name,
                propInfo => propInfo.GetValue(source, null)
            );

        }
        /*
        public static T[] ToArray<T>(this T source) where T : struct, Enum
        {
            var values = EnumsExtensions.GetValues<T>();
            var arrValues = new List<T>();
            foreach (var value in values)
            {
                if((((int)(object)source & (int)(object)value)) == (int)(object)value) arrValues.Add(value);
            }
            return arrValues.ToArray();
        }

        public static T ToFlags<T>(this T[] source) where T : struct, Enum
        {
            int result = 0;
            foreach (var value in source)
            {
                result &= (int)(object)value;
            }
            return (T)Enum.ToObject(typeof(T), result);
        }
        */
    }
}
