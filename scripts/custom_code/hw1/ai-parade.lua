-- To ensure research ships and sensor arrays dont end up in weird places (also to mimick vanilla behavior)

---@class AIParader : Ship
ai_parade_proto = {};

function ai_parade_proto:paradeIfAI()
	if (self.player:isHuman() == nil) then
		local target = GLOBAL_SHIPS:find( -- find a mothership; if that fails, find a carrier
			function (ship)
				return ship.player.id == %self.player.id and ship:isMothership();
			end
		) or GLOBAL_SHIPS:find(
			function (ship)
				return ship.player.id == %self.player.id and ship:isCarrier();
			end
		);
		if (target) then
			self:parade(target);
		end
	end
end

function ai_parade_proto:afterUpdate()
	self:paradeIfAI();
end

-- for _, type in ai_paraders do
-- 	modkit.compose:addShipProto(type, ai_parade_proto);
-- end
modkit.compose:addBaseProto(ai_parade_proto, {
	"kus_sensorarray",
	"tai_sensorarray",
	"kus_researchship",
	"tai_researchship"
});