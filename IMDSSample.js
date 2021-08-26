// NodeJS Sample for IMDS

var http = require('http');

function JsonQueryIMDS(path, callback) 
{
    api_version = '2021-02-01';
    imds_server = '169.254.169.254';

    result = ''  
    // Set your node js environment variable in .env to bypass proxies.
    // Aka NO_PROXY = "*"
    http.get({
        host: imds_server,
        path: '/metadata' + path + '?api-version=' + api_version,
        headers: {'Metadata': 'True'}
    }, function(response) {
        var statusCode = response.statusCode;
        if (statusCode != 200)
        {
            console.log('Request failed: ')
        }
        var body = '';
        response.on('data', function(d) {
            body += d;
        });
        response.on('end', function() {
            result = body;
            callback(result);
        });
    })
}

// query /instance metadata
JsonQueryIMDS('/instance', function(result) {
    // display raw json
    console.log(result);

    // parse json
    // ..
});
