# Hypertable

A 'hypertable' is a name given to the technique of writing data to the UI in a readable format, so that it can be _shared between scopes_.

I made a small writeup about this kind of state sharing [here on Karos](https://github.com/HWRM/KarosGraveyard/wiki/Tutorial;-Sharing-State-Between-Scopes), under a different term.

You can make multiple hypertables, but in Modkit there is only one and so I'll refer to it in the singular.

## How `Ship` scope is synced to `Rules`:

In `driver.lua` we check the `_hoisted` flag on ships whenever we call `register`, if passing `1` for the final parameter. If `_hoisted` is not set, then the ship's core data (group, player id, ship id) is written into the hypertable, under the key `GLOBAL_SHIPS`.

At the same time, there is a rule running in that scope which reads this table out of the UI, generates ship objects in it's own scope to match what it found, and then clears the table.

Note that ships do not need to be synced in the other direction except for ships which are placed on a map before the game begins.

## How map ships are registered:

Ships placed on the map in the `.level` are not immediately available to use in the `Rule` scope, since they must run their update scripts at least once and then sync back via the above method, which takes a short time, but easily long enough to make using them in a mission script impossible without some kind of arbitary wait period.

To overcome this, we call `RegisterShips`, which writes to the rules state directly, skipping the need to sync from the `Ship` scope.
