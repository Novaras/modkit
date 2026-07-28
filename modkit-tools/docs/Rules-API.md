# Modkit Rules API

As `modkit.campaign.rules`.

The rules API provides an abstraction around the existing stock functions regarding rules (see [rules documentation on karos](https://github.com/HWRM/KarosGraveyard/wiki/Dictionary;-GameRule)).

Modelled after [JS Promises](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise), though the concept is not exclusive to those; the Modkit Rules API intends to make writing code for mission rules much more expressive and readable (and easier to think about).

All the following examples use an alias like this:

```lua
rules = modkit.campaign.rules;
```

It provides a chaining syntax:

```lua
rule_a() -- store a rule and begin it by invoking it just like a function
	:next(rule_b) -- rules can be chained together with `:next()`
	:next(rule_c)
	:catch(function (err) print("error occured!: " .. err) end); -- errors anywhere in a chain will exit the chain and end up in `:catch`
```

And a more traditional event listener API:

```lua
local rules = modkit.campaign.rules;

-- begin another rule
rules:on(rule_a, rule_b);

-- invoke a function once
rules:on(rule_b, function()
	rule_c();
	rule_d:begin(); -- you can also call `:begin` explicitly instead of calling the rule itself (`rule_d()`)
end);
```

### Defining Rules

A rule is a `table` type. Construct rules using `modkit.campaign.rules:make`:

```lua
local rules = modkit.campaign.rules;

-- pass a function directly (will provide defaults)
rule_a = rules:make(function () end);
-- or define it more thoroughly
rule_b = rules:make({
	name = "my-rule",
	interval = 2,
	fn = function () end
});
```

### Invoking Rules

Invoke a rule by calling it like a function, or via it's `:begin()` method:

```lua
my_rule = rules:make(...);

my_rule(); -- like a function
my_rule:begin(); -- or via `:begin()`
```

### Listening for Rules

When a rule resolves, any _subscribers_ (or _'listeners'_) to that rule are invoked. Listen for rules using `:on()`:

```lua
local rule_a = rules:make({
	name = "weird-name",
	fn = function() end,
});
local rule_b = rules:make(...);

rules:on(rule_a, rule_b); -- listen via the rule
rules:on("weird-name", rule_b); -- or just its name
rules:on(rule_a, function() end); -- if the listener is a plain function, its just invoked once
```

You may listen to multiple rules with logical expressions:

```lua
-- if all of the first three OR just D finish:
rules:on('(A and rule_b and myC00lRule) or D', function ()
	--
end);
```

### Exiting Rules

Rules exit with a success or error state, known as 'resolving' and 'rejecting'. They also carry a state table which keeps state between calls.

```lua
rule_a = rules:make(function(resolve, reject, state)
	if (state._tick == 5) then -- every run, the special field `_tick` is incremented
		state.foo = "bar"; -- we can add arbitary data to the state on each run
	end

	if (state.bar == "foo") then
		resolve(10, "hello");
	end

	if (some_error_occurred) then
		reject("error!");
	end
end);
```

#### Resolving

The `resolve` callback may accept any number of any kind of arguments, whereas `reject` may only accept an error string. Anything passed to `resolve` will be stored on the rule's `result` array, and if another rule is chained with `:next`, that rule can find the result on it's state object under `_previous_result` (special fields are all prepended with `_`).

```lua
-- chain syntax
rule_a():next(function(_, _, state)
	print("state._previous_result:");
	print(state._previous_result[1]); -- 10
	print(state._previous_result[2]); -- "hello"
end);

-- or a plain listener
rules:on(rule_a, function()
	print("rule_a.result:");
	print(rule_a.result[1]); -- 10
	print(rule_a.result[2]); -- "hello"
end);
```

#### Rejecting

The `reject` callback accepts a `string`, which is considered an 'error message'. You should only call `reject` if an _error state_ occurs in your rule; a file couldn't be loaded, some important variable is missing, etc.

If something 'bad' can happen during a rule, like a player failing an objective, that is not considered an _error_, so we would still want to use `resolve` in that case.

```lua
rules:on(rule_a, function()
	print("rule_a err: " .. rule_a.error);
end);
```

If a rule rejects anywhere in a chain, the entire chain is cancelled there and then. If an error handler is supplied using `:catch`, then the error message is sent there immediately:

```lua
rule_a()
	:next(rule_b)
	:next(rule_c)
	:next(rule_d)
	:catch(function (err)
		print("error occurred! " .. err);
	end);
```

If `rule_b` called its `reject` function, `rule_c` and `rule_d` would be _skipped_.
