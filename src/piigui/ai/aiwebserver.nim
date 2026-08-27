import std/[asynchttpserver, asyncdispatch, json, strutils]

proc cb(req: Request) {.async.} =
  echo req.reqMethod, " ", req.url.path
  let headers = newHttpHeaders([("Content-Type", "application/json")])

  # --- NEW: Dynamic Manifest Endpoint ---
  if req.url.path == "/manifest" and req.reqMethod == HttpGet:
    # We define the commands, their descriptions, and exact arguments in JSON
    let manifest = %*{
      "available_commands": [
        {
          "name": "restart_process",
          "description": "Restarts a target system process. Use this if a service is lagging or unresponsive.",
          "required_args": ["process_name"]
        },
        {
          "name": "backup_database",
          "description": "Triggers a full snapshot backup of the application state.",
          "required_args": []
        },
        {
          "name": "adjust_log_level",
          "description": "Changes system logging severity dynamically.",
          "required_args": ["level"] # e.g. "debug", "info", "error"
        }
      ]
    }
    await req.respond(Http200, $manifest, headers)

  # --- UPDATED: POST /command to handle dynamic payloads ---
  elif req.url.path == "/command" and req.reqMethod == HttpPost:
    try:
      let jsonBody = parseJson(req.body)
      let command = jsonBody["command"].getStr()
      
      # Extract optional arguments payload if sent by the AI
      let args = if jsonBody.hasKey("args"): jsonBody["args"] else: %*{}
      
      # Execute your logic based on the dynamic command name
      echo "AI Executed Dynamic Command -> [", command, "] with args: ", $args
      
      # --- Add your backend logic routines here ---
      # if command == "restart_process": ...
      
      let resJson = %*{"success": true, "executed": command, "args_received": args}
      await req.respond(Http200, $resJson, headers)
    except:
      await req.respond(Http400, $(%*{"error": "Invalid payload structure"}), headers)

  else:
    await req.respond(Http404, $(%*{"error": "Route not found"}), headers)

proc main() {.async.} =
  let server = newAsyncHttpServer()
  server.listen(Port(55501))
  echo "Dynamic Nim Server running on http://localhost:55501"
  while true:
    if server.shouldAcceptRequest(): await server.acceptRequest(cb)
    else: await sleepAsync(1)

waitFor main()
