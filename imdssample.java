package com.microsoft.azure.imds.samples;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.Proxy;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.security.cert.CertPathBuilder;
import java.security.cert.CertStore;
import java.security.cert.CollectionCertStoreParameters;
import java.security.cert.PKIXCertPathBuilderResult;
import java.security.cert.PKIXBuilderParameters;
import java.security.cert.TrustAnchor;
import java.security.cert.X509CertSelector;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import javax.net.ssl.TrustManager;
import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509TrustManager;
import org.bouncycastle.cert.X509CertificateHolder;
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter;
import org.bouncycastle.cms.CMSSignedData;
import org.bouncycastle.cms.CMSTypedData;
import org.bouncycastle.cms.SignerInformation;
import org.bouncycastle.cms.SignerInformationStore;
import org.bouncycastle.cms.jcajce.JcaSimpleSignerInfoVerifierBuilder;
import org.bouncycastle.util.Store;
import org.bouncycastle.util.encoders.Base64;
import com.google.gson.Gson;

/**
 * This example has two dependencies:
 *  1. Google Gson library: https://github.com/google/gson
 *  2. BouncyCastle Java library: https://www.bouncycastle.org/java.html
 */
public class IMDSSample 
{
    private static final int DnsSubjectAlternativeNameType = 2;
    private static final String MetadataDnsSuffix = ".metadata.azure.com";
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
        ValidateAttestedData(decoded);
    }
    
    private static void ValidateAttestedData(byte[] decoded)
    {
        try
        {
            CMSSignedData signature = new CMSSignedData(decoded);
            Store<X509CertificateHolder> certificateStore = signature.getCertificates();
            SignerInformationStore signerStore = signature.getSignerInfos();
            Collection<SignerInformation> signers = signerStore.getSigners();
            if(signers.size() != 1)
            {
                throw new SecurityException("Expected exactly one attested-document signer");
            }

            SignerInformation signer = signers.iterator().next();
            Collection<X509CertificateHolder> signerCertificates = certificateStore.getMatches(signer.getSID());
            if(signerCertificates.size() != 1)
            {
                throw new SecurityException("Unable to identify the attested-document signer certificate");
            }

            JcaX509CertificateConverter converter = new JcaX509CertificateConverter();
            X509Certificate signerCertificate = converter.getCertificate(signerCertificates.iterator().next());
            ValidateMetadataIdentity(signerCertificate);
            PKIXCertPathBuilderResult certificatePath = ValidateCertificatePath(
                signerCertificate, certificateStore, converter);
            if(!signer.verify(new JcaSimpleSignerInfoVerifierBuilder().build(signerCertificate)))
            {
                throw new SecurityException("Invalid attested-document signature");
            }

            PrintCertificatePath(certificatePath);

            CMSTypedData signedData = signature.getSignedContent();
            if(signedData == null || !(signedData.getContent() instanceof byte[]))
            {
                throw new SecurityException("Attested document does not contain signed data");
            }

            String signedDataString = new String((byte[])signedData.getContent(), StandardCharsets.UTF_8);
            AttestedData data = new Gson().fromJson(signedDataString, AttestedData.class);
            if(data == null || !NonceValue.equals(data.nonce))
            {
                throw new SecurityException("Attested-document nonce does not match the request");
            }

            System.out.println("Attested data: " + signedDataString);
            System.out.println("Nonce values match");
			// You should also verify the plan and subscription information
        }
        catch(Exception ex)
        {
            throw new SecurityException("Attested-document validation failed", ex);
        }
    }

    private static void ValidateMetadataIdentity(X509Certificate certificate) throws Exception
    {
        Collection<List<?>> subjectAlternativeNames = certificate.getSubjectAlternativeNames();
        if(subjectAlternativeNames != null)
        {
            for(List<?> subjectAlternativeName : subjectAlternativeNames)
            {
                if(Integer.valueOf(DnsSubjectAlternativeNameType).equals(subjectAlternativeName.get(0)))
                {
                    String dnsName = subjectAlternativeName.get(1).toString().toLowerCase(Locale.ROOT);
                    if(dnsName.equals(MetadataDnsSuffix.substring(1)) || dnsName.endsWith(MetadataDnsSuffix))
                    {
                        return;
                    }
                }
            }
        }

        throw new SecurityException("Signer certificate is not valid for Azure IMDS");
    }

    private static void PrintCertificatePath(PKIXCertPathBuilderResult certificatePath)
    {
        for(java.security.cert.Certificate pathCertificate : certificatePath.getCertPath().getCertificates())
        {
            PrintCertificate((X509Certificate)pathCertificate);
        }

        PrintCertificate(certificatePath.getTrustAnchor().getTrustedCert());
    }

    private static void PrintCertificate(X509Certificate certificate)
    {
        System.out.println("Issuer: " + certificate.getIssuerX500Principal().toString());
        System.out.println("Subject: " + certificate.getSubjectX500Principal().toString());
        System.out.println("Valid until: " + certificate.getNotAfter().toString());
    }

    private static PKIXCertPathBuilderResult ValidateCertificatePath(
        X509Certificate signerCertificate,
        Store<X509CertificateHolder> certificateStore,
        JcaX509CertificateConverter converter) throws Exception
    {
        List<X509Certificate> certificates = new ArrayList<X509Certificate>();
        for(X509CertificateHolder certificateHolder : certificateStore.getMatches(null))
        {
            certificates.add(converter.getCertificate(certificateHolder));
        }

        Set<TrustAnchor> trustAnchors = new HashSet<TrustAnchor>();
        TrustManagerFactory trustManagerFactory = TrustManagerFactory.getInstance(
            TrustManagerFactory.getDefaultAlgorithm());
        trustManagerFactory.init((KeyStore)null);
        for(TrustManager trustManager : trustManagerFactory.getTrustManagers())
        {
            if(trustManager instanceof X509TrustManager)
            {
                for(X509Certificate acceptedIssuer : ((X509TrustManager)trustManager).getAcceptedIssuers())
                {
                    trustAnchors.add(new TrustAnchor(acceptedIssuer, null));
                }
            }
        }

        X509CertSelector signerSelector = new X509CertSelector();
        signerSelector.setCertificate(signerCertificate);
        PKIXBuilderParameters parameters = new PKIXBuilderParameters(trustAnchors, signerSelector);
        parameters.addCertStore(CertStore.getInstance(
            "Collection", new CollectionCertStoreParameters(certificates)));
        parameters.setRevocationEnabled(true);
        return (PKIXCertPathBuilderResult)CertPathBuilder.getInstance("PKIX").build(parameters);
    }
    
    private static String QueryInstanceEndpoint()
    {
        return QueryImds(InstanceEndpoint, "2023-07-01");       
    }
    
    private static String QueryAttestedEndpoint()
    {
        String nonce = "nonce=" + NonceValue;
        return QueryImds(AttestedEndpoint, "2023-07-01", nonce);
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
            HttpURLConnection con = (HttpURLConnection) url.openConnection(Proxy.NO_PROXY);
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
