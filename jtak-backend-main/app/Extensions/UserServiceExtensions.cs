using System.Linq;
using App.Shared.Entities.Enums;
using App.Shared.Services;

namespace App.Extensions
{
    public static class UserServiceExtensions
    {
        public static int Count(this IUserService service, Gender? gender) => service.Queryable().Count(x => gender == null || x.Gender == gender);
    }
}
