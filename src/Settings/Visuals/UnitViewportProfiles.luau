export type BoundsMode = "Portrait" | "Character" | "Visual"

export type Profile = {
	BoundsMode: BoundsMode,
	CenterOnBounds: boolean,
	FitPadding: number,
	FocusYOffset: number,
}

local CARD_DEFAULT: Profile = {
	BoundsMode = "Portrait",
	CenterOnBounds = false,
	FitPadding = 1.25,
	FocusYOffset = 0.5,
}

-- Detail previews include weapons/accessories in the distance calculation, but
-- retain HumanoidRootPart as the composition center.
local DETAIL_DEFAULT: Profile = {
	BoundsMode = "Visual",
	CenterOnBounds = false,
	FitPadding = 1.15,
	FocusYOffset = 0.18,
}

-- Weapon-inclusive full-model fitting made Galahad's face much smaller than
-- other units. All humanoids now share the animated bust composition.
local OVERRIDES: { [string]: Profile } = {}

local UnitViewportProfiles = {}

function UnitViewportProfiles.GetCard(unitName: string): Profile
	return OVERRIDES[unitName] or CARD_DEFAULT
end

function UnitViewportProfiles.GetDetail(_unitName: string): Profile
	return DETAIL_DEFAULT
end

-- Compatibility for existing card callers.
UnitViewportProfiles.Get = UnitViewportProfiles.GetCard
UnitViewportProfiles.CardDefault = CARD_DEFAULT
UnitViewportProfiles.DetailDefault = DETAIL_DEFAULT
UnitViewportProfiles.Overrides = OVERRIDES

return table.freeze(UnitViewportProfiles)
