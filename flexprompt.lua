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
    lean        = "lean",
    classic     = "classic",
    rainbow     = "rainbow",
}

flexprompt.choices.sides =
{
    left        = "left",
    both        = "both",
}

-- Default prompt strings based on styles and sides.
flexprompt.choices.prompts =
{
    lean        = { left = { "{cwd}{time}" }, both = { "{cwd}", "{time}" } },
    classic     = { left = { "{cwd}{exit}{time}" }, both = { "{cwd}", "{exit}{time}" } },
    rainbow     = { left = { "{cwd}{exit}{time}" }, both = { "{cwd}", "{exit}{time}" } },
}

-- Only if style != lean.
flexprompt.choices.ascii_caps =
{
                --  Open    Close
    vertical    = { "",     ""      },
}

-- Only if style != lean.
flexprompt.choices.caps =
{
                --  Open    Close
    vertical    = { "",     ""      },
    pointed     = { "",    ""     },
    upslant     = { "",    ""     },
    downslant   = { "",    ""     },
    round       = { "",    ""     },
    blurred     = { "░▒▓",  "▓▒░"   },
}

-- Only if style == classic.
flexprompt.choices.ascii_separators =
{               --  Left    Right
    none        = { "",     ""      },
    vertical    = { "|",    "|"     },
    slash       = { "/",    "/"     },
    backslash   = { "\\",   "\\"    },
}

-- Only if style == classic.
flexprompt.choices.separators =
{               --  Left    Right
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
local fc_frame = 1
local fc_back = 2
local fc_fore = 3
flexprompt.choices.frame_colors =
{               --  Frame       Back        Fore
    lightest    = { "38;5;244", "38;5;240", "38;5;248"  },
    light       = { "38;5;242", "38;5;238", "38;5;246"  },
    dark        = { "38;5;240", "38;5;236", "38;5;244"  },
    darkest     = { "38;5;238", "38;5;234", "38;5;242"  },
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
flexprompt.style = "lean"
--flexprompt.spacing = "sparse"
flexprompt.left_frame = "round"
flexprompt.right_frame = "round"
flexprompt.connection = "dotted"
flexprompt.tails = "blurred"
flexprompt.heads = "pointed"
flexprompt.separators = "upslant"
flexprompt.frame_color = "lightest"
--flexprompt.left_prompt = "{cwd:t=smart}"
--flexprompt.right_prompt = "{time:c=red,brightwhite}"

flexprompt.use_home_symbol = true
--flexprompt.use_git_symbol = true
--flexprompt.git_symbol = "git"

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
    if not args or type(args) == "table" then
        return args
    end

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
    local frame_color = flexprompt.choices.frame_colors[flexprompt.frame_color or "light"]
    if not frame_color then
        frame_color = flexprompt.choices.frame_colors["light"]
    end

    if type(frame_color) ~= "table" then
        frame_color = { frame_color, frame_color, frame_color }
    end

    frame_color = { lookup_color(frame_color[1]), lookup_color(frame_color[2]), lookup_color(frame_color[3]) }

    return frame_color
end

local function get_symbol_color()
    local color
    if flexprompt.symbol_color then
        color = flexprompt.symbol_color
    else
        color = (os.geterrorlevel() == 0) and "brightgreen" or "brightred"
    end
    color = lookup_color(color)
    return sgr(color.fg)
end

local function get_symbol()
    return flexprompt.choices.symbols[flexprompt.symbol or "angle"] or ">"
end

local function connect(lhs, rhs, frame, sgr_frame_color)
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
        if not sgr_frame_color then
            sgr_frame_color = sgr(flexprompt.colors.red.fg)
        end
        lhs = lhs .. sgr_frame_color .. string.rep(get_connector(), gap)
    end
    return lhs..rhs..frame
end

--------------------------------------------------------------------------------
-- Other helpers.

local function get_folder_name(dir)
    local parent,child = path.toparent(dir)
    dir = child
    if #dir == 0 then
        dir = parent
    end
    return dir
end

--------------------------------------------------------------------------------
-- Segments.

local segmenter = nil

local function init_segmenter(side, frame_color)
    local open_caps, close_caps, separators

    if side == 0 then
        open_caps = flexprompt.tails or "vertical"
        close_caps = flexprompt.heads or "vertical"
    else
        open_caps = flexprompt.heads or "vertical"
        close_caps = flexprompt.tails or "vertical"
    end
    if type(open_caps) ~= "table" then
        open_caps = flexprompt.choices.caps[open_caps]
    end
    if type(close_caps) ~= "table" then
        close_caps = flexprompt.choices.caps[close_caps]
    end

    segmenter = {}
    segmenter.side = side
    segmenter.style = get_style()
    segmenter.frame_color = frame_color
    segmenter.back_color = flexprompt.colors.default
    segmenter.open_cap = open_caps[1]
    segmenter.close_cap = close_caps[2]

    if segmenter.style == "lean" then
        --[[
        separators = flexprompt.separators or "vertical"
        if type(separators) ~= "table" then
            separators = flexprompt.choices.separators[separators]
        end
        segmenter.separator = " " .. separators[side + 1] .. " "
        --]]
        segmenter.separator = " "
        segmenter.open_cap = ""
        segmenter.close_cap = ""
    elseif segmenter.style == "classic" then
        separators = flexprompt.separators or "vertical"
        if type(separators) ~= "table" then
            separators = flexprompt.choices.separators[separators]
        end
        segmenter.separator = separators[side + 1]
    elseif segmenter.style == "rainbow" then
        separators = flexprompt.separators or "vertical"
        if type(separators) ~= "table" then
            local altseparators = flexprompt.choices.separators[separators]
            if altseparators then
                segmenter.altseparator = altseparators[side + 1]
            end
            separators = flexprompt.choices.caps[separators]
        end
        segmenter.separator = separators[2 - side]
    end
end

local function color_segment_transition(color, symbol, close)
    if not symbol or symbol == "" then
        return ""
    end

    local swap = (close and segmenter.style == "classic") or (not close and segmenter.style == "rainbow")
    local fg = swap and "bg" or "fg"
    local bg = swap and "fg" or "bg"
    if segmenter.style == "rainbow" then
        if segmenter.back_color.bg == color.bg then
            return sgr(segmenter.frame_color[fc_frame].fg) .. segmenter.altseparator
        else
            return sgr(segmenter.back_color[fg] .. ";" .. color[bg]) .. symbol
        end
    else
        return sgr(segmenter.back_color[bg] .. ";" .. color[fg]) .. symbol
    end
end

local function next_segment(text, color, rainbow_text_color)
    local out = ""

    if not color then
        color = flexprompt.colors.brightred
    end
    if not rainbow_text_color then
        rainbow_text_color = flexprompt.colors.brightred
    else
        rainbow_text_color = lookup_color(rainbow_text_color)
    end

    if not text then
        if segmenter.style ~= "lean" and not segmenter.open_cap then
            out = out .. color_segment_transition(color, segmenter.close_cap, true)
        end
        return out
    end

    local pad = (segmenter.style == "lean") and "" or " "

    if true then
        local sep
        local transition_color = color
        local back, fore
        local classic = segmenter.style == "classic"
        local rainbow = segmenter.style == "rainbow"

        if segmenter.open_cap then
            sep = segmenter.open_cap
            segmenter.open_cap = nil
            if classic then
                transition_color = segmenter.frame_color[fc_back]
                back = segmenter.frame_color[fc_back].bg
                fore = segmenter.frame_color[fc_fore].fg
            end
        else
            sep = segmenter.separator
            if classic then
                transition_color = segmenter.frame_color[fc_fore]
            end
        end

        out = out .. color_segment_transition(transition_color, sep)
        if fore then
            out = out .. sgr(back .. ";" .. fore)
        end
        out = out .. sgr(rainbow and color.bg or color.fg)

        if rainbow then
            segmenter.back_color = color
            text = sgr(rainbow_text_color.fg) .. text
        elseif classic then
            segmenter.back_color = segmenter.frame_color[fc_back]
        end
    end

    out = out .. pad .. text .. pad
    return out
end

--------------------------------------------------------------------------------
-- Module parsing and rendering.

local function render_module(name, args)
    local func = modules[string.lower(name)]
    if func then
        return func(args)
    end
end

local function render_modules(prompt, side, frame_color)
    local out = ""
    local init = 1

    init_segmenter(side, frame_color)

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
            local segment,color,rainbow_text_color = render_module(name, args)
            if segment then
                out = out .. next_segment(segment, lookup_color(color), rainbow_text_color)
            end
        end
    end

    out = out .. next_segment(nil, flexprompt.colors.default)

    return out
end

--------------------------------------------------------------------------------
-- Build prompt.

local pf = clink.promptfilter(5)

local right

function pf:filter(prompt)
    local style = get_style()
    local lines = get_lines()

    local left_prompt = flexprompt.left_prompt
    local right_prompt = flexprompt.right_prompt
    if not left_prompt and not right_prompt then
        local prompts = flexprompt.choices.prompts[style]["both"]
        left_prompt = prompts[1]
        right_prompt = prompts[2]
    end

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
    local sgr_frame_color = (left_frame or right_frame) and sgr("0;" .. frame_color[fc_frame].fg) or nil

    -- Padding around left/right segments for lean style.
    local pad_frame = (style == "lean") and " " or ""

    -- Line 1 ----------------------------------------------------------------

    if true then

        if left_frame then
            left1 = left1 .. sgr_frame_color .. left_frame[1] .. pad_frame
        end

        left1 = left1 .. render_modules(left_prompt or "", 0, frame_color)

        if lines == 1 and style == "lean" then
            left1 = left1 .. get_symbol_color() .. " " .. get_symbol() .. " "
        end

        if right_prompt then
            right1 = render_modules(right_prompt, 1, frame_color)
        end

        if right_frame then
            rightframe1 = sgr_frame_color .. pad_frame .. right_frame[1]
        end
    end

    -- Line 2 ----------------------------------------------------------------

    if lines > 1 then
        left2 = ""
        right2 = ""

        if left_frame then
            left2 = left2 .. sgr_frame_color .. left_frame[2]
        end
        if not left_frame or style == "lean" then
            left2 = left2 .. get_symbol_color() .. get_symbol()
        end

        left2 = left2 .. sgr() .. " "

        if right_frame then
            right2 = right2 .. sgr_frame_color .. right_frame[2]
        end
    end

    -- Combine segments ------------------------------------------------------

    prompt = left1
    if lines == 1 then
        right = right1
    else
        right = right2
        if right_frame then
            if style == "lean" then
                -- Padding around left/right segments for lean style.
                if #left1 > 0 then left1 = left1 .. " " end
                if #right1 > 0 then right1 = " " .. right1 end
            end
            prompt = connect(left1, right1, rightframe1, sgr_frame_color)
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

-- Function to get style.
flexprompt.get_style = get_style

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

-- Parse arg "abc:def=mno:xyz" for token "def" returns value "xyz".
function flexprompt.parse_arg_token(args, name, altname)
    if not args then
        return
    end

    args = ":" .. args .. ":"

    local value
    if name then
        value = string.match(args, ":" .. name .. "=([^:]*):")
        if not value and altname then
            value = string.match(args, ":" .. altname .. "=([^:]*):")
        end
    end

    return value
end

-- Parsing arg "abc:def=mno:xyz" for a keyword like "abc" or "xyz" returns true.
function flexprompt.parse_arg_keyword(args, name, altname)
    if not args then
        return
    end

    args = ":" .. args .. ":"

    local value
    if name then
        value = string.match(args, ":" .. name .. ":")
        if not value and altname then
            value = string.match(args, ":" .. altname .. ":")
        end
    end

    return value
end

-- Test whether dir is part of a git repo.
function flexprompt.get_git_dir(dir)
    local function has_git_dir(dir)
        local dotgit = path.join(dir, '.git')
        return os.isdir(dotgit) and dotgit
    end

    local function has_git_file(dir)
        local dotgit = path.join(dir, '.git')
        local gitfile
        if os.isfile(dotgit) then
            gitfile = io.open(dotgit)
        end
        if not gitfile then return end

        local git_dir = gitfile:read():match('gitdir: (.*)')
        gitfile:close()

        -- gitdir can (apparently) be absolute or relative:
        local file_when_absolute = git_dir and os.isdir(git_dir) and git_dir
        if file_when_absolute then
            -- Don't waste time calling os.isdir on a potentially relative path
            -- if we already know it's an absolute path.
            return file_when_absolute
        end
        local rel_dir = path.join(dir, git_dir)
        local file_when_relative = git_dir and os.isdir(rel_dir) and rel_dir
        if file_when_relative then
            return file_when_relative
        end
    end

    -- Set default path to current directory.
    if not dir or dir == '.' then dir = os.getcwd() end

    -- Return if it's a git dir.
    local has = has_git_dir(dir) or has_git_file(dir)
    if has then return has end

    -- Walk up to parent path.
    local parent = path.toparent(dir)
    return (parent ~= dir) and flexprompt.get_git_dir(parent) or nil
end

--------------------------------------------------------------------------------
-- Built in modules.

-- CWD MODULE:  {cwd:c=color_name:t=type_name}
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - type_name is the format to use:
--      - "full" is the full path.
--      - "folder" is just the folder name.
--      - "smart" is the git repo\subdir, or the full path.
local function render_cwd(args)
    local color = flexprompt.parse_arg_token(args, "c", "color")
    if not color then
        if flexprompt.get_style() == "rainbow" then
            color = "blue"
        else
            color = "38;5;33"
        end
    end

    local cwd = os.getcwd()
    local git_dir

    local type = flexprompt.parse_arg_token(args, "t", "type") or "full"
    if type == "folder" then
        cwd = get_folder_name(cwd)
    else
        repeat
            if flexprompt.use_home_symbol then
                local home = os.getenv("HOME")
                if home and string.find(cwd, home) then
                    git_dir = flexprompt.get_git_dir(cwd) or false
                    if not git_dir then
                        cwd = string.gsub(cwd, home, flexprompt.home_symbol or "~")
                        break
                    end
                end
            end

            if type == "smart" then
                if git_dir == nil then -- Don't double-hunt for it!
                    git_dir = flexprompt.get_git_dir()
                end
                if git_dir then
                    -- Get the root git folder name and reappend any part of the
                    -- directory that comes after.
                    -- Ex: C:\Users\username\some-repo\innerdir -> some-repo\innerdir
                    local git_root_dir = path.toparent(git_dir)
                    local appended_dir = string.sub(cwd, string.len(git_root_dir) + 1)
                    cwd = get_folder_name(git_root_dir)..appended_dir
                    if flexprompt.use_git_symbol and (flexprompt.git_symbol or "") ~= "" then
                        cwd = flexprompt.git_symbol .. " " .. cwd
                    end
                end
            end
        until true
    end

    return dirStackDepth .. cwd, color, "white"
end

-- TIME MODULE:  {time:c=color_name,alt_color_name:f=format_string}
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style.
--  - format_string is a format string for os.date().
local function render_time(args)
    local colors = flexprompt.parse_arg_token(args, "c", "color")
    local color, altcolor
    if flexprompt.get_style() == "rainbow" then
        color = "white"
        altcolor = "black"
    else
        color = "cyan"
    end
    if colors then
        if string.find(colors, ",") then
            color, altcolor = string.match(colors, "([^,]+),([^,]+)")
        else
            color = colors
        end
    end

    local format = flexprompt.parse_arg_token(args, "f", "format")
    if not format then
        format = "%a %H:%M"
    end

    return os.date(format), color, altcolor
end

--[[local]] modules =
{
    cwd = render_cwd,
    time = render_time,
}

-- modules (git, npm, mercurial, time, battery, exit code, duration, cwd, ?)
