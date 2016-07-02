-- A Json Reader and Writer implemented in Lua-5.3
-- Copyright (c) 2016 sysu_AT < owtotwo@163.com >

-- Using GNU Lesser General Public License (LGPL)
-- [ http://www.gnu.org/licenses/lgpl-3.0.en.html ] for License Text
-- [ https://en.wikipedia.org/wiki/MD5 ] for Algorithm Detials


-- API --
-- Reader : json.parse('["a", 123, -123.45e-67, true, null]')
-- Writer : json.stringify({"a", 123, -123.45e-67, true, null})
local json = {}

-- jsondata for parser
local jsondata = {}
jsondata.__index = jsondata

function jsondata:new(text)
	local t = { text = assert(text), index = 1, last = #text }
	return setmetatable(t, self)
end

function jsondata:cur()
	return self.text:sub(self.index, self.index)
end

function jsondata:move(offset)
	offset = offset or 1
	self.index = self.index + offset 
	return assert(self.index <= self.last + 1 and self.index >= 1)
end

function jsondata:look()
	local c = self:cur()
	while c == ' ' or c == '\t' or c == '\n' do
		self:move()
		c = self:cur()
	end
	return c
end

function jsondata:take(char)
	local ret = assert(self:look() == char, "Expect a '" .. char .. "'")
	self:move()
	return ret
end

function jsondata:match(pattern)
	local result = string.match(self.text, '^' .. pattern, self.index)
	self:move(#result)
	return result
end

jsondata.escape_from = {['"'] = '"', ['\\'] = '\\', ['/'] = '/',
	['b'] = '\b', ['f'] = '\f', ['n'] = '\n', ['r'] = '\r', 
	['t'] = '\t'}
	
jsondata.escape_to = {['"'] = '\\"', ['\\'] = '\\\\', ['/'] = '\\/',
	['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', 
	['\t'] = '\\t'}



-- aux functions for parser

function json.parse_string(t)
	local chars = {}
	t:take('"')
	while true do
		local c = t:cur()
		if c == '"' then break end
		if c == '\\' then
			t:move()
			if t:cur() == 'u' then
				t:move(5) -- should be modified
				-- TODO
			else
				table.insert(chars, assert(jsondata.escape_from[t:cur()]))
				t:move()
			end
		else
			table.insert(chars, c)
			t:move()
		end
	end
	t:take('"')
	return table.concat(chars)
end

function json.parse_number(t)
	local first = t.index
	if t:look() == '-' then t:move() end
	if t:cur() == '0' then t:move() else t:match("[1-9][0-9]*") end
	if t:cur() == '.' then t:match("%.[0-9]+") end
	if t:cur():lower() == 'e' then t:move()
		if t:cur() == '+' or t:cur() == '-' then t:move() end
		t:match("[0-9]+")
	end
	return (assert(tonumber(t.text:sub(first, t.index - 1)), 
		"Expect a valid Number")) -- prevent from tail calling
end

function json.parse_object(t)
	local obj = {}
	t:take('{')
	if t:look() ~= '}' then
		while true do
			local key = json.parse_string(t)
			t:take(':')
			obj[key] = json.parse_value(t)
			if t:look() == '}' then break end
			t:take(',')
		end
	end
	t:take('}')
	return obj
end

function json.parse_array(t)
	local arr = { [0] = true } -- identify the array type
	t:take('[')
	if t:look() ~= ']' then
		while true do
			table.insert(arr, json.parse_value(t))
			if t:look() == ']' then break end
			t:take(',')
		end
	end
	t:take(']')
	return arr
end

function json.parse_value(t)
	local c = t:look()
	if c == '{' then return json.parse_object(t) end
	if c == '[' then return json.parse_array(t) end
	if c == '"' then return json.parse_string(t) end
	if c == 't' then
		assert(t:match("true"), "Expect 'true'")
		return true
	end
	if c == 'f' then
		assert(t:match("false"), "Expect 'false'")
		return false
	end
	if c == 'n' then
		assert(t:match("null"), "Expect 'null'")
		return nil
	end
	return json.parse_number(t)
end


-- aux functions for serializer

function json.stringify_string(obj)
	return '"' .. obj:gsub("[\"\\/\b\f\n\r\t]", jsondata.escape_to) .. '"'
end

function json.stringify_value(obj, layout, indent)

	layout = layout or 1
	indent = indent or "    " -- four space by default

	if type(obj) == 'number' then
		return tostring(obj)
	elseif type(obj) == 'boolean' then
		return tostring(obj)
	elseif type(obj) == 'string' then
		return json.stringify_string(obj)
	elseif type(obj) == 'function' then
		error("function can not be serialized in json")
	elseif type(obj) == 'userdata' then
		error("userdata can not be serialized in json")
	elseif type(obj) == 'thread' then
		error("thread can not be serialized in json")
	elseif type(obj) == 'table' then

		local ret = {}
		local first_in = true

		if obj[0] == true then -- Array
			table.insert(ret, '[')
			for _, v in ipairs(obj) do
				if not first_in then
					table.insert(ret, ",\n")
				else
					first_in = false
					table.insert(ret, "\n")
				end
				table.insert(ret, string.rep(indent, layout)
					.. json.stringify_value(v, layout + 1))
			end
			if not first_in then 
				table.insert(ret, "\n" .. string.rep(indent, layout - 1))
			end
			table.insert(ret, "]")
		else -- Object
			table.insert(ret, '{')
			for k, v in pairs(obj) do
				if not first_in then
					table.insert(ret, ",\n")
				else
					first_in = false
					table.insert(ret, "\n")
				end
				table.insert(ret, string.rep(indent, layout)
					.. json.stringify_string(k, layout + 1) .. ': '
					.. json.stringify_value(v, layout + 1))
			end
			if not first_in then 
				table.insert(ret, "\n" .. string.rep(indent, layout - 1))
			end
			table.insert(ret, "}")
		end

		return table.concat(ret)
		
	else -- nil type
		return "null" -- "nil" expected
	end
end



------------------------- API --------------------------

--
-- FROM: string, number, object, array, true or false, null
-- TO: string, number, table[string], table[number], boolean, nil
-- 
function json.parse(text)
	local t = jsondata:new(text)
	if t:look() == '{' then return json.parse_object(t)
	elseif t:look() == '[' then return json.parse_array(t)
	else error("Not an Object or an Array") end
end

function json.stringify(obj)
	return json.stringify_value(obj)
end

return json
