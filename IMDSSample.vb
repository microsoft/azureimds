Imports System.IO
Imports System.Net
Imports Newtonsoft.Json

Module Module1

    Sub Main()
        Dim request As HttpWebRequest = WebRequest.Create("http://169.254.169.254/metadata/instance?api-version=2019-03-11")
        ' IMDS requires proxies to be bypassed
        Dim proxy As New WebProxy()
        request.Headers.Add("Metadata: True")
        request.Proxy = proxy
        Dim response As HttpWebResponse = request.GetResponse()
        Dim dataStream As Stream = response.GetResponseStream()
        Dim reader As New StreamReader(dataStream)
        Dim responseFromServer As String = reader.ReadToEnd()

        Dim json As String = JsonConvert.SerializeObject(JsonConvert.DeserializeObject(responseFromServer), Formatting.Indented)
        Console.WriteLine(json)
        reader.Close()
        dataStream.Close()
        response.Close()
    End Sub

End Module