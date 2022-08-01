# Package

version       = "0.1.0"
author        = "HugoGranstrom"
description   = "A CLOG-inspired POC in Nim"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.6.6"
requires "ws"
requires "nimhttpd"
requires "jsony"

task buildClient, "Builds the client.js":
  exec "nim js -d:danger -o:example/client/client.js example/client/client.nim"

task runAll, "Builds client and starts server":
  exec "nim js -d:danger -o:example/client/client.js example/client/client.nim"
  exec "nim r --mm:orc example/server.nim"
