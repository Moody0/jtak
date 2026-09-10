using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Hosting;
using Serilog;


namespace App
{
    public class Program
    {
        public static void Main(string[] args)
        {
            CreateHostBuilder(args).Build().Run();
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
        Host.CreateDefaultBuilder(args)
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    webBuilder.UseStartup<Startup>()
                              //.UseSetting("detailedErrors", "true")
                              .UseSerilog((hostingContext, loggerConfiguration) =>
                                  loggerConfiguration
                                  .Enrich.FromLogContext()
                                  .MinimumLevel.Error()
                                  .WriteTo.File("Logs\\log.txt", rollingInterval: RollingInterval.Day)
                                  .WriteTo.Console())
                              .CaptureStartupErrors(true);
                });
    }
}
