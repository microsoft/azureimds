using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Security.Cryptography;
using System.Security.Cryptography.Pkcs;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Threading.Tasks;

namespace Samples
{
    class IMDSSample
    {
        const string ImdsServer = "http://169.254.169.254";
        const string InstanceEndpoint = ImdsServer + "/metadata/instance";
        const string AttestedEndpoint = ImdsServer + "/metadata/attested/document";
        const string NonceValue = "123456";

        static async Task Main(string[] args)
        {
            // Query /instance metadata
            var result = await QueryInstanceEndpoint();
            ParseInstanceResponse(result);

            // Make Attested call and parse the response
            result = await QueryAttestedEndpoint();
            ParseAttestedResponse(result);
        }

        private static void ParseAttestedResponse(string response)
        {
            Console.WriteLine("Parsing Attested response");
            AttestedDocument document = (AttestedDocument)SerializeObjectFromJsonString(typeof(AttestedDocument), response);
            ValidateCertificate(document);
            ValidateAttestedData(document);
        }

        private static void ValidateCertificate(AttestedDocument document)
        {
            try
            {
                // Build certificate from response
                X509Certificate2 cert = new X509Certificate2(System.Text.Encoding.UTF8.GetBytes(document.Signature));

                // Build certificate chain
                X509Chain chain = new X509Chain();
                chain.Build(cert);

                // Print certificate chain information
                foreach (X509ChainElement element in chain.ChainElements)
                {
                    Console.WriteLine("Element issuer: {0}", element.Certificate.Issuer);
                    Console.WriteLine("Element subject: {0}", element.Certificate.Subject);
                    Console.WriteLine("Element certificate valid until: {0}", element.Certificate.NotAfter);
                    Console.WriteLine("Element certificate is valid: {0}", element.Certificate.Verify());
                    Console.WriteLine("Element error status length: {0}", element.ChainElementStatus.Length);
                    Console.WriteLine("Element information: {0}", element.Information);
                    Console.WriteLine("Number of element extensions: {0}{1}", element.Certificate.Extensions.Count, Environment.NewLine);
                }
            }
            catch (CryptographicException ex)
            {
                Console.WriteLine("Exception: {0}", ex);
            }
        }

        private static void ValidateAttestedData(AttestedDocument document)
        {
            try
            {
                byte[] blob = Convert.FromBase64String(document.Signature);
                SignedCms signedCms = new SignedCms();
                signedCms.Decode(blob);
                string result = Encoding.UTF8.GetString(signedCms.ContentInfo.Content);
                Console.WriteLine("Attested data: {0}", result);
                AttestedData data = SerializeObjectFromJsonString(typeof(AttestedData), result) as AttestedData;
                if (data.Nonce.Equals(NonceValue))
                {
                    Console.WriteLine("Nonce values match");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("Error checking signature blob: '{0}'", ex);
            }
        }

        private static void ParseInstanceResponse(string response)
        {
            // Display raw json
            Console.WriteLine("Instance response: {0}{1}", response, Environment.NewLine);
        }

        private static Task<string> QueryInstanceEndpoint()
        {
            return QueryImds(InstanceEndpoint, "2019-03-11");
        }

        private static Task<string> QueryAttestedEndpoint()
        {
            string nonce = "nonce=" + NonceValue;
            return QueryImds(AttestedEndpoint, "2019-03-11", nonce);
        }

        // Query IMDS server and retrieve JSON result
        private static Task<string> QueryImds(string path, string apiVersion)
        {
            return QueryImds(path, apiVersion, "");
        }

        private static async Task<string> QueryImds(string path, string apiVersion, string otherParams)
        {
            string imdsUri = path + "?api-version=" + apiVersion;
            if (otherParams != null &&
                !otherParams.Equals(string.Empty))
            {
                imdsUri += "&" + otherParams;
            }
            string jsonResult = string.Empty;
            using (var httpClient = new HttpClient())
            {
                // IMDS requires bypassing proxies.
                WebProxy proxy = new WebProxy();
                HttpClient.DefaultProxy = proxy;
                httpClient.DefaultRequestHeaders.Add("Metadata", "True");
                try
                {
                    jsonResult = await httpClient.GetStringAsync(imdsUri);
                }
                catch (AggregateException ex)
                {
                    // Handle response failures
                    Console.WriteLine("Request failed: " + ex.GetBaseException());
                }
            }
            return jsonResult;
        }

        private static object SerializeObjectFromJsonString(Type objectType, string json)
        {
            DataContractJsonSerializer jsonSerializer = new DataContractJsonSerializer(objectType);
            using (MemoryStream memoryStream = new MemoryStream())
            using (StreamWriter writer = new StreamWriter(memoryStream))
            {
                // Prepare stream
                writer.Write(json);
                memoryStream.Position = 0;

                // Serialize object
                return jsonSerializer.ReadObject(memoryStream);
            }
        }

        [DataContract]
        public class AttestedDocument
        {
            [DataMember(Name = "encoding")]
            public string Encoding { get; set; }

            [DataMember(Name = "signature")]
            public string Signature { get; set; }
        }

        [DataContract]
        public class AttestedData
        {
            [DataMember(Name = "nonce")]
            public string Nonce { get; set; }

            [DataMember(Name = "vmId")]
            public string VmId { get; set; }

            [DataMember(Name = "subscriptionId")]
            public string SubscriptionId { get; set; }

            [DataMember(Name = "plan")] public AttestedDataPlanInfo PlanInfo;

            [DataMember(Name = "timeStamp")] public AttestedDataTimeStamp TimeStamp;
        }

        [DataContract]
        public class AttestedDataPlanInfo
        {
            [DataMember(Name = "name")]
            public string Name { get; set; }

            [DataMember(Name = "product")]
            public string Product { get; set; }

            [DataMember(Name = "publisher")]
            public string Publisher { get; set; }
        }

        [DataContract]
        public class AttestedDataTimeStamp
        {
            [DataMember(Name = "createdOn")]
            public string CreatedDate { get; set; }

            [DataMember(Name = "expiresOn")]
            public string ExpiryDate { get; set; }
        }
    }
}
