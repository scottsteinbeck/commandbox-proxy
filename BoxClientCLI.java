import java.io.*;
import java.net.*;

public class BoxClientCLI {
    public static void main(String[] args) {
        
        String host = "localhost";
        int port = 12345;

        try (Socket socket = new Socket(host, port);
            InputStream socketInput = socket.getInputStream();
            OutputStream socketOutput = socket.getOutputStream();
            InputStream consoleInputStream = System.in
        ) { 
            // Start a thread to read and display data from the server
            Thread serverReaderThread = new Thread(() -> {
                System.out.println("Server.out Started");
                try {
                    int data;
                    while ((data = socketInput.read()) != -1) {
                        
                        //System.out.println(" :%" + new String(new byte[]{(byte) data}) + " %" );
                        System.out.write(data);
                        System.out.flush();
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                }
                System.out.println("Server.out Stopped");
                System.exit(0);
              });
            serverReaderThread.start();

            int chr = 0;
            while ( (chr = consoleInputStream.read()) != -1 ){ 
                socketOutput.write(chr);
                socketOutput.flush();
            }

        } catch (UnknownHostException e) {
            System.err.println("Unknown host: " + host);
        } catch (IOException e) {
            System.err.println("I/O error: " + e.getMessage());
        }
    }
}
