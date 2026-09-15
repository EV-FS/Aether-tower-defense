local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Components = require(ReplicatedStorage.Shared.Components)

return function(world)
    local entities = {}

    local function onAdded(instance)
        local startPos = instance:GetAttribute("StartPosition") or (instance:IsA("Model") and instance:GetPivot().Position or instance.Position)
        local endPos = instance:GetAttribute("EndPosition") or (startPos + Vector3.new(0, 10, 0))
        local speed = instance:GetAttribute("Speed") or 5

        local id = world:spawn(Components.Mover({
            TargetPart = instance,
            StartPosition = startPos,
            EndPosition = endPos,
            Speed = speed,
            Progress = 0,
            Direction = 1,
        }))
        entities[instance] = id
    end

    local function onRemoved(instance)
        if entities[instance] then
            world:despawn(entities[instance])
            entities[instance] = nil
        end
    end

    CollectionService:GetInstanceAddedSignal("Mover"):Connect(onAdded)
    CollectionService:GetInstanceRemovedSignal("Mover"):Connect(onRemoved)

    for _, instance in ipairs(CollectionService:GetTagged("Mover")) do
        onAdded(instance)
    end
end
