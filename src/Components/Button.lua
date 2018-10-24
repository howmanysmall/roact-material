-- Material design button.
-- RoactMaterial does not implement floating action buttons, so they are not shown here.

local UserInputService = game:GetService("UserInputService")

-- Import configuration, gives access to Roact library.
local Configuration = require(script.Parent.Parent.Configuration)
local Roact = Configuration.Roact
local RoactAnimate = Configuration.RoactAnimate
local CreateElement = Roact.createElement

local Shadow = require(script.Parent.Shadow)
local Ink = require(script.Parent.Ink)
local TextView = require(script.Parent.TextView)
local ThemeAccessor = require(script.Parent.Parent.Utility.ThemeAccessor)

local BUTTON_TEXT_SUBSTITUTION = string.upper

local RIPPLE_TRIGGER_INPUT_TYPES = {
	Enum.UserInputType.MouseButton1,
	Enum.UserInputType.MouseButton2,
	Enum.UserInputType.MouseButton3,
	Enum.UserInputType.Touch
}

local COLOR_TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Linear.Value)
local tick = tick -- I don't like this unless it's local.

local Button = Roact.PureComponent:extend("MaterialButton")

function Button:init(props)
	self.state = {
		_pressed = false,
		_pressPoint = UDim2.new(0, 0, 0, 0),
		Elevation = 2,
		_mouseOver = false,
		_bgColor = RoactAnimate.Value.new(self.props.BackgroundColor3 or (self.props.Flat and ThemeAccessor.Get(self, "FlatButtonColor", Color3.new(1, 1, 1)) or ThemeAccessor.Get(self, "ButtonColor", Color3.new(1, 1, 1))))
	}
	
	self._lastInputEvent = tick()
end

function Button:willUpdate(nextProps, nextState)
	local goalColor
	
	if nextState._pressed then
		goalColor = self.props.PressColor3 or ThemeAccessor.Get(self, self.props.Flat and "FlatButtonPressColor" or "ButtonPressColor", Color3.new(0.9, 0.9, 0.9))
	elseif nextState._mouseOver then
		goalColor = self.props.HoverColor3 or ThemeAccessor.Get(self, self.props.Flat and "FlatButtonHoverColor" or "ButtonHoverColor", Color3.new(1, 1, 1))
	else
		goalColor = self.props.BackgroundColor3 or ThemeAccessor.Get(self, self.props.Flat and "FlatButtonColor" or "ButtonColor", Color3.new(1, 1, 1))
	end
	
	RoactAnimate(self.state._bgColor, COLOR_TWEEN_INFO, goalColor):Start()
end

function Button:_scheduleHitTest(rbx)
	local timestamp = tick()
	self._lastHitTest = timestamp
	
	-- Spawn the function in a new thread.
	coroutine.wrap(function()
		if self._lastHitTest == timestamp then
			local absolutePosition = rbx.AbsolutePosition
			local absoluteSize = rbx.AbsoluteSize
			local mousePosition = UserInputService:GetMouseLocation()
			local bottomRight = absolutePosition + absoluteSize
			
			if mousePosition.X < absolutePosition.X or mousePosition.Y < absolutePosition.Y or mousePosition.X > bottomRight.X or mousePosition.Y > bottomRight.Y then
				self:setState { _pressed = false, _mouseOver = false }
			end
		end
	end)()
end

function Button:render()
	local props = self.props
	local transparency = props.ButtonTransparency
	local textsize = props.ButtonTextSize
	local flat = props.Flat
	local elevation = flat and 0 or self.state.Elevation
	
	local function hitTester(rbx) self:_scheduleHitTest(rbx) end
	
	-- root is a dummy frame
	return CreateElement("Frame", {
		BackgroundTransparency = 1,
		Position = props.Position or UDim2.new(0, 0, 0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		Size = props.Size or UDim2.new(0, 100, 0, 40),
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder,
		
		[Roact.Change.AbsolutePosition] = hitTester,
		[Roact.Change.AbsoluteSize] = hitTester
	}, {
		CreateElement(RoactAnimate.TextButton, {
			AutoButtonColor = false,
			BorderSizePixel = 0,
			BackgroundColor3 = self.state._bgColor,
			BackgroundTransparency = transparency or 0,
			Size = UDim2.new(1, 0, 1, 0),
			Text = "",
			ZIndex = 2,
			
			[Roact.Ref] = function(rbx) self._rbx = rbx end,
			
			[Roact.Event.InputBegan] = function(rbx, input)
				for _, allowed in next, RIPPLE_TRIGGER_INPUT_TYPES do
					if input.UserInputType == allowed then
						local relativeX = (input.Position.X - rbx.AbsolutePosition.X) / rbx.AbsoluteSize.X
						local relativeY = (input.Position.Y - rbx.AbsolutePosition.Y) / rbx.AbsoluteSize.Y
						self:setState { _pressPoint = UDim2.new(relativeX, 0, relativeY, 0), _pressed = true }
						break
					end
				end
			end,
			
			[Roact.Event.InputEnded] = function(rbx, input)
				for _, allowed in next, RIPPLE_TRIGGER_INPUT_TYPES do
					if input.UserInputType == allowed then
						self:setState { _pressed = false }
						break
					end
				end
			end,
			
			[Roact.Event.MouseEnter] = function()
				self:setState { Elevation = 4, _mouseOver = true }
			end,
			
			[Roact.Event.MouseLeave] = function()
				self:setState { Elevation = 2, _mouseOver = false }
			end,
			
			[Roact.Event.MouseButton1Click] = function()
				if props.onClicked then
					props.onClicked()
				end
			end
		}, props[Roact.Children]),
		
		Children = CreateElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 4
		}, props[Roact.Children]),
		
		Ink = CreateElement(Ink, {
			ZIndex = 3,
			Rippling = self.state._pressed,
			Origin = self.state._pressPoint,
			InkColor3 = props.InkColor3 or (props.Flat and ThemeAccessor.Get(self, "PrimaryColor") or Color3.new(1, 1, 1)),
			InkTransparency = 0.5
		}),
		
		Shadow = CreateElement(Shadow, { Elevation = elevation, ZIndex = 1 }),
		
		TextLabel = CreateElement(TextView, {
			Class = "Button",
			Size = UDim2.new(1, 0, 1, 0),
			Text = props.Text and BUTTON_TEXT_SUBSTITUTION(props.Text) or "",
			ZIndex = 4,
			TextSize = textsize or 18
		})
	})
end

return Button
