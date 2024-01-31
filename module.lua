local resmap = {}

              local friendlyHttpStatus={['200']='OK',['201']='Created',['202']='Accepted',['203']='Non-AuthoritativeInformation',['204']='NoContent',['205']='ResetContent',['206']='PartialContent',['300']='MultipleChoices',['301']='MovedPermanently',['302']='Found',['303']='SeeOther',['304']='NotModified',['305']='UseProxy',['306']='Unused',['307']='TemporaryRedirect',['400']='BadRequest',['401']='Unauthorized',['402']='PaymentRequired',['403']='Forbidden',['404']='NotFound',['405']='MethodNotAllowed',['406']='NotAcceptable',['407']='ProxyAuthenticationRequired',['408']='RequestTimeout',['409']='Conflict',['410']='Gone',['411']='LengthRequired',['412']='PreconditionRequired',['413']='RequestEntryTooLarge',['414']='Request-URITooLong',['415']='UnsupportedMediaType',['416']='RequestedRangeNotSatisfiable',['417']='ExpectationFailed',['418']='I\'mateapot',['429']='TooManyRequests',['500']='InternalServerError',['501']='NotImplemented',['502']='BadGateway',['503']='ServiceUnavailable',['504']='GatewayTimeout',['505']='HTTPVersionNotSupported'}

              local lastReset = os.time()

              local dataSent = 0

              function updateLastReset()
                local current = os.time()
                if current - lastReset > 30 then
                  lastReset = current
                  dataSent = 0
                end
              end

              function table_to_string(tbl)
                  local result = "{"
                  for k, v in pairs(tbl) do
                      -- Check the key type (ignore any numerical keys - assume its an array)
                      if type(k) == "string" then
                          result = result..""..k.."".."="
                      end

                      -- Check the value type
                      if type(v) == "table" then
                          result = result..table_to_string(v)
                      elseif type(v) == "boolean" then
                          result = result..tostring(v)
                      else
                          result = result.."\""..v.."\""
                      end
                      result = result..","
                  end
                  -- Remove leading commas from the result
                  if result ~= "" then
                      result = result:sub(1, result:len()-1)
                  end
                  return result.."}"
              end

              -- local count = 1
              function envoy_on_request(request_handle)
                  -- request_handle:headers():add("foo", count)
                  -- count = count + 1

                  if dataSent > 30000000 then
                    return
                  end
                  
                  local res = {}
                  local headers = request_handle:headers()
                  local headersMap = {}
                  for key, value in pairs(headers) do
                      headersMap[key] = value
                  end
                  res["requestHeaders"] = headersMap
                  local requestBody = ""
                  for chunk in request_handle:bodyChunks() do
                      if (chunk:length() > 0) then
                      requestBody = requestBody .. chunk:getBytes(0, chunk:length())
                      end
                  end
                  res["requestPayload"] = requestBody
                  local streamInfo = request_handle:streamInfo()
                  res["type"] = streamInfo:protocol()
                  res["path"] = request_handle:headers():get(":path")
                  res["method"] = request_handle:headers():get(":method")
                  res["ip"] = "0.0.0.0"
                  res["akto_vxlan_id"] = "123"
                  res["is_pending"] = "false"
                  res["source"] = "OTHER"
                  res["timestamp"] = request_handle:timestampString()
                  -- local connection = request_handle:connection()
                  -- print("req conn: ", tostring(connection))
                  -- local streamInfo = request_handle:streamInfo()
                  -- print("reqinfo: ", streamInfo:downstreamLocalAddress(), streamInfo:downstreamDirectRemoteAddress(), streamInfo:downstreamRemoteAddress(), streamInfo:dynamicMetadata(), streamInfo:requestedServerName())
                  local key = tostring(math.random(10000))
                  local ini = request_handle:streamInfo():dynamicMetadata():get("envoy.filters.http.lua")
                  if ini ~=null then 
                    print("reqdd: ", table_to_string())
                  end
                  request_handle:streamInfo():dynamicMetadata():set("envoy.filters.http.lua", "akto-key",key)
                  resmap[key] = res
                  -- print("traffic req: ", table_to_string(resmap))
                  -- for key, value in pairs(streamInfo:dynamicMetadata()) do
                  --  print("reqdd: ",key, value)
                  -- end
              end
              
              function envoy_on_response(response_handle)
                  -- response_handle:headers():add("foo", count)
                  -- count = count + 1
                  updateLastReset()
                  local temp = response_handle:streamInfo():dynamicMetadata():get("envoy.filters.http.lua")
                  if temp == nil then
                    return 
                  end
                  local key = temp["akto-key"]
                  if key == nil then 
                    return 
                  end
                  local res = resmap[key]
                  -- print("res: ", key, temp)

                  if res == nil then
                    return
                  end

                  local headers = response_handle:headers()
                  local headersMap = {}
                  for key, value in pairs(headers) do
                      headersMap[key] = value
                  end
                  res["responseHeaders"] = headersMap
                  local responseBody = ""
                  for chunk in response_handle:bodyChunks() do
                      if (chunk:length() > 0) then
                      responseBody = responseBody .. chunk:getBytes(0, chunk:length())
                      end
                  end
                  res["responsePayload"] = responseBody
                  res["statusCode"] = response_handle:headers():get(":status")
                  res["status"] = friendlyHttpStatus[response_handle:headers():get(":status")]

                  print("traffic res: ", table_to_string(res))
                  -- response_handle:logInfo("traffic res: ", table_to_string(res))
                  -- local connection = response_handle:connection()
                  -- print("res conn: ", tostring(connection))
                  -- local streamInfo = response_handle:streamInfo()
                  -- print("resinfo: ", streamInfo:downstreamLocalAddress(), streamInfo:downstreamDirectRemoteAddress(), streamInfo:downstreamRemoteAddress(), streamInfo:dynamicMetadata(), streamInfo:requestedServerName())
                  
                  -- for key, value in pairs(streamInfo:dynamicMetadata()) do
                  -- print("resdd: ", table_to_string(response_handle:streamInfo():dynamicMetadata():get("envoy.filters.http.lua")))
                  -- end

                  resmap[key] = nil
                  dataSent = dataSent + string.len(table_to_string(res))
                  print("dataSent: ", dataSent)
              end

              -- print("traffic: ", table_to_string(res))
