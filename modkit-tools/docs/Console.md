# Console

See the [main readme](https://github.com/Novaras/modkit/blob/console-update/Console.md) for an overview of the functionality.

- The functionality defined in `modkit/console/*.lua`
- The UI screen, `mk_consolescreen.lua`

The screen is a window with a black background which hosts several text inputs; these are the console lines and are filled from the superscope table `MK_CONSOLE_LINES` (see `consoleInit`). Calls to `consoleLog` and (most of) its sister functions push lines to that state.

The flow is as follows:

1. On game start, the console functions are loaded into scope, including `consoleLog` etc.
1. Also, `keybinds.lua` is executed, which binds the `P` key to a function which displays the console window
1. The function bound to the `P` key also calls `textCaptureMode`, which takes over most of the keybinds
1. Keystrokes then push their asscociated char to a string buffer
    - On update, the buffer is re-printed to the 'input' on the console window (although it is not really an input).
1. On `ENTER` press, the buffer is flushed
    - `consoleLog` is given this input
    - The input is also interpreted and one of three things can happen:
        - If prepended with the word `do`, we execute the remaining input as Lua
        - If `run`, we assume the rest is a file path, so we try to load a file at that path
        - Otherwise, assume it's a **command**.
1. On `ESC` press, close the console window and call `textCaptureMode(1)` to unbind everything

## Command Anatomy

```
research grant t=corvettedrive --r
```

Here we have the command itself, `research`, it is passed an _argument_ in `grant`, a _parameter_ in `t=corvettedrive`, and a _flag_ in `--r`.

### Arguments

Arguments are just plain values, delimeted by spaces. Arguments must be given in the expected order, and this also means any _optional_ arguments must be at the end of the list.

```
<command> arg1 arg2 ?optArg
```

Arguments must be given before either _parameters_ or _flags_.

### Parameters

Parameters are `key=value` pairs, delimeted by spaces. Params can be given in _any_ order, which generally makes them preferable to arguments unless a command wouldn't make sense at all without the desired value.

Since they can be given in any order, this also means any param can be optional if desired.

```
<command> param1=value1 param3=value3
```

### Flags

Flags are `nil` (falsy) by default, but become `1` (truthy) when supplied, and are denoted by a prefix `--`.

```
<command> --flag1 --flag2
```

## Defining Commands

The commands live in `modkit/console/commands/`, and are loaded in by `modkit/console/commands.lua` using `doscanpath`.

A 'command' is a collection of data as well as the actual Lua function to execute.

Most of the data fields are used for documentation via the `help` command, however the `params` and `fn` fields are essential to understand.

### Reading Arguments

Arguments are supplied as the second parameter to a command's `fn`, and are simply given as a `string[]`. No parsing is performed.

```
fight 2 5
```

Here we access the two args from the supplied table, which looks like this:

```lua
{
    '2',
    '5',
}
```

### Reading Params

Parameters are supplied as the first parameter to a command's `fn`, and are given as a `table<string, any>` table. That is, if we had the params like this:

```
move t=kus_scout pos=0 10 -3 p=1
```

The supplied table would look like this:

```lua
{
    type = 'kus_scout',
    position = { 0, 10, -3 },
    -- A `Player` object
    player = { },
}
```

As the `move` command is defined with params like so:

```lua
params = {
    type = PARAMS.str({ 't', 'type' }),
    family = PARAMS.str({ 'f', 'family '}),
    player = PARAMS.intToPlayer(),
    position = PARAMS.strToVec3({ 'pos', 'position' })
}
```

Note that the `family` and `type` params are mutally exclusive.

Although we might try to match manually, this can become tedious especially when we want a parameter to have many aliases, for example the 'value' parameter which appears in many commands:

```
[n|v|val|value]=[number]
```

It can be given by any of its names:

```
foo n=10
foo v=10
foo val=10
foo value=10
```

To make things easier, the `parseParams` function takes the input and a _`ParamConfig`_ object, and does the heavy lifting for us, returning the value.

There are several _`ParamConfig`_ objects already defined in `commands.lua`. The above snippet is acheived with the `PARAMS.int` config, which looks for all the aliases followed by a digit pattern (`%d+`).

### Reading Flags

Flags are supplied as the third argument to a command's `fn`, are are given as a `bool[]` (that is, its just a table of `1`s).

```
move t=kus_scout pos=0 0 0 --force
```

We can check whether the force flag was set by checking for the `.force` field on the flags table supplied.

