# Overview

Flex prompt is a flexible customizable prompt for [Clink](https://github.com/chrisant996/clink).

There are several built-in prompt modules, and it's easy to add new custom prompt modules.<br/>
The style of the prompt can be customized in many ways as well.

Flex prompt for Clink was inspired by the zsh [powerlevel10k](https://github.com/romkatv/powerlevel10k) theme by Roman Perepelitsa.<br/>
Some of the prompt modules are based on [cmder-powerline-prompt](https://github.com/chrisant996/cmder-powerline-prompt).

- [ ] _TBD: screen shot._

# Configuration Wizard

Flex prompt can be easily customized via its configuration wizard.

- [ ] _TBD: How to use the configuration wizard._

# Advanced Configuration

The wizard doesn't cover everything, and more advanced configuration is possible by assigning settings manually in a `flexprompt_config.lua` file.

The script will look something like this:

**flexprompt_config.lua**
```lua
flexprompt.settings.style = "classic"
flexprompt.settings.heads = "pointed"
flexprompt.settings.lines = "two"
flexprompt.settings.left_prompt = "{cwd}{git}"
flexprompt.settings.right_prompt = "{exit}{duration}{time}"
```

## Modules
The `flexprompt.settings.left_prompt` and `flexprompt.settings.right_prompt` string variables list prompt modules to be displayed.

- `"{battery}"` shows the battery level and whether the battery is charging.
- `"{cwd}"` shows the current working directory.
- `"{duration}"` shows the duration of the previous command.
- `"{exit}"` shows the exit code of the previous command.
- `"{git}"` shows git status.
- `"{hg}"` shows Mercurial status.
- `"{maven}"` shows package info.
- `"{npm}"` shows package name and version.
- `"{python}"` shows the virtual environment.
- `"{svn}"` shows Subversion status.
- `"{time}"` shows the current time and/or date.
- `"{user}"` shows the current user name and/or computer name.

```lua
flexprompt.settings.left_prompt = "{battery}{user}{cwd}{git}"
flexprompt.settings.right_prompt = "{exit}{duration}{time}"
```

## Style
- `"lean"` shows prompt modules using only colored text.
- `"classic"` shows prompt modules using colored text on a gray background.
- `"rainbow"` shows prompt modules using text on colored backgrounds.

```lua
flexprompt.settings.style = "classic"
```

## Charset
- `"ascii"` uses only ASCII characters, and is compatible with all fonts; text copy/pasted from the terminal display will look right everywhere.
- `"unicode"` uses Unicode characters to add styling to the prompt, and requires fonts compatible with powerline symbols; text copy/pasted from the terminal display will look wrong when pasted somewhere that doesn't use a compatible font.

The "rainbow" style requires Unicode.

```lua
flexprompt.settings.charset = "unicode"
```

## Frame Color
- `"lightest"`
- `"light"`
- `"dark"`
- `"darkest"`
- Custom frame colors can be provided as `{ frame_color, background_color, fluent_text_color, separator_color }`.  The fields can be color name strings or ANSI escape code SGR arguments (e.g. `"31"` is red text).

These choose the prompt background color for the "classic" style, and choose the frame and connection color for all styles.

```lua
-- Use a predefined set of coordinated dark colors:
flexprompt.settings.frame_color = "dark"

-- Or use custom colors:
flexprompt.settings.frame_color =
{
    "38;5;242",     -- frame color (gray 44%)
    "38;5;238",     -- background color (gray 28%)
    "38;5;246",     -- text color (gray 60%)
    "38;5;234",     -- separator color (gray 12%)
}
```

## Separators
For the "classic" style:
- `"none"` is just a space between prompt modules.
- `"vertical"` is a vertical bar.
- `"pointed"` is a sideward-pointing triangle (requires Unicode).
- `"slant"` is slanted from bottom left to top right.
- `"backslant"` is slanted from top left to bottom right.
- `"round"` is a semi circle (requires Unicode).
- `"dot"` is a dot (requires Unicode).
- `"updiagonal"` is a small slash from bottom left to top right (requires Unicode).
- `"downdiagonal"` is a small slash from top left to bottom right (requires Unicode).
- Custom separators can be provided as a string.

For the "rainbow" style:
- Any of the **Heads** or **Tails** options may be used as separators (except not "blurred").

```lua
-- Use a predefined separator:
flexprompt.settings.separator = "pointed"

-- Or use a custom separator:
flexprompt.settings.separator = "»"
```

## Tails and Heads
Tails are at the outside ends of the prompts.  Heads are at the inside ends.
- `"flat"` is a flat vertical edge.
- `"pointed"` is a sideward-pointing triangle (requires Unicode).
- `"slant"` is slanted from bottom left to top right (requires Unicode).
- `"backslant"` is slanted from top left to bottom right (requires Unicode).
- `"round"` is a semi circle (requires Unicode).
- `"blurred"` uses shaded block characters to fade the edge (requires Unicode).
- Custom end types can be provided as `{ open_string, close_string }`.  However, that is advanced usage and you need to know how background and foreground colors work; that isn't covered in this documentation.

```lua
flexprompt.settings.tails = "flat"
flexprompt.settings.heads = "blurred"
```

## Lines
- `"one"` uses a single line.  Any right-side prompt modules are shown if there is room, and if the input text hasn't reached them.
- `"two"` uses two lines.  The first line shows the prompt modules, and the second line is for input text.

```lua
flexprompt.settings.lines = "two"
```

## Connection
Only when using "both" sides:
- `"disconnected"` shows blank space between the left and right side prompts.
- `"dotted"` shows dots between the left and right side prompts.
- `"solid"` draws a horizontal line connecting the left and right side prompts.
- A custom connection can be provided as a string.

```lua
-- Use a predefined connection:
flexprompt.settings.connection = "solid"

-- Or use a custom connection:
flexprompt.settings.connection = "═"
```

## Frame
When using "two" lines, left and right prompt frames can each be:
- `"none"` shows no frame.
- `"square"` shows a frame with square corners.
- `"round"` shows a frame with rounded corners.
- Custom frames can be provided as `{ top_frame, bottom_frame }`.

```lua
-- Use predefined frame shapes:
flexprompt.settings.left_frame = "none"
flexprompt.settings.right_frame = "round"

-- Or use custom frame shapes:
flexprompt.settings.left_frame = { "╔═", "╚═" }
flexprompt.settings.right_frame = { "═╗", "◄───╜" }
```

## Spacing
- "compact" removes blank lines before the prompt.
- "normal" neither removes nor adds blank lines before the prompt.
- "sparse" removes blank lines before the prompt, and then inserts one blank line.

```lua
flexprompt.settings.spacing = "sparse"
```

## Flow
- `"concise"` shows minimal text for each prompt module.
- `"fluent"` shows additional text for some prompt modules, to make the prompt "read" nicely.

```lua
flexprompt.settings.flow = "fluent"
```

# Writing Custom Prompt Modules

_TBD_

# License

clink-flex-prompt is distributed under the terms of The MIT License.

<!-- vim: set ft=markdown : -->
