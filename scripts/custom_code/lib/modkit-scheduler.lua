-- =====[[ modkit_scheduler ship update, which drives `modkit.events` in the ship custom code scope ]]=====

if (not modkit or not modkit.events or not hyperTableHandle) then
	dofilepath("data:scripts/modkit/events.lua");
	dofilepath("data:scripts/modkit/hypertable.lua");
end


---@class MKScheduler: Ship
scheduler = {};

function scheduler:pruneOthers()
	for _, ship in GLOBAL_SHIPS:all() do
		---@cast ship Ship
		if (ship.ship_type == "modkit_scheduler" and ship.id > self.id) then
			ship:die();
		end
	end
end

function scheduler:update()
	if (self:tick() == 1) then
		modkit.events:reset();

		self:spawn(0);
	end

	if (mod(self:tick(), 10) == 0) then
		self:pruneOthers();
	end

	modkit.events:tick();
end

modkit.compose:addShipProto("modkit_scheduler", scheduler);
