# ModKit

A new way to write custom code for HWRM.

## What you get out the box

- A large and growing library of utility functions for working with ships and players
- A new way to write code, which works with _ships_ instead of SobGroups
- A builtin library for working more easily with tables
- A math library
- A state management system
- Freedom to express your ideas in code much more intuitively, without the noise of `SobGroup_`, `Universe_` and `Player_` functions, and the string references associated with them.
- Extremely flexible, can be used simply as a collection of utilities to bolster your own scripting style, or can provide a whole new way of approaching custom code

## Use as a mod template:

**⚠️ [Check out a video version of this very example](https://www.youtube.com/watch?v=FmQQPslBmaM)**!

Install [degit](https://www.npmjs.com/package/degit):

> Note: You need both Node and npm to use modkit this way. You can get Node (and npm with it) here: https://nodejs.org/en/

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

When given the multiple choice question, I recommend the first option if starting a new mod:

<img src="https://i.imgur.com/cWq7AOs.png">

Your custom code will live in any file you like within the `scripts/custom_code` directory:

```
scripts/
|- custom_code/
    |- my_script.lua
```

You can name these files however you like.

## Example

An example script, which heals Taiidan Field Frigates by 1/20 of their HP every `update` call (1s by default):

```lua
-- scripts/custom_code/my_script.lua:

-- here, we define what properties a field frigate has in-memory
-- the 'prototype' is basically our own custom definition of a field frigate

tai_fields_prototype = {
	foo = 10 -- we can assign a custom property 'foo' that all field frigates will have
};

-- we can hook up methods to our field frigates:
function tai_fields_prototype:doSomething()
	-- do something...
end

-- Most importantly, we can provide custom behavior for the four hooks as we please:
-- load, create, update, and destroy

-- akin to the classic 'Update_Tai_FieldFrigate()
function tai_fields_prototype:update() 
	-- 'self' refers to the ship which called its 'update' hook

	-- new_hp = the smaller of (current health + 0.05) or 1
	local new_hp = min(self:HP() + (1/20), 1);
	self:HP(new_hp); -- set the hp to new_hp

	print(self.foo); -- we can access the 'foo' property we defined
end

-- hook our definition up to the ship type
modkit.compose:addShipProto("tai_fieldfrigate", tai_fields_prototype);
```

If we boil it down and remove the comments, we can see modkit code is extremely concise and expressive:

```lua
-- scripts/custom_code/my_script.lua:

tai_fields_prototype = {};

function tai_fields_prototype:update()
	local new_hp = min(self:HP() + (1/20), 1);
	self:HP(new_hp);
end

modkit.compose:addShipProto("tai_fieldfrigate", tai_fields_prototype);
```

**This is now a fully working mod!**

This setup process is much faster than extracting big files etc., and the amount of tooling in addition to the large library make modkit a great option for any new mod author!

## Contributing to modkit

Firstly, feel free to create issues: https://github.com/Novaras/modkit/issues

You can also fork the repo and make pull requests.

Talk to me on [Discord](https://discord.gg/homeworld) if you want to contribute directly to modkit (or just ask me anything :+1:). 
