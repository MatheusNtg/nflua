local lunatik = require'lunatik'
local memory  = require'memory'
local session = lunatik.session()
local kscript = [[
	function match(packet)
		print("Veja o que eu recebi: " .. packet)
		return true	
	end
]]

local function print_states(states)
	print'name\t\tmaxalloc\tcurralloc'
	for _, state in ipairs(states) do
		print(string.format('%-16s%-16d%-16d', state.name,
			state.maxalloc, state.curralloc))
	end
end

local nflua = session:newstate('nflua', 100000)
nflua:dostring(kscript)

--local recv = nflua:receive()
--print(memory.tostring(recv))

-- print("Apagando a regra\n")
-- os.execute("sudo iptables -D OUTPUT 1")

-- nflua:close()
print_states(session:list())

session:close()
