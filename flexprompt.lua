--------------------------------------------------------------------------------
-- Clink requirements.
--
-- Notes:
--  - Transient prompt support requires Clink v1.2.29 or higher.
--  - Right prompt support requires Clink v1.2.24 or higher.
--  - Exit code support requires Clink v1.2.14 or higher.
--  - Async prompt filtering requires Clink v1.2.10 or higher.

if ((clink and clink.version_encoded) or 0) < 10020010 then
    print("clink-flex-prompt requires Clink v1.2.10 or higher.")
    return
end

settings.add(
    "flexprompt.enable",
    true,
    "Enable flexprompt.",
    "Setting this to false disables the flexprompt prompt filter.\n" ..
    "Takes effect on the next Clink session.")

if not settings.get("flexprompt.enable") then
    log.info("Flexprompt is disabled by the 'flexprompt.enable' setting.")
    return
end

--------------------------------------------------------------------------------
-- Internals.

-- luacheck: no max line length
-- luacheck: globals console io os unicode
-- luacheck: globals string.equalsi string.matchlen
-- luacheck: globals _error_handler NONL
-- luacheck: globals flexprompt
-- luacheck: globals CMDER_SESSION prompt_includeVersionControl

flexprompt = flexprompt or {}
flexprompt.settings = flexprompt.settings or {}
flexprompt.settings.symbols = flexprompt.settings.symbols or {}
flexprompt.defaultargs = flexprompt.defaultargs or {}
local modules = {}
local scms = {}
local vpns = {}

-- Is reset to {} at each onbeginedit.
local _cached_state = {}

-- Check if Clink natively supporting prompt spacing.
local clink_prompt_spacing = (settings.get("prompt.spacing") ~= nil)

--------------------------------------------------------------------------------
-- Color codes.

local realblack = { fg="30", bg="40", extfg="38;5;0", extbg="48;5;0" }
local realwhite = { fg="37", bg="47", extfg="38;5;7", extbg="48;5;7", altcolor=realblack }
local nearlywhite = { fg="37", bg="47", extfg="38;5;252", extbg="48;5;252" }

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

    -- Real colors.  These use the real color (vs console theme color) when
    -- extended colors are available.
    realblack           = realblack,
    realred             = { fg="31", bg="41",   extfg="38;5;1",     extbg="48;5;1"  },
    realgreen           = { fg="32", bg="42",   extfg="38;5;2",     extbg="48;5;2"  },
    realyellow          = { fg="33", bg="43",   extfg="38;5;3",     extbg="48;5;3"  },
    realblue            = { fg="34", bg="44",   extfg="38;5;4",     extbg="48;5;4"  },
    realmagenta         = { fg="35", bg="45",   extfg="38;5;5",     extbg="48;5;5"  },
    realcyan            = { fg="36", bg="46",   extfg="38;5;6",     extbg="48;5;6"  },
    realwhite           = realwhite,
    realbrightblack     = { fg="91", bg="101",  extfg="38;5;8",     extbg="48;5;8"  },
    realbrightred       = { fg="91", bg="101",  extfg="38;5;9",     extbg="48;5;9"  },
    realbrightgreen     = { fg="92", bg="102",  extfg="38;5;10",    extbg="48;5;10" },
    realbrightyellow    = { fg="93", bg="103",  extfg="38;5;11",    extbg="48;5;11" },
    realbrightblue      = { fg="94", bg="104",  extfg="38;5;12",    extbg="48;5;12" },
    realbrightmagenta   = { fg="95", bg="105",  extfg="38;5;13",    extbg="48;5;13" },
    realbrightcyan      = { fg="96", bg="106",  extfg="38;5;14",    extbg="48;5;14" },
    realbrightwhite     = { fg="97", bg="107",  extfg="38;5;15",    extbg="48;5;15" },

    -- Default text color in rainbow style.
    rainbow_text    = nearlywhite,

    -- Version control colors.
    vcs_blacktext   = realblack,
    vcs_whitetext   = nearlywhite,
    vcs_conflict    = { fg="91",    bg="101",   extfg="38;5;160",   extbg="48;5;160",   rainbow={ fg="31", bg="41", extfg="38;5;1", extbg="48;5;1", altcolor=nearlywhite } },
    vcs_unresolved  = { fg="91",    bg="101",   extfg="38;5;160",   extbg="48;5;160",   rainbow={ fg="31", bg="41", extfg="38;5;1", extbg="48;5;1", altcolor=realblack } },
    vcs_clean       = { fg="92",    bg="102",   extfg="38;5;40",    extbg="48;5;40",    rainbow={ fg="32", bg="42", extfg="38;5;2", extbg="48;5;2", altcolor=realblack } },
    vcs_dirty       = { fg="93",    bg="103",   extfg="38;5;11",    extbg="48;5;11",    rainbow={ fg="33", bg="43", extfg="38;5;178", extbg="48;5;178", altcolor=realblack } },
    vcs_staged      = { fg="95",    bg="105",   extfg="38;5;164",   extbg="48;5;164",   rainbow={ fg="35", bg="45", extfg="38;5;5", extbg="48;5;5", altcolor=realblack } },
    vcs_unpublished = { fg="95",    bg="105",   extfg="38;5;141",   extbg="48;5;141",   rainbow={ fg="35", bg="45", extfg="38;5;99", extbg="48;5;99", altcolor=realblack } },
    vcs_remote      = { fg="96",    bg="106",   extfg="38;5;44",    extbg="48;5;44",    rainbow={ fg="36", bg="46", extfg="38;5;6", extbg="48;5;6", altcolor=realblack } },
    vcs_unknown     = realwhite,

    -- Exit code colors.
    exit_zero       = { fg="32",    bg="42",    extfg="38;5;2",     extbg="48;5;2",     rainbow={ fg="30", bg="40", extfg="38;5;0", extbg="48;5;0", altcolor={ fg="32", bg="42", extfg="38;5;34", extbg="48;5;34" } } },
    exit_nonzero    = { fg="91",    bg="101",   extfg="38;5;160",   extbg="48;5;160",   rainbow={ fg="31", bg="41", extfg="38;5;1", extbg="48;5;1", altcolor={ fg="93", bg="103", extfg="38;5;11", extbg="48;5;11" } },
                                                                                        classic={ fg="91", bg="101", extfg="38;5;196", extbg="48;5;196" } },
}

--------------------------------------------------------------------------------
-- Configuration.

flexprompt.choices = {}

flexprompt.choices.charsets =
{
    ascii       = "ascii",
    unicode     = "unicode",
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
    lean        = { left = { "{battery}{histlabel}{cwd}{git}{duration}{time}" }, both = { "{battery}{histlabel}{cwd}{git}", "{exit}{duration}{time}" } },
    classic     = { left = { "{battery}{histlabel}{cwd}{git}{exit}{duration}{time}" }, both = { "{battery}{histlabel}{cwd}{git}", "{exit}{duration}{time}" } },
    rainbow     = { left = { "{battery:breakright}{histlabel}{cwd}{git}{exit}{duration}{time:dim}" }, both = { "{battery:breakright}{histlabel}{cwd}{git}", "{exit}{duration}{time}" } },
    breaks      = { left = { "{battery:breakright}{histlabel}{cwd}{break}{git}{break}{exit}{duration}{break}{time:dim}" }, both = { "{battery}{break}{histlabel}{cwd}{break}{git}", "{exit}{duration}{break}{time}" } },
}

-- Only if style != lean.
flexprompt.choices.ascii_caps =
{
                --  Open    Close
    none        = { "",     ""      },
    flat        = { "",     "",     separators="bar" },
}

-- Only if style != lean.
flexprompt.choices.caps =
{
                --  Open    Close
    none        = { "",     ""      },
    flat        = { "",     ""      },
    vertical    = { "",     ""      },  -- A separator when style == rainbow.
    pointed     = { "",    ""     },
    slant       = { "",    ""     },
    backslant   = { "",    ""     },
    round       = { "",    ""     },
    blurred     = { "░▒▓",  "▓▒░"   },
}

-- Only if style == classic.
flexprompt.choices.separators =
{               --  Left    Right
    none        = { "",     ""      },
    space       = { " ",    " ",    lean=" " },     -- Also when style == lean.
    spaces      = { "  ",   "  ",   lean="  " },    -- Also when style == lean.
    vertical    = { "│",    "│",    rainbow="" },
    pointed     = { "",    ""     },
    slant       = { "",    ""     },
    backslant   = { "",    ""     },
    round       = { "",    ""     },
    dot         = { "·",    "·"     },
    updiagonal  = { "╱",    "╱"     },
    downdiagonal= { "╲",    "╲"     },
    bar         = { "|",    "|"     },
    slash       = { "/",    "/"     },
    backslash   = { "\\",   "\\"    },
}

flexprompt.choices.lines =
{
    one         = 1,
    two         = 2,
}

-- Only if lines > 1 and right_prompt is not nil.
flexprompt.choices.connections =
{
    disconnected= " ",
    dotted      = "·",
    solid       = "─",
    dashed      = "-",
}

-- Only if lines > 1.
flexprompt.choices.left_frames =
{
    none        = {},
    square      = { "┌─",   "└─"    },
    round       = { "╭─",   "╰─"    },
}

-- Only if lines > 1 and right_prompt is not nil.
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
local fc_sep = 4
flexprompt.choices.frame_colors =
{               --  Frame       Back        Fore        Separator (optional; falls back to Frame)
    lightest    = { "38;5;244", "38;5;240", "38;5;248"  },
    light       = { "38;5;242", "38;5;238", "38;5;246"  },
    dark        = { "38;5;240", "38;5;236", "38;5;244"  },
    darkest     = { "38;5;238", "38;5;234", "38;5;242"  },
}

flexprompt.choices.spacing =
{
    compact     = "compact",
    normal      = "normal",
    sparse      = "sparse",
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
flexprompt.choices.prompt_symbols =
{
    angle       = { ">" }, -- unicode="❯" looks very good in some fonts, and is missing in some fonts.
    dollar      = { "$" },
    percent     = { "%" },
}

local symbols =
{
    branch          = {         powerline="" },
    unpublished     = {         nerdfonts2={""," "}, nerdfonts3={""," "} },
    submodule       = {         nerdfonts2={""," "}, nerdfonts3={""," "} },

    conflict        = { "!" },
    addcount        = { "+" },
    modifycount     = { "*" },
    deletecount     = { "-" },
    renamecount     = { "" },   -- Empty string counts renames as modified.
    summarycount    = { "*",    unicode="±" },
    untrackedcount  = { "?" },
    aheadbehind     = { "" },   -- Optional symbol preceding ahead/behind counts.
    aheadcount      = { ">>",   unicode="↓" },
    behindcount     = { "<<",   unicode="↑" },
    staged          = { "#",    unicode="↗" },

    battery         = { "%" },
    charging        = { "++",   nerdfonts2={""," "}, nerdfonts3={"󱐋","󱐋 "} },
    smartcharging   = { "%",    unicode="♥" },

                                -- Note: coloremoji for exit_zero requires Clink v1.4.28 or higher.
    exit_zero       = {         coloremoji="✔️", nerdfonts2={"\x1b[92m\002","\x1b[92m \002"}, nerdfonts3={"\x1b[92m\002","\x1b[92m \002"} },
    exit_nonzero    = {         coloremoji="❌", nerdfonts2={"\x1b[91m\002","\x1b[91m \002"}, nerdfonts3={"\x1b[91m\002","\x1b[91m \002"} },

    prompt          = { ">" },
    overtype_prompt = { ">",    unicode="►" },

    admin           = {         powerline="" },
    no_admin        = {         nerdfonts2={""," "} },

    vpn             = {         coloremoji="☁️", nerdfonts2={"",""}, nerdfonts3="󰖂 " },
    no_vpn          = {         coloremoji="🌎", nerdfonts2={""," "}, nerdfonts3={""," "} },

    refresh         = {         nerdfonts2="", nerdfonts3=" " },  --   
}

if ((clink.version_encoded) or 0) < 10040028 then
    -- Remove the coloremoji for exit_zero if the Clink version is too low.
    symbols.exit_zero.coloremoji = nil
end

--------------------------------------------------------------------------------
-- Wizard state.

local _wizard

local function get_errorlevel()
    if os.geterrorlevel and settings.get("cmd.get_errorlevel") then
        if _wizard then return _wizard.exit or 0 end
        return os.geterrorlevel()
    end
end

--------------------------------------------------------------------------------
-- Configuration helpers.

local pad_right_edge = " "

local function sgr(code)
    if not code then
        return "\x1b[m"
    elseif string.byte(code) == 0x1b then
        return code
    else
        return "\x1b["..code.."m"
    end
end

local getcolortable = console.getcolortable
if not getcolortable then
    getcolortable = function()
        return {
            "#0c0c0c", "#0037da", "#13a10e", "#3a96dd",
            "#c50f1f", "#881798", "#c19c00", "#cccccc",
            "#767676", "#3b78ff", "#16c60c", "#61d6d6",
            "#e74856", "#b4009e", "#f9f1a5", "#f2f2f2",
            foreground=8, background=1, default=true,
        }
    end
end

local ansi_to_vga =
{
    0,  4,  2,  6,  1,  5,  3,  7,
    8, 12, 10, 14,  9, 13, 11, 15,
}

local function rgb_from_colortable(num)
    num = num and ansi_to_vga[num + 1]
    if not num then
        return
    end
    local colortable = getcolortable()
    if not colortable or not colortable[num + 1] then
        return
    end
    local r, g, b = colortable[num + 1]:match("^#(%x%x)(%x%x)(%x%x)$")
    if not r or not g or not b then
        return
    end
    r = tonumber(r, 16)
    g = tonumber(g, 16)
    b = tonumber(b, 16)
    return r, g, b
end

local cube_series = { 0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff }
local function rgb_from_color(inner)
    local pro, r, g, b, epi = inner:match("^([34]8;2;)(%d+);(%d+);(%d+)(.*)$")
    if pro and r and g and b and epi then
        return pro, r, g, b, epi
    end
    local cube
    pro, cube, epi = inner:match("^([34]8;5;)(%d+)(.*)$") -- luacheck: no unused
    if cube then
        cube = tonumber(cube)
        if cube < 0 or cube > 255 then
            return
        elseif cube <= 15 then
            cube = cube
            r, g, b = rgb_from_colortable(cube)
            if not r or not g or not b then
                return
            end
        elseif cube >= 232 and cube <= 255 then
            r = 8 + ((cube - 232) * 10)
            g = r
            b = r
        else
            cube = cube - 16
            r = math.floor(cube / 36)
            cube = cube - r * 36
            g = math.floor(cube / 6)
            cube = cube - g * 6
            b = cube
            r = cube_series[r + 1]
            g = cube_series[g + 1]
            b = cube_series[b + 1]
        end
        pro = inner:sub(1, 1).."8;2;"
        return pro, r, g, b, epi
    end
    local n = 0
    local bold = false
    local tag = 0
    epi = ""
    for i = 1, #inner + 1 do
        local x = inner:byte(i)
        if x == 0x3b or not x then
            if n == 1 then
                bold = true
            elseif (n >= 30 and n <= 37) or
                    (n >= 40 and n <= 47) or
                    (n >= 90 and n <= 97) or
                    (n >= 100 and n <= 107) or
                    n == 39 or n == 49 then
                if tag == 0 then
                    tag = n
                end
            else
                if #epi > 0 then
                    epi = epi..";"
                end
                epi = epi..tostring(n)
            end
            if not x then
                break
            end
            n = 0
        elseif x >= 0x30 and x <= 0x39 then
            n = (n * 10) + (x - 0x30)
        elseif x == 0x6d then
            break
        else
            return
        end
    end
    if tag == 0 then
        tag = 39
    end
    if tag >= 90 then
        bold = true
        tag = tag - 60
    end
    local fore = (tag >= 30 and tag < 40)
    tag = math.fmod(tag, 10) + (bold and 8 or 0)
    r, g, b = rgb_from_colortable(tag)
    if not r or not g or not b then
        return
    end
    return (fore and "38;2;" or "48;2;"), r, g, b, epi
end

local function blend_color(code1, code2, opacity1)
    opacity1 = opacity1 or 0.5
    if opacity1 < 0 or opacity1 > 1 then
        return
    end
    local inner1 = code1:match("^\x1b%[(.*)m$") or code1
    local inner2 = code2:match("^\x1b%[(.*)m$") or code2
    if inner1:find("\x1b") or inner2:find("\x1b") then
        return
    end
    local pro1, r1, g1, b1, epi1 = rgb_from_color(inner1)
    if not pro1 or not r1 or not g1 or not b1 then
        return
    end
    local _, r2, g2, b2 = rgb_from_color(inner2)
    if not r2 or not g2 or not b2 then
        return
    end
    local r = math.floor((tonumber(r1) * opacity1) + (tonumber(r2) * (1 - opacity1)))
    local g = math.floor((tonumber(g1) * opacity1) + (tonumber(g2) * (1 - opacity1)))
    local b = math.floor((tonumber(b1) * opacity1) + (tonumber(b2) * (1 - opacity1)))
    local ret = pro1..string.format("%u;%u;%u", r, g, b)..epi1
    if inner1 ~= code1 then
        ret = sgr(ret)
    end
    return ret
end

local _can_use_extended_colors = nil
local function can_use_extended_colors(force)
    if _can_use_extended_colors == nil or force then
        _can_use_extended_colors = flexprompt.settings.use_8bit_color
        if _can_use_extended_colors == nil then
            _can_use_extended_colors = false
            if clink.getansihost then
                local host = clink.getansihost()
                if host == "winconsolev2" or host == "winterminal" then
                    _can_use_extended_colors = true
                end
            end
        end
    end
    return _can_use_extended_colors
end

local function get_best_fg(color)
    if can_use_extended_colors() then
        return color.extfg or color.fg
    end
    return color.fg
end

local function get_best_bg(color)
    if can_use_extended_colors() then
        return color.extbg or color.bg
    end
    return color.bg
end

local function use_best_color(normal, extended)
    return can_use_extended_colors() and extended or normal
end

local function get_style()
    -- Indexing into the styles table validates that the style name is
    -- recognized.
    return flexprompt.choices.styles[flexprompt.settings.style or "lean"] or "lean"
end

local _charset
local function get_charset()
    if not _charset then
        -- Indexing into the charsets table validates that the charset name is
        -- recognized.
        if flexprompt.settings.no_graphics then
            _charset = "ascii"
        else
            _charset = flexprompt.choices.charsets[flexprompt.settings.charset or "unicode"] or "unicode"
        end
    end
    return _charset
end

local _nerdfonts_version
local function get_nerdfonts_version()
    if not _nerdfonts_version then
        local ver
        local t = type(flexprompt.settings.nerdfonts_version)
        if t == "string" or t == "number" then
            ver = tostring(flexprompt.settings.nerdfonts_version)
            if ver == "" then
                ver = nil
            end
        end
        if not ver then
            local env = os.getenv("FLEXPROMPT_NERDFONTS_VERSION")
            if env then
                local num = tonumber(env:gsub("^ +", ""))
                if num then
                    ver = tostring(num)
                    if ver == "" then
                        ver = nil
                    end
                end
            end
        end
        if ver then
            _nerdfonts_version = "nerdfonts" .. ver
        end
    end
    return not flexprompt.settings.no_graphics and _nerdfonts_version or nil
end

local _nerdfonts_width
local function get_nerdfonts_width()
    if not _nerdfonts_width then
        if flexprompt.settings.nerdfonts_width == 2 then
            _nerdfonts_width = 2
        else
            local env = os.getenv("FLEXPROMPT_NERDFONTS_WIDTH")
            if env and tonumber(env) == 2 then
                _nerdfonts_width = 2
            else
                _nerdfonts_width = 1
            end
        end
    end
    return _nerdfonts_width
end

local function get_lines()
    return flexprompt.choices.lines[flexprompt.settings.lines or "one"] or 1
end

local function get_spacing()
    if clink_prompt_spacing then
        return "normal"
    else
        -- Indexing into the spacing table validates that the spacing name is
        -- recognized.
        return flexprompt.choices.spacing[flexprompt.settings.spacing or "normal"] or "normal"
    end
end

local function get_connector()
    local connector = flexprompt.settings.connection or "disconnected"
    if flexprompt.choices.connections[connector] then
        return flexprompt.choices.connections[connector]
    end
    if console.cellcount(connector) == 1 then
        return connector
    end
    return " "
end

local function lookup_color(args)
    if not args or type(args) == "table" then
        return args[get_style()] or args
    end

    if args and not args:match("^[0-9]") then
        local color = flexprompt.colors[args]
        if color then
            local redirect = color[get_style()]
            if redirect then
                if type(redirect) == "table" then
                    color = redirect
                else
                    color = flexprompt.colors[redirect]
                end
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
    if not _charset then get_charset() end
    if _charset == "ascii" then return end

    local l = flexprompt.choices.left_frames[flexprompt.settings.left_frame or "none"]
    local r = flexprompt.choices.right_frames[flexprompt.settings.right_frame or "none"]
    if l and #l == 0 then
        l = nil
    end
    if r and #r == 0 then
        r = nil
    end
    return l, r
end

local function get_frame_color()
    local frame_color = flexprompt.settings.frame_color or "light"
    if type(frame_color) ~= table then
        frame_color = flexprompt.choices.frame_colors[frame_color] or frame_color
    end

    if type(frame_color) ~= "table" then
        frame_color = { frame_color, frame_color, frame_color }
    end

    frame_color =
    {
        lookup_color(frame_color[fc_frame]),
        lookup_color(frame_color[fc_back]),
        lookup_color(frame_color[fc_fore]),
        lookup_color(frame_color[fc_sep] or frame_color[fc_frame]),
    }

    return frame_color
end

local function resolve_symbol_table(symbol)
    if type(symbol) ~= "table" then
        return symbol
    else
        local ret
        if not flexprompt.settings.no_graphics then
            local term = clink.getansihost and clink.getansihost() or nil
            if flexprompt.settings.use_color_emoji and term == "winterminal" and symbol["coloremoji"] then
                ret = symbol["coloremoji"]
            elseif term and symbol[term] then
                ret = symbol[term]
            else
                local nf = get_nerdfonts_version()
                if symbol[nf] then
                    symbol = symbol[nf]
                    if type(symbol) == "table" then
                        if get_nerdfonts_width() == 2 then
                            ret = symbol[2] or symbol[1]
                        else
                            ret = symbol[1]
                        end
                    else
                        ret = symbol
                    end
                elseif flexprompt.settings.powerline_font and symbol["powerline"] then
                    ret = symbol["powerline"]
                end
            end
        end
        if not ret then
            local charset = get_charset()
            ret = symbol[charset] or symbol[1]
        end
        return ret
    end
end

local function get_symbol(name, fallback)
    local settings_symbols = flexprompt.settings.symbols
    local symbol = settings_symbols and settings_symbols[name] or symbols[name] or fallback or ""
    symbol = resolve_symbol_table(symbol)
    if not symbol then
        symbol = resolve_symbol_table(symbols[name] or fallback or "")
    end
    return symbol or ""
end

local function get_icon(name)
    if flexprompt.settings.no_graphics or not flexprompt.settings.use_icons then return "" end
    if type(flexprompt.settings.use_icons) == "table" and not flexprompt.settings.use_icons[name] then return "" end

    return get_symbol(name)
end

local function get_prompt_symbol_color()
    local color
    if flexprompt.settings.prompt_symbol_color then
        color = flexprompt.settings.prompt_symbol_color
    else
        local err = get_errorlevel()
        if err then
            color = (err == 0) and
                    (flexprompt.settings.exit_zero_color or "realbrightgreen") or
                    (flexprompt.settings.exit_nonzero_color or "realbrightred")
        end
    end
    color = color or "brightwhite"
    color = lookup_color(color)
    return sgr(get_best_fg(color))
end

local function get_prompt_symbol()
    local p = nil
    if rl.insertmode and not rl.insertmode() then
        p = get_symbol("overtype_prompt", "►")
    end
    return p or get_symbol("prompt", ">")
end

local function get_transient_prompt_symbol()
    local p = get_symbol("transient_prompt")
    if p ~= "" then
        return p
    end
    return get_symbol("prompt", ">")
end

local function get_flow()
    -- Indexing into the flows table validates that the flow name is recognized.
    return flexprompt.choices.flows[flexprompt.settings.flow or "concise"] or "concise"
end

local function make_fluent_text(text, force)
    if not force and get_style() == "rainbow" then
        return text
    else
        local t = type(force)
        if t == "string" or t == "table" then
            local color = lookup_color(force)
            if color then
                return sgr(get_best_fg(color)) .. text .. "\002"
            end
        end
        return "\001" .. text .. "\002"
    end
end

local function get_screen_width()
    return _wizard and _wizard.width or console.getwidth()
end

local function connect(lhs, rhs, frame, sgr_frame_color)
    local lhs_len = console.cellcount(lhs)
    local rhs_len = console.cellcount(rhs)
    local frame_len = console.cellcount(frame)
    local width = get_screen_width() - #pad_right_edge
    local gap = width - (lhs_len + rhs_len + frame_len)
    local dropped
    if gap < 0 then
        gap = gap + rhs_len
        rhs_len = 0 -- luacheck: no unused
        rhs = ""
        if gap < 0 then
            gap = gap + frame_len
            frame_len = 0 -- luacheck: no unused
            frame = ""
        end
        dropped = true
    end
    if gap > 0 then
        if not sgr_frame_color then
            sgr_frame_color = sgr(get_best_fg(flexprompt.colors.red))
        end
        lhs = lhs .. sgr_frame_color .. string.rep(get_connector(), gap)
    end
    return lhs..rhs..frame, dropped
end

local _refilter_modules
local _module_results = {}
local function refilter_module(module)
    _refilter_modules = _refilter_modules or {}
    _refilter_modules[module] = true
end

local function reset_render_state(keep_results)
    _can_use_extended_colors = nil
    _charset = nil
    _nerdfonts_version = nil
    _nerdfonts_width = nil
    _wizard = nil
    _refilter_modules = nil
    if not keep_results then
        _module_results = {}
    end
end

local list_on_reset_render_state = {}
local function add_on_reset_render_state(func)
    table.insert(list_on_reset_render_state, func)
end

--------------------------------------------------------------------------------
-- Other helpers.

local function spairs(t, order)
    local keys = {}
    local num = 0
    for k in pairs(t) do
        num = num + 1
        keys[num] = k
    end

    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

local function get_parent(dir)
    local parent = path.toparent(dir)
    if parent and parent ~= "" and parent ~= dir then
        return parent
    end
end

local function has_dir(dir, subdir)
    local test = path.join(dir, subdir)
    return os.isdir(test) and test or nil
end

local function has_file(dir, file)
    local test = path.join(dir, file)
    return os.isfile(test) and test or nil
end

local function append_text(lhs, rhs)
    if not lhs then return rhs and tostring(rhs) or "" end
    if not rhs then return tostring(lhs) end

    lhs = tostring(lhs)
    rhs = tostring(rhs)

    if #lhs > 0 and #rhs > 0 then
        return lhs .. " " .. rhs
    else
        return lhs .. rhs
    end
end

local function maybe_apply_tilde(dir, force)
    if force or flexprompt.settings.use_home_tilde then
        local home = os.getenv("HOME")
        if home and string.find(string.lower(dir), string.lower(home), 1, true--[[plain]]) == 1 then
            dir = "~" .. string.sub(dir, #home + 1)
            return dir, true
        end
    end
    return dir
end

local function get_default_prompts()
    local style = get_style()
    local prompts = flexprompt.choices.prompts[style]["both"]
    local left_prompt = prompts[1]
    local right_prompt = prompts[2]
    if flexprompt.default_prompt_append then
        left_prompt = left_prompt .. (flexprompt.default_prompt_append.left_prompt or "")
        right_prompt = (flexprompt.default_prompt_append.right_prompt or "") .. right_prompt
    end
    return left_prompt, right_prompt
end

local function is_module_in_prompt(name)
    local pattern = "{" .. name .. "[:}]"
    local top_prompt = flexprompt.settings.top_prompt
    local left_prompt = flexprompt.settings.left_prompt
    local right_prompt = flexprompt.settings.right_prompt
    if not top_prompt and not left_prompt and not right_prompt then
        left_prompt, right_prompt = get_default_prompts()
    end

    local is = 0
    if top_prompt and top_prompt:match(pattern) then
        is = is + 1
    end
    if left_prompt and left_prompt:match(pattern) then
        is = is + 1
    end
    if right_prompt and right_prompt:match(pattern) then
        is = is + 2
    end
    if is > 0 then
        return is
    end
end

local function unicode_normalize(s)
    if unicode.normalize then
        return unicode.normalize(3, s)
    else
        return s
    end
end

local function first_letter(s)
    if unicode.iter then
        -- This handles combining marks, but does not yet handle ZWJ (0x200d)
        -- such as in emoji sequences.
        local letter = ""
        for codepoint, value, combining in unicode.iter(s) do
            if value == 0x200d then
                break
            elseif not combining and #letter > 0 then
                break
            end
            letter = letter .. codepoint
        end
        return letter
    else
        return s:sub(1, 1)
    end
end

local function abbrev_child(parent, child)
    local letter = first_letter(child)
    if not letter or letter == "" then
        return child, false
    end

    local any = false
    local lcd = 0
    local dirs = os.globdirs(path.join(parent, letter .. "*"))
    for _, x in ipairs(dirs) do
        local m = string.matchlen(child, x)
        if lcd < m then
            lcd = m
        end
        any = true
    end
    lcd = (lcd >= 0) and lcd or 0

    if not any then
        return child, false
    end

    local abbr = child:sub(1, lcd) .. first_letter(child:sub(lcd + 1))
    return abbr, abbr ~= child
end

local function abbrev_path(dir, fluent, all)
    -- Removeable drives could be floppy disks or CD-ROMs, which are slow.
    -- Network drives are slow.  Invalid drives are unknown.  If the drive
    -- type might be slow then don't abbreviate.
    local tilde, tilde_len = dir:find("^~[/\\]+")
    local s, parent

    local drivetype, parse
    local drive = path.getdrive(dir) or ""
    if tilde then
        parent = os.getenv("HOME")
        drive = path.getdrive(parent) or ""
        drivetype = os.getdrivetype(drive)
        s = "~"
        parse = dir:sub(tilde_len + 1)
    elseif drive ~= "" then
        local seps
        parent = drive
        drivetype = os.getdrivetype(drive)
        seps, parse = dir:match("^([/\\]*)(.*)$", #drive + 1)
        s = drive
        if #seps > 0 then
            parent = parent .. "\\"
            s = s .. "\\"
        end
    else
        parent = os.getcwd()
        drive = path.getdrive(parent) or ""
        drivetype = os.getdrivetype(drive)
        s = ""
        parse = dir
    end

    if drivetype ~= "fixed" and drivetype ~= "ramdisk" then
        return dir
    end

    local components = {}
    while true do
        local up, child = path.toparent(parse)
        if #child > 0 then
            table.insert(components, child .. "\\")
        else
            if #up > 0 then
                table.insert(components, up)
            end
            break
        end
        parse = up
    end

    local first = #components
    if tilde then
        first = first - 1
    end

    for i = first, 1, -1 do
        local child = components[i]
        local this_dir = path.join(parent, child)
        local special = not all and (i == 1 or i == #components or flexprompt.is_git_dir(this_dir))
        if special then
            s = path.join(s, child)
        else
            local text, abbreviated = abbrev_child(parent, child)
            if abbreviated and fluent then
                s = path.join(s, make_fluent_text(text, fluent))
            else
                s = path.join(s, text)
            end
        end
        parent = this_dir
    end

    dir = s:gsub("[/\\]+$", "")
    return dir
end

--------------------------------------------------------------------------------
-- Overtype helpers.

local _insertmode

local function insertmode_onbeginedit()
    if rl.insertmode then
        -- Readline _always_ sets it true at the beginning of a new edit line.
        -- But that happens _after_ prompt filtering.  Since flexprompt can show
        -- the insert/overtype mode in the prompt, it's necessary to forcibly
        -- reset it ourselves.  Otherwise in certain cases (such as reloading
        -- Lua) the prompt initially shows an inaccurate insert/overtype mode.
        _insertmode = rl.insertmode(true)
    end
end

if clink.onaftercommand then
    local function insertmode_aftercommand()
        if _insertmode ~= rl.insertmode() then
            _insertmode = rl.insertmode()
            if (flexprompt.get_symbol("overtype_prompt") ~= flexprompt.get_symbol("prompt") or
                    is_module_in_prompt("overtype")) then
                flexprompt.refilter_module("overtype")
                clink.refilterprompt()
            end
        end
    end

    clink.onaftercommand(insertmode_aftercommand)
end

--------------------------------------------------------------------------------
-- Helpers for duration, exit code, and time.

local duration_modules
local endedit_time
local last_duration
local last_time

-- Clink v1.2.30 has a fix for Lua's os.clock() implementation failing after the
-- program has been running more than 24 days.  Without that fix, os.time() must
-- be used instead, but the resulting duration can be off by up to +/- 1 second.
local duration_clock = ((clink.version_encoded or 0) >= 10020030) and os.clock or os.time

local function duration_onbeginedit()
    last_duration = nil
    duration_modules = nil
    flexprompt.settings.force_duration = nil
    if endedit_time then
        local beginedit_time = duration_clock()
        local elapsed = beginedit_time - endedit_time
        if elapsed >= 0 then
            last_duration = elapsed
        end
    end
end

local function duration_onendedit()
    endedit_time = duration_clock()
end

local function time_onbeginedit()
    last_time = nil
end

add_on_reset_render_state(time_onbeginedit)

--------------------------------------------------------------------------------
-- Segments.

local segmenter = nil

-- `\001` => Fluent text foreground color.
-- `\002` => Restore base color of segment (foreground and background).
-- `\003` => Frame color (foreground and background).
-- `\004` => Separator foreground color.
local function resolve_color_codes(text, base_color)
    local frame_color = segmenter.frame_color
    text = string.gsub(text, "\001", sgr(get_best_fg(frame_color[fc_fore]))):gsub("\002", base_color)
    if text:find("\003") then
        text = text:gsub("\003", sgr("0;" .. get_best_fg(frame_color[fc_frame])))
    end
    if text:find("\004") then
        text = text:gsub("\004", sgr(get_best_fg(frame_color[fc_sep])))
    end
    return text
end

local function init_segmenter(side, frame_color)
    local charset = get_charset()
    local open_caps, close_caps, separators, altseparators

    if side == 0 then
        open_caps = flexprompt.settings.tails or "flat"
        close_caps = flexprompt.settings.heads or "flat"
    else
        open_caps = flexprompt.settings.heads or "flat"
        close_caps = flexprompt.settings.tails or "flat"
    end
    if type(open_caps) ~= "table" then
        if charset == "ascii" then
            open_caps = flexprompt.choices.caps["flat"]
        else
            open_caps = flexprompt.choices.caps[open_caps] or flexprompt.choices.caps["flat"]
        end
    end
    if type(close_caps) ~= "table" then
        if charset == "ascii" then
            close_caps = flexprompt.choices.caps["flat"]
        else
            close_caps = flexprompt.choices.caps[close_caps] or flexprompt.choices.caps["flat"]
        end
    end

    segmenter = {}
    segmenter.side = side
    segmenter.style = get_style()
    segmenter.frame_color = frame_color
    segmenter.back_color = flexprompt.colors.default
    segmenter.open_cap = open_caps[1]
    segmenter.close_cap = close_caps[2]

    local sep_index = side + 1      -- Overridden later if sep is an end cap.
    local altsep_index = side + 1

    if segmenter.style == "lean" then
        local available_separators = flexprompt.choices.separators
        separators = flexprompt.settings.lean_separators or "space"

        if type(separators) ~= "table" then
            if available_separators[separators] then
                local pad = separators ~= "none" and separators ~= "space" and separators ~= "spaces"
                separators = available_separators[separators]
                if pad then
                    local pads = {}
                    if separators[1] then
                        pads[1] = " " .. separators[1] .. " "
                    end
                    if separators[2] then
                        pads[2] = " " .. separators[2] .. " "
                    end
                    separators = pads
                end
            end
            if separators.lean then
                separators = separators.lean
            end
        end

        segmenter.open_cap = ""
        segmenter.close_cap = ""
    else
        -- If separators missing, default to heads.  If heads missing, default
        -- to "flat".  Note that "flat" end cap redirects to "bar" or "vertical"
        -- separators.
        separators = flexprompt.settings.separators or flexprompt.settings.heads

        -- Rainbow needs to know available_separators for setting up
        -- altseparators, for when bg == fg.
        local available_separators = (charset == "ascii") and flexprompt.choices.ascii_separators or flexprompt.choices.separators

        if segmenter.style == "classic" then
            -- If separators (still) missing, default based on charset.
            if not separators then
                separators = (charset == "ascii") and "bar" or "vertical"
            end

            -- If specified separators not found, use it as a literal separator.
            separators = available_separators[separators] or separators
        else
            -- If separators (still) missing, default to "flat".
            if not separators then
                separators = "flat"
            end

            local sep_name = separators

            -- If specified separators not found, use it as a literal separator.
            local available_caps = (charset == "ascii") and flexprompt.choices.ascii_caps or flexprompt.choices.caps
            separators = available_caps[sep_name] or available_caps["none"]
            sep_index = (1 - side) + 1 -- Convert to an end cap index.

            -- Set up altseparators, if available, for when bg == fg.
            altseparators = available_separators[sep_name]
        end
    end

    local resolve_separator = function(separators, index) -- luacheck: ignore 431
        if not separators then return end

        if type(separators) == "table" then
            separators = separators[index]
        end

        if separators == "connector" then
            local connector = get_connector()
            if segmenter.style == "lean" then
                connector = " " .. connector .. " "
            end
            separators = sgr(flexprompt.colors.default.bg .. ";" .. get_best_fg(segmenter.frame_color[fc_frame])) .. connector
        else
            separators = resolve_color_codes(separators, "")
        end

        if separators and flexprompt.settings.no_graphics then
            local t = separators
            if type(t) ~= "table" then
                t = { t }
            end
            for _, s in ipairs(t) do
                if s:find("[\x01-\x1f\x80-\xff]") then
                    separators = ""
                    break
                end
            end
        end

        return separators
    end

    segmenter.separator = resolve_separator(separators, sep_index)
    segmenter.altseparator = resolve_separator(altseparators, altsep_index)
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

    local primary = swap and color or segmenter.back_color
    local secondary = swap and segmenter.back_color or color

    local out
    if segmenter.style == "rainbow" then
        if get_best_bg(segmenter.back_color) == get_best_bg(color) and segmenter.altseparator then
            out = sgr(get_best_fg(segmenter.frame_color[fc_sep])) .. segmenter.altseparator
        elseif not symbol:find("^\x1b") then
            if primary == flexprompt.colors.default then
                out = sgr(get_best_bg(primary) .. ";" .. get_best_fg(secondary) .. ";7") .. symbol .. sgr("27")
            end
        end
    end

    if not out then
        if segmenter.style == "rainbow" then
            out = sgr(get_best_fg(primary) .. ";" .. get_best_bg(secondary)) .. symbol
        else
            out = sgr(get_best_bg(primary) .. ";" .. get_best_fg(secondary)) .. symbol
        end
    end

    if flexprompt.debug_logging then
        log.info(string.format('transition "%s", close %d, side %d, ', out, close, segmenter.side))
    end
    return out
end

local function next_segment(text, color, rainbow_text_color, isbreak, pending_segment)
    local out = ""

    if pending_segment then
        out = next_segment(pending_segment.text, lookup_color(pending_segment.color), pending_segment.altcolor, pending_segment.isbreak)
    end

    local wasbreak = segmenter.isbreak
    segmenter.isbreak = isbreak

    if not color then color = flexprompt.colors.red end

    if rainbow_text_color then rainbow_text_color = lookup_color(rainbow_text_color) end
    if not rainbow_text_color then rainbow_text_color = color.altcolor end
    if not rainbow_text_color then rainbow_text_color = lookup_color("rainbow_text") end
    if not rainbow_text_color then rainbow_text_color = flexprompt.colors.brightred end

    local sep
    local transition_color = color
    local back, fore
    local classic = segmenter.style == "classic"
    local rainbow = segmenter.style == "rainbow"

    if segmenter.open_cap then
        sep = segmenter.open_cap
        if not rainbow then
            transition_color = segmenter.frame_color[fc_back]
            back = get_best_bg(segmenter.frame_color[fc_back])
            fore = get_best_fg(segmenter.frame_color[fc_fore])
        end
    else
        sep = segmenter.separator
        if not rainbow then
            transition_color = segmenter.frame_color[fc_sep]
        end
    end

    local override_style = segmenter.style
    if segmenter.override_separator then
        sep = segmenter.override_separator
        transition_color = segmenter.frame_color[fc_back]
        override_style = segmenter.override_style
        segmenter.override_separator = nil
        segmenter.override_back_color = nil
        segmenter.override_style = nil
    end

    local pad = (segmenter.style == "lean" -- Lean has no padding.
                 or text == "") -- Segment with empty string has no padding.
                 and "" or " "

    if not text then
        if segmenter.style ~= "lean" and not segmenter.open_cap then
            out = out .. color_segment_transition(color, segmenter.close_cap, true)
        end
        return out
    end

    local override_back_color
    if classic and text == "" then
        local charset = get_charset()
        local available_caps = (charset == "ascii") and flexprompt.choices.ascii_caps or flexprompt.choices.caps
        local cap = available_caps[flexprompt.settings.separators]
        if cap then
            sep = cap[2 - segmenter.side]
            override_style = "rainbow"
            segmenter.override_separator = sep
            segmenter.override_back_color = true
            segmenter.override_style = override_style
            transition_color = color
            override_back_color = transition_color
        end
    end

    if override_style then
        local restore_style = segmenter.style
        segmenter.style = override_style
        out = out .. color_segment_transition(transition_color, sep)
        segmenter.style = restore_style
    else
        out = out .. color_segment_transition(transition_color, sep)
    end
    if fore then
        out = out .. sgr(back .. ";" .. fore)
    end

    -- A module with an empty string is a segment break.  When there's no
    -- separator, force a break by showing one connector character using the
    -- frame color.
    if text == "" and sep:gsub(" ", "") == "" then
        local connector = get_connector()
        text = make_fluent_text(sgr(flexprompt.colors.default.bg .. ";" .. get_best_fg(segmenter.frame_color[fc_frame])) .. connector)
    end

    -- Applying 'color' goes last so that the module can override other colors
    -- if it really wants to.  E.g. by returning "41;30" as the color a module
    -- can force the segment color to be black on red, even in classic or lean
    -- styles.  But doing that in the rainbow style will garble segment
    -- transition colors.
    local base_color
    if rainbow then
        base_color = sgr(get_best_fg(rainbow_text_color) .. ";" .. get_best_bg(color))
    elseif classic then
        base_color = sgr(get_best_bg(segmenter.frame_color[fc_back]) .. ";" .. get_best_fg(color))
    else
        base_color = sgr("49;" .. get_best_fg(color))
    end

    out = out .. base_color

    -- Add leading pad character.  Except in classic style if two segments are
    -- immediately adjacent; in that case it would look like double-padding.
    if pad ~= "" and not (classic and not wasbreak and (sep == "" or sep == " ") and not segmenter.open_cap) then
        out = out .. pad
    end

    text = resolve_color_codes(text, base_color) .. pad
    if flexprompt.debug_logging then
        log.info(string.format('segment "%s", side %d', text, segmenter.side))
    end
    out = out .. text

    if override_back_color then
        segmenter.back_color = override_back_color
    elseif rainbow then
        segmenter.back_color = color
    elseif classic then
        segmenter.back_color = segmenter.frame_color[fc_back]
    end

    segmenter.open_cap = nil

    return out
end

--------------------------------------------------------------------------------
-- Coroutines.

local function promptcoroutine_manager()
    if _cached_state.coroutines then
        for _,entry in pairs(_cached_state.coroutines) do
            entry.func(true--[[async]])
        end
    end
end

local function promptcoroutine(func)
    if not segmenter._current_module then return end

    _cached_state.coroutines = _cached_state.coroutines or {}

    local entry = _cached_state.coroutines[segmenter._current_module]
    if entry == nil then
        entry = { done=false, result=nil }
        _cached_state.coroutines[segmenter._current_module] = entry

        -- Wrap func to track completion and result.
        entry.func = function (async)
            local o = func(async)
            entry.done = true
            entry.result = o
        end

        local async = settings.get("prompt.async")
        if async then
            -- Create the prompt coroutine manager if needed.
            if not _cached_state.has_promptcoroutine then
                clink.promptcoroutine(promptcoroutine_manager)
                _cached_state.has_promptcoroutine = true
            end
        else
            -- Create coroutine for running func synchronously.  We must
            -- maintain func's expectation that it is run as a coroutine, even
            -- when it's not being run asynchronously.
            local c = coroutine.create(function ()
                entry.func(false--[[async]])
            end)

            -- Run the coroutine synchronously.
            local max_iter = 25
            for iteration = 1, max_iter + 1, 1 do
                -- Pass false to let it know it is not async.
                local result, _ = coroutine.resume(c)
                if result then
                    if coroutine.status(c) == "dead" then
                        break
                    end
                else
                    if _ and type(_) == "string" then
                        _error_handler(_)
                    end
                    break
                end
                -- Cap iterations when running synchronously, in case it's
                -- poorly behaved.
                if iteration >= max_iter then
                    -- Ideally this could print an error message about
                    -- abandoning a misbehaving coroutine, but that would mess
                    -- up the prompt and input line display.
                    break
                end
            end

            -- Update the entry indicating completion, even if the loop ended
            -- before func ever returned.
            entry.done = true
        end
    end

    return entry.result
end

--------------------------------------------------------------------------------
-- Module parsing and rendering.

local _module_costs = {}
local function log_cost(tick, module)
    local elapsed = (os.clock() - tick) * 1000
    local cost = _module_costs[module] or {}
    cost.milliseconds = elapsed
    if not cost.peak or cost.peak < elapsed then
        cost.peak = elapsed
    end
    cost.count = (cost.count or 0) + 1
    cost.total = (cost.total or 0) + elapsed
    _module_costs[module] = cost
end

local function normalize_segment_table(t)
    if t[1] then
        return { text=t[1], color=t[2], altcolor=t[3], isbreak=t.isbreak, condense_callback=t.condense_callback }
    elseif t.text then
        return t
    end
end

local function render_module(name, args, try_condense)
    local key = string.lower(name)
    local results = _module_results[key]

    if try_condense then
        if results then
            -- Don't modify the existing table; it needs to stay
            -- unmodified so resizing the terminal wider can uncondense.
            local ret = {}
            for _, segment in ipairs(results) do
                if segment.condense_callback then
                    local s = segment.condense_callback()
                    table.insert(ret, {
                        text = s.text or segment.text,
                        color = s.color or segment.color,
                        altcolor = s.altcolor or segment.altcolor,
                        isbreak = s.isbreak or segment.isbreak,
                    })
                else
                    table.insert(ret, segment)
                end
            end
            results = ret
        end
        return results
    end

    if _refilter_modules and not _refilter_modules[key] then
        if results then
            return results
        end
    end

    local func = modules[key]
    if func then
        local tick = os.clock()
        local a, b, c = func(args)
        log_cost(tick, key)
        if a == nil then
            results = nil
        elseif type(a) ~= "table" then
            -- Not a table means func() returned up to 3 strings.
            results = { { text=a, color=b, altcolor=c } }
        elseif type(a[1]) ~= "table" then
            -- A table with no nested tables means func() returned one segment,
            -- but it could be in either of two different formats.
            results = normalize_segment_table(a)
            if results then
                results = { results }
            end
        else
            -- A table of tables means func() returned one or more segments,
            -- but each could be in either of two different formats.
            results = {}
            for _, t in ipairs(a) do
                table.insert(results, normalize_segment_table(t))
            end
            if #results == 0 then
                results = nil
            end
        end
        _module_results[key] = results
        return results
    end
end

local function render_modules(prompt, side, frame_color, condense, anchors)
    local out = ""
    local init = 1

    init_segmenter(side, frame_color)

    local oncommands
    if type(flexprompt.settings.oncommands) == "table" then
        -- Already in table form?  Use it as is.
        -- Scheme:  oncommands[module] = { cmd1, cmd2, ... }
        oncommands = flexprompt.settings.oncommands
    elseif type(flexprompt.settings.oncommands) == "string" then
        -- Build oncommands table from string.
        -- Format:  "moduleA=cmd1,moduleA=cmd2,moduleB=cmd3"
        -- Delimiters are space, comma, or semicolon (all are interchangeable).
        oncommands = {}
        for _,s in ipairs(string.explode(flexprompt.settings.oncommands, " ,;")) do
            local m,c = s:match("^([^ =]+)=(.+)$")
            if m then
                m = clink.lower(m)
                c = clink.lower(c)
                if not oncommands[m] then
                    oncommands[m] = {}
                end
                table.insert(oncommands[m], c)
            end
        end
    end

    if flexprompt.debug_logging then
        log.info('BEGIN render_modules')
    end

    local any_condense_callbacks
    local pending_segment
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

        -- If the module is in the oncommands table then only show it if one of
        -- the associated commands is entered.
        if oncommands and oncommands[name:lower()] then
            local n = name
            name = nil
            if _cached_state.command then
                for _,c in ipairs(oncommands[n:lower()]) do
                    if string.equalsi(c, _cached_state.command) then
                        name = n
                        break
                    end
                end
            end
        end

        segmenter._current_module = name

        if name and #name > 0 then
            local results = render_module(name, args, condense)
            if results then
                if anchors then
                    -- Add 1 because the separator isn't added yet.
                    anchors[1] = console.cellcount(out) + 1
                end

                for _,segment in pairs(results) do
                    if segment then
                        if segment.isbreak then
                            if out ~= "" then
                                pending_segment = segment
                            end
                        else
                            out = out .. next_segment(segment.text, lookup_color(segment.color), segment.altcolor, segment.isbreak, pending_segment)
                            pending_segment = nil
                        end
                        if segment.condense_callback then
                            any_condense_callbacks = true
                        end
                    end
                end
            end
        end

        segmenter._current_module = nil
    end

    out = out .. next_segment(nil, flexprompt.colors.default, nil, nil)

    if anchors then
        anchors[2] = console.cellcount(out)
    end

    if flexprompt.debug_logging then
        log.info('END render_modules')
    end

    return out, any_condense_callbacks
end

local function render_prompts(render_settings, need_anchors, condense)
    reset_render_state(condense)

    local old_settings = flexprompt.settings
    if render_settings then
        flexprompt.settings = render_settings
        if render_settings.wizard then
            reset_render_state(condense)
            _wizard = render_settings.wizard
            local screenwidth = _wizard.screenwidth or console.getwidth()
            _wizard.width = _wizard.width or (screenwidth - 8)
            _wizard.prefix = ""
            if _wizard.width < screenwidth then
                _wizard.prefix = string.rep(" ", (screenwidth - _wizard.width) / 2)
            end
        end
    end

    local style = get_style()
    local lines = get_lines()

    local top_prompt = flexprompt.settings.top_prompt
    local left_prompt = flexprompt.settings.left_prompt
    local right_prompt = flexprompt.settings.right_prompt
    if not top_prompt and not left_prompt and not right_prompt then
        left_prompt, right_prompt = get_default_prompts()
    end

    local can_condense = nil
    local any_condense_callbacks

    local top = ""
    local left1 = "" -- luacheck: no unused
    local right1
    local rightframe1
    local left2 = nil
    local right2 = nil

    local anchors = need_anchors and {} or nil
    local left_frame, right_frame
    if lines > 1 then
        left_frame, right_frame = get_frame()
    end
    local frame_color = get_frame_color()
    local sgr_frame_color = sgr("0;" .. get_best_fg(frame_color[fc_frame])) or nil

    -- Padding around left/right segments for lean style.
    local pad_frame = (style == "lean") and " " or ""

    -- Top -------------------------------------------------------------------

    if top_prompt then
        local orig_style = flexprompt.settings.style
        flexprompt.settings.style = flexprompt.settings.top_style or flexprompt.settings.style
        top, any_condense_callbacks = render_modules(top_prompt, 0, frame_color, condense)
        can_condense = can_condense or any_condense_callbacks
        flexprompt.settings.style = orig_style
    end

    -- Line 1 ----------------------------------------------------------------

    do
        left1, any_condense_callbacks = render_modules(left_prompt or "", 0, frame_color, condense, anchors)
        can_condense = can_condense or any_condense_callbacks

        if left_frame then
            if left1 ~= "" then
                left1 = pad_frame .. left1
            end
            left1 = sgr_frame_color .. left_frame[1] .. left1
        end

        if lines == 1 then
            left1 = left1 .. sgr() .. " "
            if style == "lean" then
                left1 = left1 .. get_prompt_symbol_color() .. get_prompt_symbol() .. sgr() .. " "
            end
        end

        if right_prompt then
            right1, any_condense_callbacks = render_modules(right_prompt, 1, frame_color, condense)
            can_condense = can_condense or any_condense_callbacks
        end

        if right_frame then
            rightframe1 = sgr_frame_color
            if right1 and right1 ~= "" then
                rightframe1 = rightframe1 .. pad_frame
            end
            rightframe1 = rightframe1 .. right_frame[1]
        end

        if rl.ismodifiedline and lines == 1 and not is_module_in_prompt("modmark") then
            if rl.ismodifiedline() then
                left1 = sgr("0;" .. (settings.get("color.modmark") or "")) .. "*" .. left1
            end
        end
    end

    -- Line 2 ----------------------------------------------------------------

    if lines > 1 then
        left2 = ""
        right2 = ""

        if left_frame then
            left2 = left2 .. sgr_frame_color .. left_frame[2]
        end

        if rl.ismodifiedline and not is_module_in_prompt("modmark") then
            if rl.ismodifiedline() then
                left2 = left2 .. sgr("0;" .. (settings.get("color.modmark") or "")) .. "*"
            end
        end

        if not left_frame or style == "lean" then
            left2 = left2 .. get_prompt_symbol_color() .. get_prompt_symbol()
        end

        left2 = left2 .. sgr() .. " "

        if right_frame then
            right2 = right2 .. sgr_frame_color .. right_frame[2]
        end
    end

    -- Combine segments ------------------------------------------------------

    local prompt = left1
    local try_condense
    local rprompt
    local wizard_prefix = _wizard and _wizard.prefix or ""
    local screen_width = get_screen_width()

    if lines == 1 then
        rprompt = right1
        if console.cellcount(prompt) + (rprompt and console.cellcount(rprompt) or 0) + 10 > screen_width then
            try_condense = true
        end
        prompt = wizard_prefix .. prompt
    else
        rprompt = right2
        if right1 or right_frame then
            if style == "lean" then
                -- Padding around left/right segments for lean style.
                if left1 and #left1 > 0 then left1 = left1 .. " " end
                if right1 and #right1 > 0 then right1 = " " .. right1 end
            end
            prompt, try_condense = connect((left1 or ""), right1 or "", rightframe1 or "", sgr_frame_color)
        end
        if console.cellcount(prompt) > screen_width then
            try_condense = true
        end
        prompt = wizard_prefix .. prompt .. sgr() .. "\r\n" .. wizard_prefix .. left2
    end

    if #top > 0 then
        if left_frame then
            top = string.rep(" ", console.cellcount(left_frame[1] .. pad_frame)) .. top
        end
        if console.cellcount(top) > screen_width then
            try_condense = true
        end
        prompt = top .. "\n" .. prompt
    end

    if rprompt and #rprompt > 0 then
        rprompt = rprompt .. sgr() .. pad_right_edge
    end

    if get_spacing() == "sparse" and not _wizard then
        prompt = sgr() .. "\r\n" .. prompt
    end

    if render_settings then
        flexprompt.settings = old_settings
    end

    if need_anchors then
        local left_frame_len = left_frame and console.cellcount(left_frame[1]) or 0
        if anchors[1] then
            anchors[1] = #wizard_prefix + left_frame_len + anchors[1]
        end
        if anchors[2] then
            anchors[2] = #wizard_prefix + left_frame_len + anchors[2]
        end
        if rightframe1 then
            anchors[3] = #wizard_prefix + (_wizard and _wizard.width or 0) + - #pad_right_edge - console.cellcount(rightframe1)
        end
    end

    if try_condense and can_condense and not condense then
        prompt, rprompt, anchors = render_prompts(render_settings, need_anchors, true--[[condense]])
    end
    return prompt, rprompt, anchors
end

local function render_transient_prompt(wizard)
    local s
    _wizard = wizard
    s = get_prompt_symbol_color() .. get_transient_prompt_symbol() .. sgr() .. " "
    _wizard = nil
    return s
end

function flexprompt.render_wizard(settings, need_anchors)
    local left, right, anchors = render_prompts(settings, need_anchors)
    local col
    if not right or right == "" then
        right = nil
    else
        col = #_wizard.prefix + (_wizard.width - console.cellcount(right)) + 1
    end
    _wizard = nil
    return left, right, col, anchors
end

flexprompt.render_transient_wizard = render_transient_prompt

--------------------------------------------------------------------------------
-- Build prompt.

local pf = clink.promptfilter(5)
local continue_filtering = nil

if CMDER_SESSION then
    -- Halt further prompt filtering when used with Cmder.  This ensures our
    -- prompt replaces the Cmder default prompt.
    continue_filtering = false

    -- Disable the Cmder prompt's version control status, since it's expensive
    -- and we supersede it with our own prompt text.  It should be unreachable
    -- because of setting continue_filtering = false, but is still included for
    -- extra thoroughness.
    prompt_includeVersionControl = false
end

local right

function pf:filter(prompt) -- luacheck: no unused
    prompt, right = render_prompts()
    return prompt
end

function pf:rightfilter(prompt) -- luacheck: no unused
    return right or "", continue_filtering
end

function pf:transientfilter(prompt) -- luacheck: no unused
    return render_transient_prompt()
end

function pf:transientrightfilter(prompt) -- luacheck: no unused
    return "", continue_filtering
end

-- Capture the $+ dir stack depth if present at the beginning of PROMPT.
local plus_capture = clink.promptfilter(1)
function plus_capture:filter(prompt) -- luacheck: no unused
    local plusBegin, plusEnd = prompt:find("^[+]+")
    if plusBegin == nil then
        plusBegin, plusEnd = prompt:find("[\n][+]+")
        if plusBegin then
            plusBegin = plusBegin + 1
        end
    end
    if plusBegin ~= nil then
        _cached_state.dirStackDepth = prompt:sub(plusBegin, plusEnd)
    end
end

-- Consume blank lines before the prompt.  Powerlevel10k doesn't consume blank
-- lines, but CMD causes blank lines more often than zsh does, so to achieve a
-- similar effect it's necessary to consume blank lines.
local function spacing_onbeginedit()
    if get_spacing() ~= "normal" then
        local text
        local up = 0
        local line
        if console.getcursorpos then
            local _, y = console.getcursorpos()
            if y then
                line = y - 1
            end
        end
        line = line or console.getnumlines() - 1
        while line > 0 do
            text = console.getlinetext(line)
            if not text or #text ~= 0 then
                break
            end
            up = up + 1
            line = line - 1
        end
        if up > 0 then
            clink.print("\x1b[" .. up .. "A\x1b[J", NONL)
        end
    end
end

--------------------------------------------------------------------------------
-- Public API.

-- Add a module.
-- E.g. flexprompt.add_module("xyz", xyz_render, "X") calls the xyz_render
-- function when "{xyz}" or "{xyz:args}" is encountered in a prompt string.
-- The prompt text "{xyz:args}" would call xyz_render("args").
-- The symbol is optional, and is the default symbol for the module.
function flexprompt.add_module(name, func, symbol)
    modules[string.lower(name)] = func
    symbols[name .. "_module"] = symbol
end

-- Add a source control management plugin.
function flexprompt.register_scm(name, funcs, priority)
    if type(name) ~= "string" then
        error("arg #1 must be name of source control management system")
    end
    if type(funcs) ~= "table" then
        error("arg #2 must be a table of functions")
    elseif type(funcs.test) ~= "function" or type(funcs.info) ~= "function" then
        error("arg #2 table must include 'test' and 'info' functions")
    end
    table.insert(scms, { type=name, test=funcs.test, info=funcs.info, prio=(priority or 50) })
    table.sort(scms, function(a, b) return a.prio < b.prio end)
end

-- Add a VPN detector plugin.
function flexprompt.register_vpn(name, func, priority)
    if type(name) ~= "string" then
        error("arg #1 must be name of VPN detector")
    end
    if type(func) ~= "function" then
        error("arg #2 must be a function")
    end
    table.insert(vpns, { type=name, test=func, prio=(priority or 50) })
    table.sort(vpns, function(a, b) return a.prio < b.prio end)
end

-- Add a named color.
-- Named colors must be a table { fg=_sgr_code_, bg=_sgr_code_ }.
-- The fg and bg are needed for the rainbow style to properly color transitions
-- between segments.
-- If the fore argument is a table then back is ignored.  The table should
-- include fg and bg fields.  It can also contain lean, classic, or rainbow
-- fields to redirect to another color when using that style.  E.g. this table
-- defines red foreground and background, but in the lean style it redirects to
-- bright yellow:  { fg="31", bg="41", lean="brightyellow" }
function flexprompt.add_color(name, fore, back)
    if type(fore) == "table" then
        flexprompt.colors[name] = fore
    else
        flexprompt.colors[name] = { fg=fore, bg=back }
    end
end

-- Function to lookup a color.  If it's a named color, the named color
-- definition is returned.  If it starts with "38;" or "48;" then it's an
-- extended color (8-bit or 24-bit), and lookup_color automatically builds a
-- color table with corresponding foreground and background colors (so that it
-- can be used with the rainbow style).  Otherwise, the function gives up and
-- builds a color table using the literal input string for both the foreground
-- and background SGR codes (beware of unexpected side effects).
flexprompt.lookup_color = lookup_color

-- Function to choose between a normal color and an extended color, based on
-- whether extended colors are available.
flexprompt.use_best_color = use_best_color

-- Function to get the prompt frame.
flexprompt.get_frame = get_frame

-- Function to get the prompt style.
flexprompt.get_style = get_style

-- Function to get the prompt line count.
flexprompt.get_lines = get_lines

-- Function to get the nerdfonts version (based on what the user has told us).
flexprompt.get_nerdfonts_version = get_nerdfonts_version

-- Function to get the nerdfonts width (based on what the user has told us).
flexprompt.get_nerdfonts_width = get_nerdfonts_width

-- Function to get the prompt flow.
flexprompt.get_flow = get_flow

-- Function to get the prompt spacing.
flexprompt.get_spacing = get_spacing

-- Get an SGR string to apply the named color as either a foreground or
-- background color, depending on the style (rainbow style applies colors as
-- background colors).
function flexprompt.get_styled_sgr(name)
    local color = lookup_color(name)
    if color then
        if get_style() == "rainbow" then
            color = get_best_bg(color)
        else
            color = get_best_fg(color)
        end
        if color then
            return sgr(color)
        end
    end
    return ""
end

-- Parse arg "abc:def=mno:xyz" for token "def" returns value "mno".
function flexprompt.parse_arg_token(args, name, altname, include_colon)
    if not name then
        return
    end

    local defargs
    if segmenter and flexprompt.defaultargs and segmenter._current_module then
        -- First check for style-specific default args.
        if segmenter.style then
            defargs = flexprompt.defaultargs[segmenter._current_module.."|"..segmenter.style]
        end
        -- If not found, check for general default args.
        if not defargs then
            defargs = flexprompt.defaultargs[segmenter._current_module]
        end
    end

    if not defargs and not args then
        return
    end

    local value
    local pat = include_colon and "=(.*)" or "=([^:]*):"

    -- First try args specified in the prompt string.
    if args then
        args = ":" .. args .. (include_colon and "" or ":")
        value = string.match(args, ":" .. name .. pat)
        if not value and altname then
            value = string.match(args, ":" .. altname .. pat)
        end
    end

    -- If not found try default args.
    if not value and defargs then
        defargs = ":" .. defargs .. (include_colon and "" or ":")
        value = string.match(defargs, ":" .. name .. pat)
        if not value and altname then
            value = string.match(defargs, ":" .. altname .. pat)
        end
    end

    return value
end

-- Parsing arg "abc:def=mno:xyz" for a keyword like "abc" or "xyz" returns true.
function flexprompt.parse_arg_keyword(args, name, altname)
    if not name then
        return
    end

    local defargs
    if segmenter and flexprompt.defaultargs and segmenter._current_module then
        -- First check for style-specific default args.
        if segmenter.style then
            defargs = flexprompt.defaultargs[segmenter._current_module.."|"..segmenter.style]
        end
        -- If not found, check for general default args.
        if not defargs then
            defargs = flexprompt.defaultargs[segmenter._current_module]
        end
    end

    if not defargs and not args then
        return
    end

    local value

    -- First try args specified in the prompt string.
    if args then
        args = ":" .. args .. ":"
        value = string.match(args, ":" .. name .. ":")
        if not value and altname then
            value = string.match(args, ":" .. altname .. ":")
        end
    end

    -- If not found try default args.
    if not value and defargs then
        defargs = ":" .. defargs .. ":"
        value = string.match(defargs, ":" .. name .. ":")
        if not value and altname then
            value = string.match(defargs, ":" .. altname .. ":")
        end
    end

    return value
end

-- Parsing text "white,cyan" returns "white", "cyan".
function flexprompt.parse_colors(text, default, altdefault)
    local color, altcolor = default, altdefault
    if not altdefault then
        altcolor = color.altcolor
    end
    if text then
        if string.find(text, ",") then
            color, altcolor = string.match(text, "([^,]+),([^,]+)")
        else
            color = text
        end
    end
    return color, altcolor
end

-- Function that returns a table of modules that include the duration.
function flexprompt.get_duration_modules()
    local any
    local m = {}
    for k, v in pairs(duration_modules) do
        any = true
        m[k] = v
    end
    return any and m
end

-- Function that gets the duration of the last command.
function flexprompt.get_duration()
    local wizard = flexprompt.get_wizard_state()
    if segmenter and segmenter._current_module then
        duration_modules = duration_modules or {}
        duration_modules[segmenter._current_module] = true
    end
    return wizard and wizard.duration or last_duration or 0
end

-- Function that gets the time for the prompt.
function flexprompt.get_time()
    if not last_time then
        last_time = os.time()
    end
    return last_time
end

-- Function that takes (dir, force) and collapses HOME dir prefix into a tilde,
-- if configured to do so (flexprompt.settings.use_home_tilde) or if force.
-- Returns the directory and true or false indicating whether tilde was applied.
flexprompt.maybe_apply_tilde = maybe_apply_tilde

-- Function that takes (text, force) and surrounds it with control codes to
-- apply fluent coloring to the text.  If force is true, the fluent color is
-- applied even when using the rainbow style.  If force is a string it's a named
-- color to use instead of the fluent color, and if force is a table its fg
-- field is used instead of the fluent color.
flexprompt.make_fluent_text = make_fluent_text

-- Function that takes (dir, fluent) to abbreviate the path specified by the
-- dir parameter.  Each directory name is abbreviated to the shortest string
-- that uniquely distinguishes it from its sibling directories.  The first and
-- last directory names in the path are never abbreviated.  And git repo root
-- directories or workspace directories are never abbreviated.  If fluent is
-- true, then abbreviated directory names are surrounded with control codes to
-- apply fluent coloring (even when using the rainbow style).  If fluent is a
-- string it's a named color to use instead of the fluent color, and if force
-- is a table its fg field is used instead of the fluent color.
flexprompt.abbrev_path = abbrev_path

-- Function that takes (lhs, rhs) and appends them together with a space in
-- between.  If either string is empty or nil, the other string is returned
-- (without appending them).
flexprompt.append_text = append_text

-- Function that returns whether the prompt settings include the name module.
-- Returns 1 if in left, 2 if in right, or 3 if in both.
flexprompt.is_module_in_prompt = is_module_in_prompt

-- Function that flags the named module to be re-filtered.  If no modules are
-- flagged then all modules are re-filtered.  If any modules are flagged then
-- only those modules are re-filtered.  This is how only the overtype module
-- gets refreshed when toggling insert/overtype mode.  The flags are reset
-- whenever a new prompt is begun (i.e. a new edit line is begun).
flexprompt.refilter_module = refilter_module

-- Function that resets all rendering state and forces rerunning all prompt
-- modules the next time the prompt is filtered.
function flexprompt.reset_render_state()
    reset_render_state()
    for _, func in ipairs(list_on_reset_render_state) do
        func()
    end
end

function flexprompt.on_reset_render_state(func)
    add_on_reset_render_state(func)
end

-- Function to check whether extended colors are available (256 color and 24 bit
-- color codes).
flexprompt.can_use_extended_colors = can_use_extended_colors

-- Function that takes (name) and retrieves the named icon (same as get_symbol,
-- but only gets the symbol if flexprompt.settings.use_icons is set).
flexprompt.get_icon = get_icon

-- Function that takes (name) and retrieves the named symbol.
flexprompt.get_symbol = get_symbol

-- Function to get customizable symbol for current module (only gets the symbol
-- if flexprompt.settings.use_icons is true).
function flexprompt.get_module_symbol(refreshing)
    local s
    if segmenter and segmenter._current_module then
        local name = segmenter._current_module .. "_module"
        s = flexprompt.get_icon(name)
    end
    if refreshing and s ~= "" then
        local ref_sym = flexprompt.get_icon("refresh")
        if ref_sym and ref_sym ~= "" then
            s = ref_sym
        end
    end
    return s or ""
end

-- Function to retrieve a string of "+" corresponding to the pushd stack depth
-- if %PROMPT% begins with "$+".
function flexprompt.get_dir_stack_depth()
    return _cached_state.dirStackDepth or ""
end

-- Function that takes (dir, subdir) and returns "dir\subdir" if the subdir
-- exists, otherwise it returns nil.
flexprompt.has_dir = has_dir

-- Function that takes (dir, file) and returns "dir\file" if the file exists,
-- otherwise it returns nil.
flexprompt.has_file = has_file

-- Function that walks up from dir, looking for scan_for in each directory.
-- Starting with dir (or cwd if dir is nil), this invokes scan_func(dir), which
-- can check for a subdir or a file or whatever it wants to check.
-- NOTE:  scan_func(dir) must return nil to keep scanning upwards; any other
-- value (including false) is returned to the caller.
function flexprompt.scan_upwards(dir, scan_func)
    -- Set default path to current directory.
    if not dir or dir == '.' then dir = os.getcwd() end

    repeat
        -- Call the supplied function.
        local result = table.pack(scan_func(dir))
        if result ~= nil and result[1] ~= nil then return table.unpack(result, 1, result.n) end

        -- Walk up to parent path.
        local parent = get_parent(dir)
        dir = parent
    until not dir
end

-- Function to format a version control branch name:
-- "on module_symbol submodule_symbol branch_symbol branch"
--  - The "on" is present when flow is fluent.
--  - The module_symbol is present when using icons and the module has a symbol.
--  - The submodule_symbol is present when using icons and in a submodule.
--  - The branch_symbol is present when not lean and not fluent, or when using
--    icons (the icon_name argument is optional, and defaults to "branch").
--  - The branch name is always present.
function flexprompt.format_branch_name(branch, icon_name, refreshing, submodule, module_icon)
    local style = get_style()
    local flow = get_flow()

    local text = branch

    if style == "lean" or flow == "fluent" then
        text = append_text(flexprompt.get_icon(icon_name or "branch"), text)
    else
        text = append_text(flexprompt.get_symbol(icon_name or "branch"), text)
    end

    if submodule then
        text = append_text(flexprompt.get_symbol("submodule"), text)
    end

    text = append_text(module_icon or flexprompt.get_module_symbol(refreshing), text)

    if flow == "fluent" then
        text = append_text(flexprompt.make_fluent_text("on"), text)
    end

    return text
end

-- Function to check whether flexprompt.settings.no_smart_cwd should disable
-- smart cwd behavior for the specified directory.
function flexprompt.is_no_smart_cwd(dir)
    if flexprompt.settings.no_smart_cwd then
        if type(flexprompt.settings.no_smart_cwd) ~= "table" then
            return true
        else
            dir = clink.lower(path.normalise(path.join(unicode_normalize(dir), "")))
            for _, value in ipairs(flexprompt.settings.no_smart_cwd) do
                if type(value) == "string" then
                    if dir:find(value, 1, true) == 1 then
                        return true
                    end
                elseif type(value) == "function" then
                    local ret = value(dir)
                    if ret then
                        return ret
                    end
                end
            end
        end
    end
end

-- Function to add a specified directory to not use smart cwd display, or add
-- a function to check whether a directory should not use smart cwd display.
-- When adding a function, the function can return true to disable smart cwd
-- display, or can return a string to use as the parent for the smart cwd
-- display.
function flexprompt.add_no_smart_cwd(dir)
    flexprompt.settings.no_smart_cwd = flexprompt.settings.no_smart_cwd or {}
    if type(dir) == "string" then
        dir = clink.lower(path.normalise(path.join(unicode_normalize(dir), "")))
    end
    table.insert(flexprompt.settings.no_smart_cwd, dir)
end

-- Function to check whether flexprompt.settings.cwd_colors has a custom color
-- for the specified directory.
function flexprompt.get_cwd_color(dir)
    if type(flexprompt.settings.cwd_colors) == "table" then
        dir = clink.lower(path.normalise(path.join(unicode_normalize(dir), "")))
        for _, t in ipairs(flexprompt.settings.cwd_colors) do
            if dir:find(t.dir, 1, true) == 1 then
                if t.color then
                    local color = t.color
                    if string.byte(color) ~= 0x1b then
                        color = sgr(color)
                    end
                    return color
                end
            end
        end
    end
end

-- Function to add a custom color for the specified directory.
function flexprompt.set_cwd_color(dir, color)
    flexprompt.settings.cwd_colors = flexprompt.settings.cwd_colors or {}
    dir = clink.lower(path.normalise(path.join(unicode_normalize(dir), "")))
    table.insert(flexprompt.settings.cwd_colors, { dir=dir, color=color })
end

-- Function to check whether a custom color is available for the specified
-- Source Control Management plugin.
function flexprompt.get_scm_color(scm_type)
    if scm_type and type(flexprompt.settings.scm_colors) == "table" then
        local color = flexprompt.settings.scm_colors[scm_type:lower()]
        if color then
            if string.byte(color) ~= 0x1b then
                color = sgr(color)
            end
            return color
        end
    end
end

-- Function to set a custom color for the specified Source Control Management
-- plugin.
function flexprompt.set_scm_color(scm_type, color)
    flexprompt.settings.scm_colors = flexprompt.settings.scm_colors or {}
    flexprompt.settings.scm_colors[scm_type:lower()] = color
end

-- Function to register a module's prompt coroutine.
-- IMPORTANT:  Use this instead of clink.promptcoroutine()!
flexprompt.promptcoroutine = promptcoroutine

-- Function to use io.popenyield when available, otherwise io.popen.
flexprompt.popenyield = io.popenyield or io.popen

-- Function to simplify caching async prompt info.
function flexprompt.prompt_info(cache_container, root, branch, collect_func)
    if not cache_container.cached_info then
        cache_container.cached_info = {}
    end

    -- Discard cached info if from a different root or branch.
    if (cache_container.cached_info.root ~= root) or (cache_container.cached_info.branch ~= branch) then
        cache_container.cached_info = {}
        cache_container.cached_info.root = root
        cache_container.cached_info.branch = branch
    end

    -- Use coroutine to collect status info asynchronously.
    local info = flexprompt.promptcoroutine(collect_func)
    local refreshing

    -- Use cached info until coroutine is finished.
    if not info then
        info = cache_container.cached_info.info or {}
        refreshing = true
    else
        cache_container.cached_info.info = info
    end

    return info, refreshing
end

-- Function to perform alpha blending of two SGR codes.
flexprompt.blend_color = blend_color

--------------------------------------------------------------------------------
-- Internal helpers.

local function load_ini(fileName)
    -- This function is based on https://github.com/Dynodzzo/Lua_INI_Parser/blob/master/LIP.lua
    local file = io.open(fileName, 'r')
    if not file then return nil end

    local data = {};
    local section;
    for line in file:lines() do
        local tempSection = line:match('^%[([^%[%]]+)%]$');
        if tempSection then
            section = tonumber(tempSection) and tonumber(tempSection) or tempSection;
            data[section] = data[section] or {}
        end

        local param, value = line:match('^%s-([%w|_]+)%s-=%s+(.+)$')
        if param and value ~= nil then
            if tonumber(value) then
                value = tonumber(value);
            elseif value == 'true' then
                value = true;
            elseif value == 'false' then
                value = false;
            end
            if tonumber(param) then
                param = tonumber(param);
            end
            data[section][param] = value
        end
    end
    file:close();
    return data;
end

local function join_into_absolute(parent, child)
    -- gitdir can (apparently) be absolute or relative, but everything
    -- downstream wants absolute paths.  Process leading .. and . path
    -- components in child.
    while true do
        if child:find('^%.%.[/\\]') or child == '..' then
            parent = path.toparent(parent)
            child = child:sub(4)
        elseif child:find('^%.[/\\]') or child == '.' then
            child = child:sub(3)
        else
            break
        end
    end

    -- Join the remaining parent and child.
    return path.join(parent, child):gsub('/', '\\')
end

local git_config = {}
function git_config.load(git_dir)
    git_config.config = git_dir and load_ini(path.join(git_dir, 'config')) or nil
    return git_config.config
end
function git_config.get(section, param)
    if not git_config.config then return end
    if (not param) or (not section) then return end
    return git_config.config[section] and git_config.config[section][param] or nil
end

--------------------------------------------------------------------------------
-- Wizard helpers.  These are only useful to the built-in modules.  The wizard
-- needs to override what some of the built-in modules display.

function flexprompt.get_wizard_state()
    return _wizard
end

flexprompt.get_errorlevel = get_errorlevel

--------------------------------------------------------------------------------
-- Public API; git functions.

-- Return a command line string to run the specified git command.  It will
-- include relevant global flags such as "--no-optional-locks", and also "2>nul"
-- to suppress stderr.
--
-- Currently it is just "git", but this function makes it possible in the future
-- to specify "git.exe" (bypass any git.bat or git.cmd scripts) and/or add a
-- fully qualified path.
local function git_command(command, dont_suppress_stderr)
    command = command or ""

    if not flexprompt.settings.take_optional_locks then
        command = "--no-optional-locks " .. command
    elseif type(flexprompt.settings.take_optional_locks) == "table" then
        local words = string.explode(command)
        if not flexprompt.settings.take_optional_locks[words[1]] then
            command = "--no-optional-locks " .. command
        end
    end

    command = "git " .. command

    if not dont_suppress_stderr then
        command = "2>nul " .. command
    end

    return command
end

flexprompt.git_command = git_command

-- Test whether dir is a git repo root, or workspace dir, or submodule dir.
-- @return  nil if not; otherwise git_dir, workspace_dir, dir.
--
-- Examples:
--  * In a repo c:\repo, the return is:
--      "c:\repo\.git", "c:\repo\.git", "c:\repo"
--  * In a submodule under c:\repo, the return is:
--      "c:\repo\.git\modules\submodule", "c:\repo\.git", "c:\repo\submodule"
--  * In a worktree under c:\repo, the return is:
--      "c:\repo\.git\worktrees\worktree", "c:\repo\worktree\.git", "c:\repo\worktree"
--  * In a worktree outside c:\repo, the return is:
--      "c:\repo\.git\worktrees\worktree", "c:\worktree\.git", "c:\worktree"
--
-- Synchronous call.
function flexprompt.is_git_dir(dir)
    local function has_git_file(dir) -- luacheck: ignore 432
        local dotgit = path.join(dir, '.git')
        local gitfile
        if os.isfile(dotgit) then
            gitfile = io.open(dotgit)
        end
        if not gitfile then return end

        local git_dir = (gitfile:read() or ""):match('gitdir: (.*)')
        gitfile:close()

        if git_dir then
            -- gitdir can (apparently) be absolute or relative, so a custom
            -- join routine is needed to build an absolute path regardless.
            local abs_dir = join_into_absolute(dir, git_dir)
            if os.isdir(abs_dir) then
                return abs_dir
            end
        end
    end

    -- Return if it's a git dir.
    local gitdir = has_dir(dir, ".git")
    if gitdir then
        return gitdir, gitdir, dir
    end

    -- Check if it has a .git file.
    gitdir = has_git_file(dir)
    if gitdir then
        -- Check if it has a worktree.
        local gitdir_file = path.join(gitdir, "gitdir")
        local file = io.open(gitdir_file)
        local wks
        if file then
            wks = file:read("*l")
            file:close()
        end
        -- If no worktree, check if submodule inside a repo.
        if not wks then
            wks = flexprompt.scan_upwards(dir, function (x)
                return has_dir(x, ".git")
            end)
            if not wks then
                -- No worktree and not nested inside a repo, so give up!
                return
            end
        end
        return gitdir, wks, dir
    end
end

-- Test whether dir is part of a git repo.
-- @return  nil for not in a git repo; or git dir, workspace dir.
--
-- Synchronous call.
function flexprompt.get_git_dir(dir)
    return flexprompt.scan_upwards(dir, flexprompt.is_git_dir)
end

-- Get the name of the current branch.
-- @return  branch_name, is_detached.
--
-- Newer versions return branch_name, is_detached, detached_commit.
--
-- Synchronous call.
function flexprompt.get_git_branch(git_dir)
    git_dir = git_dir or flexprompt.get_git_dir()

    -- If git directory not found then we're probably outside of repo or
    -- something went wrong.  The same is when head_file is nil.
    local head_file = git_dir and io.open(path.join(git_dir, 'HEAD'))
    if not head_file then return end

    local HEAD = head_file:read()
    head_file:close()

    -- If HEAD isn't present, something is wrong.
    if not HEAD then return end

    -- If HEAD matches branch expression, then we're on named branch otherwise
    -- it is a detached commit.
    local branch_name = HEAD:match('ref: refs/heads/(.+)')
    if branch_name then
        return branch_name
    else
        return 'HEAD detached at '..HEAD:sub(1, 7), true, HEAD
    end
end

-- Get the status of working dir.
-- @return  nil for clean, or a table with dirty counts.
--
-- Use in promptcoroutine callback function.
function flexprompt.get_git_status(no_untracked, include_submodules)
    local flags = ""
    if no_untracked then
        flags = flags .. "-uno "
    end
    if include_submodules then
        flags = flags .. "--ignore-submodules=none "
    end

    local file = flexprompt.popenyield(git_command("status " .. flags .. " --branch --porcelain"))
    if not file then
        return { errmsg="[error]" }
    end

    local w_add, w_mod, w_del, w_con, w_unt = 0, 0, 0, 0, 0
    local s_add, s_mod, s_del, s_ren = 0, 0, 0, 0
    local unpublished
    local line

    line = file:read("*l")
    if line and not flexprompt.settings.dont_check_unpublished then
        unpublished = not line:find("^## (.+)%.%.%.")
    end

    while true do
        line = file:read("*l")
        if not line then break end

        local kindStaged, kind = string.match(line, "(.)(.) ")

        if kind == "A" then
            w_add = w_add + 1
        elseif kind == "M" then
            w_mod = w_mod + 1
        elseif kind == "D" then
            w_del = w_del + 1
        elseif kind == "U" then
            w_con = w_con + 1
        elseif kind == "?" then
            w_unt = w_unt + 1
        end

        if kindStaged == "A" then
            s_add = s_add + 1
        elseif kindStaged == "M" then
            s_mod = s_mod + 1
        elseif kindStaged == "D" then
            s_del = s_del + 1
        elseif kindStaged == "R" then
            s_ren = s_ren + 1
        end
    end
    file:close()

    if flexprompt.get_symbol("renamecount") == "" then
        s_mod = s_mod + s_ren
        s_ren = 0
    end

    local working
    local staged

    if w_add + w_mod + w_del + w_con + w_unt > 0 then
        working = {}
        working.add = w_add
        working.modify = w_mod
        working.delete = w_del
        working.conflict = w_con
        working.untracked = w_unt
    end

    if s_add + s_mod + s_del + s_ren > 0 then
        staged = {}
        staged.add = s_add
        staged.modify = s_mod
        staged.delete = s_del
        staged.rename = s_ren
    end

    local status
    if working or staged then
        status = status or {} -- luacheck: ignore 321
        status.working = working
        status.staged = staged
    end
    if unpublished then
        status = status or {}
        status.unpublished = true
    end
    return status
end

-- Gets the number of commits ahead/behind from upstream.
-- @return  ahead, behind.
--
-- Use in promptcoroutine callback function.
function flexprompt.get_git_ahead_behind()
    local file = flexprompt.popenyield(git_command("rev-list --count --left-right @{upstream}...HEAD"))
    if not file then
        return
    end

    local ahead, behind = "0", "0"
    for line in file:lines() do
        ahead, behind = string.match(line, "(%d+)[^%d]+(%d+)")
    end
    file:close()

    return ahead, behind
end

-- Gets the conflict status.
-- @return  true for conflict, or false for no conflicts.
--
-- Use in promptcoroutine callback function.
function flexprompt.get_git_conflict()
    local file = flexprompt.popenyield(git_command("diff --name-only --diff-filter=U"))
    if not file then
        return
    end

    for _ in file:lines() do -- luacheck: ignore 512
        file:close()
        return true;
    end
    file:close()

    return false
end

-- Gets remote for current branch.
-- @return  remote name, or nil if not found.
--
-- Synchronous call.
function flexprompt.get_git_remote(git_dir)
    if not git_dir then return end

    local branch = flexprompt.get_git_branch(git_dir)
    if not branch then return end

    -- Load git config info.
    if not git_config.load(git_dir) then return end

    -- For remote and ref resolution algorithm see https://git-scm.com/docs/git-push.
    local remote_to_push = git_config.get('branch "' .. branch .. '"', 'remote') or ''
    local remote_ref = git_config.get('remote "' .. remote_to_push .. '"', 'push') or git_config.get('push', 'default')

    local remote = remote_to_push
    if remote_ref then remote = remote .. '/' .. remote_ref end

    if remote ~= '' then
        return remote
    end
end

--------------------------------------------------------------------------------
-- SCM detectors.

function flexprompt.detect_scm()
    local cwd = os.getcwd()
    return flexprompt.scan_upwards(cwd, function(dir)
        for _, scm in ipairs(scms) do
            local tested_info = scm.test(dir)
            if tested_info then
                tested_info = type(tested_info) == "table" and tested_info or {}
                tested_info.type = scm.type
                tested_info.info_func = scm.info
                tested_info.cwd = cwd
                tested_info.root = dir
                return tested_info
            end
        end
    end)
end

function flexprompt.get_scm_info(detected_info, flags)
    if not detected_info or not detected_info.info_func or not detected_info.root then
        detected_info = flexprompt.detect_scm()
        if not detected_info or not detected_info.info_func or not detected_info.root then
            return
        end
    end

    local info = detected_info.info_func(detected_info.root, detected_info, flags)
    if not info then
        return
    end

    info.type = info.type or detected_info.type
    info.cwd = info.cwd or detected_info.cwd
    info.root = info.root or detected_info.root

    if info and info.status then
        local wrk = info.status.working
        if wrk then
            if (wrk.conflict or 0) > 0 then
                info.conflict = true
            end
            local keep = false
            for _, value in pairs(wrk) do
                if type(value) ~= "number" or value ~= 0 then
                    keep = true
                    break
                end
            end
            if keep then
                info.status.working.add = info.status.working.add or 0
                info.status.working.modify = info.status.working.modify or 0
                info.status.working.delete = info.status.working.delete or 0
                info.status.working.conflict = info.status.working.conflict or 0
                info.status.working.untracked = info.status.working.untracked or 0
            else
                info.status.working = nil
            end
        end
        local stg = info.status.staged
        if stg then
            local keep = false
            for _, value in pairs(stg) do
                if type(value) ~= "number" or value ~= 0 then
                    keep = true
                    break
                end
            end
            if keep then
                info.status.staged.add = info.status.staged.add or 0
                info.status.staged.modify = info.status.staged.modify or 0
                info.status.staged.delete = info.status.staged.delete or 0
                info.status.staged.rename = info.status.staged.rename or 0
            else
                info.status.staged = nil
            end
        end
    end
    return info
end

--------------------------------------------------------------------------------
-- VPN detectors.

-- Run the VPN detectors to get a list of VPN connections.
--
-- Use in promptcoroutine callback function.
function flexprompt.get_vpn_info()
    local connections = {}
    for _, vpn in ipairs(vpns) do
        local t = vpn.test()
        if t then
            if type(t) == "table" then
                for _, name in ipairs(t) do
                    if type(name) == "table" then
                        if type(name.name) == "string" then
                            table.insert(connections, { name=name.name, type=vpn.type, table=name })
                        end
                    else
                        table.insert(connections, { name=name, type=vpn.type })
                    end
                end
            elseif type(t) == "string" then
                table.insert(connections, { name=t, type=vpn.type })
            end
        end
    end
    return connections[1] and connections or nil
end

--------------------------------------------------------------------------------
-- Shared event handlers.

local offered_wizard

local function onbeginedit()
    -- Fix our tables if a script deleted them accidentally.
    if not flexprompt.settings then flexprompt.settings = {} end
    if not flexprompt.settings.symbols then flexprompt.settings.symbols = {} end

    _cached_state = {}

    reset_render_state()

    duration_onbeginedit()
    time_onbeginedit()

    spacing_onbeginedit()

    insertmode_onbeginedit()

    if not offered_wizard then
        local settings = flexprompt.settings or {}
        if not settings.top_prompt and not settings.left_prompt and not settings.right_prompt then
            clink.print("\n" .. sgr(1) .. "Flexprompt has not yet been configured." .. sgr())
            clink.print('Run "flexprompt configure" to configure the prompt.\n')
        end
        offered_wizard = true
    end
end

local function onendedit()
    duration_onendedit()
end

local function oncommand(line_state, info) -- luacheck: no unused
    if flexprompt.settings.oncommands then
        _cached_state.command = path.getbasename(info.command):lower()
        clink.refilterprompt()
    end
end

clink.onbeginedit(onbeginedit)
clink.onendedit(onendedit)
if clink.oncommand then
    clink.oncommand(oncommand)
end

if clink.refilterafterterminalresize then
    clink.refilterafterterminalresize()
end

local old_diag_custom = clink._diag_custom
clink._diag_custom = function (arg)
    if old_diag_custom then
        old_diag_custom(arg)
    end

    if not arg or arg < 1 then
        return
    end

    local longest = 4
    for key, _ in pairs(_module_costs) do
        local len = console.cellcount(key)
        if longest < len then
            longest = len
        end
    end

    if longest > 0 then
        clink.print('\x1b[0;1mflexprompt module cost:\x1b[m')
        clink.print(string.format('  \x1b[36mmodule%s     last    avg     peak\x1b[m', string.rep(' ', longest - 4)))
        for key, cost in spairs(_module_costs) do
            local color
            if cost.peak >= 10 then
                color = '\x1b[91m'
            elseif cost.peak >= 4 then
                color = '\x1b[93m'
            else
                color = ''
            end
            clink.print(string.format(
                '  %s{%s}%s  %4u ms %4u ms %4u ms\x1b[m',
                color,
                key,
                string.rep(' ', longest - console.cellcount(key)),
                cost.milliseconds,
                cost.total / cost.count,
                cost.peak))
        end
    end
end
