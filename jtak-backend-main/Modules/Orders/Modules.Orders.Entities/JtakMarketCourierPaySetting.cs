using System;
using App.Shared.Entities.Enums;

namespace Modules.Orders.Entities
{
    // Stored under a neutral GenericSettings key; no schema migration needed.
    public class JtakMarketCourierPaySetting
    {
        public const string Key = "JtakMarketCourierPaySetting";
        public CaptainCompensationType Mode { get; set; } = CaptainCompensationType.SalariedEmployee;
        public decimal Rate { get; set; }
        public bool IsValid => Rate >= 0m && decimal.Round(Rate, 2) == Rate &&
            (Mode == CaptainCompensationType.SalariedEmployee && Rate == 0m ||
             Mode == CaptainCompensationType.FixedPerOrder && Rate > 0m && Rate <= 100000000m ||
             Mode == CaptainCompensationType.Percentage && Rate > 0m && Rate <= 100m);
    }
}
