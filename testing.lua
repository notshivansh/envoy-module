
-- local res = {}

-- function table_to_string(tbl)
--     local result = "{"
--     for k, v in pairs(tbl) do
--         -- Check the key type (ignore any numerical keys - assume its an array)
--         if type(k) == "string" then
--             result = result..""..k.."".."="
--         end

--         -- Check the value type
--         if type(v) == "table" then
--             result = result..table_to_string(v)
--         elseif type(v) == "boolean" then
--             result = result..tostring(v)
--         else
--             result = result.."\""..v.."\""
--         end
--         result = result..","
--     end
--     -- Remove leading commas from the result
--     if result ~= "" then
--         result = result:sub(1, result:len()-1)
--     end
--     return result.."}"
-- end

-- local cjson = require 'cjson'

-- -- function hash(str)
-- --     res["something"] = "something else"

-- --         print(res)
        
-- --         local res2 = {}
        
-- --         res2["sometnin"] = "sedmfod"
        
-- --         res["ss"] = res2
        
-- --         print(cjson.encode(res))
        
-- --         local num = "10029038"
        
-- --         local x = tostring(math.floor(tonumber(num)/1000))
        
-- --         print(num, x , num , x)
-- --     h = 5381;

-- --     for c in str:gmatch"." do
-- --         h = ((h << 5) + h) + string.byte(c)
-- --     end
-- --     h = h%10000000000
-- --     return h
-- -- end

local function lshift(x, by)
    return x * 2 ^ by
  end

  function hash(str)
    h = 5381;
    print(str)
    for c in str:gmatch"." do
        h = lshift(h, 5) + h + string.byte(c)
        h = h%10000000000
        print(h)
    end
    h = h%10000000000
    print(h)
    return h
  end

local str = tostring("10.240.0.92:9092")
local aa = tostring(math.floor(hash(str)))
print(str, aa)

-- function fun()
--     -- local something = l.llss;
--     print("something")
-- end
-- pcall(fun)