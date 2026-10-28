# ModKit

A new way to write custom code for HWRM.

## What you get out the box

- A large and growing library of utility functions for working with ships and players
- A new way to write code, which works with _ships_ instead of SobGroups
- `ShipList`s: call any ship method on a whole list of ships at once (e.g `my_ships:attack(target)`)
- A promise-like [rules API](modkit-tools/docs/Rules-API.md) for mission scripting (`rule_a():next(rule_b):catch(...)`)
- State shared between the game's separate Lua scopes (custom code, rules, UI), see [Hypertable](modkit-tools/docs/Hypertable.md) and [Hoisting](modkit-tools/docs/Hoisting.md)
- An [ingame console window](Console.md)
- Math, table, string, Vec3 and other utils
- Freedom to express your ideas in code much more intuitively, without the noise of `SobGroup_`, `Universe_` and `Player_` functions, and the string references associated with them.
- Extremely flexible, can be used simply as a collection of utilities to bolster your own scripting style, or can provide a whole new way of approaching custom code

## Use as a mod template:

**⚠️ [Check out a video version of this very example](https://www.youtube.com/watch?v=FmQQPslBmaM)**!

Install [degit](https://www.npmjs.com/package/degit):

> **💡 Note: You need git, Node, and npm to use modkit this way.**
> - **You can get Node (and npm with it) here: https://nodejs.org/en/**
> - **Git can be [installed in various ways](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)**

```bash
npm install -g degit
```

You can now use `degit` to create new projects using this repo as a template:

```bash
degit novaras/modkit my-mod
```

Then initialise:

```bash
cd my-mod
init.bat
```

On Linux or macOS, run the same steps `init.bat` does:

```bash
cd modkit-tools && npm i && cd .. && node ./modkit-tools/link.js && node ./modkit-tools/ship-types.js && node ./modkit-tools/purge.js
```

When asked whether to generate missing vanilla ship files, I recommend the first option ("Generate missing vanilla ship files where needed") if starting a new mod:

<img src="https://i.imgur.com/cWq7AOs.png">

This links every ship to modkit (by adding an `addCustomCode` line to its `.ship` file), so all ships appear in modkit's ship registry (`GLOBAL_SHIPS`). Choose the second option instead if your mod already has its own `.ship` files.

Your custom code will live in any file you like within the `scripts/custom_code` directory:

```
scripts/
|- custom_code/
    |- my_script.lua
```

You can name these files however you like. Note that only files directly in `scripts/custom_code` are loaded, not subdirectories (modkit's own `lib`, `hw1` and `hw2` subdirectories are loaded explicitly by `scripts/modkit/compose.lua`; add yours there if you want to use subdirectories). The scripts in `hw1` and `hw2` (e.g `hw1/drones.lua`, the Kushan drone frigate) are good examples of real modkit code.

Finally, I usually initialise the project's current state as a new git repo:

```bash
git init
git add -A
git commit -m "post-setup initial state"
```

This is optional, although I strongly recommend using a version manager like git or something similar!

## Example

An example script, which heals Taiidan Field Frigates by 1/20 of their HP every `update` call (1s by default):

```lua
-- scripts/custom_code/field_frig_code.lua:

local tai_fields_prototype = {};

-- define the update method (akin to classic `Update_Tai_FieldFrigate`)
function tai_fields_prototype:update()
	local new_hp = min(self:HP() + (1/20), 1); -- new_hp = smaller of (current hp + 1/20) or 1 [so we don't exceed 1]
	self:HP(new_hp); -- set this ship's hp to new_hp
end

-- link this definition for ships of type "tai_fieldfrigate"
modkit.compose:addShipProto("tai_fieldfrigate", tai_fields_prototype);
```

**This is now a fully working mod!**

This setup process is much faster than extracting big files etc., and the amount of tooling in addition to the large library make modkit a great option for any new mod author!

We don't need to worry about editing the `.ship` file or anything - the setup process earlier should already have linked field frigates to modkit for you.

## Documentation

- [Console](Console.md): using the ingame console
- [Rules API](modkit-tools/docs/Rules-API.md): promise-like rules for mission scripting
- [Hypertable](modkit-tools/docs/Hypertable.md) and [Hoisting](modkit-tools/docs/Hoisting.md): how state is shared between the game's Lua scopes
- [Console internals](modkit-tools/docs/Console.md): how the console is implemented
- The modkit source is annotated for the [Lua language server](https://luals.github.io/), so hovering/completion in an editor like VS Code is the best way to explore the API
- For the stock game API, see the community wiki, [Karos Graveyard](https://github.com/HWRM/KarosGraveyard/wiki)

## Contributing to modkit

Firstly, feel free to create issues: https://github.com/Novaras/modkit/issues

You can also fork the repo and make pull requests.

Talk to me on [Discord](https://discord.gg/homeworld) if you want to contribute directly to modkit (or just ask me (Fear) anything :+1:). 
