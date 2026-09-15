using App.Models;
using App.Shared.Services.Helpers;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System;
using System.Diagnostics;

namespace App.Controllers
{
    public class HomeController : Controller
    {
        private readonly ILogger<HomeController> _logger;

        public HomeController(ILogger<HomeController> logger)
        {
            _logger = logger;
        }

        public IActionResult Index()
        {
            try
            {
                return View();
            }
            catch
            {
                return Content("<!DOCTYPE html><html><head><meta charset='utf-8'><title>JTAK API</title><style>body{font-family:system-ui,-apple-system,sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;background:#f8fafc;color:#1e293b;}div{text-align:center;padding:2rem;background:#fff;border-radius:12px;box-shadow:0 4px 6px -1px rgb(0 0 0/0.1);max-width:480px;}h1{color:#10b981;margin-bottom:0.5rem;}p{color:#64748b;margin-bottom:1.5rem;}a{display:inline-block;padding:0.75rem 1.5rem;background:#0d9488;color:#fff;border-radius:8px;text-decoration:none;font-weight:600;}</style></head><body><div><h1>JTAK API Service</h1><p>The API backend is running successfully.</p><a href='/" + AppDomainHelper.SwaggerGuid + "'>Swagger API Documentation</a></div></body></html>", "text/html");
            }
        }

        public IActionResult Privacy()
        {
            try
            {
                return View();
            }
            catch
            {
                return Ok(new { page = "Privacy" });
            }
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            try
            {
                return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
            }
            catch
            {
                return Problem(
                    title: "An internal error occurred",
                    statusCode: 500,
                    detail: Activity.Current?.Id ?? HttpContext.TraceIdentifier
                );
            }
        }
    }
}
