using App.Shared.Data.MultiContext;
using Microsoft.EntityFrameworkCore;
using Modules.Accounting.Data;
using Modules.Accounting.Entities;
using Solf.Base;
using Solf.Models;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;

namespace Modules.Accounting.Services
{
    public interface IBillService : ISolService<Bill, BillDto>
    {
        Task<TableResponseModel<BillDto>> GetDataTableAsync(
            MetronicTable request,
            Dictionary<int, string> merchantTitles = null,
            IEnumerable<int> allowedMerchantIds = null);
    }

    public class BillService : SolService<Bill, BillDto>, IBillService
    {
        public BillService(ITrackableRepository<Bill, AccountingDbContext> repo) : base(repo)
        {
        }

        public async Task<TableResponseModel<BillDto>> GetDataTableAsync(
            MetronicTable request,
            Dictionary<int, string> merchantTitles = null,
            IEnumerable<int> allowedMerchantIds = null)
        {
            var query = Queryable().AsNoTracking();

            if (allowedMerchantIds != null)
            {
                var mids = allowedMerchantIds.ToList();
                query = query.Where(b => mids.Contains(b.MerchantId));
            }

            // Search filter
            if (!string.IsNullOrWhiteSpace(request?.Search))
            {
                var term = request.Search.Trim();
                var cleanTerm = term.TrimStart('#').Trim();
                var isNumeric = int.TryParse(cleanTerm, out var searchId);
                var isDecimal = decimal.TryParse(cleanTerm, NumberStyles.Any, CultureInfo.InvariantCulture, out var searchAmount)
                             || decimal.TryParse(cleanTerm, NumberStyles.Any, new CultureInfo("ar-SY"), out searchAmount);

                List<int> matchingMerchantIds = null;
                if (merchantTitles != null && merchantTitles.Count > 0)
                {
                    matchingMerchantIds = merchantTitles
                        .Where(m => !string.IsNullOrEmpty(m.Value) && m.Value.Contains(term, StringComparison.OrdinalIgnoreCase))
                        .Select(m => m.Key)
                        .ToList();
                }

                if (isNumeric && isDecimal)
                {
                    if (matchingMerchantIds != null && matchingMerchantIds.Count > 0)
                    {
                        query = query.Where(b => b.Id == searchId ||
                                                 b.OrderId == searchId ||
                                                 b.MerchantId == searchId ||
                                                 b.TotalAmount == searchAmount ||
                                                 b.MerchantAmount == searchAmount ||
                                                 matchingMerchantIds.Contains(b.MerchantId));
                    }
                    else
                    {
                        query = query.Where(b => b.Id == searchId ||
                                                 b.OrderId == searchId ||
                                                 b.MerchantId == searchId ||
                                                 b.TotalAmount == searchAmount ||
                                                 b.MerchantAmount == searchAmount);
                    }
                }
                else if (isNumeric)
                {
                    if (matchingMerchantIds != null && matchingMerchantIds.Count > 0)
                    {
                        query = query.Where(b => b.Id == searchId ||
                                                 b.OrderId == searchId ||
                                                 b.MerchantId == searchId ||
                                                 matchingMerchantIds.Contains(b.MerchantId));
                    }
                    else
                    {
                        query = query.Where(b => b.Id == searchId ||
                                                 b.OrderId == searchId ||
                                                 b.MerchantId == searchId);
                    }
                }
                else if (isDecimal)
                {
                    if (matchingMerchantIds != null && matchingMerchantIds.Count > 0)
                    {
                        query = query.Where(b => b.TotalAmount == searchAmount ||
                                                 b.MerchantAmount == searchAmount ||
                                                 matchingMerchantIds.Contains(b.MerchantId));
                    }
                    else
                    {
                        query = query.Where(b => b.TotalAmount == searchAmount ||
                                                 b.MerchantAmount == searchAmount);
                    }
                }
                else if (matchingMerchantIds != null && matchingMerchantIds.Count > 0)
                {
                    query = query.Where(b => matchingMerchantIds.Contains(b.MerchantId));
                }
                else
                {
                    query = query.Where(b => false);
                }
            }

            var totalRecords = await query.CountAsync();

            // Sorting
            var sortField = request?.SortField?.Trim()?.ToLower();
            var sortAsc = string.Equals(request?.SortOrder, "ASC", StringComparison.OrdinalIgnoreCase);

            query = sortField switch
            {
                "id" => sortAsc ? query.OrderBy(x => x.Id) : query.OrderByDescending(x => x.Id),
                "orderid" => sortAsc ? query.OrderBy(x => x.OrderId) : query.OrderByDescending(x => x.OrderId),
                "merchantid" => sortAsc ? query.OrderBy(x => x.MerchantId) : query.OrderByDescending(x => x.MerchantId),
                "totalamount" => sortAsc ? query.OrderBy(x => x.TotalAmount) : query.OrderByDescending(x => x.TotalAmount),
                "merchantamount" => sortAsc ? query.OrderBy(x => x.MerchantAmount) : query.OrderByDescending(x => x.MerchantAmount),
                "jtakamount" => sortAsc ? query.OrderBy(x => x.JTakAmount) : query.OrderByDescending(x => x.JTakAmount),
                "jtakadditionalamount" => sortAsc ? query.OrderBy(x => x.JTakAdditionalAmount) : query.OrderByDescending(x => x.JTakAdditionalAmount),
                "duedate" => sortAsc ? query.OrderBy(x => x.DueDate) : query.OrderByDescending(x => x.DueDate),
                "isaddedtodues" => sortAsc ? query.OrderBy(x => x.IsAddedToDues) : query.OrderByDescending(x => x.IsAddedToDues),
                "createddate" => sortAsc ? query.OrderBy(x => x.CreatedDate) : query.OrderByDescending(x => x.CreatedDate),
                _ => query.OrderByDescending(x => x.CreatedDate).ThenByDescending(x => x.Id)
            };

            // Pagination
            var pageNumber = Math.Max(request?.PageNumber ?? 1, 1);
            var pageSize = Math.Max(request?.PageSize ?? 10, 1);
            var pagedBills = await query.Skip((pageNumber - 1) * pageSize).Take(pageSize).ToListAsync();

            var dtos = pagedBills.Select(x => new BillDto
            {
                Id = x.Id,
                OrderId = x.OrderId,
                MerchantId = x.MerchantId,
                MerchantTitle = merchantTitles != null && merchantTitles.TryGetValue(x.MerchantId, out var title)
                    ? title
                    : $"#{x.MerchantId}",
                PaymentMethod = x.PaymentMethod,
                MerchantAmount = x.MerchantAmount,
                JTakAdditionalAmount = x.JTakAdditionalAmount,
                JTakAmount = x.JTakAmount,
                TotalAmount = x.TotalAmount,
                CreatedDate = x.CreatedDate,
                DueDate = x.DueDate,
                IsAddedToDues = x.IsAddedToDues
            }).ToArray();

            return new TableResponseModel<BillDto>
            {
                Items = dtos,
                TotalRecords = totalRecords,
                TotalRecordsFiltered = totalRecords
            };
        }
    }
}
