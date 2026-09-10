using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Linq.Expressions;
using System.Threading.Tasks;
using App.Shared.Data.App;
using App.Shared.Data.MultiContext;
using App.Shared.Entities;
using Microsoft.EntityFrameworkCore;
using Solf.Base;
using Solf.Identity;
using URF.Core.Abstractions.Trackable;

namespace App.Shared.Services
{
    public interface IUserService : ISolService<AppUser, UserDto>
    {
        int CountByRole(string roleName);
        Task<AppUser[]> ListFromRoles(params string[] roleNames);
        List<AppUser> ListFromRole(string roleName, params Expression<Func<AppUser, object>>[] eagerProperties);
    }

    public class UserService : SolService<AppUser, UserDto>, IUserService
    {
        private readonly ITrackableRepository<SolRole> _roleRepo;
        private readonly ITrackableRepository<SolUserRole> _userRoleRepo;
        private readonly ITrackableRepository<AppUser> _userRepo;

        public UserService(ITrackableRepository<AppUser, AppDbContext> repository,
            ITrackableRepository<SolUserRole> userRoleRepository,
            ITrackableRepository<SolRole> roleRepository,
            ITrackableRepository<AppUser> userRepository) : base(repository)
        {
            _userRoleRepo = userRoleRepository;
            _roleRepo = roleRepository;
            _userRepo = userRepository;
        }

        public int CountByRole(string roleName)
        {
            var rid = _roleRepo.Queryable().FirstOrDefault(r => r.NormalizedName == roleName.ToUpper())?.Id;
            return _userRoleRepo.Queryable()
                .Where(a => a.RoleId == rid)
                .Select(b => b.UserId)
                .Distinct()
                .Count();
        }

        public async Task<AppUser[]> ListFromRoles(params string[] roleNames)
        {
            roleNames = roleNames?.Select(r => r.ToUpper()).ToArray();
            var rids = await _roleRepo.Queryable().Where(x => roleNames.Contains(x.NormalizedName)).Select(x => x.Id).ToArrayAsync();

            var Users = _userRepo.Queryable() as DbSet<AppUser>;
            var UserRoles = _userRoleRepo.Queryable() as DbSet<SolUserRole>;

            var query = from userrole in UserRoles
                        join user in Users on userrole.UserId equals user.Id
                        where rids.Contains(userrole.RoleId)
                        select user;

            return await query.ToArrayAsync();
        }
        public List<AppUser> ListFromRole(string roleName, params Expression<Func<AppUser, Object>>[] eagerProperties)
        {
            roleName = roleName.ToUpper();
            var rid = _roleRepo.Queryable().FirstOrDefault(r => r.NormalizedName == roleName)?.Id;
            var uids = _userRoleRepo.Queryable()
                .Where(a => a.RoleId == rid)
                .Select(x => x.UserId)
                .Distinct()
                .ToList();
            var query = _userRepo.Queryable();
            query = eagerProperties.Aggregate(query, (current, e) => current.Include(e));
            return query.Where(x => uids.Contains(x.Id)).ToList();
        }

        public override IQueryable<UserDto> OrderBy(IQueryable<UserDto> query, string orderColumn, ListSortDirection dir)
        {
            if (string.IsNullOrEmpty(orderColumn)) return query;
            var isAsc = dir == ListSortDirection.Ascending;
            orderColumn = orderColumn.Trim().ToLower();

            query = orderColumn switch
            {
                "fullname" => isAsc ? query.OrderBy(x => x.FullName) : query.OrderByDescending(x => x.FullName),
                "firstname" => isAsc ? query.OrderBy(x => x.FirstName) : query.OrderByDescending(x => x.FirstName),
                "lastname" => isAsc ? query.OrderBy(x => x.LastName) : query.OrderByDescending(x => x.LastName),
                "email" => isAsc ? query.OrderBy(x => x.Email) : query.OrderByDescending(x => x.Email),
                _ => isAsc ? query.OrderBy(x => x.Id) : query.OrderByDescending(x => x.Id)
            };
            return query;
        }

        public override IQueryable<AppUser> OrderBy(IQueryable<AppUser> query, string orderColumn, ListSortDirection dir)
        {
            if (string.IsNullOrEmpty(orderColumn)) return query;
            var isAsc = dir == ListSortDirection.Ascending;
            orderColumn = orderColumn.Trim().ToLower();

            query = orderColumn switch
            {
                "fullname" => isAsc ? query.OrderBy(x => x.FullName) : query.OrderByDescending(x => x.FullName),
                "firstname" => isAsc ? query.OrderBy(x => x.FirstName) : query.OrderByDescending(x => x.FirstName),
                "lastname" => isAsc ? query.OrderBy(x => x.LastName) : query.OrderByDescending(x => x.LastName),
                "email" => isAsc ? query.OrderBy(x => x.Email) : query.OrderByDescending(x => x.Email),
                _ => isAsc ? query.OrderBy(x => x.Id) : query.OrderByDescending(x => x.Id)
            };
            return query;
        }

        public override IQueryable<AppUser> Search(IQueryable<AppUser> query, string keyword)
        {
            keyword = keyword?.Trim()?.ToLower();
            if (string.IsNullOrEmpty(keyword))
                return query;
            return query.Where(x => x.FullName.ToLower().Contains(keyword) ||
            x.Email.ToLower().Contains(keyword) ||
            x.PhoneNumber.ToLower().Contains(keyword));
        }
        public override IQueryable<UserDto> Search(IQueryable<UserDto> query, string keyword)
        {
            keyword = keyword?.Trim()?.ToLower();
            if (string.IsNullOrEmpty(keyword))
                return query;
            return query.Where(x => x.FullName.ToLower().Contains(keyword) ||
            x.Email.ToLower().Contains(keyword) ||
            x.PhoneNumber.ToLower().Contains(keyword));
        }
    }
}