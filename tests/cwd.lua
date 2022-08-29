-- luacheck: globals flexprompt flexprompt
-- luacheck: globals _flexprompt_test_process_cwd_string

local uht = flexprompt.settings.use_home_tilde

local test_cwd          = "c:\\Users\\chrisant\\source\\repos\\win32-darkmode\\win32-darkmode\\x64"
local test_git_dir      = "c:\\Users\\chrisant\\source\\repos\\win32-darkmode\\.git"

local full              = "\x01c:\\Users\\chrisant\\source\\repos\\\x02win32-darkmode\\win32-darkmode\\x64"
local short_all         = "\x01c:\\U\\c\\s\\r\\\x02w\\w\\x64"
local short_rootsmart   = "\x01c:\\U\\c\\s\\r\\\x02win32-darkmode\\win32-darkmode\\x64"

local tests =
{
    -- git    colors
    { false,  false,    "cwd",                          full },
    { false,  false,    "cwd:t=full:",                  full },
    { false,  false,    "cwd:t=smart:",                 full },
    { false,  false,    "cwd:s:",                       short_all },
    { false,  false,    "cwd:s=rootsmart:",             short_all },
    { false,  false,    "cwd:s:t=full:",                short_all },
    { false,  false,    "cwd:s=rootsmart:t=full:",      short_all },
    { false,  false,    "cwd:t=folder:",                "x64" },
    { false,  false,    "cwd:s:t=folder:",              "x64" },
    -- git
    { true,   true,     "cwd",                          full },
    { true,   false,    "cwd:t=full:",                  full },
    { true,   false,    "cwd:t=smart:",                 "win32-darkmode\\win32-darkmode\\x64" },
    { true,   true,     "cwd:s:",                       short_all },
    { true,   true,     "cwd:s=rootsmart:",             short_rootsmart },
    { true,   false,    "cwd:s:t=full:",                short_all },
    { true,   false,    "cwd:s=rootsmart:t=full:",      short_all },
    { true,   false,    "cwd:t=folder:",                "x64" },
    { true,   false,    "cwd:s:t=folder:",              "x64" },
}

print("-- CWD MODULE TESTS ----------------------------------------------------")

local i = 0
for _,e in ipairs(tests) do
    i = i + 1
    for t = 1,2 do
        flexprompt.settings.use_home_tilde = (t > 1)

        local cwd = test_cwd
        local git_dir = e[1] and test_git_dir or false

        local r = _flexprompt_test_process_cwd_string(cwd, git_dir, e[3])
        local num = tostring(i)
        local name = e[3]

        local x = e[4]
        if not e[2] then
            x = x:gsub("\x01", ""):gsub("\x02", "")
        end
        if (t > 1) then
            x = x:gsub("c:\\Users\\chrisant", "~"):gsub("c:\\U\\c", "~")
            num = num.."~"
        end

        if r == x then
            clink.print(num, "\x1b[32mok\x1b[m", name)
        else
            clink.print(num, "\x1b[31mFAIL\x1b[m", name)
            clink.print("", "", "\x1b[36mexpected:\x1b[m    "..x)
            clink.print("", "", "\x1b[33m  actual:\x1b[m    "..r)
        end
    end
end

print("------------------------------------------------------------------------")

flexprompt.settings.use_home_tilde = uht

print()
print()
print()

