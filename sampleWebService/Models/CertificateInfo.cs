using System.Security.Cryptography.X509Certificates;

namespace CertificateApi.Models
{
    public class CertificateInfo
    {
        public CertificateInfo(){}
        
        public CertificateInfo(X509Certificate2 certificate)
        {
            Subject = certificate.Subject;
            Issuer = certificate.Issuer;
            SerialNumber = certificate.SerialNumber;
            Thumbprint = certificate.Thumbprint;
            Version = certificate.Version.ToString();
            NotBefore = certificate.NotBefore.ToString();
            NotAfter = certificate.NotAfter.ToString();
            SignatureAlgorithm = certificate.SignatureAlgorithm.FriendlyName ?? "";
            PublicKeyAlgorithm = certificate.PublicKey.Oid.FriendlyName ?? "";
            PublicKey = certificate.GetPublicKeyString();
        }

        public string Subject { get; set; } = null!;
        public string Issuer { get; set; } = null!;
        public string SerialNumber { get; set; } = null!;
        public string Thumbprint { get; set; } = null!;
        public string Version { get; set; } = null!;
        public string NotBefore { get; set; } = null!;
        public string NotAfter { get; set; } = null!;
        public string SignatureAlgorithm { get; set; } = null!;
        public string PublicKeyAlgorithm { get; set; } = null!;
        public string PublicKey { get; set; } = null!;
    }
}