namespace Samples
{
    using System;
    using System.Net.Http;
    class IMDSSample
    {        
        // Query IMDS server and retrieve JSON result
        private static string JsonQueryIMDS(string path)
        {
            const string api_version = "2017-04-02";
            const string imds_server = "169.254.169.254";

            string imdsUri = "http://" + imds_server + "/metadata" + path + "?api-version=" + api_version;

            string jsonResult = string.Empty;
            using (var httpClient = new HttpClient())
            {
                httpClient.DefaultRequestHeaders.Add("Metadata", "True");
                try
                {
                    jsonResult = httpClient.GetStringAsync(imdsUri).Result;
                }
                catch (AggregateException ex)
                {
                    // handle response failures
                    Console.WriteLine("Request failed: " + ex.InnerException.Message);
                }
            }
            return jsonResult;
        }

        static void Main(string[] args)
        {
            // query /instance metadata
            var result = JsonQueryIMDS("/instance");
            
            // display raw json
            Console.WriteLine(result);

            // parse json result
            // ...
        }
    }
}
