using App.ApiModels;
using App.Orders.Data;
using App.Shared.Data.App;
using App.Shared.Entities.Enums;
using Modules.Catalog.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Modules.Orders.Entities;
using OpenIddict.Validation.AspNetCore;
using Solf.Models;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace App.ApiControllers.V1.Admin
{
    [Route("api/v{version:apiVersion}/Admin/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme,
        Policy = nameof(AppPermissionKey.AdminPermission))]
    [ApiVersion("1")]
    public class MerchantReviewsController : SolApiController
    {
        private readonly IOrdersUnitOfWork _orders;
        private readonly IMerchantService _merchantService;
        private readonly IAppUnitOfWork _users;

        public MerchantReviewsController(
            IOrdersUnitOfWork orders,
            IMerchantService merchantService,
            IAppUnitOfWork users)
        {
            _orders = orders;
            _merchantService = merchantService;
            _users = users;
        }

        [HttpPost("DataTable")]
        public async Task<ActionResult<TableResponseModel<OrderReviewAdminDto>>> DataTable([FromBody] MetronicTable request, [FromQuery] string ratingFilter = "all")
        {
            var query = _orders.Context.MerchantReviews.AsNoTracking();
            query = ratingFilter switch
            {
                "all" => query,
                "5" => query.Where(x => x.Rate == 5),
                "4" => query.Where(x => x.Rate == 4),
                "3" => query.Where(x => x.Rate == 3),
                "critical" => query.Where(x => x.Rate >= 1 && x.Rate <= 2),
                "with_text" => query.Where(x => x.TextReview != null && x.TextReview.Trim() != ""),
                _ => null
            };
            if (query == null) return BadRequest(ApiErr.Create("فلتر التقييم غير صالح."));
            var search = request?.Search?.Trim();
            if (!string.IsNullOrWhiteSpace(search))
            {
                var matchingMerchantIds = await _merchantService.Queryable().AsNoTracking()
                    .Where(merchant => merchant.Title != null && merchant.Title.Contains(search))
                    .Select(merchant => merchant.Id)
                    .ToArrayAsync();
                var matchingReviewerIds = await _users.Context.Users.AsNoTracking()
                    .Where(user =>
                        (user.FullName != null && user.FullName.Contains(search)) ||
                        (user.FirstName != null && user.FirstName.Contains(search)) ||
                        (user.LastName != null && user.LastName.Contains(search)))
                    .Select(user => user.Id)
                    .ToArrayAsync();

                var cleanSearch = search.TrimStart('#').Trim();
                var hasNumericSearch = int.TryParse(cleanSearch, out var numericSearch);
                query = query.Where(review =>
                    (review.TextReview != null && review.TextReview.Contains(search)) ||
                    matchingMerchantIds.Contains(review.MerchantId) ||
                    matchingReviewerIds.Contains(review.ReviewerId) ||
                    (hasNumericSearch && (review.Id == numericSearch || review.OrderId == numericSearch ||
                                          review.MerchantId == numericSearch || review.Rate == numericSearch)));
            }

            var totalRecords = await query.CountAsync();
            var fiveStarCount = await query.CountAsync(x => x.Rate == 5);
            var summary = new {
                Total = totalRecords,
                AverageRating = totalRecords == 0 ? 0 : Math.Round(await query.AverageAsync(x => (double)x.Rate), 1),
                FiveStarCount = fiveStarCount,
                FiveStarPct = totalRecords == 0 ? 0 : (int)Math.Round(100d * fiveStarCount / totalRecords),
                CriticalCount = await query.CountAsync(x => x.Rate >= 1 && x.Rate <= 2),
                WithTextCount = await query.CountAsync(x => x.TextReview != null && x.TextReview.Trim() != "")
            };
            var sortAscending = string.Equals(request?.SortOrder, "ASC", StringComparison.OrdinalIgnoreCase);
            query = request?.SortField?.Trim()?.ToLowerInvariant() switch
            {
                "id" => sortAscending ? query.OrderBy(review => review.Id) : query.OrderByDescending(review => review.Id),
                "orderid" => sortAscending ? query.OrderBy(review => review.OrderId) : query.OrderByDescending(review => review.OrderId),
                "rate" => sortAscending ? query.OrderBy(review => review.Rate) : query.OrderByDescending(review => review.Rate),
                "createddate" => sortAscending ? query.OrderBy(review => review.CreatedDate) : query.OrderByDescending(review => review.CreatedDate),
                _ => query.OrderByDescending(review => review.CreatedDate).ThenByDescending(review => review.Id)
            };

            query = ((IOrderedQueryable<MerchantReview>)query).ThenByDescending(x => x.Id);
            // TableService converts the widget's zero-based index to a one-based API page.
            var pageNumber = Math.Max(request?.PageNumber ?? 1, 1) - 1;
            var pageSize = Math.Clamp(request?.PageSize ?? 10, 1, 100);
            var reviews = await query.Skip(pageNumber * pageSize).Take(pageSize).ToArrayAsync();
            var merchantIds = reviews.Select(review => review.MerchantId).Distinct().ToArray();
            var reviewerIds = reviews.Select(review => review.ReviewerId).Distinct().ToArray();

            var merchants = await _merchantService.Queryable().AsNoTracking()
                .Where(merchant => merchantIds.Contains(merchant.Id))
                .Select(merchant => new { merchant.Id, merchant.Title })
                .ToDictionaryAsync(merchant => merchant.Id, merchant => merchant.Title);
            var reviewers = await _users.Context.Users.AsNoTracking()
                .Where(user => reviewerIds.Contains(user.Id))
                .Select(user => new { user.Id, user.FullName, user.FirstName, user.LastName })
                .ToDictionaryAsync(user => user.Id,
                    user => !string.IsNullOrWhiteSpace(user.FullName) ? user.FullName : string.Join(" ", new[] { user.FirstName, user.LastName }.Where(name => !string.IsNullOrWhiteSpace(name))));

            return Ok(new
            {
                Items = reviews.Select(review => new OrderReviewAdminDto
                {
                    Id = review.Id,
                    OrderId = review.OrderId,
                    MerchantId = review.MerchantId,
                    ReviewerId = review.ReviewerId,
                    MerchantTitle = merchants.TryGetValue(review.MerchantId, out var title) ? title : $"#{review.MerchantId}",
                    ReviewerName = reviewers.TryGetValue(review.ReviewerId, out var reviewer) ? reviewer : string.Empty,
                    CreatedDate = review.CreatedDate,
                    Rate = review.Rate,
                    TextReview = review.TextReview
                }).ToArray(),
                TotalRecords = totalRecords,
                TotalRecordsFiltered = totalRecords,
                Summary = summary
            });
        }
    }

    public class OrderReviewAdminDto
    {
        public int Id { get; set; }
        public int OrderId { get; set; }
        public int MerchantId { get; set; }
        public string MerchantTitle { get; set; }
        public string ReviewerName { get; set; }
        public Guid ReviewerId { get; set; }
        public DateTime CreatedDate { get; set; }
        public int Rate { get; set; }
        public string TextReview { get; set; }
    }
}
