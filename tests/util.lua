-- Creio que não precisa mexer nesse


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

local util = {}

math.randomseed(os.time())

function util.gentoken(n)
	n = n or 16
	local s = {}
	for i = 1, n do
		s[i] = math.random(0, 9)
	end
	return table.concat(s)
end

function util.pipeexec(cmd, ...)
	local f = assert(io.popen(string.format(cmd, ...)))
	local out = f:read'a'
	local ok = f:close()
	return ok, out
end

function util.assertexec(cmd, ...)
	assert(os.execute(string.format(cmd, ...)))
end

function util.silentexec(cmd, ...)
	return os.execute(string.format(cmd, ...) .. ' > /dev/null 2>&1')
end

return util
