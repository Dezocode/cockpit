#!/usr/bin/env python3
import http.server, socketserver, os, pathlib, sys
os.chdir(sys.argv[1])
portfile = pathlib.Path(sys.argv[2])
class H(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass
httpd = socketserver.TCPServer(("127.0.0.1", 0), H)
portfile.write_text(str(httpd.server_address[1]))
while True:
    httpd.handle_request()
