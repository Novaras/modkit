# ModKit

A collection of functions and utilties for use when modding HWRM.

**See [Using as a mod template](#use-as-a-mod-template) at the bottom for a quick-start guide if you're creating a new mod.**

There are two main functionalities:

- `modkit.lua`: Provides all the modding utilities and functions
- `driver.lua`: [[Usage](Driver.md)] Provides a mechanism to unify all script calls (see section below)

## `modkit.lua` as a standalone utility:

Consists of distinct modules:

- `sobgroup.lua`: populates the global scope with extra user-defined `SobGroup_` functions
- `memgroup.lua`: [[Usage](MemGroup.md)] MemGroup is a state management system, which allows you to maintain state between script calls in a well-defined pattern
- `math_util.lua`, `table_util.lua`: Maths and table utilities (especially table utilies)

You may import this file into whatever script you like:

```lua
dofilepath("data:scripts/modkit.lua");
```

It will be instantiated only once, and provide the global scope with a bunch of goodies:

### Custom `SobGroup_` Functions:

All of these functions are documented, and try to follow conventions used by the stock library.

Worth noting: all of these custom functions return a value - usually it will be the name of a sobgroup, but may vary depending.

### Modding Utilities:

These utilities are scoped under the `modkit` object:

```lua
dofilepath("data:scripts/modkit.lua");

modkit.math;		-- Math utils
modkit.table;		-- Table utils
modkit.memgroup;	-- State management utils
```

The table and math utils are simple to understand, as they're just collections of functions which are documented in their files (todo). The state management utility, `memgroup`, is a little more complicated:

#### MemGroup:

MemGroup is a state management utility.

Ships are expected to register themselves with a memgroup, and later script calls may access this specific ship by finding it in the memgroup (via its `shipID`).

See [MemGroup.md](MemGroup.md) for a quick example / tutorial.

## Use as a mod template

Install [degit](https://www.npmjs.com/package/degit):

> Note: You need both Node and npm to use modkit this way. You can get Node (and npm with it) here: https://nodejs.org/en/

```bash
npm install -g degit
```

You can now use `degit` to create new projects using this repo as a template:

```bash
degit novaras/modkit my-mod
```

Simple as that. Feel free to delete these readme files after.

Otherwise, a normal clone will work, just make sure to remove the `.git` directory, or retarget the origin.

```bash 
git clone https://github.com/Novaras/modkit.git my-mod
```

Forking is also fine.