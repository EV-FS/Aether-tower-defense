return function(scrollFrame: ScrollingFrame, button: GuiObject): boolean
	local framePos = scrollFrame.AbsolutePosition
	local frameSize = scrollFrame.AbsoluteWindowSize

	local buttonPos = button.AbsolutePosition
	local buttonSize = button.AbsoluteSize

	return buttonPos.X < framePos.X + frameSize.X
		and buttonPos.X + buttonSize.X > framePos.X
		and buttonPos.Y < framePos.Y + frameSize.Y
		and buttonPos.Y + buttonSize.Y > framePos.Y
end
