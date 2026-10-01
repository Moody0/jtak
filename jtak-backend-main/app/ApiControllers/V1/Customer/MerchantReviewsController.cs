using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using App.Orders.Data;
using App.Extensions;
using App.Shared.Data.App;
using App.Shared.Entities.Enums;
using App.Shared.Services.Extentions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Modules.Orders.Entities;
using OpenIddict.Validation.AspNetCore;

namespace App.ApiControllers.V1.Customer
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [ApiVersion("1")]
    public class MerchantReviewsController : SolApiController
    {
        private readonly IOrdersUnitOfWork _orders;
        private readonly IAppUnitOfWork _users;

        public MerchantReviewsController(IOrdersUnitOfWork orders, IAppUnitOfWork users)
        {
            _orders = orders;
            _users = users;
        }

        [HttpGet("Summaries")]
        public async Task<ActionResult<MerchantReviewSummary[]>> Summaries([FromQuery] string merchantIds)
        {
            var ids = (merchantIds ?? "")
                .Split(',', StringSplitOptions.RemoveEmptyEntries)
                .Select(value => int.TryParse(value, out var id) ? id : 0)
                .Where(id => id > 0)
                .Distinct()
                .Take(100)
                .ToArray();

            if (ids.Length == 0) return Array.Empty<MerchantReviewSummary>();

            return await _orders.Context.MerchantReviews.AsNoTracking()
                .Where(review => ids.Contains(review.MerchantId))
                .GroupBy(review => review.MerchantId)
                .Select(group => new MerchantReviewSummary
                {
                    MerchantId = group.Key,
                    Rating = group.Average(review => (double)review.Rate),
                    RatingCount = group.Count()
                })
                .ToArrayAsync();
        }

        [HttpGet("{merchantId:int}")]
        public async Task<ActionResult<MerchantReviewResult>> Get(int merchantId)
        {
            if (merchantId <= 0) return BadRequest();

            var query = _orders.Context.MerchantReviews.AsNoTracking()
                .Where(review => review.MerchantId == merchantId);
            var count = await query.CountAsync();
            var rating = count == 0 ? 0 : await query.AverageAsync(review => (double)review.Rate);
            var reviews = await query.OrderByDescending(review => review.CreatedDate)
                .ThenByDescending(review => review.Id)
                .Take(100)
                .ToArrayAsync();

            var reviewerIds = reviews.Select(review => review.ReviewerId).Distinct().ToArray();
            var names = await _users.Context.Users.AsNoTracking()
                .Where(user => reviewerIds.Contains(user.Id))
                .Select(user => new { user.Id, user.FirstName })
                .ToDictionaryAsync(user => user.Id, user => user.FirstName);

            return new MerchantReviewResult
            {
                MerchantId = merchantId,
                Rating = rating,
                RatingCount = count,
                Reviews = reviews.Select(review => new MerchantReviewItem
                {
                    Rating = review.Rate,
                    Comment = review.TextReview ?? "",
                    Author = names.TryGetValue(review.ReviewerId, out var name) &&
                             !string.IsNullOrWhiteSpace(name) ? name : "عميل جيتك",
                    Date = review.CreatedDate
                }).ToArray()
            };
        }

        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme,
            Policy = nameof(AppPermissionKey.CustomerPermission))]
        [HttpPost("Order/{orderId:int}")]
        public async Task<ActionResult<int>> Create(int orderId, [FromBody] CreateMerchantReviewRequest request)
        {
            var reviewerId = User.GetUserId();
            if (!reviewerId.HasValue) return Unauthorized();
            if (request == null || request.Rate < 1 || request.Rate > 5)
                return BadRequest("Rating must be between 1 and 5.");
            if (request.TextReview?.Length > 2000)
                return BadRequest("Review text is too long.");

            var order = await _orders.Context.Orders.AsNoTracking()
                .Include(item => item.OrderDetails)
                .FirstOrDefaultAsync(item => item.Id == orderId && item.UserId == reviewerId.Value);
            if (order == null) return NotFound();
            if (order.OrderStatus != OrderStatus.Success)
                return BadRequest("The order has not been completed.");

            var deliveredMerchantIds = order.OrderDetails
                .Where(detail => detail.OrderDetailStatus == OrderDetailStatus.Delivered && detail.MerchantId > 0)
                .Select(detail => detail.MerchantId)
                .Distinct()
                .ToArray();
            if (deliveredMerchantIds.Length == 0)
                return BadRequest("Only delivered orders can be reviewed.");
            var merchantId = request.MerchantId > 0
                ? request.MerchantId
                : deliveredMerchantIds.Length == 1 ? deliveredMerchantIds[0] : 0;
            if (!deliveredMerchantIds.Contains(merchantId))
                return BadRequest("Select a merchant with delivered items in this order.");

            var review = await _orders.Context.MerchantReviews
                .FirstOrDefaultAsync(item => item.OrderId == orderId && item.MerchantId == merchantId);
            var now = DateTime.UtcNow;
            if (review == null)
            {
                review = new MerchantReview
                {
                    OrderId = orderId,
                    MerchantId = merchantId,
                    ReviewerId = reviewerId.Value,
                    CreatedDate = now
                };
                _orders.Context.MerchantReviews.Add(review);
            }
            review.Rate = request.Rate;
            review.TextReview = request.TextReview?.Trim();
            review.UpdatedDate = now;

            await _orders.Context.SaveChangesAsync();
            return review.Id;
        }

        public class CreateMerchantReviewRequest
        {
            public int MerchantId { get; set; }
            public int Rate { get; set; }
            public string TextReview { get; set; }
        }

        public class MerchantReviewSummary
        {
            public int MerchantId { get; set; }
            public double Rating { get; set; }
            public int RatingCount { get; set; }
        }

        public class MerchantReviewResult : MerchantReviewSummary
        {
            public MerchantReviewItem[] Reviews { get; set; } = Array.Empty<MerchantReviewItem>();
        }

        public class MerchantReviewItem
        {
            public string Author { get; set; }
            public DateTime Date { get; set; }
            public int Rating { get; set; }
            public string Comment { get; set; }
        }
    }
}
