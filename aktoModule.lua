local cjson = require 'cjson'

local friendlyHttpStatus={['200']='OK',['201']='Created',['202']='Accepted',['203']='Non-AuthoritativeInformation',['204']='NoContent',['205']='ResetContent',['206']='PartialContent',['300']='MultipleChoices',['301']='MovedPermanently',['302']='Found',['303']='SeeOther',['304']='NotModified',['305']='UseProxy',['306']='Unused',['307']='TemporaryRedirect',['400']='BadRequest',['401']='Unauthorized',['402']='PaymentRequired',['403']='Forbidden',['404']='NotFound',['405']='MethodNotAllowed',['406']='NotAcceptable',['407']='ProxyAuthenticationRequired',['408']='RequestTimeout',['409']='Conflict',['410']='Gone',['411']='LengthRequired',['412']='PreconditionRequired',['413']='RequestEntryTooLarge',['414']='Request-URITooLong',['415']='UnsupportedMediaType',['416']='RequestedRangeNotSatisfiable',['417']='ExpectationFailed',['418']='I\'mateapot',['429']='TooManyRequests',['500']='InternalServerError',['501']='NotImplemented',['502']='BadGateway',['503']='ServiceUnavailable',['504']='GatewayTimeout',['505']='HTTPVersionNotSupported'}

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

local function producer(message)
    local config = require 'rdkafka.config'.create()
    local kafkaServer = os.getenv("AKTO_KAFKA_IP")
    print("traffic res: ", message)
    if kafkaServer~=nil then
        config["statistics.interval.ms"] = "100"
        config["bootstrap.servers"] = kafkaServer
        config:set_delivery_cb(function (payload, err) print("Delivery Callback '"..payload.."'") end)
        config:set_stat_cb(function (payload) print("Stat Callback '"..payload.."'") end)

        local producer = require 'rdkafka.producer'.create(config)
        local topic_config = require 'rdkafka.topic_config'.create()
        topic_config["auto.commit.enable"] = "true"

        local topic = require 'rdkafka.topic'.create(producer, "akto.api.logs", topic_config)

        local KAFKA_PARTITION_UA = -1
        producer:produce(topic, KAFKA_PARTITION_UA, message)

        while producer:outq_len() ~= 0 do
            producer:poll(10)
        end
    end
end

function hash(str)
    h = 5381;

    for c in str:gmatch"." do
        h = ((h << 1) + h) + string.byte(c)
    end
    h = h%10000000000
    return h
end

M = {}

function M.sendToAkto()

    local resmap = {}
    local lastReset = os.time()
    local dataSent = 0

    function updateLastReset()
      local current = os.time()
      if current - lastReset > 30 then
        lastReset = current
        dataSent = 0
      end
    end

    function envoy_on_request(request_handle)

        if dataSent > 30000000 then
            return
        end

        local res = {}
        local headers = request_handle:headers()
        local headersMap = {}
        for key, value in pairs(headers) do
            headersMap[key] = value
        end
        res["requestHeaders"] = cjson.encode(headersMap)
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
        local address = request_handle:streamInfo():downstreamLocalAddress()
        res["akto_vxlan_id"] = tostring(hash(address))
        res["is_pending"] = "false"
        res["source"] = "OTHER"
        res["time"] = tostring(math.floor(tonumber(request_handle:timestampString())/1000))
        res["akto_account_id"] = "1000000"
        local key = tostring(math.random(10000))
        print("request stream info: ", request_handle:streamInfo():downstreamLocalAddress() , request_handle:streamInfo():downstreamDirectRemoteAddress(), request_handle:streamInfo():downstreamRemoteAddress(), request_handle:streamInfo():requestedServerName())
        request_handle:streamInfo():dynamicMetadata():set("envoy.filters.http.lua", "akto-key",key)
        resmap[key] = res
    end
    
    function envoy_on_response(response_handle)
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
        if res == nil then
            return
        end

        local headers = response_handle:headers()
        local headersMap = {}
        for key, value in pairs(headers) do
            headersMap[key] = value
        end
        res["responseHeaders"] = cjson.encode(headersMap)
        local responseBody = ""
        for chunk in response_handle:bodyChunks() do
            if (chunk:length() > 0) then
            responseBody = responseBody .. chunk:getBytes(0, chunk:length())
            end
        end
        res["responsePayload"] = responseBody
        res["statusCode"] = response_handle:headers():get(":status")
        res["status"] = friendlyHttpStatus[response_handle:headers():get(":status")]

        print("response stream info: ", response_handle:streamInfo():downstreamLocalAddress() , response_handle:streamInfo():downstreamDirectRemoteAddress(), response_handle:streamInfo():downstreamRemoteAddress(), response_handle:streamInfo():requestedServerName())
        resmap[key] = nil
        local messageEncoded = cjson.encode(res)
        dataSent = dataSent + string.len(messageEncoded)
        print("dataSent: ", dataSent)
        producer(messageEncoded)
    end

end

return M