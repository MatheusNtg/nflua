/*
 * Copyright (C) 2017-2019 CUJO LLC
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

#include <stdio.h>
#include <string.h>
#include <xtables.h>

#include <xt_lua_common.h>

enum {
	O_STATE,
	O_FUNCTION,
};

static const struct xt_option_entry nflua_tg_opts[] = {
	{
		.name = "state",
		.id = O_STATE,
		.type = XTTYPE_STRING,
		.flags = XTOPT_MAND | XTOPT_PUT,
		XTOPT_POINTER(struct xt_lua_mtinfo, name)
	},
	{
		.name = "function",
		.id = O_FUNCTION,
		.type = XTTYPE_STRING,
		.flags = XTOPT_MAND | XTOPT_PUT,
		XTOPT_POINTER(struct xt_lua_mtinfo, func)
	},
	XTOPT_TABLEEND,
};

static void nflua_tg_help(void)
{
	printf("Netfilter Lua target arguments\n"
		"[!] --state\tmatch state\n"
		"[!] --function\tmatch function\n");
}

static void
nflua_tg_print(const void *ip, const struct xt_entry_target *target, int numeric)
{
	((void) ip);
	((void) numeric);
        struct xt_lua_mtinfo *info = (struct xt_lua_mtinfo *) target->data;

	printf(" LUA state:%.*s", NFLUA_NAME_MAXSIZE - 1, info->name);
	printf(" function:%.*s", NFLUA_NAME_MAXSIZE - 1, info->func);
}

static void
nflua_tg_save(const void *ip, const struct xt_entry_target *target)
{
	((void) ip);
	struct xt_lua_mtinfo *info = (struct xt_lua_mtinfo *) target->data;

	printf(" --state %.*s", NFLUA_NAME_MAXSIZE - 1, info->name);
	printf(" --function %.*s", NFLUA_NAME_MAXSIZE - 1, info->func);
}

static int
nflua_tg_xlate(struct xt_xlate *xl, const struct xt_xlate_tg_params *params)
{
	struct xt_lua_mtinfo *info =
		(struct xt_lua_mtinfo *)params->target->data;

	xt_xlate_add(xl, " state %.*s function %.*s",
			NFLUA_NAME_MAXSIZE - 1, info->name,
			NFLUA_NAME_MAXSIZE - 1, info->func);

	return 1;
}

static struct xtables_target nflua_tg_reg = {
	.version	= XTABLES_VERSION,
	.name		= "LUA",
	.revision	= 0,
	.family		= NFPROTO_UNSPEC,
	.size		= XT_ALIGN(sizeof(struct xt_lua_mtinfo)),
	.userspacesize	= XT_ALIGN(sizeof(struct xt_lua_mtinfo)),
	.help		= nflua_tg_help,
	.print		= nflua_tg_print,
	.save		= nflua_tg_save,
	.x6_parse	= xtables_option_parse,
	.x6_options	= nflua_tg_opts,
	.xlate          = nflua_tg_xlate,
};

static void _init(void)
{
	xtables_register_target(&nflua_tg_reg);
}
