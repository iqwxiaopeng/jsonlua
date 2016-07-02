-- json.lua

json = {}

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

jsondata.escapes = {['"'] = '"', ['\\'] = '\\', ['/'] = '/',
	['b'] = '\b', ['f'] = '\f', ['n'] = '\n', ['r'] = '\r',
	['t'] = '\t'}

--
-- FROM: string, number, object, array, true or false, null
-- TO: string, number, table[string], table[number], boolean, nil
-- 
function json.parse(text)
	local t = jsondata:new(text)
	return assert(json.parse_object(t) or json.parse_array(t), 
		"Not an Object or an Array")
end

function json.stringify(obj)
	-- TODO
end


-- aux functions

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
				table.insert(chars, assert(jsondata.escapes[t:cur()]))
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
	
	local arr = {}
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

local tmp = json.parse_number(jsondata:new("   -123.45e+16  "))

tmp = json.parse_string(jsondata:new("\"hello\\n world\""))


local file = assert(io.open("data.json"))
tmp = json.parse(file:read('a'))
serialize = require "serialize"
print(serialize(tmp))

return json
