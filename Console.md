# hwrm console

Modkit comes with an ingame console. This is available as a mod [here](https://steamcommunity.com/sharedfiles/filedetails/?id=2894486483).

The console can run whole files, and also comes prepackaged with many commands. Use the '`help`' command for info while ingame.

Post issues about bugs or feature requests [here](https://github.com/Novaras/modkit/issues).

Code documentation for the console is [here](https://github.com/Novaras/modkit/blob/master/modkit-tools/docs/Console.md).

## Controls

The console is brought up with the `P` key. Close it again with `ESC`.

Due to the way the mod had to be made (there appears to be no way to retrieve the text content of a regular text input element), the text input of the console is a custom solution, so some of the keybinds are a little unusual:

- Shift doesn't work; use caps lock toggling
- Alphanumeric keys are bound as expected
- Quotes are on the `\`/`"` key (under backspace)
- Period (full stop) is on `f1`
- Comma is on `f2`
- Semicolon is on `f3`
- Square brackets are on `f4` and `f5`

## Premade Commands

The console currently has a small group of premade commands.

Use `help` in the console for more info. Use `help help` for help about the help syntax.

Use `commands` to see all available commands.

## Executing Lua In-Console

You can run any Lua you like in-console using `do` like so:

```
do <lua code>
```

Examples:
```
do Player_SetRU(0, 10000000)

do Player_Kill(1)

do SobGroup_SetHealth("Player_Ships0", 0.1)

do print('hi!')
```

## Running Lua From a Script

You can execute existing scripts using `run`:

```
run <path to file>
```

This internally calls [`dofilepath`](https://github.com/HWRM/KarosGraveyard/wiki/Function;-dofilepath), which usually expects a relative path root to be set (see [this explanation](https://github.com/HWRM/KarosGraveyard/wiki/Tutorial;-Relative-File-Paths)). If the supplied path has no prefix, the `"data:"` prefix will be added by default.

Example:

```
run scripts/my-script.lua
```

This is equivalent to `dofilepath("data:scripts/my-script.lua");`.
