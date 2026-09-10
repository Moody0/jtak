using Solf.Base;
using Solf.Enums;
using System;

namespace App.Shared.Entities.Domain
{
    public class Address : AuditableEntity
    {
        public int Id { get; set; }
        public Guid UserId { get; set; }
        public string Title { get; set; } // 'Home' or 'Work'

        public string FullName { get; set; }
        public string Phonenumber { get; set; }
        public string TaxNumber { get; set; }

        public CountryEnum Country { get; set; } // Country/Region

        public string Level1 { get; set; } // State/Province/Governorate
        public string Level2 { get; set; } // Province/District
        public string Level3 { get; set; } // Sub-District
        public string Level4 { get; set; } // Neighbourhood/Village

        public string ZipPostalCode { get; set; } // Zip

        public string FullAddress { get; set; } // OpenText Address
        public string Apartment { get; set; } // FlatNumber

        public decimal? Lng { get; set; }
        public decimal? Lat { get; set; }
        public bool IsCompany { get; set; }
        public AddressType AddressType { get; set; }
    }

    public class AddressDto
    {
        public int Id { get; set; }
        public Guid UserId { get; set; }
        public string Title { get; set; }

        public string FullName { get; set; }
        public string Phonenumber { get; set; }
        public string TaxNumber { get; set; }

        public CountryEnum Country { get; set; }
        public string Level1 { get; set; }
        public string Level2 { get; set; }
        public string Level3 { get; set; }
        public string Level4 { get; set; }
        public string ZipPostalCode { get; set; }

        public string FullAddress { get; set; }
        public string Apartment { get; set; }

        public decimal? Lng { get; set; }
        public decimal? Lat { get; set; }
        public bool IsCompany { get; set; }
        public AddressType AddressType { get; set; }
    }
    //[JsonConverter(typeof(JsonStringEnumConverter))]
    public enum AddressType
    {
        Shipping = 0,
        Billing = 1
    }
}
