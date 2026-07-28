# Hoisting

During the game's runtime, there are multiple Lua 'scopes' running. These behave as though they are totally seperate instances of Lua, with different globals etc.

'Hoisting' is what we call it when a ship is synced from the 'custom code' (`Ship`) scope into the 'rules' (`Rules`) scope.

- `Ship`: this is the scope shared by all invocations of `addCustomCode` hooks, and is the primary space modkit runs in (i.e all the ship functions etc.)
- `Rules`: this refers to the scope which hosts rule functions and other mission scripting, it's presence is detectable via checking for `Rule_AddInterval`

See [Hoisting](./Hoisting.md)
