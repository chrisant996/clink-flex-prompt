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
    -- Normal low intensity colors.  Some styles brighten the normal low
    -- intensity colors; the "dark" versions are never brightened.
    black           = { fg="30",    bg="40",    lean="brightblack",     classic="brightblack",      },
    red             = { fg="31",    bg="41",    lean="brightred",       classic="brightred",        },
    green           = { fg="32",    bg="42",    lean="brightgreen",     classic="brightgreen",      },
    yellow          = { fg="33",    bg="43",    lean="brightyellow",    classic="brightyellow",     },
    blue            = { fg="34",    bg="44",    lean="brightblue",      classic="brightblue",       },
    magenta         = { fg="35",    bg="45",    lean="brightmagenta",   classic="brightmagenta",    },
    cyan            = { fg="36",    bg="46",    lean="brightcyan",      classic="brightcyan",       },
    white           = { fg="37",    bg="47",    lean="brightwhite",     classic="brightwhite",      },
    -- High intensity colors.
    brightblack     = { fg="90",    bg="100",   },
    brightred       = { fg="91",    bg="101",   },
    brightgreen     = { fg="92",    bg="102",   },
    brightyellow    = { fg="93",    bg="103",   },
    brightblue      = { fg="94",    bg="104",   },
    brightmagenta   = { fg="95",    bg="105",   },
    brightcyan      = { fg="96",    bg="106",   },
    brightwhite     = { fg="97",    bg="107",   },
    -- Low intensity colors.  Some styles brighten the normal low intensity
    -- colors; the "dark" versions are never brightened.
    darkblack       = { fg="30",    bg="40",    },
    darkred         = { fg="31",    bg="41",    },
    darkgreen       = { fg="32",    bg="42",    },
    darkyellow      = { fg="33",    bg="43",    },
    darkblue        = { fg="34",    bg="44",    },
    darkmagenta     = { fg="35",    bg="45",    },
    darkcyan        = { fg="36",    bg="46",    },
    darkwhite       = { fg="37",    bg="47",    },
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
    lean        = { left = { "{battery}{cwd}{time}" }, both = { "{battery}{cwd}", "{exit}{time}" } },
    classic     = { left = { "{battery}{cwd}{exit}{time}" }, both = { "{battery}{cwd}", "{exit}{time}" } },
    rainbow     = { left = { "{battery:breakright}{cwd}{exit}{time:color=black}" }, both = { "{battery:breakright}{cwd}", "{exit}{time}" } },
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
    none        = { "",     ""      },
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

flexprompt.choices.flows =
{
    concise     = "concise",
    fluent      = "fluent",
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
flexprompt.style = "classic"
flexprompt.flow = "fluent"
--flexprompt.spacing = "sparse"
flexprompt.left_frame = "round"
flexprompt.right_frame = "round"
flexprompt.connection = "dotted"
flexprompt.tails = "blurred"
flexprompt.heads = "pointed"
flexprompt.separators = "none" --{ "updiagonal", "downdiagonal" } --"vertical"
flexprompt.frame_color = "darkest"
flexprompt.left_prompt = "{battery:s=100:br}{user:t=computer}{cwd}"
flexprompt.right_prompt = "{exit}{duration}{time}"

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

local _can_use_extended_colors = nil
local function can_use_extended_colors()
    if _can_use_extended_colors ~= nil then
        return _can_use_extended_colors
    end

    if clink.getansihost then
        local host = clink.getansihost()
        if host == "conemu" or host == "winconsolev2" or host == "winterminal" then
            _can_use_extended_colors = true
            return true;
        end
    end

    _can_use_extended_colors = false
    return false
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

local function lookup_color(args, verbatim)
    if not args or type(args) == "table" then
        return args
    end

    if args and not args:match("^[0-9]") then
        local color = flexprompt.colors[args]
        if color then
            local redirect = color[get_style()]
            if redirect then
                color = flexprompt.colors[redirect]
            end
        end
        return color
    end

    local mode = args:sub(1,3)
    if mode == "38;" or mode == "48;" then
        args = args:sub(4)
        return { fg = "38;"..args, bg = "48;"..args }
    end

    -- Use the color even though it's not understood.  But not in rainbow style,
    -- because that can garble segment transitions.
    if get_style() ~= "rainbow" then
        return { fg = args, bg = args }
    end
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

local function get_flow()
    -- Indexing into the flows table validates that the flow name is recognized.
    return flexprompt.choices.flows[flexprompt.flow or "concise"] or "concise"
end

local function make_fluent_text(text)
    return "\001" .. text .. "\002"
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

local function reset_cached_state()
    _can_use_extended_colors = nil
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
        else
            local custom = flexprompt.choices.separators[separators[side + 1]]
            if custom then
                separators = { custom[side + 1], custom[side] }
            end
        end
        segmenter.separator = separators[side + 1]
    elseif segmenter.style == "rainbow" then
        separators = flexprompt.separators or "vertical"
        if type(separators) ~= "table" then
            local altseparators = flexprompt.choices.separators[separators]
            if altseparators then
                segmenter.altseparator = altseparators[side + 1]
            end
            separators = flexprompt.choices.caps[separators] or flexprompt.choices.caps["vertical"]
        else
            local custom = flexprompt.choices.caps[separators[side + 1]]
            if custom then
                separators = { custom[side + 1], custom[side] }
            end
        end
        segmenter.separator = separators[2 - side]
    end
end

local function color_segment_transition(color, symbol, close)
    if not symbol or symbol == "" then
        return ""
    end

    local swap
    if segmenter.style == "classic" then
        swap = close
    elseif segmenter.style == "rainbow" then
        swap = not close
        if not segmenter.open_cap and not close and segmenter.side == 0 then
            swap = false
        end
    end

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

local function apply_fluent_colors(text, base_color)
    return string.gsub(text, "\001", sgr(segmenter.frame_color[fc_fore].fg)):gsub("\002", base_color)
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

    local sep
    local transition_color = color
    local back, fore
    local classic = segmenter.style == "classic"
    local rainbow = segmenter.style == "rainbow"

    if segmenter.open_cap then
        sep = segmenter.open_cap
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

    local pad = (segmenter.style == "lean" -- Lean has no padding.
                 or text == "" -- Segment with empty string has no padding.
                 or (sep == "" and segmenter.style == "classic")) -- Classic with no separator has no padding.
                 and "" or " "

    if not text then
        if segmenter.style ~= "lean" and not segmenter.open_cap then
            if sep == "" and pad == "" then
                out = out .. " "
            end
            out = out .. color_segment_transition(color, segmenter.close_cap, true)
        end
        return out
    end

    out = out .. color_segment_transition(transition_color, sep)
    if fore then
        out = out .. sgr(back .. ";" .. fore)
    end

    -- A module with an empty string is a segment break.  When there's no
    -- separator, force a break by showing one connector character using the
    -- frame color.
    if text == "" and sep == "" and (rainbow or classic) then
        text = make_fluent_text(sgr(flexprompt.colors.default.bg) .. get_connector())
    end

    -- Applying 'color' goes last so that the module can override other colors
    -- if it really wants to.  E.g. by returning "41;30" as the color a module
    -- can force the segment color to be black on red, even in classic or lean
    -- styles.  But doing that in the rainbow style will garble segment
    -- transition colors.
    local base_color
    if rainbow then
        base_color = sgr(rainbow_text_color.fg .. ";" .. color.bg)
    elseif classic then
        base_color = sgr(segmenter.frame_color[fc_back].bg .. ";" .. color.fg)
    else
        base_color = sgr("49;" .. color.fg )
    end

    out = out .. base_color
    out = out .. pad .. apply_fluent_colors(text, base_color) .. pad

    if rainbow then
        segmenter.back_color = color
    elseif classic then
        segmenter.back_color = segmenter.frame_color[fc_back]
    end

    segmenter.open_cap = nil

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
            local text,color,rainbow_text_color = render_module(name, args)
            if text then
                local segments
                if type(text) ~= "table" then
                    -- No table provided.
                    segments = { { text, color, rainbow_text_color } }
                elseif type(text[1]) ~= "table" then
                    -- Table of non-tables provided.
                    segments = { text }
                else
                    -- Table of tables provided.
                    segments = text
                end
                for _,segment in pairs(segments) do
                    if segment then
                        out = out .. next_segment(segment[1], lookup_color(segment[2]), segment[3])
                    end
                end
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
    reset_cached_state()

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
    local right1
    local rightframe1
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
        left1 = render_modules(left_prompt or "", 0, frame_color)

        if left_frame then
            if left1 ~= "" then
                left1 = pad_frame .. left1
            end
            left1 = sgr_frame_color .. left_frame[1] .. left1
        end

        if lines == 1 and style == "lean" then
            left1 = left1 .. get_symbol_color() .. " " .. get_symbol() .. " "
        end

        if right_prompt then
            right1 = render_modules(right_prompt, 1, frame_color)
        end

        if right_frame then
            rightframe1 = sgr_frame_color
            if right1 and right1 ~= "" then
                rightframe1 = rightframe1 .. pad_frame
            end
            rightframe1 = rightframe1 .. right_frame[1]
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
        if right1 or right_frame then
            if style == "lean" then
                -- Padding around left/right segments for lean style.
                if left1 and #left1 > 0 then left1 = left1 .. " " end
                if right1 and #right1 > 0 then right1 = " " .. right1 end
            end
            prompt = connect(left1 or "", right1 or "", rightframe1 or "", sgr_frame_color)
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
    return right or ""
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

-- Function to get flow.
flexprompt.get_flow = get_flow

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

-- Parsing text "white,cyan" returns "white", "cyan".
function flexprompt.parse_colors(text, default, altdefault)
    local color, altcolor = default, altdefault
    if text then
        if string.find(text, ",") then
            color, altcolor = string.match(text, "([^,]+),([^,]+)")
        else
            color = text
        end
    end
    return color, altcolor
end

-- Function to add control codes around fluent text.
flexprompt.make_fluent_text = make_fluent_text

-- Function to check whether extended colors are available (256 color and 24 bit
-- color codes).
flexprompt.can_use_extended_colors = can_use_extended_colors

--------------------------------------------------------------------------------
-- Public API; git functions.

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
-- BATTERY MODULE:  {battery:show=show_level:breakleft:breakright}
--  - show_level shows the battery module unless the battery level is greater
--    than show_level.
--  - 'breakleft' adds an empty prompt segment to the left of battery.
--  - 'breakright' adds an empty prompt segment to the right of battery.
--
-- The 'breakleft' and 'breakright' options may look better than having battery
-- segment colors adjacent to other similarly colored segments.

local rainbow_battery_colors =
{
    {
        fg = "38;2;239;65;54",
        bg = "48;2;239;65;54"
    },
    {
        fg = "38;2;252;176;64",
        bg = "48;2;252;176;64"
    },
    {
        fg = "38;2;248;237;50",
        bg = "48;2;248;237;50"
    },
    {
        fg = "38;2;142;198;64",
        bg = "48;2;142;198;64"
    },
    {
        fg = "38;2;1;148;68",
        bg = "48;2;1;148;68"
    }
}

local function get_battery_status()
    local level, acpower, charging
    local batt_symbol = flexprompt.battery_symbol or "%"

    local status = os.getbatterystatus()
    level = status.level
    acpower = status.acpower
    charging = status.charging

    if not level or level < 0 or (acpower and not charging) then
        return "", 0
    end
    if charging then
        batt_symbol = flexprompt.charging_symbol or "↑"
    end

    return level..batt_symbol, level
end

local function get_battery_status_color(level)
    if flexprompt.can_use_extended_colors() then
        local index = ((((level > 0) and level or 1) - 1) / 20) + 1
        index = math.modf(index)
        return rainbow_battery_colors[index], index == 1
    elseif level > 50 then
        return "green"
    elseif level > 30 then
        return "yellow"
    end
    return "red", true
end

local prev_battery_status, prev_battery_level
local function update_battery_prompt()
    while true do
        local status,level = get_battery_status()
        if prev_battery_level ~= status or prev_battery_level ~= level then
            clink.refilterprompt()
        end
        coroutine.yield()
    end
end

local cached_battery_coroutine
local function render_battery(args)
    local show = tonumber(flexprompt.parse_arg_token(args, "s", "show") or "100")
    local batteryStatus,level = get_battery_status()
    prev_battery_status = batteryStatus
    prev_battery_level = level

    if flexprompt.battery_idle_refresh and not cached_battery_coroutine then
        local t = coroutine.create(update_battery_prompt)
        cached_battery_coroutine = t
        clink.addcoroutine(t, flexprompt.battery_refresh_interval or 15)
    end

    -- Hide when on AC power and fully charged, or when level is less than or
    -- equal to the specified 'show=level' ({battery:show=75} means "show at 75
    -- or lower").
    if not batteryStatus or batteryStatus == "" or level > (show or 80) then
        return
    end

    -- The 'breakleft' and 'breakright' args add blank segments to force a color
    -- break between segments, in case the adjacent colors are too similar.
    local bl = flexprompt.parse_arg_keyword(args, "bl", "breakleft")
    local br = flexprompt.parse_arg_keyword(args, "br", "breakright")

    local color, warning = get_battery_status_color(level)

    if warning and flexprompt.get_style() == "classic" then
        -- batteryStatus = flexprompt.make_fluent_text(sgr(color.bg .. ";30") .. batteryStatus)
        -- The "22;" defeats the color parsing that would normally generate
        -- corresponding fg and bg colors even though only an explicit bg color
        -- was provided (versus a usual {fg=x,bg=y} color table).
        color = "22;" .. color.bg .. ";30"
    end

    local segments = {}
    if bl then table.insert(segments, { "", "black" }) end
    table.insert(segments, { batteryStatus, color, "black" })
    if br then table.insert(segments, { "", "black" }) end

    return segments
end

--------------------------------------------------------------------------------
-- CWD MODULE:  {cwd:color=color_name,alt_color_name:type=type_name}
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style.
--  - type_name is the format to use:
--      - "full" is the full path.
--      - "folder" is just the folder name.
--      - "smart" is the git repo\subdir, or the full path.
--      - "rootsmart" is the full path, with parent of git repo not colored.
--
-- The default type is "rootsmart" if not specified.

local function render_cwd(args)
    local colors = flexprompt.parse_arg_token(args, "c", "color")
    local color, altcolor
    local style = flexprompt.get_style()
    if style == "rainbow" then
        color = "blue"
        altcolor = "white"
    elseif style == "classic" then
        color = flexprompt.can_use_extended_colors() and "38;5;39" or "cyan"
    else
        color = flexprompt.can_use_extended_colors() and "38;5;33" or "blue"
    end
    color, altcolor = flexprompt.parse_colors(colors, color, altcolor)

    local cwd = os.getcwd()
    local git_dir

    local type = flexprompt.parse_arg_token(args, "t", "type") or "rootsmart"
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

            if type == "smart" or type == "rootsmart" then
                if git_dir == nil then -- Don't double-hunt for it!
                    git_dir = flexprompt.get_git_dir()
                end
                if git_dir then
                    -- Get the root git folder name and reappend any part of the
                    -- directory that comes after.
                    -- Ex: C:\Users\username\some-repo\innerdir -> some-repo\innerdir
                    local git_root_dir = path.toparent(git_dir)
                    local appended_dir = string.sub(cwd, string.len(git_root_dir) + 1)
                    local smart_dir = get_folder_name(git_root_dir) .. appended_dir
                    if type == "rootsmart" then
                        cwd = flexprompt.make_fluent_text(cwd:sub(1, #cwd - #smart_dir)) .. smart_dir
                    else
                        cwd = smart_dir
                    end
                    if flexprompt.use_git_symbol and (flexprompt.git_symbol or "") ~= "" then
                        cwd = flexprompt.git_symbol .. " " .. cwd
                    end
                end
            end
        until true
    end

    return dirStackDepth .. cwd, color, "white"
end

--------------------------------------------------------------------------------
-- DURATION MODULE:  {duration:color=color_name,alt_color_name}
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style.

local endedit_time
local _duration

local function render_duration(args)
    if not _duration then
        return
    end

    local colors = flexprompt.parse_arg_token(args, "c", "color")
    local color, altcolor
    if not flexprompt.can_use_extended_colors() then
        color = "darkyellow"
    elseif flexprompt.get_style() == "rainbow" then
        color = "yellow"
        altcolor = "black"
    else
        color = "38;5;214"
    end
    color, altcolor = flexprompt.parse_colors(colors, color, altcolor)

    local text = _duration .. "s"

    if flexprompt.get_flow() == "fluent" then
        text = flexprompt.make_fluent_text("took ") .. text
    end

    return text, color, altcolor
end

clink.onbeginedit(function ()
    if endedit_time then
        local beginedit_time = os.time()
        local elapsed = beginedit_time - endedit_time
        if elapsed >= 0 then
            _duration = math.floor(elapsed)
        end
    end
end)

clink.onendedit(function ()
    endedit_time = os.time()
end)

--------------------------------------------------------------------------------
-- EXIT MODULE:  {exit:always:color=color_name,alt_color_name:hex}
--  - 'always' always shows the exit code even when 0.
--  - color_name is used when the exit code is 0, and is a name like "green", or
--    an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style when the
--    exit code is 0.
--  - 'hex' shows the exit code in hex when > 255 or < -255.

local function render_exit(args)
    local text
    local value = os.geterrorlevel()

    local always = flexprompt.parse_arg_keyword(args, "a", "always")
    if not always and value == 0 then
        return
    end

    local hex = flexprompt.parse_arg_keyword(args, "h", "hex")

    if hex and math.abs(value) > 255 then
        local lo = bit32.band(value, 0xffff)
        local hi = bit32.rshift(value, 16)
        if hi > 0 then
            hex = string.format("%x", hi) .. string.format("%04.4x", lo)
        else
            hex = string.format("%x", lo)
        end
        text = "0x" .. hex
    else
        text = value
    end

    local colors = flexprompt.parse_arg_token(args, "c", "color")
    local color, altcolor
    if flexprompt.get_style() == "rainbow" then
        color = "black"
        altcolor = "red"
    else
        color = "red"
    end
    color, altcolor = flexprompt.parse_colors(colors, color, altcolor)

    if value ~= 0 then
        color = "red"
        altcolor = "brightyellow"
    end

    if flexprompt.get_flow() == "fluent" then
        text = flexprompt.make_fluent_text("exit ") .. text
    end

    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- TIME MODULE:  {time:color=color_name,alt_color_name:format=format_string}
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
        color = "darkcyan"
    end
    color, altcolor = flexprompt.parse_colors(colors, color, altcolor)

    local format = flexprompt.parse_arg_token(args, "f", "format")
    if not format then
        format = "%a %H:%M"
    end

    local text = os.date(format)

    if flexprompt.get_flow() == "fluent" then
        text = flexprompt.make_fluent_text("at ") .. text
    end

    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- USER MODULE:  {user:type=type_name:color=color_name,alt_color_name}
--  - type_name is any of 'computer', 'user', or 'both' (the default).
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style.

local function render_user(args)
    local colors = flexprompt.parse_arg_token(args, "c", "color")
    local color, altcolor
    local style = flexprompt.get_style()
    if not flexprompt.can_use_extended_colors() then
        color = "magenta"
    elseif style == "rainbow" then
        color = "38;5;90"
        altcolor = "white"
    elseif style == "classic" then
        color = "38;5;171"
    else
        color = "38;5;135"
    end
    color, altcolor = flexprompt.parse_colors(colors, color, altcolor)

    local type = flexprompt.parse_arg_token(args, "t", "type") or "both"
    local user = (type ~= "computer") and os.getenv("username") or ""
    local computer = (type ~= "user") and os.getenv("computername") or ""
    if #computer > 0 then
        local prefix = "@"
        -- if #user == 0 then prefix = "\\\\" end
        computer = prefix .. computer
    end

    local text = user..computer
    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- Module table.
-- Initialized with the built-in modules.
-- Custom modules can be added with flexprompt.add_module().

--[[local]] modules =
{
    battery = render_battery,
    cwd = render_cwd,
    duration = render_duration,
    exit = render_exit,
    time = render_time,
    user = render_user,
}

