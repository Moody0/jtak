using App.ApiModels;
using App.Extensions;
using App.Shared.Services;
using App.Shared.Services.Domain;
using AutoMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using OpenIddict.Validation.AspNetCore;
using App.Shared.Entities;
using App.Shared.Entities.Domain;
using App.Shared.Data.App;
using App.Shared.Entities.Enums;

namespace App.ApiControllers.V1.Customer
{
    [Route("api/v{version:apiVersion}/Customer/[controller]")]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ApiErr))]
    [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme, Policy = nameof(AppPermissionKey.CustomerPermission))]
    [ApiVersion("1")]
    public class AddressController : SolApiController
    {
        private readonly IAppUnitOfWork _uow;
        private readonly INotificationService _notificationService;
        private readonly UserManager<AppUser> _userManager;
        private readonly IMapper _mapper;
        private readonly ILogger _logger;
        private readonly IAddressService _service;

        public AddressController(IAppUnitOfWork unitOfWork,
            INotificationService notificationService,
            UserManager<AppUser> userManager,
            IAddressService service,
            ILogger<AddressController> logger,
            IMapper mapper)
        {
            _uow = unitOfWork;
            _userManager = userManager;
            _notificationService = notificationService;
            _logger = logger;
            _mapper = mapper;
            _service = service;
        }

        /// <summary>
        /// Get All My Addresses
        /// </summary>
        /// <returns></returns>
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [HttpGet]
        [Route("Mine")]
        public async Task<ActionResult<AddressDto[]>> GetMine() =>
            await _service.GetUserAddresses(User.GetUserId());


        /// <summary>
        /// Create address
        /// </summary>
        /// <returns></returns>
        [HttpPost]
        public async Task<ActionResult<int>> Create(AddressDto model)
        {
            var uid = User.GetUserId();
            var entity = new Address
            {
                UserId = uid.Value,

                Title = model.Title,
                FullName = model.FullName,
                Phonenumber = model.Phonenumber,
                TaxNumber = model.TaxNumber,

                Country = model.Country,
                Level1 = model.Level1,
                Level2 = model.Level2,
                Level3 = model.Level3,
                Level4 = model.Level4,
                ZipPostalCode = model.ZipPostalCode,

                FullAddress = model.FullAddress,
                Apartment = model.Apartment,
                Lng = model.Lng,
                Lat = model.Lat,
                IsCompany = model.IsCompany,
                AddressType = model.AddressType
            };
            _service.Insert(entity);
            await _uow.SaveChangesAsync();
            return entity.Id;
        }

        /// <summary>
        /// Edit address
        /// </summary>
        /// <returns></returns>
        [HttpPut]
        [Authorize(AuthenticationSchemes = OpenIddictValidationAspNetCoreDefaults.AuthenticationScheme)]
        [Route("{id}")]
        public async Task<ActionResult<int>> Edit(int id, AddressDto model)
        {
            var entity = await _service.FindAsync(id);
            if (entity == null)
            {
                return BadRequest("Not found!");
            }
            var uid = User.GetUserId();
            if (uid == null || entity.UserId != uid.Value)
            {
                return Forbid();
            }

            entity.Title = model.Title;
            entity.FullName = model.FullName;
            entity.Phonenumber = model.Phonenumber;
            entity.TaxNumber = model.TaxNumber;

            entity.Country = model.Country;
            entity.Level1 = model.Level1;
            entity.Level2 = model.Level2;
            entity.Level3 = model.Level3;
            entity.Level4 = model.Level4;
            entity.ZipPostalCode = model.ZipPostalCode;

            entity.FullAddress = model.FullAddress;
            entity.Apartment = model.Apartment;
            entity.Lng = model.Lng;
            entity.Lat = model.Lat;
            entity.IsCompany = model.IsCompany;
            entity.AddressType = model.AddressType;

            await _uow.SaveChangesAsync();

            return entity.Id;
        }

        /// <summary>
        /// Delete address
        /// </summary>
        /// <returns></returns>
        [HttpDelete]
        [Route("{id}")]
        public async Task<ActionResult<bool>> Delete(int id)
        {
            var entity = await _service.FindAsync(id);
            if (entity == null)
            {
                return BadRequest("Not found!");
            }
            var uid = User.GetUserId();
            if (uid == null || entity.UserId != uid.Value)
            {
                return Forbid();
            }

            await _service.DeleteAsync(id);
            await _uow.SaveChangesAsync();
            return true;
        }
    }
}
