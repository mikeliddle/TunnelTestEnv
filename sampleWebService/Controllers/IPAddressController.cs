using Microsoft.AspNetCore.Mvc;
using TodoApi.Models;

namespace TodoApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class IPAddressController : ControllerBase
    {
        public IPAddressController() {}

        [HttpGet]
        public ActionResult<IPAddressModel> GetIPAddress()
        {
            var ip = Request.HttpContext.Connection.RemoteIpAddress;
            return new IPAddressModel() { IPAddress = ip.ToString() };
        }
    }
}