local assets =
{
	Asset("ANIM", "anim/buildgridplacer.zip"),
}

local function fn()
	local inst = CreateEntity()

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
	
	inst.Transform:SetScale(1.5,1.5,1.5)
	
	-- inst:AddComponent("placer")
	-- from gridplacer, not sure what this is supposed to be doing, but seems irrelevant here
	-- inst.components.placer.oncanbuild = inst.Show
	-- inst.components.placer.oncannotbuild = inst.Hide
	
	return inst
end

return Prefab("common/buildgridplacer", fn, assets)