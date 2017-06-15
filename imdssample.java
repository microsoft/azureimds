import java.io.*;
import java.net.*;

public class imdssample {

   public static String sendGet() throws Exception {
	String imdsUrl= "http://169.254.169.254/metadata/instance?api-version=2017-04-02";
		
	URL url = new URL(imdsUrl);
  	HttpURLConnection con = (HttpURLConnection) url.openConnection();
  	con.setRequestMethod("GET");

  	//add request header
  	con.setRequestProperty("Metadata", "True");

  	int responseCode = con.getResponseCode();
  	System.out.println("IMDS URL : " + url);
  	System.out.println("Response Code : " + responseCode);

  	BufferedReader in = new BufferedReader(new InputStreamReader(con.getInputStream()));

  	String line;
  	StringBuffer response = new StringBuffer();
  	while ((line = in.readLine()) != null) {
	  response.append(line);
  	}
  	in.close();
	
	return response.toString();

   }

   public static void main(String[] args) throws Exception {
   	System.out.println("Response: " + sendGet());
	// parse json
	//..
   }
}
