using AutoMapper;
using Solf.Base;
using System;
using System.Linq;

namespace App.Extensions
{
    public static class AutoMapperExtensions
    {
        public static IProfileExpression CreateMultiLingualMap<TMultiLingualEntity, TMultiLingualEntityPrimaryKey, TTranslation, TDestination>(
            this IProfileExpression config,
            string defaultLanguage,
            Action<TMultiLingualEntity, TDestination, ResolutionContext> beforeFunction = null)
            where TTranslation : class, IEntityTranslation<TMultiLingualEntity, TMultiLingualEntityPrimaryKey>, new()
            where TMultiLingualEntity : IMultiLingualEntity<TTranslation>
        {
            config.CreateMap<TTranslation, TDestination>();
            config.CreateMap<TMultiLingualEntity, TDestination>().BeforeMap((source, destination, context) =>
            {
                if (beforeFunction != null)
                    beforeFunction.Invoke(source, destination, context);
                var lang = System.Threading.Thread.CurrentThread.CurrentUICulture.TwoLetterISOLanguageName;
                //var translation = source.Translations?.FirstOrDefault(pt => pt.Language.Substring(0, 2) == CultureInfo.CurrentUICulture.TwoLetterISOLanguageName);
                var translation = source.Translations?.OrderByDescending(x=> x.Language == lang).FirstOrDefault();
                if (translation != null)
                {
                    context.Mapper.Map(translation, destination);
                    return;
                }
                //
                //translation = source.Translations?.FirstOrDefault(x => x.Language.Substring(0, 2) == defaultLanguage);
                //if (translation != null)
                //{
                //    context.Mapper.Map(translation, destination);
                //    return;
                //}
                //
                //translation = source.Translations?.FirstOrDefault();
                //if (translation != null)
                //{
                //    context.Mapper.Map(translation, destination);
                //}
            });
            return config;
        }

        public static IProfileExpression CreateMultiLingualMap<TMultiLingualEntity, TTranslation, TDestination>(this IProfileExpression config,
            string defaultLanguage,
            Action<TMultiLingualEntity, TDestination, ResolutionContext> beforeFunction = null)
            where TTranslation : class, IEntityTranslation<TMultiLingualEntity, int>, new()
            where TMultiLingualEntity : IMultiLingualEntity<TTranslation>
        {
            return config.CreateMultiLingualMap<TMultiLingualEntity, int, TTranslation, TDestination>(defaultLanguage, beforeFunction);
        }
    }
}
