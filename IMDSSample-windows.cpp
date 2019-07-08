// build using 
// cl /EHsc imds_windows.cpp

#include <windows.h>
#include <WinHttp.h>
#include <iostream>
#include <string>

#pragma comment(lib,"winhttp.lib")

const wchar_t* MetadataRequiredHeader = L"metadata: true";

void GetMetadata(LPCWSTR serverName, WORD port, LPCWSTR url)
{
    LPSTR pszOutBuffer = NULL;
    HINTERNET  hSession = NULL, hConnect = NULL, hRequest = NULL;

    try
    {
        // ========================================================================================
        // Setup connection
        // ========================================================================================
        hSession = WinHttpOpen(L"WinHTTP connection from WS to IMDS",
                               WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                               WINHTTP_NO_PROXY_NAME,
                               WINHTTP_NO_PROXY_BYPASS,
                               /* dwFlags */ 0);
        if (hSession == NULL)
            throw L"Failed to create session";

        hConnect = WinHttpConnect(hSession, serverName, port, /* dwReserved */ 0);
        if(!hConnect)
        {
            throw L"Failed to connect";
        }

        hRequest = WinHttpOpenRequest(hConnect, L"GET", url,
                                      NULL, WINHTTP_NO_REFERER,
                                      WINHTTP_DEFAULT_ACCEPT_TYPES,
                                      0);

        if(!hRequest) throw L"Failed to open request";
      
        if(!WinHttpAddRequestHeaders(hRequest, MetadataRequiredHeader, -1L, WINHTTP_ADDREQ_FLAG_ADD))
            throw L" Failed in WinHttpAddRequestHeaders";

        if(!WinHttpSendRequest(hRequest,
                               WINHTTP_NO_ADDITIONAL_HEADERS, /* dwHeadersLength */ 0,
                               WINHTTP_NO_REQUEST_DATA, /* dwOptionalLength */ 0,
                               /* dwTotalLength */ 0, /* dwContext */ 0))
            throw L"Failed in WinHttpSendRequest";
        
        // ========================================================================================
        // Receive response and headers
        // ========================================================================================
        DWORD httpStatusCode = 0;
        DWORD httpStatusSize = sizeof(httpStatusCode);
        if(!WinHttpReceiveResponse(hRequest, /* lpReserved */ NULL))
        {
            throw L"Failed in WinHttpReceiveReponse";
        }

        if(!WinHttpQueryHeaders(hRequest,
                                WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                                WINHTTP_HEADER_NAME_BY_INDEX,
                                &httpStatusCode, &httpStatusSize, WINHTTP_NO_HEADER_INDEX))
        {
            throw L"Failed in WinHttpQueryHeaders";
        }
        
        std::wcout << L"Status code: " << httpStatusCode << std::endl;

        wchar_t contentType[256];
        DWORD headerLength = sizeof(contentType);
        if(!WinHttpQueryHeaders(hRequest,
                                WINHTTP_QUERY_CONTENT_TYPE,
                                NULL,
                                contentType,
                                &headerLength,
                                WINHTTP_NO_HEADER_INDEX))
        {
            throw L"Failed inWinHttpQueryHeaders";
        }

        
        DWORD dwSize;
        WinHttpQueryHeaders(hRequest, 
                            WINHTTP_QUERY_RAW_HEADERS_CRLF,
                            WINHTTP_HEADER_NAME_BY_INDEX, NULL, 
                            &dwSize, WINHTTP_NO_HEADER_INDEX);
        if(GetLastError() == ERROR_INSUFFICIENT_BUFFER)
        {
            auto lpOutBuffer = new wchar_t[dwSize/sizeof(wchar_t)];

            // Now, use WinHttpQueryHeaders to retrieve the header.
            if(!WinHttpQueryHeaders(hRequest,
                                    WINHTTP_QUERY_RAW_HEADERS_CRLF,
                                    WINHTTP_HEADER_NAME_BY_INDEX,
                                    lpOutBuffer, &dwSize,
                                    WINHTTP_NO_HEADER_INDEX))
            {
                throw L"Failed in WinHttpQueryHeaders - All Headers";
            }

            std::wcout << L"=============================================================" << std::endl;
            std::wcout << lpOutBuffer;
            std::wcout << L"=============================================================" << std::endl;

            delete []  lpOutBuffer;
        }

        // ========================================================================================
        // Receive data from server and print
        // ========================================================================================
        // Keep checking for data until there is nothing left.
        dwSize = 0;
        do
        {
            // Check for available data.
            if(!WinHttpQueryDataAvailable(hRequest, &dwSize))
            {
                throw L"Failed in WinHttpQueryDataAvailable";
            }

            // Allocate space for the buffer.
            pszOutBuffer = new char[dwSize + 1];
            if(pszOutBuffer == NULL)
            {
                throw L"Failed to allocate memory for pszOutBuffer.";
            }

            // Read the data.
            ZeroMemory(pszOutBuffer, dwSize + 1);
    
            DWORD dwDownloaded = 0;
            if(!WinHttpReadData(hRequest, (LPVOID)pszOutBuffer, dwSize, &dwDownloaded))
            {
                throw L"Failed in WinHttpReadData";
            }

            // this is a simple client and we don't parse content-type to find charset
            // we assume IMDS always returns utf-8
            int wchars_num = ::MultiByteToWideChar(CP_UTF8 , 0 , pszOutBuffer, -1, NULL , 0 );
            wchar_t* wstr = new wchar_t[wchars_num];
            ::MultiByteToWideChar( CP_UTF8 , 0 , pszOutBuffer, -1, wstr , wchars_num );
            
            std::wcout << wstr;

            // Free the memory allocated to the buffer.
            delete[] wstr;
            delete[] pszOutBuffer;
            pszOutBuffer = NULL;

        } while (dwSize > 0);
    }
    catch(LPCWSTR msg)
    {
        std::wcout << L"ERROR!! " << msg;
    }
    
    if (hRequest)
        WinHttpCloseHandle(hRequest);
        
    if (hConnect)
        WinHttpCloseHandle(hConnect);
        
    if (hSession)
        WinHttpCloseHandle(hSession);
        
    if (pszOutBuffer != NULL)
        delete[] pszOutBuffer;
}

int wmain(int argc, PCWSTR argv[])
{
    GetMetadata(L"169.254.169.254", 80, L"metadata/instance?api-version=2019-04-30");

    return 0;
}
