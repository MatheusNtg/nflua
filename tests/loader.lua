local lunatik = require'lunatik'
local memory  = require'memory'
local session = lunatik.session()
local kscript = [[
	function match(packet)
		netlink.send'Oh hey, a match have been occurred'
	end
]]
local nflua = session:newstate'nflua'
nflua:dostring(kscript)

local recv = nflua:receive()
print(memory.tostring(recv))

print("Entrei aqui ou qua?")

err = nflua:close()

print(err)

session:close()
