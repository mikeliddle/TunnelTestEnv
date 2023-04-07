using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using CertificateApi.Models;

namespace CertificateApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CertificateInfoController : ControllerBase
    {
        // GET: api/CertificateInfo
        [HttpGet]
        [Authorize]
        public ActionResult<CertificateInfo> Get()
        {
            var certificate = this.Request.HttpContext.Connection.ClientCertificate;
            
            if (certificate == null)
            {
                return BadRequest("No client certificate found");
            }

            return Ok(new CertificateInfo(certificate));
        }
    }
}