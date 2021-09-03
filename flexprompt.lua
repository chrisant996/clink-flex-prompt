--------------------------------------------------------------------------------
-- Clink requirements.

if ((clink and clink.version_encoded) or 0) < 10020029 then
    print("clink-flex-prompt requires Clink v1.2.29 or higher.")
    return
end

--------------------------------------------------------------------------------
-- Internals.

flexprompt = {}
local modules

--------------------------------------------------------------------------------
-- Color codes.

flexprompt.fg_colors =
{
    normal = "0",
    bold = "1",
    default = "39",
    black = "30",
    red = "31",
    green = "32",
    yellow = "33",
    blue = "34",
    magenta = "35",
    cyan = "36",
    white = "37",
    brightblack = "90",
    brightred = "91",
    brightgreen = "92",
    brightyellow = "93",
    brightblue = "94",
    brightmagenta = "95",
    brightcyan = "96",
    brightwhite = "97",
}

flexprompt.bg_colors =
{
    default = "49",
    black = "40",
    red = "41",
    green = "42",
    yellow = "43",
    blue = "44",
    magenta = "45",
    cyan = "46",
    white = "47",
    brightblack = "100",
    brightred = "101",
    brightgreen = "102",
    brightyellow = "103",
    brightblue = "104",
    brightmagenta = "105",
    brightcyan = "106",
    brightwhite = "107",
}

--------------------------------------------------------------------------------
-- Configuration.

flexprompt.choices = {}

flexprompt.choices.charsets =
{
    "ascii",
    "unicode"
}

flexprompt.choices.styles =
{
    "lean",
    "classic",
    "rainbow",
}

flexprompt.choices.sides =
{
    "left",
    "both",
}

-- Only if style != lean.
flexprompt.choices.ascii_caps =
{
                --  Right           Left
                --  Open    Close   Open    Close
    vertical    = { "",     "",     "",     ""      },
}

-- Only if style != lean.
flexprompt.choices.caps =
{
                --  Right           Left
                --  Open    Close   Open    Close
    vertical    = { "",     "",     "",     ""      },
    pointed     = { nil,    "",    nil,    ""     },
    upslant     = { "",    "",    "",    ""     },
    downslant   = { "",    "",    "",    ""     },
    round       = { nil,    "",    nil,    ""     },
    blurred     = { "░▒▓",  "▓▒░",  "▓▒░",  "░▒▓"   },
}

-- Only if style == classic.
flexprompt.choices.ascii_separators =
{               --  Right   Left
    none        = { "",     "",     },
    vertical    = { "|",    "|"     },
    slash       = { "/",    "/"     },
    backslash   = { "\\",   "\\"    },
}

-- Only if style != lean.
flexprompt.choices.separators =
{               --  Right   Left
    vertical    = { "│",    "│"     },
    pointed     = { "",    ""     },
    upslant     = { "",    ""     },
    downslant   = { "",    ""     },
    round       = { "",    ""     },
    dot         = { "·",    "·"     },
    updiagonal  = { "╱",    "╱"     },
    downdiagonal= { "╲",    "╲"     },
}

flexprompt.choices.lines =
{
    one         = 1,
    two         = 2,
}

-- Only if lines > 1 and sides == both.
flexprompt.choices.connections =
{
    disconnected= " ",
    dotted      = "·",
    solid       = "─",
}

-- Only if lines > 1 and sides == both.
flexprompt.choices.left_frames =
{
    none        = {},
    square      = { "┌─",   "└─"    },
    round       = { "╭─",   "╰─"    },
}

-- Only if lines > 1 and sides == both.
flexprompt.choices.right_frames =
{
    none        = {},
    square      = { "─┐",   "─┘"    },
    round       = { "─╮",   "─╯"    },
}

-- Only if separators or connectors or frames.
flexprompt.choices.frame_colors =
{
    lightest    = "38;5;249",
    light       = "38;5;245",
    dark        = "38;5;241",
    darkest     = "38;5;237",
}

flexprompt.choices.spacing =
{
    normal      = 0,
    sparse      = 1,
}

flexprompt.choices.flow =
{
    "concise",
    "fluent",
}

flexprompt.choices.transient =
{
    "off",
    "same dir",
    "always",
}

-- Only if lines > 1 and left frame none, or if lines == 1 and style == lean, or if transient.
flexprompt.choices.symbols =
{
    angle       = ">",
    dollar      = "$",
    percent     = "%",
}

flexprompt.lines = "two"
flexprompt.spacing = "sparse"
flexprompt.left_frame = nil--"round"
flexprompt.right_frame = "round"
flexprompt.connection = "dotted"
flexprompt.frame_color = "darkest"
flexprompt.left_prompt = "{cwd}"
flexprompt.right_prompt = "{time}"

--------------------------------------------------------------------------------
-- Configuration helpers.

local function csi(args, code)
    return "\x1b["..args..code
end

local function sgr(args)
    if not args then
        return "\x1b[m"
    end

    if not args:match("^[0-9]") then
        local color = flexprompt.fg_colors[args]
        if color then
            args = color
        end
    end

    return "\x1b["..args.."m"
end

local function get_lines()
    return flexprompt.choices.lines[flexprompt.lines or "one"] or 1
end

local function get_spacing()
    return flexprompt.choices.spacing[flexprompt.spacing or "normal"] or 0
end

local function get_connector()
    return flexprompt.choices.connections[flexprompt.connection or "disconnected"] or " "
end

local function get_frame()
    local l = flexprompt.choices.left_frames[flexprompt.left_frame or "none"]
    local r = flexprompt.choices.right_frames[flexprompt.right_frame or "none"]
    if l and #l == 0 then
        l = nil
    end
    if r and #r == 0 then
        r = nil
    end
    return l, r
end

local function get_frame_color()
    return sgr(flexprompt.choices.frame_colors[flexprompt.frame_color or "light"])
end

local function get_symbol_color()
    return sgr(flexprompt.symbol_color or "brightblue")
end

local function get_symbol()
    return flexprompt.choices.symbols[flexprompt.symbol or "angle"] or ">"
end

local function connect(lhs, rhs, frame)
    local lhs_len = console.cellcount(lhs)
    local rhs_len = console.cellcount(rhs)
    local frame_len = console.cellcount(frame)
    local width = console.getwidth() - 1
    local gap = width - (lhs_len + rhs_len + frame_len)
    if gap < 0 then
        gap = gap + rhs_len
        rhs_len = 0
        rhs = ""
        if gap < 0 then
            frame = ""
        end
    end
    if gap > 0 then
        lhs = lhs .. get_frame_color() .. string.rep(get_connector(), gap)
    end
    return lhs..rhs..frame
end

--------------------------------------------------------------------------------
-- Module parsing and rendering.

local function render_module(name, args)
    local func = modules[string.lower(name)]
    if func then
        return func(args)
    end
end

local function render_modules(prompt)
    local out = ""
    local init = 1
    while true do
        local s,e,cap = string.find(prompt, "{([^}]*)}", init)
        if not s then
            break
        end

        init = e + 1

        local args = nil
        local name = string.match(cap, "(%w+):")
        if name then
            args = string.sub(cap, #name + 2)
        else
            name = cap
        end

        if name and #name > 0 then
            local segment = render_module(name, args)
            if segment then
                out = out .. segment
            end
        end
    end

    return out
end

--------------------------------------------------------------------------------
-- Build prompt.

local pf = clink.promptfilter(5)

local right

function pf:filter(prompt)
    local lines = get_lines()

    local left1 = ""
    local right1 = ""
    local rightframe1 = ""
    local left2 = nil
    local right2 = nil

    local left_frame, right_frame
    if lines > 1 then
        left_frame, right_frame = get_frame()
    end
    local frame_color = get_frame_color()

    -- Line 1 ----------------------------------------------------------------

    if true then
        if left_frame then
            left1 = left1 .. frame_color .. left_frame[1]
        end

        left1 = left1 .. render_modules(flexprompt.left_prompt)

        if flexprompt.right_prompt then
            right1 = render_modules(flexprompt.right_prompt)
        end

        if right_frame then
            rightframe1 = frame_color .. right_frame[1]
        end
    end

    -- Line 2 ----------------------------------------------------------------

    if lines > 1 then
        left2 = ""
        right2 = ""

        if left_frame then
            left2 = left2 .. frame_color .. left_frame[2]
        else
            left2 = left2 .. get_symbol_color() .. get_symbol()
        end

        left2 = left2 .. sgr() .. " "

        if sides == "both" then
            -- ...
        end

        if right_frame then
            right2 = right2 .. frame_color .. right_frame[2]
        end
    end

    -- Combine segments ------------------------------------------------------

    prompt = left1
    if lines == 1 then
        right = right1
    else
        right = right2
        if right_frame then
            prompt = connect(left1, right1, rightframe1)
        end
        prompt = prompt .. sgr() .. "\r\n" .. left2
    end

    if #right > 0 then
        right = right .. " "
    end

    if get_spacing() > 0 then
        prompt = sgr() .. "\r\n" .. prompt
    end

    return prompt
end

function pf:rightfilter(prompt)
    return right
end

function pf:transientfilter(prompt)
    return get_symbol_color() .. get_symbol() .. sgr() .. " "
end

function pf:transientrightfilter(prompt)
    return ""
end

--------------------------------------------------------------------------------
-- Public API.

-- Add a module.
-- E.g. flexprompt.add_module("xyz", xyz_render) calls the xyz_render function
-- when "{xyz}" or "{xyz:args}" is encountered in a prompt string.  The function
-- receives "args" as its only argument.
function flexprompt.add_module(name, func)
    table[string.lower(name)] = func
end

--------------------------------------------------------------------------------
-- Built in modules.

local function render_cwd(args)
    return sgr("brightblue") .. os.getcwd()
end

local function render_time(args)
    return sgr("yellow") .. os.date("%a %H:%M")
end

--[[local]] modules =
{
    cwd = render_cwd,
    time = render_time,
}

-- modules (git, npm, mercurial, time, battery, exit code, duration, cwd, ?)
-- custom modules
