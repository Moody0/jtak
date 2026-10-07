using System;
using System.Linq;
using System.Threading.Tasks;
using App.Shared.Data.App;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.EntityFrameworkCore;

namespace App.Helpers.Authorization
{
    // Applies to every dashboard API, including controllers without an Authorize attribute.
    public sealed class DashboardPermissionFilter : IAsyncActionFilter, IOrderedFilter
    {
        public int Order => -3000;
        private readonly DashboardAccessService _access;
        private readonly AppDbContext _db;
        public DashboardPermissionFilter(DashboardAccessService access, AppDbContext db) { _access = access; _db = db; }

        public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
        {
            if (context.ActionDescriptor is not ControllerActionDescriptor action) { await next(); return; }
            var isAdmin = action.ControllerTypeInfo.Namespace?.StartsWith("App.ApiControllers.V1.Admin", StringComparison.Ordinal) == true;
            var isReceipt = action.ControllerName == "Services" && action.ActionName == "ErrandReceipt";
            var isStaffUpload = action.ControllerName == "Services" && action.ActionName == "SaveUploaded" && context.HttpContext.User.HasClaim(DashboardAccessService.AccountMarker, "1");
            if (!isAdmin && !isReceipt && !isStaffUpload) { await next(); return; }
            var access = await _access.CurrentAsync(context.HttpContext.User);
            if (isReceipt || isStaffUpload)
            {
                var serviceAllowed = isReceipt ? access.Has("orders.view") || access.Has("finance.view") :
                    new[] { "orders", "support", "catalog", "storefront", "communications" }.Any(s => access.Has(s + ".manage"));
                if (!serviceAllowed) { context.Result = new StatusCodeResult(403); return; }
                await next(); return;
            }
            var controller = action.ControllerName;
            var name = action.ActionName;
            var read = context.HttpContext.Request.Method == "GET" || IsReadPost(controller, name);
            var section = Section(controller, name);
            var allowed = access.CanAccess && (access.IsSuperAdmin ||
                (controller == "Staff" && name == "Access") ||
                (controller == "Notifications" && name == "Summary") ||
                (section != null && access.Has(section + (read ? ".view" : ".manage"))));

            // Narrow reference lists are needed while assigning orders or recording payments.
            if (access.CanAccess && read && controller == "Users" && (name == "GetMerchants" || name == "GetDeliveries"))
                allowed |= access.Has("orders.view") || access.Has("finance.view") || access.Has("catalog.view");
            if (access.CanAccess && read && controller == "Settings" && name == "GetCatalogDefaults")
                allowed |= access.Has("catalog.view");
            // Storefront editors need reference data for tile/banner targets, but cannot edit the catalog.
            if (access.CanAccess && read && ((controller == "Merchants" && name == "GetAll") ||
                (controller == "ProductCategories" && name == "Get") ||
                (controller == "RestaurantCategories" && name == "GetConfig")))
                allowed |= access.Has("storefront.view");

            if (!allowed) { context.Result = new ObjectResult(new { message = "ليس لديك الصلاحية للوصول إلى هذا القسم أو تنفيذ هذا الإجراء." }) { StatusCode = 403 }; return; }

            // App-user maintenance must never be a second path for changing privileged accounts.
            if (controller == "Users" && !read)
            {
                var target = context.ActionArguments.Values.OfType<Guid>().FirstOrDefault();
                if (target == Guid.Empty)
                    target = context.ActionArguments.Values.OfType<App.Shared.Entities.UserDto>().Select(u => u.Id).FirstOrDefault();
                if (target != Guid.Empty && await _db.UserRoles.AnyAsync(ur => ur.UserId == target &&
                    (_db.Roles.Any(r => r.Id == ur.RoleId && r.Name == "Admin") || _db.RoleClaims.Any(rc => rc.RoleId == ur.RoleId && rc.ClaimType == DashboardAccessService.RoleMarker))) ||
                    (target != Guid.Empty && await _db.UserClaims.AnyAsync(c => c.UserId == target && c.ClaimType == DashboardAccessService.AccountMarker)))
                { context.Result = new BadRequestObjectResult(new { message = "حسابات لوحة التحكم تُدار من قسم الموظفين والصلاحيات فقط." }); return; }
            }
            await next();
        }

        private static bool IsReadPost(string controller, string action) => action.Equals("DataTable", StringComparison.OrdinalIgnoreCase) || action == "GetDataTable" ||
            (controller == "Balances" && action == "DriversDataTable") ||
            (controller == "MerchantReconciliation" && action == "GetMerchantStatement") ||
            (controller == "SettlementHistory" && action == "GetPrintData");

        private static string Section(string controller, string action) => controller switch
        {
            "Dashboard" => "dashboard",
            "Orders" or "ErrandRequests" => "orders",
            "SupportMessages" or "ProductReviews" or "MerchantReviews" => "support",
            "Products" or "Merchants" or "ProductCategories" or "RestaurantCategories" or "Batches" or "Tags" => "catalog",
            "HomeCategories" or "PopularProducts" or "MarketBestSelling" or "Banner" or "Banners" or "Testimonials" => "storefront",
            "Bills" or "Balances" or "Payments" or "CaptainSettlements" or "FleetReconciliation" or "MerchantReconciliation" or "DriverCashAdvances" or "SettlementRequests" or "SettlementHistory" or "ProductionReconciliation" => "finance",
            "Users" => "users",
            "Notifications" => "communications",
            "Settings" when action.Contains("Tedallal", StringComparison.OrdinalIgnoreCase) => "storefront",
            "Settings" or "Pages" => "settings",
            "AuditLogs" => "audit",
            _ => null // New/unmapped controllers stay restricted to full administrators.
        };
    }
}
