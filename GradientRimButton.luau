--!strict

--@author BostonWhaIer
--@created 1/2/2025
--@updated 11/16/2025

--[[
Gradient Rim Button
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signal = require(ReplicatedStorage.Modules.Shared.Dependencies.Signal)

export type TriggerSource = "MouseEnter" | "MouseMoved"


-- configuration for the buttons
export type GradientRimButtonConfig = {
	TriggerSource: TriggerSource,
	GradientScale: number
}

type GradientRimButtonProto = {
	__index: GradientRimButtonProto,
	
	new: (Frame, GradientRimButtonConfig) -> GradientRimButton,
	
	_setup: (GradientRimButton) -> (),
	_teardown: (GradientRimButton) -> (),
	_rotateGradient: (GradientRimButton, number) -> ()
}

type GradientRimButton = typeof(setmetatable({} :: {
	-- internal
	_frame: Frame,
	_gradient: UIGradient,
	_button: GuiButton,
	
	_instanceColors: {
		defaultFrameColor3: Color3,
		hoverFrameColor3: Color3,
		defaultButtonColor3: Color3,
		hoverButtonColor3: Color3,
		defaultGradientColorSequence: ColorSequence,
	},
	_effectColorSequence: ColorSequence,
	
	-- state
	_triggerSource: TriggerSource,
	
	_connections: {RBXScriptConnection},
	
	-- external
	Name: string,
	MouseButton1Down: Signal.ClassType,
	MouseButton1Up: Signal.ClassType,
	MouseEnter: Signal.ClassType,
	MouseLeave: Signal.ClassType,
	MouseMoved: Signal.ClassType
	
}, {} :: GradientRimButtonProto))

local GradientRimButton: GradientRimButtonProto = {} :: GradientRimButtonProto
GradientRimButton.__index = GradientRimButton

local function traceInstancePath(instance: Instance)	
	local path = instance.Name
	local cursor = instance.Parent
	
	while cursor and cursor.Parent do
		path = cursor.Name .. "." .. path
		cursor = cursor.Parent
	end
	
	return path
end

function GradientRimButton.new(frame: Frame, config: GradientRimButtonConfig)
	local button = frame:FindFirstChildWhichIsA("GuiButton")
	if not button then
		error(
			string.format(
				"no GuiButton found inside of %s",
				traceInstancePath(frame)
			)
		)
	end

	local stroke = frame:FindFirstChildWhichIsA("UIStroke")
	if not stroke then
		error(
			string.format(
				"no UIStroke found inside of %s",
				traceInstancePath(frame)
			)
		)
	end
	
	local gradient = stroke:FindFirstChildWhichIsA("UIGradient")
	if not gradient then
		error(
			string.format(
				"no UIGradient found inside of %s",
				traceInstancePath(stroke)
			)
		)
	end
	
	local scale = config.GradientScale
	local colorScale = (1 - scale)
	
	local frameColor = frame.BackgroundColor3
	local buttonColor = button.BackgroundColor3
	
	if button:IsA("ImageButton") then
		buttonColor = button.ImageColor3
	end
	
	local self = setmetatable({
		-- internal properties
		_frame = frame,
		_gradient = gradient,
		_button = button,
		_instanceColors = table.freeze({
			defaultFrameColor3 = frameColor,
			hoverFrameColor3 = Color3.new(
				frameColor.R * colorScale,
				frameColor.G * colorScale,
				frameColor.B * colorScale
			),
			defaultButtonColor3 = buttonColor,
			hoverButtonColor3 = Color3.new(
				buttonColor.R * colorScale,
				buttonColor.G * colorScale,
				buttonColor.B * colorScale
			),
			defaultGradientColorSequence = gradient.Color,
		}),
		_effectColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.1, Color3.new(colorScale, colorScale, colorScale)),
			ColorSequenceKeypoint.new(1, Color3.new(colorScale, colorScale, colorScale))
		}),	
		
		-- state
		_connections = {},
		_triggerSource = config.TriggerSource,
		
		-- external properties
		Name = frame.Name,	-- we COULD use newproxy to do this the right way

		-- signals
		MouseButton1Down = Signal.new(),
		MouseButton1Up = Signal.new(),
		MouseEnter = Signal.new(),
		MouseLeave = Signal.new(),
		MouseMoved = Signal.new()
	}, GradientRimButton)
	
	self:_setup()
	
	return self
end

function GradientRimButton:_setup()
	local mouseEnterConnection = self._button.MouseEnter:Connect(function(x, y)
		self._frame.BackgroundColor3 = self._instanceColors.hoverFrameColor3
		
		if self._button:IsA("ImageButton") then
			self._button.ImageColor3 = self._instanceColors.hoverButtonColor3
		end
		
		if self._gradient.Color ~= self._effectColorSequence then
			self._gradient.Color = self._effectColorSequence
		end
		
		if self._triggerSource == "MouseEnter" then
			local heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
				self:_rotateGradient(self._gradient.Rotation + (dt * 250))
			end)
			
			local mouseLeaveConnection = nil
			mouseLeaveConnection = self.MouseLeave:Connect(function()
				if heartbeatConnection then
					heartbeatConnection:Disconnect()
				end
				if mouseLeaveConnection then
					mouseLeaveConnection:Disconnect()
				end
			end)
		end
		
		-- fire signal
		self.MouseEnter:Fire()
	end)
	
	local mouseLeaveConnection = self._button.MouseLeave:Connect(function()
		self._frame.BackgroundColor3 = self._instanceColors.defaultFrameColor3
		
		if self._button:IsA("ImageButton") then
			self._button.ImageColor3 = self._instanceColors.defaultButtonColor3
		end
		
		self._gradient.Color = self._instanceColors.defaultGradientColorSequence
		
		-- fire signal
		self.MouseLeave:Fire()
	end)
	
	local downConnection = self._button.MouseButton1Down:Connect(function()
		self._frame.BackgroundColor3 = self._instanceColors.defaultFrameColor3
		
		if self._button:IsA("ImageButton") then
			self._button.ImageColor3 = self._instanceColors.defaultButtonColor3
		end
		
		-- trigger the external signal
		self.MouseButton1Down:Fire()
	end)
	
	local upConnection = self._button.MouseButton1Up:Connect(function()
		self._frame.BackgroundColor3 = self._instanceColors.hoverFrameColor3

		if self._button:IsA("ImageButton") then
			self._button.ImageColor3 = self._instanceColors.hoverButtonColor3
		end
		
		-- fire signal
		self.MouseButton1Up:Fire()
	end)
	
	local mouseMovedConnection = self._button.MouseMoved:Connect(function(x, y)
		if self._triggerSource == "MouseMoved" then
			local frameAbsolutePos = self._frame.AbsolutePosition
			local frameAbsoluteSizeHalf = self._frame.AbsoluteSize / 2

			local centerAbsolutePos = frameAbsolutePos + frameAbsoluteSizeHalf

			local topBarInset = GuiService.TopbarInset

			local offsetVector = centerAbsolutePos - Vector2.new(x, y - topBarInset.Height)

			local theta = math.deg(math.atan2(offsetVector.Y, offsetVector.X))
			
			self:_rotateGradient(theta)
		end
		
		-- fire signal
		self.MouseMoved:Fire() -- eventually send args along with this signal
	end)
	
	table.insert(self._connections, mouseEnterConnection)
	table.insert(self._connections, mouseMovedConnection)
	table.insert(self._connections, mouseLeaveConnection)
	table.insert(self._connections, downConnection)
	table.insert(self._connections, upConnection)
end

function GradientRimButton:_teardown()
	for _, conn in pairs(self._connections) do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	
	self.MouseButton1Down:DisconnectAll()
	self.MouseButton1Up:DisconnectAll()
	self.MouseEnter:DisconnectAll()
	self.MouseLeave:DisconnectAll()
	self.MouseMoved:DisconnectAll()
	
	self._connections = {}
end

-- do the rim effect

function GradientRimButton:_rotateGradient(t: number)
	self._gradient.Rotation = t
end





return GradientRimButton
