return {
    exclude_files = { ".install", ".lua", ".luarocks", "modules/JSON.lua", "lua_modules" },
    files = {
        spec = { std = "+busted" },
    },
    globals = {
        "CLINK_EXE",
        "clink",
        "console",
        "error",
        "io",
        "log",
        "os",
        "path",
        "pause",
        "rl",
        "rl_state",
        "settings",
        "string.explode",
        "string.matchlen",
        "unicode",
    }
}
