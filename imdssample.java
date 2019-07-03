package com.microsoft.azure.imds.samples;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.Collection;
import java.util.Iterator;
import javax.security.auth.x500.X500Principal;
import org.bouncycastle.cms.CMSSignedData;
import org.bouncycastle.cms.CMSTypedData;
import org.bouncycastle.util.encoders.Base64;
import com.google.gson.Gson;

/**
 * This example has two dependencies:
 *  1. Google Gson library: https://github.com/google/gson
 *  2. BouncyCastle Java library: https://www.bouncycastle.org/java.html
 */
public class IMDSSample 
{
    public static final String ImdsServer = "http://169.254.169.254";
    public static final String InstanceEndpoint = ImdsServer + "/metadata/instance";
    public static final String AttestedEndpoint = ImdsServer + "/metadata/attested/document";
    public static final String NonceValue = "123456";
    
    public static void main(String[] args)
    {
        // Query /instance metadata
        String result = QueryInstanceEndpoint();
        ParseInstanceResponse(result);

        // Make Attested call and parse the response
        result = QueryAttestedEndpoint();
        ParseAttestedResponse(result);
    }
    
    private static void ParseInstanceResponse(String response)
    {
        System.out.println("Instance response: " + response);
    }
    
    private static void ParseAttestedResponse(String response)
    {
        System.out.println("Parsing Attested response");
        AttestedDocument document = new Gson().fromJson(response, AttestedDocument.class);
        byte[] decoded = Base64.decode(document.signature);
        ValidateCertificate(decoded);
        ValidateAttestedData(decoded);
    }
    
    private static void ValidateCertificate(byte[] decoded)
    {
        try
        {
            CertificateFactory factory =  CertificateFactory.getInstance("X.509");
            Collection certs = factory.generateCertificates(new ByteArrayInputStream(decoded));
            Iterator it = certs.iterator();
            while(it.hasNext())
            {
                X509Certificate cert = (X509Certificate)it.next();
                cert.checkValidity();
                X500Principal issuer = cert.getIssuerX500Principal();
                System.out.println("Issuer: " + issuer.toString());
                X500Principal subject = cert.getSubjectX500Principal();
                System.out.println("Subject: " + subject.toString());
                System.out.println("Valid until: " + cert.getNotAfter().toString());
            }
        }
        catch(Exception ex)
        {
            System.out.println("Exception validating certificate: " + ex.getMessage());
        }
    }
    
    private static void ValidateAttestedData(byte[] decoded)
    {
        try
        {
            CMSSignedData signature = new CMSSignedData(decoded);
            CMSTypedData signedData = signature.getSignedContent();
            String signedDataString = new String((byte[])signedData.getContent());
            System.out.println("Attested data: " + signedDataString);
            AttestedData data = new Gson().fromJson(signedDataString, AttestedData.class);
            if(data.nonce.compareTo(NonceValue) == 0)
            {
                System.out.println("Nonce values match");
            }
        }
        catch(Exception ex)
        {
            System.out.println("Exception validating data: " + ex.getMessage());
        }
    }
    
    private static String QueryInstanceEndpoint()
    {
        return QueryImds(InstanceEndpoint, "2017-04-02");       
    }
    
    private static String QueryAttestedEndpoint()
    {
        String nonce = "nonce=" + NonceValue;
        return QueryImds(AttestedEndpoint, "2019-04-30", nonce);
    }
    
    private static String QueryImds(String path, String apiVersion)
    {
        return QueryImds(path, apiVersion, "");
    }
    
    private static String QueryImds(String path, String apiVersion, String otherParams)
    {
        String imdsUrl = path + "?api-version=" + apiVersion;
        if(otherParams != null && !otherParams.isEmpty())
        {
            imdsUrl += "&" + otherParams;
        }
        
        try
        {
            URL url = new URL(imdsUrl);
            HttpURLConnection con = (HttpURLConnection) url.openConnection();
            con.setRequestMethod("GET");
            con.setRequestProperty("Metadata", "True");
            BufferedReader in = new BufferedReader(new InputStreamReader(con.getInputStream()));
            String line;
            StringBuffer response = new StringBuffer();
            while ((line = in.readLine()) != null) {
              response.append(line);
            }
            in.close();
            return response.toString();
        }
        catch(Exception ex)
        {
            return "";
        }
    }
    
    public class AttestedDocument
    {
        public String encoding;
        public String signature;
    }

    public class AttestedData
    {
        public String nonce;
        public String vmId;
        public String subscriptionId;
        public AttestedDataPlanInfo plan;
        public AttestedDataTimeStamp timeStamp;
    }

    public class AttestedDataPlanInfo
    {
        public String name;
        public String product;
        public String publisher;
    }

    public class AttestedDataTimeStamp
    {
        public String createdOn;
        public String expiresOn;
    }
    
}
