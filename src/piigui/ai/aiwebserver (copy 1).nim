import std/[asynchttpserver, asyncdispatch, json, strutils]

# Request handler function
proc cb(req: Request) {.async.} =
  # Log incoming requests to the console
  echo req.reqMethod, " ", req.url.path

  # Route: GET /status
  if req.url.path == "/status" and req.reqMethod == HttpGet:
    let headers = newHttpHeaders([("Content-Type", "application/json")])
    let body = %*{"status": "running", "message": "Minimal Nim API is active"}
    await req.respond(Http200, $body, headers)

  # Route: POST /command
  elif req.url.path == "/command" and req.reqMethod == HttpPost:
    let headers = newHttpHeaders([("Content-Type", "application/json")])
    try:
      # Parse the request body
      let jsonBody = parseJson(req.body)
      let command = jsonBody["command"].getStr()
      
      # Execute or log your program logic here
      echo "AI triggered action: ", command
      
      let resJson = %*{"success": true, "executed": command}
      await req.respond(Http200, $resJson, headers)
    except:
      let errJson = %*{"error": "Invalid or missing JSON payload"}
      await req.respond(Http400, $errJson, headers)

  # Catch-all: 404 Not Found
  else:
    let headers = newHttpHeaders([("Content-Type", "application/json")])
    let errJson = %*{"error": "Route not found"}
    await req.respond(Http404, $errJson, headers)

# Main entry point
proc main() {.async.} =
  let server = newAsyncHttpServer()
  let port = 55501
  
  echo "Server starting on http://localhost:", port
  
  # Start listening and serving requests asynchronously
  server.listen(Port(port))
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      await sleepAsync(1)

# Run the async loop
waitFor main()
