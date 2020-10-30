--
-- Copyright (C) 2017-2019  CUJO LLC
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program; if not, write to the Free Software Foundation, Inc.,
-- 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
--

local lunatik = require'lunatik'
local memory = require'memory'

local driver = require'tests.driver'
local network = require'tests.network'
local util = require'tests.util'

local function argerror(arg, msg, fname)
	fname = fname or '?'
	local l = string.format("bad argument #%d to '%s' (%s)", arg, fname, msg)
--	print(l)
	return l
end

local function defaults(cmd)
	if cmd == 'newstate' then
		return 'st', lunatik.defaultmaxallocbytes
	elseif cmd == 'getstate' then
		return 'st'
	else
		return
	end
end


-- Verifica se um socket socktype está fechado utilizando o comando cmd
-- Caso não esteja, fecha ele e verifica se, ao tentar executar um comando cmd
-- retorna um erro (o que deveria acontecer) e verifica também, se o erro executado é 'socket closed'
local function socketclosed(socktype, cmd, ...)
	local s = assert(lunatik[socktype]())
	s:close()
	local ok, err = pcall(s[cmd], s, ...)
	assert(ok == false)
	assert(err == argerror(1, 'socket closed'))
end

local cases = {
	session = {
		'newstate',
		'list',
		'close',
		'getstate',
		'getfd'
	}
}

for socktype, cmds in pairs(cases) do
	for _, cmd in ipairs(cmds) do
		local t = 'socketclosed ' .. socktype .. ' ' .. cmd
		driver.test(t, socketclosed, socktype, cmd, defaults(socktype, cmd))
	end
end

-- Esse teste não se aplica à lib do lunatik pela forma como ela funciona
-- isto é, não é necessário receber uma resposta para realizar outra operação
-- (coisa que é necessária no NFLua). Por outro lado, certas operações não podem ser
-- realizadas se um determinado socket estiver fechado, como é o caso das operações
-- que estão baseadas nos estados, pois, para estas existirem, uma determinada sessão
-- precisa existir. (Então para esse caso, rever como fazer o teste)

local function doublesendtest()
	local function doublesend(socktype, cmd, ...)
		local s = assert(nflua[socktype]())
		assert(s[cmd](s, ...) == true)
		local ok, err = s[cmd](s, ...)
		assert(ok == nil)
		assert(err == 'Operation not permitted')
	end

	local cases = {
		control = {'create', 'destroy', 'execute', 'list'},
	}

	for socktype, cmds in pairs(cases) do
		for _, cmd in ipairs(cmds) do
			local t = 'doublesend ' .. socktype .. ' ' .. cmd
			driver.test(t, doublesend, socktype, cmd, defaults(socktype, cmd))
		end
	end
end

-- Essa função realiza testes na abertura de sockets de controle
-- os testes específicos que estão aqui não são necessários para
-- a lib do lunatik, que cuida de coisas como portas automatica
-- mente, por outro lado, é necessário realizar testes relacionados
-- a falhas na criação de sockets de controle, tanto de estado quanto
-- de sessão

local function openclosetest_notused()
	local function openclose(socktype)
		local s = assert(nflua[socktype]())
		assert(type(s) == 'userdata')
		assert(s:close() == true)

		s = assert(nflua[socktype](123))
		local ok, err = nflua[socktype](123)
		assert(ok == nil)
		assert(err == 'Address already in use')
		s:close()

		local fname = 'nflua.' .. socktype
		local ok, err = pcall(nflua[socktype], 2 ^ 31)
		assert(ok == false)
		assert(err == argerror(1, "must be in range [0, 2^31)", fname))

		local ok, err = pcall(nflua[socktype], 'a')
		assert(ok == false)
		assert(err, argerror(1, "must be integer or nil" == fname))
	end

	for _, socktype in ipairs{'control', 'data'} do
		driver.test('openclose ' .. socktype, openclose, socktype)
	end
end

-- Essa função só realiza o teste no file descriptor do socket
-- Seria realmente necessário oferecer isso ao usuário?

local function getfd_notusedyet()
	local function getfd(socktype)
		local fd = nil
		if socktype == 'session' then
			session = session or assert(lunatik.session())
		elseif socktype == 'state' then
			session = session or assert(lunatik.session())
			state = session:newstate(defaults(socktype))
			fd = state:getfd()
		elseif socktype == 'data' then
			print('Data')
		end
	end

	for _, socktype in ipairs{'session', 'state', 'data', ''} do
		driver.test('getfd ' .. socktype, getfd, socktype)
	end

end

-- A lib do lunatik não oferece suporte ao acesso do pid relacionado
-- à um socket
local function getpid_notused()
	local function getpid(socktype)
		local s = assert(nflua[socktype]())
		local pid = s:getpid()
		assert(type(pid) == 'number')
		assert(pid & (2 ^ 31) == 2 ^ 31)
		s:close()

		s = assert(nflua[socktype](123))
		assert(s:getpid() == 123)
	end

	for _, socktype in ipairs{'control', 'data'} do
		driver.test('getpid ' .. socktype, getpid, socktype)
	end
end

local ok, session = pcall(lunatik.session)

if not ok then
	 print(session)
end

driver.test('session:create', function()
	-- Testing a normal creation
	local s = assert(session:newstate(defaults('newstate')))

	-- Testing creation of a state that already exists
	session:newstate(defaults('newstate'))
	driver.matchdmesg(3, 'state already exists: st')

	-- Testing creation of a state with maxalloc less than the allowed
	assert(not (session:newstate('test', 1)))

	-- Testing creation of a state with a really long name
	local ok, err = pcall(session.newstate, session, 'herewehaveareallyreallybignamethatshouldnotworktoourcasesoletseeit')
	assert(ok == false)
	assert(err == argerror(2, 'name too long'))

	s:close()
end)

os.exit()

driver.test('session:getstate', function()
	assert(type(session:getstate()) == 'userdata')
end)

driver.test('control.create', function()
	local s = assert(nflua.control())

	driver.run(s, 'create', 'st1')
	local l = driver.run(s, 'list')
	assert(l[1].name == 'st1')
	assert(l[1].maxalloc == nflua.defaultmaxallocbytes)
	driver.run(s, 'destroy', 'st1')

	driver.run(s, 'create', 'st2', 128 * 1024)
	local l = driver.run(s, 'list')
	assert(l[1].name == 'st2')
	assert(l[1].maxalloc == 128 * 1024)

	driver.failrun(s, 'state already exists: st2', 'create', 'st2')
	driver.run(s, 'destroy', 'st2')

	driver.run(s, 'create', 'st2')
	driver.run(s, 'destroy', 'st2')

	local n = nflua.maxstates
	for i = 1, n do
		driver.run(s, 'create', 'st' .. i)
	end
	driver.failrun(s, 'max states limit reached or out of memory',
		'create', 'st' .. (n + 1))

	local name = string.rep('a', 64)
	local ok, err = pcall(s.create, s, name)
	assert(ok == false)
	assert(err == argerror(2, 'name too long'))
end)

driver.test('allocation size', function()
	local s = assert(nflua.control())

	local code = 'string.rep("a", 32 * 1024)'

	driver.run(s, 'create', 'st1')
	driver.failrun(s, 'could not execute / load data!',
		'execute', 'st1', code)

	driver.run(s, 'create', 'st2', 128 * 1024)
	driver.run(s, 'execute', 'st2', code)
end)

driver.test('control.destroy', function()
	local s = assert(nflua.control())

	driver.run(s, 'create', 'st')
	driver.run(s, 'destroy', 'st')
	assert(#driver.run(s, 'list') == 0)

	driver.failrun(s, 'could not destroy lua state', 'destroy', 'st')
end)

driver.test('control.destroy and iptables', function()
	local s = assert(nflua.control())

	local rule = network.toserver .. ' -m lua --state st --function f'

	driver.run(s, 'create', 'st')
	util.assertexec('iptables -A %s', rule)
	driver.failrun(s, 'could not destroy lua state', 'destroy', 'st')
	assert(#driver.run(s, 'list') == 1)

	util.assertexec('iptables -D %s', rule)
	driver.run(s, 'destroy', 'st')
	assert(#driver.run(s, 'list') == 0)
end)

driver.test('control.execute', function()
	local s = assert(nflua.control())

	driver.run(s, 'create', 'st')
	local token = util.gentoken()
	local code = string.format('print(%q)', token)
	driver.run(s, 'execute', 'st', code)
	driver.matchdmesg(4, token)

	token = util.gentoken()
	code = string.format('print(%q)', token)
	driver.run(s, 'execute', 'st', code, 'test.lua')
	driver.matchdmesg(4, token)

	driver.run(s, 'destroy', 'st')
	driver.failrun(s, 'lua state not found', 'execute', 'st', 'print()')

	local bigstring = util.gentoken(64 * 1024)
	local code = string.format('print(%q)', bigstring)
	local ok, err = s:execute('st1', code)
	assert(ok == nil)
	assert(err == 'Invalid argument')
end)

driver.test('control.list', function()
	local s = assert(nflua.control())

	local function statename(i)
		return string.format('st%04d', i)
	end

	local n = 10
	for i = 1, n do
		driver.run(s, 'create', statename(i))
	end

	local l = driver.run(s, 'list')
	assert(#l == n)
	table.sort(l, function(a, b) return a.name < b.name end)
	for i = 1, n do
		assert(l[i].name == statename(i))
	end

	for i = 1, n do
		driver.run(s, 'destroy', statename(i))
	end

	assert(#driver.run(s, 'list') == 0)
end)

driver.test('control.receive', function()
	local s = assert(nflua.control())

	local ok, err = s:receive()
	assert(ok == nil)
	assert(err == 'Operation not permitted')
end)

driver.test('data.send', function()
	local c = assert(nflua.control())
	driver.run(c, 'create', 'st')
	driver.run(c, 'execute', 'st', [[
		function __receive_callback(pid, data)
			netlink.send(pid, nil, data)
		end
	]])

	local s = assert(nflua.data())

	local token = util.gentoken()
	assert(s:send('st', memory.create(token)) == true)
	local buff, state = driver.datareceive(s)
	assert(buff == token)
	assert(state == 'st')

	token = util.gentoken(nflua.datamaxsize + 1)
	local ok, err = s:send('st', memory.create(token))
	assert(ok == nil)
	assert(err == 'Operation not permitted')

	local ok, err = pcall(s.send, s, 'st', 0)
	assert(ok == false)
	assert(err == argerror(3, 'memory expected, got number'))
end)

driver.test('data.receive', function()
	local c = assert(nflua.control())
	local s = assert(nflua.data())
	driver.run(c, 'create', 'st', 256 * 1024)

	local ok, err = pcall(s.receive, s, 0, 0)
	assert(ok == false)
	assert(err == argerror(2, 'memory expected, got number'))

	local code = string.format([[
		netlink.send(%d, nil, string.rep('x', 65000))
	]], s:getpid())
	driver.failrun(c, 'could not execute / load data', 'execute', 'st', code)
end)

session:close()
