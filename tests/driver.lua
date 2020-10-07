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

local memory = require'memory'

local network = require'tests.network'
local util = require'tests.util'

local driver = {}

local rmmodule = 'sudo rmmod nflua'
local loadmodule = 'sudo insmod ./src/nflua.ko'

function driver.reloadmodule()
	util.assertexec(rmmodule)
	util.assertexec(loadmodule)
end

-- Talvez criar um session para o driver seja uma boa solução


network.cleanup()
--util.silentexec(rmmodule) Não preciso disso agora
--util.silentexec(loadmodule) Não preciso disso agora


-- O único jeito que pensei de adaptar isso é encapsulando
-- cada comando possível e seus possíveis retornos
-- Mas como ficaria o caso da criação dos estados? Estes precisam de
-- uma determinada sessão criada para poderem ser executadas
-- será que um session = session or lunatik.session resolveria?
local function run(socket, cmd, ...)
	local ok, err
	repeat ok, err = socket[cmd](socket, ...) until ok or err ~= 'pending'
	if not ok then return ok, err end
	repeat ok, err = socket:receive() until ok or err ~= 'pending'
	return ok, err
end

function driver.datareceive(s)
	local buff = memory.create(nflua.datamaxsize)
	local recv, state = assert(s:receive(buff, 0))
	return memory.tostring(buff, 1, recv), state
end

function driver.run(s, cmd, ...)
	return assert(run(s, cmd, ...))
end

function driver.test(name, f, ...)
	print('testing', name)
	network.setup()
	f(...)
	collectgarbage()
	network.cleanup()
	driver.reloadmodule()
end

function driver.matchdmesg(n, str)
	local _, out = assert(util.pipeexec('dmesg | tail -%d', n))
	assert(string.find(out, str))
end

function driver.failrun(s, msg, cmd, ...)
	local ok, err = run(s, cmd, ...)
	assert(ok == nil)
	assert(err == 'operation could not be completed')
	driver.matchdmesg(3, msg)
end

function driver.setup(st, code, loadutil)
	local c = assert(nflua.control())
	driver.run(c, 'create', st, 1024 ^ 3)
	if code then
		driver.run(c, 'execute', st, code)
	end
	if loadutil then
		local path = package.searchpath('tests.nfutil', package.path)
		local f = io.open(path)
		driver.run(c, 'execute', st, f:read'a')
		f:close()
	end
	return c
end

return driver
