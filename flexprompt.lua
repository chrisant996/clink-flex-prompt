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

flexprompt.colors =
{
    bold            = { fg="1"                  },
    default         = { fg="39",    bg="49"     },
    black           = { fg="30",    bg="40"     },
    red             = { fg="31",    bg="41"     },
    green           = { fg="32",    bg="42"     },
    yellow          = { fg="33",    bg="43"     },
    blue            = { fg="34",    bg="44"     },
    magenta         = { fg="35",    bg="45"     },
    cyan            = { fg="36",    bg="46"     },
    white           = { fg="37",    bg="47"     },
    brightblack     = { fg="90",    bg="100"    },
    brightred       = { fg="91",    bg="101"    },
    brightgreen     = { fg="92",    bg="102"    },
    brightyellow    = { fg="93",    bg="103"    },
    brightblue      = { fg="94",    bg="104"    },
    brightmagenta   = { fg="95",    bg="105"    },
    brightcyan      = { fg="96",    bg="106"    },
    brightwhite     = { fg="97",    bg="107"    },
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
    if args then
        return "\x1b["..args.."m"
    else
        return "\x1b[m"
    end
end

local function lookup_color(args, verbatim)
    if args and not args:match("^[0-9]") then
        return flexprompt.colors[args]
    end

    local mode = args:sub(1,3)
    if mode == "38;" or mode == "48;" then
        args = args:sub(4)
        return { fg = "38;"..args, bg = "48;"..args }
    end
end

local function get_style()
    -- Indexing into the styles table validates that the style name is
    -- recognized.
    return flexprompt.choices.styles[flexprompt.style or "lean"] or "lean"
end

local function get_style_ground()
    return (get_style() == "rainbow") and "bg" or "fg"
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
    local color = lookup_color(flexprompt.choices.frame_colors[flexprompt.frame_color or "light"])
    if not color then
        color = lookup_color(flexprompt.frame_color)
    end
    if color then
        return sgr(color.fg)
    end
    return sgr(flexprompt.frame_color)
end

local function get_symbol_color()
    local color = lookup_color(flexprompt.symbol_color or "brightblue")
    return sgr(color.fg)
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

-- Capture the $+ dir stack depth if present at the beginning of PROMPT.
local dirStackDepth
local plus_capture = clink.promptfilter(1)
function plus_capture:filter(prompt)
    dirStackDepth = ""
    local plusBegin, plusEnd = prompt:find("^[+]+")
    if plusBegin == nil then
        plusBegin, plusEnd = prompt:find("[\n][+]+")
        if plusBegin then
            plusBegin = plusBegin + 1
        end
    end
    if plusBegin ~= nil then
        dirStackDepth = prompt:sub(plusBegin, plusEnd).." "
    end
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

-- Add a named color.
-- Named colors must be a table { fg=_sgr_code_, bg=_sgr_code_ }.
-- The fg and bg are needed for the rainbow style to properly color transitions
-- between segments.
function flexprompt.add_color(name, fore, back)
    flexprompt.colors[name] = { fg=fore, bg=back }
end

-- Get an SGR string to apply the named color as either a foreground or
-- background color, depending on the style (rainbow style applies colors as
-- background colors).
function flexprompt.get_styled_sgr(name)
    local color = lookup_color(name)
    if color then
        return sgr(color[get_style_ground()])
    end
    return ""
end

--------------------------------------------------------------------------------
-- Built in modules.

local function render_cwd(args)
    local color = sgr("brightblue")

    local cwd = os.getcwd()
    return color .. dirStackDepth .. cwd
end

local function render_time(args)
    local color = flexprompt.parse_arg_token(args, "c", "color") or "cyan"
    color = flexprompt.get_styled_sgr(color)
    return color .. os.date("%a %H:%M")
end

--[[local]] modules =
{
    cwd = render_cwd,
    time = render_time,
}

-- modules (git, npm, mercurial, time, battery, exit code, duration, cwd, ?)
-- custom modules
