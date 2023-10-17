## Commandbox Proxy
Command box proxy is a way to communicate with a running command box instance with a thin client that connects over a socket protocol to allow you to communicate and run command box functions, without having to start up a brand new instance of command box

To start the socket server, we have packaged it in a task runner
```
box task run socket
```

To start the client server, we created a shell script to interact with a java file
```
# may need to make the shell script execuatble
chmod +x box-proxy
# start the proxy
./box-proxy.sh
```