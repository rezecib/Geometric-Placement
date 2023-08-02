local assets =
{
	Asset("ANIM", "anim/buildgridplacer.zip"),
}

local function common_fn()
	local inst = CreateEntity()

	inst:AddTag("CLASSIFIED")
	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
    --[[Non-networked entity]]
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("buildgridplacer")
	inst.AnimState:SetBuild("buildgridplacer")
	inst.AnimState:PlayAnimation("anim", true)
    inst.AnimState:SetLightOverride(1)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
	
	inst.Transform:SetScale(1.5,1.5,1.5)
	
	inst:AddComponent("placer")
	-- from gridplacer, not sure what this is supposed to be doing, but seems irrelevant here
	-- inst.components.placer.oncanbuild = inst.Show
	-- inst.components.placer.oncannotbuild = inst.Hide
	
	return inst
end

local FIND_SOIL_MUST_TAGS = { "soil" }
local TILLSOIL_IGNORE_TAGS = { "NOBLOCK", "player", "FX", "INLIMBO", "DECOR", "WALKABLEPLATFORM" } --, "soil" }
local function till_testfn(pt)
	if TheWorld.Map:CanTillSoilAtPoint(pt.x, 0, pt.z) then
		for i, v in ipairs(TheSim:FindEntities(pt.x, 0, pt.z, GetFarmTillSpacing(), FIND_SOIL_MUST_TAGS, TILLSOIL_IGNORE_TAGS)) do
			-- print(v)
			return false
		end
		return true
	end
	return false
end

local function till()
	local inst = common_fn()
	inst.components.placer.testfn = till_testfn
	return inst
end

return Prefab("common/till_actiongridplacer", till, assets)