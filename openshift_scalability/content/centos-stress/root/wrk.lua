-- load modules -------------------------------------------------------------------------------------
require("json")

-- global variables ---------------------------------------------------------------------------------
local requests_json = "requests.json"
local addrs_live = 0
local counter = 0
local max_requests = 0	-- maximum request (per thread)
local threads = {}	-- only for done() statistics

-- general functions --------------------------------------------------------------------------------
function to_integer(number)
  return math.floor(tonumber(number) or error("Could not cast '" .. tostring(number) .. "' to number.'"))
end

-- Load URL paths from a file
function load_request_objects_from_file(file)
  local data = {}
  local content

  -- Check if the file exists
  local f=io.open(file,"r")
  if f~=nil then
    content = f:read("*all")

    io.close(f)
  else
    local msg = "load_request_objects_from_file(): unable to open %s\n"
    io.write(msg:format(file))
    os.exit()
  end

  -- Translate Lua value to/from JSON
  data = json.decode.decode(content, strict)

  return data
end

-- wrk() functions ----------------------------------------------------------------------------------
function delay() -- [ms]
  local delay_rand = math.random(delay_min, delay_max)

  return delay_rand
end

function setup(thread)
  local addrs_append = function(host, port)
    for i, addr in ipairs(wrk.lookup(host, port)) do
      if wrk.connect(addr) then
        addrs_live = addrs_live + 1
        return addr
      else
        local msg = "setup(): couldn't connect to %s:%s\n"
        io.write(msg:format(host, port))
        return nil
      end
    end
  end

  if addrs_live == 0 then
    requests_data = load_request_objects_from_file(requests_json)

    -- Check if at least one request was found in the requests_json file
    if #requests_data <= 0 then
      local msg = "setup(): no requests found in %s\n"
      io.write(msg:format(requests_json))
      os.exit()
    end

    for i, req in ipairs(requests_data) do
       -- Use the global host/port defined on the command line if not defined
       if req.host == nil then req.host = wrk.host end
       if req.port == nil then req.port = wrk.port end

       req.addr = addrs_append(req.host, req.port)
    end
  end

  if addrs_live == 0 then
    io.write("setup(): no live hosts to test against\n")
    os.exit()
  end

  local index
  while true do
    index = (counter % #requests_data) + 1 	-- we can have more connections than threads
    req = requests_data[index]
    if req.addr ~= nil then break end
    counter = counter + 1			-- skip unreachable hosts
  end
  counter = counter + 1

  -- set per-thread userdata
  thread:set("thread_id", counter)
  thread:set("host", req.host)
  thread:set("port", req.port)
  thread:set("method", req.method)
  thread:set("path", req.path)
  thread:set("headers", req.headers)
  thread:set("body", req.body)
  thread:set("delay_min", req.delay.min)	-- minimum per thread delay between requests [ms]
  thread:set("delay_max", req.delay.max)	-- maximum per thread delay between requests [ms]

  -- bindings to wrk C code
  thread.addr = req.addr
  thread.host = req.host			-- addition to standard wrk (TLS)
  thread.scheme = req.scheme			-- addition to standard wrk
  thread.src_ip = req.host_from			-- addition to standard wrk

  table.insert(threads, thread)
end

-- redefining wrk.init() --> for testing multiple hosts, faster than "Host" redefinitions in requests
function wrk.init(args)
  requests  = 0	-- how many requests was issued within a thread
  responses = 0	-- how many responses was received within a thread

  if #args >= 1 then
    max_requests = to_integer(args[1])
  end

  math.randomseed(thread_id)			-- generate different random seed for every thread

  wrk.headers["Host"] = host

  if type(init) == "function" then
    init(args)
  end

  local req = wrk.format()
  wrk.request = function()
    return req
  end
end

function request()
  requests = requests + 1

  return wrk.format(method, path, headers, body)
end

function response(status, headers, body, stats)
  responses = responses + 1

  local cont_len = headers["Content-Length"]
  if (cont_len == nil) then
    cont_len = 0
  end

  local msg = "%d,%d,%d,%d,%s %s://%s:%s%s,%d,%d,%d,%d,%d,%d\n"
  local now_us = wrk.time_us()
  local conn_id = stats["conn_id"]			-- file descriptor of the connection for which we received this response
  local conn_reqs = stats["conn_reqs"]			-- number of requests sent over this connection
  local conn_start = stats["conn_start"]		-- time [us] since the Epoch we first tried to establish this connection
  local conn_delay_est = stats["conn_delay_est"]	-- time [us] it took to establish this connection (e.g. TLS establishment); initial connection establishment delay
  local conn_delay_req = stats["conn_delay_req"]	-- time [us] wrk was instructed to wait before sending a request at start_us
  local start_us = stats["start"]			-- time [us] since the Epoch conn_id became writeable and we issued a new request
  local delay = now_us - start_us			-- request latency [us] (conn_delay_est excluded)

  io.write(msg:format(start_us,delay,status,cont_len,method,wrk.thread.scheme,host,port,path,thread_id,conn_id,conn_reqs,conn_start,conn_delay_est,conn_delay_req))
  io.flush()

  -- Stop after max_requests if max_requests is a positive number
  if (max_requests > 0) and (responses >= max_requests) then
    wrk.thread:stop()
  end
end
