-- Offline unit tests for `scripts/modkit/memgroup.lua` (`modkit.MemGroup`). Run with `npm test` in `modkit-tools`.
--
-- Groups are global (by name), so each test uses its own group name.

dofile("modkit-tools/tests/lua/harness.lua");
loadQuietly("scripts/modkit/table_util.lua");
loadQuietly("scripts/modkit/memgroup.lua");

MG = modkit.MemGroup; -- (a global: in Lua 4, `%upvalue` can only reach the immediately enclosing function)

describe("Create / ForceCreate / Get / Exists", function ()
	it("Create makes a named group, with no entities", function ()
		local group = MG.Create("create-new");
		expectEq(group.group_name, "create-new");
		expectEq(group:all(), {});
		expectEq(group:length(), 0);
	end);
	it("Create returns the existing group for a name already in use", function ()
		local first = MG.Create("create-existing");
		first:set(1, { hp = 10 });
		local second = MG.Create("create-existing", { extra = 1 });
		expectTruthy(second == first, "the same group");
		expectEq(second:get(1).hp, 10);
		---@diagnostic disable-next-line: undefined-field
		expectNil(second.extra, "custom attribs of the second call are ignored");
	end);
	it("copies custom attribs onto the group", function ()
		local group = MG.Create("create-attribs", { _counter = 5, describe = function (self) return "group " .. self.group_name; end });
		---@cast group table (custom attribs aren't on the MemGroupInst class)
		expectEq(group._counter, 5);
		expectEq(group:describe(), "group create-attribs");
	end);
	it("ForceCreate replaces an existing group", function ()
		local first = MG.Create("force-create");
		first:set(1, {});
		local replaced = MG.ForceCreate("force-create");
		expectTruthy(replaced ~= first, "a new group");
		expectEq(replaced:length(), 0);
		expectTruthy(MG.Get("force-create") == replaced, "Get finds the new one");
	end);
	it("Get returns a group by name, or nil", function ()
		local group = MG.Create("get-me");
		expectTruthy(MG.Get("get-me") == group);
		expectNil(MG.Get("never-made"));
	end);
	it("Exists says whether a group exists", function ()
		MG.Create("exists");
		expectTruthy(MG.Exists("exists"));
		expectNil(MG.Exists("never-made"));
	end);
end);

describe("set / get / delete", function ()
	it("stores entities by id, and get returns them", function ()
		local group = MG.Create("set-get");
		local entity = { hp = 10 };
		local returned = group:set("a", entity);
		expectTruthy(returned == entity, "set returns the stored entity");
		expectTruthy(group:get("a") == entity, "get returns the same table");
		expectNil(group:get("missing"));
	end);
	it("gives an entity its id, unless it already has one", function ()
		local group = MG.Create("set-ids");
		expectEq(group:set(7, {}).id, 7);
		expectEq(group:set(8, { id = "own" }).id, "own");
	end);
	it("stores an empty entity when given nil", function ()
		local group = MG.Create("set-nil");
		expectEq(group:set(3), { id = 3 });
	end);
	it("overwrites an entity with the same id", function ()
		local group = MG.Create("set-overwrite");
		group:set(1, { v = 1 });
		group:set(1, { v = 2 });
		expectEq(group:get(1).v, 2);
		expectEq(group:length(), 1);
	end);
	it("delete removes an entity", function ()
		local group = MG.Create("delete");
		group:set(1, {});
		group:set(2, {});
		group:delete(1);
		expectNil(group:get(1));
		expectEq(group:length(), 1);
	end);
end);

describe("all / find / filter / length", function ()
	it("all returns the entities, by id", function ()
		local group = MG.Create("all");
		group:set(1, { v = "a" });
		group:set("x", { v = "b" });
		expectEq(group:all(), { [1] = { id = 1, v = "a" }, x = { id = "x", v = "b" } });
	end);
	it("find returns an entity passing the predicate, or nil", function ()
		local group = MG.Create("find");
		group:set(1, { hp = 5 });
		group:set(2, { hp = 50 });
		expectEq(group:find(function (entity) return entity.hp > 10; end).id, 2);
		expectNil(group:find(function (entity) return entity.hp > 100; end));
	end);
	it("filter returns the entities passing the predicate, under their ids", function ()
		local group = MG.Create("filter");
		group:set(1, { hp = 5 });
		group:set(2, { hp = 50 });
		group:set(3, { hp = 60 });
		local strong = group:filter(function (entity) return entity.hp > 10; end);
		expectEq(modkit.table.keys(strong), modkit.table.keys({ [2] = 1, [3] = 1 }));
		expectEq(modkit.table.length(strong), 2);
	end);
	it("length counts the entities", function ()
		local group = MG.Create("length");
		group:set(1, {});
		group:set("b", {});
		expectEq(group:length(), 2);
	end);
end);

describe("shallowCopy", function ()
	it("copies the group with new entities, keeping its methods and name", function ()
		local group = MG.Create("copy-new", { label = "units" });
		group:set(1, {});
		local copy = group:shallowCopy({ [9] = { id = 9 } });
		expectTruthy(copy ~= group, "a new table");
		expectEq(copy.group_name, "copy-new");
		expectEq(copy.label, "units");
		expectEq(copy:length(), 1);
		expectEq(copy:get(9), { id = 9 });
		expectEq(group:length(), 1, "the original keeps its entities");
		expectTruthy(group:get(1), "the original's entity is still there");
	end);
	it("shares the original's entities table when given none", function ()
		local group = MG.Create("copy-same");
		group:set(1, {});
		local copy = group:shallowCopy();
		expectTruthy(copy:all() == group:all(), "the same entities table");
	end);
	it("isn't registered as a group", function ()
		local group = MG.Create("copy-unregistered");
		group:shallowCopy({});
		expectTruthy(MG.Get("copy-unregistered") == group, "Get still returns the original");
	end);
end);

finish();
