package main

import (
    "fmt"
    "io/ioutil"
    "net/http"
)

func main() {
    client := &http.Client{}

    req, _ := http.NewRequest("GET", "http://169.254.169.254/metadata/instance", nil)
    req.Header.Add("Metadata", "True")

    q := req.URL.Query()
    q.Add("format", "json")
    q.Add("api-version", "2019-04-30")
    req.URL.RawQuery = q.Encode()

    resp, err := client.Do(req)
    if err != nil {
        fmt.Println("Errored when sending request to the server")
        return
    }

    defer resp.Body.Close()
    resp_body, _ := ioutil.ReadAll(resp.Body)

    fmt.Println(resp.Status)
    fmt.Println(string(resp_body))
}
