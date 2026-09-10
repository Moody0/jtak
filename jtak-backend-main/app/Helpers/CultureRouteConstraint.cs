using Microsoft.AspNetCore.Routing.Constraints;

namespace App.Helpers
{

    public class CultureRouteConstraint : RegexRouteConstraint
    {
        public CultureRouteConstraint() : base(@"^[a-zA-Z]{0,2}") { }
    }
}
