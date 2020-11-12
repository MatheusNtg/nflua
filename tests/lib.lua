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

driver.test('session:getstate', function()
	local s = assert(session:newstate(defaults('newstate')))

	local rule = network.toserver .. ' -m lua --state st --function f'

	util.assertexec('iptables -A %s', rule)

	s:put()

	local s = session:getstate('st')
	assert(s:getname() == 'st')

	util.assertexec('iptables -D %s', rule)

	s:close()
end)

driver.test('allocation size', function()
	local s = assert(session:newstate(defaults('newstate')))
	local s2 = assert(session:newstate('test', 128 * 1024))

	local code = 'string.rep("a", 32 * 1024)'

	assert(not s:dostring(code))
	s:close()

	assert(s2:dostring(code))
	s2:close()
end)

driver.test('state:close', function()
	local s = assert(session:newstate(defaults('newstate')))

	assert(s:close())
	assert(#session:list() == 0)
end)

driver.test('state:close and iptables', function()
	local s = assert(session:newstate(defaults('newstate')))

	local rule = network.toserver .. ' -m lua --state st --function f'

	util.assertexec('iptables -A %s', rule)

	assert(not s:close())
	assert(#session:list() == 1)

	util.assertexec('iptables -D %s', rule)

	assert(s:close())
	assert(#session:list() == 0)
end)

driver.test('state:dostring', function()
	local s = assert(session:newstate(defaults('newstate')))

	local token = util.gentoken()
	local code = string.format('print(%q)', token)
	assert(s:dostring(code))
	driver.matchdmesg(4, token)

	token = util.gentoken()
	code = string.format('print(%q)', token)
	assert(s:dostring(code))
	driver.matchdmesg(4, token)

	assert(s:close())
	assert(not session:getstate('st'))
end)

driver.test('session:list', function()
	local states = {}

	local function statename(i)
		return string.format('st%04d', i)
	end

	local n = 10
	for i = 1, n do
		states[statename(i)] = assert(session:newstate(statename(i)))
	end

	local l = assert(session:list())
	assert(#l == n)
	table.sort(l, function(a, b) return a.name < b.name end)
	for i = 1, n do
		assert(l[i].name == statename(i))
	end

	for i = 1, n do
		assert(states[statename(i)]:close())
	end

	assert(#session:list() == 0)
end)

session:close()

-- TODO due the bug of a send message these tests were not adapted
function notused()
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
end
