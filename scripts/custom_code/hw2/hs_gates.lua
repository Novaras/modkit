---@class HyperspaceGate: Ship
hs_gate_proto = {};

--- Causes this gate to link with the `target` gate.
---
---@param target HyperspaceGate
function hs_gate_proto:formHyperspaceGate(target)
	SobGroup_FormHyperspaceGate(self.own_group, target.own_group);
end

modkit.compose:addShipProto("vgr_hyperspace_platform", hs_gate_proto);
