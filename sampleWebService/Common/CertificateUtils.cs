using System.IO;
using System.Security.Cryptography.X509Certificates;

namespace CertificateApi.Common{
    public static class CertificateUtils
    {
        public static bool ValidateCertificate(X509Certificate2 clientCertificate)
        {
            var cert = new X509Certificate2(Path.Combine("cacert.pem"), "");
            if (clientCertificate.Issuer == cert.SubjectName.Name)
            {
                // TODO: perform chain validation
                return true;
            }

            return false;
        }
    }
}