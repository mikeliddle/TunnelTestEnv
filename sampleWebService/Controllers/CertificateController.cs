using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;

namespace CertificateApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CertificateInfoController : ControllerBase
    {
        // GET: api/CertificateInfo
        [HttpGet]
        [Authorize]
        public string Get()
        {
            return "Hello World!";
        }
    }
}