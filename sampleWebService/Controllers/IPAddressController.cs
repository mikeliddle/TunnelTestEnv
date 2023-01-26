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
            var ip = Request.Headers["X-Real-IP"];
            return new IPAddressModel() { IPAddress = ip };
        }
    }
}