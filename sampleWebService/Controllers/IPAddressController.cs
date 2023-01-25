using Microsoft.AspNetCore.Mvc;

namespace TodoApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class IPAddressController : ControllerBase
    {
        public IPAddressController() {}

        [HttpGet]
        public ActionResult<string> GetIPAddress()
        {
            var ip = Request.HttpContext.Connection.RemoteIpAddress;
            return ip.ToString();
        }
    }
}