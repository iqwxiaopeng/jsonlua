# **jsonlua** #
A [JSON](http://json.org/) Reader and Writer implemented in Lua-5.3 .  
__*Copyright (c) 2016 sysu_AT < owtotwo@163.com >*__  


## How to Use ##

Just use `json.lua` for your project and require this file.  

```
json = require "json"

local str = [[
    {
        "project name" : "jsonlua",
        "author" : "sysu_AT",
        "array" : [1, 2.34e-56, "string", true, false, null],
        "object" : { "key" : "value" }
    }
]]

local obj = json.parse(str) -- a lua table
print(json.stringify(obj)) -- same as str

```
*Notice that the order of items in lua table parsed from JSON Object is uncertain.*

## License ##
* GNU Lesser General Public License ([LGPL](LICENSE))  
  http://www.gnu.org/licenses/lgpl-3.0.en.html
