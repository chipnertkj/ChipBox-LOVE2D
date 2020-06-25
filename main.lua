function Clamp(value, min, max)
	return math.min(max, math.max(value, min))
end

function KeybindSet(keybind, key, ctrl, shift, alt)
	keybinds[keybind] = {key, ctrl, shift, alt}
end

function KeybindPass(keybind)
	if keybinds[keybind][2] then
		if not (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
			return false
		end
	elseif love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
		return false
	end
	if keybinds[keybind][3] then
		if not (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) then
			return false
		end
	elseif love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
		return false
	end
	if keybinds[keybind][4] then
		if not (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")) then
			return false
		end
	elseif love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt") then
		return false
	end
	return true
end

function love.load()
	-- release
	if setup then
		love.audio.stop()
		for i = 1, #channels do
			for ii = 1, #channels[i].instruments do
				for iii = 1, #channels[i].instruments[ii].source do
					channels[i].instruments[ii].source[iii]:release()
				end
			end
		end
	end

	-- reset
	startTime = love.timer.getTime()
	cursorReset = false
	visSpectrum = {}
	pressed = false

	keys = {
		"C",
		"C#",
		"D",
		"D#",
		"E",
		"F",
		"F#",
		"G",
		"G#",
		"A",
		"A#",
		"B",
	}

	-- song setup
	channels = {}
	channelsMax = 24
	song = {
		length = 64,
		key = keys[1],
		patterns = 32,
		path = "",
		chordSize = 10,
		instruments = 1,
	}

	delta = {
		addChannel = 0,
		nameChannel = 0,
		renameChannel = 0,
		popupAddChannel = 0,
		popupRenameChannel = 0,
		popupSaveSettings = 0,
		channels = 1,
		editor = 0,
		intro = 1,
		introW = 0,
		patterns = 0,
		selectedPat = 0,
		hoveredPat = 0,
		shadowL = 0,
		shadowR = 0,
		shadowU = 0,
		shadowD = 0,
		instruments = 1,
		notePreview = 0,
	}

	settings = {
		shaders = true,
		undos = 128,
		resizable = false,
		autoSave = false,
		sliderSmoothing = 3,
		visualizerAcc = 64
	}

	sliders = 0
	timer = 0
	hover = ""
	lasthover = hover
	popup = ""
	scroll = {0, 0}
	scrollApp = {0, 0}
	scrollMax = {0, 0}
	scrollStart = {0, 0}
	isScrolling = true
	selectedPat = {}
	canMult = false
	hoverPattern = false
	selection = {{}, {}}
	undos = {}
	redos = {}
	moveSelect = false
	keyboardModes = {normal = 1, note = 2}
	keyboardMode = keyboardModes.normal
	dropdown = ""
	menuPos = {}
	settingsWindow = false
	slider = nil
	sliderScroll = 0
	changedCursor = false
	preview = {}
	
	-- setup
	if setup == nil then
		-- require
		require("luafft")

		cc = {}
		for i = 1, channelsMax do
			local ccc = 255/(channelsMax-2)*((channelsMax-i-1)*3.5)%255
			cc[i] = {{HSL(ccc, 220, 180, 255)}, {HSL(ccc, 75, 150, 120)}}
		end

		-- tables
		dropdowns = {
				--	1				2			3			4		5		6			7		8			9		10		11
			File = {"New File", "Open File", "Open Recent", "-", "Save", "Save As...", "-", "Auto Save", "Settings", "-", "Exit"},
				--	1		2		3		4		5		6		7		8		9		10				11						12				13				14				15			16		17
			Edit = {"Undo", "Redo", "-", "Cut", "Copy", "Paste", "-", "Select All", "-", "Add Channel", "Remove Selected Channels", "-", "Insert Bar Before", "Insert Bar After", "Remove Bar", "-", "Song Settings"}
		}

		keybinds = {}
		KeybindSet(dropdowns.File[1], "n", true)
		KeybindSet(dropdowns.File[2], "o", true)
		KeybindSet(dropdowns.File[3], "o", true, true)
		KeybindSet(dropdowns.File[5], "s", true)
		KeybindSet(dropdowns.File[6], "s", true, true)
		KeybindSet(dropdowns.File[9], ",", true)
		KeybindSet(dropdowns.File[11], "f4", false, false, true)
		KeybindSet(dropdowns.Edit[1], "z", true)
		KeybindSet(dropdowns.Edit[2], "z", true, true)
		KeybindSet(dropdowns.Edit[4], "x", true)
		KeybindSet(dropdowns.Edit[5], "x", true)
		KeybindSet(dropdowns.Edit[6], "v", true)
		KeybindSet(dropdowns.Edit[10], "w", true)
		KeybindSet(dropdowns.Edit[11], "delete", true, true)
		KeybindSet(dropdowns.Edit[13], "left", false, false, true)
		KeybindSet(dropdowns.Edit[14], "right", false, false, true)
		KeybindSet(dropdowns.Edit[15], "delete", true)
		KeybindSet(dropdowns.Edit[17], "q", true)
		KeybindSet("Mute", "m", true)


		windows = {
			song = "Song"
		}

		-- freq
		octaves = 7		-- plus one C

		local root = 2^(1/12)

		frequency = {}
		kfreq = {}
		for i = 0, octaves do
			for ii = 1, #keys do
				local m = 16.35*((root)^(i*12+ii-1))
				frequency[keys[ii] .. tostring(i)] = m
				kfreq[m] = ii + i*12
			end
		end


		-- hey idiot try not using anything outside (-1, 1)
		wavePresets = {
			rounded = {0, 0.2, 0.4, 0.5, 0.6, 0.7, 0.8, 0.85, 0.9, 0.95, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.95, 0.9, 0.85, 0.8,
				0.7, 0.6, 0.5, 0.4, 0.2, 0, -0.2, -0.4, -0.5, -0.6, -0.7, -0.8, -0.85, -0.9, -0.95, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
				-0.95, -0.9, -0.85, -0.8, -0.7, -0.6, -0.5, -0.4, -0.2
			},
			square = {1, -1},
			sawtooth = {1 / 31, 3 / 31, 5 / 31, 7 / 31, 9 / 31, 11 / 31, 13 / 31, 15 / 31, 17 / 31, 19 / 31, 21 / 31, 23 / 31,
				25 / 31, 27 / 31, 29 / 31, 1, -1, -29 / 31, -27 / 31, -25 / 31, -23 / 31, -21 / 31,
				-19 / 31, -17 / 31, -15 / 31, -13 / 31, -11 / 31, -9 / 31, -7 / 31, -5 / 31, -3 / 31, -1 / 31
			},
			triangle = {1 / 15, 0.2, 5 / 15, 7 / 15, 0.6, 11 / 15, 13 / 15, 1, 1, 13 / 15, 11 / 15, 0.6, 7 / 15, 5 / 15, 0.2, 1 / 15,
				-1 / 15, -0.2, -5 / 15, -7 / 15, -0.6, -11 / 15, -13 / 15, -1, -1, -13 / 15, -11 / 15, -0.6, -7 / 15, -5 / 15, -0.2, -1 / 15
			},
			doubleSaw = {0, -0.2, -0.4, -0.6, -0.8, -1, 1, -0.8, -0.6, -0.4, -0.2, 1, 0.8, 0.6, 0.4, 0.2},
			doublePulse = {1, 1, 1, 1, 1, -1, -1, -1, 1, 1, 1, 1, -1, -1, -1, -1},
			spiky = {1, -1, 1, -1, 1, 0},
			-- idiot: does it anyways
			sine = {8, 9, 11, 12, 13, 14, 15, 15, 15, 15, 14, 14, 13, 11, 10, 9, 7, 6, 4, 3, 2, 1, 0, 0, 0, 0, 1, 1, 2, 4, 5, 6}
		}
		
		-- info
		debug = true
		dirSprites = "sprites/"
		version = "devbuild 6.16.20"
		appName = "ChipBox"
		appNameFull = appName .. " | " .. version
		love.window.setIcon(love.image.newImageData(dirSprites .. "icon.png"))
		love.window.setTitle(appNameFull)
		love.filesystem.setIdentity(appName)
		love.keyboard.setKeyRepeat(true)

		-- load nickname
		nickname = ""

		nickname = string.gsub(nickname, "%#", "%%23")

		if nickname ~= "" then
			feedbackURL = "https://docs.google.com/forms/d/e/1FAIpQLSdzgGHqSVmXrGyZFRfgp1JXJ8c5RSm7bwv1D2ykMg6DVikkLQ/viewform?usp=pp_url&entry.1904527334=" .. nickname
		else
			feedbackURL = "https://docs.google.com/forms/d/e/1FAIpQLSdzgGHqSVmXrGyZFRfgp1JXJ8c5RSm7bwv1D2ykMg6DVikkLQ/viewform"
		end
		manualURL = "https://sites.google.com/view/chipbox"

		degToRad = 0.017453
		sampleSize = 64
		log = ""

		-- theme
		theme = {
			name = "",
			bg = {111/255, 116/255, 125/255},
			inside = {102/255, 105/255, 116/255},
			outside = {63/255, 66/255, 71/255},
			blank = {48/255, 48/255, 50/255},
			outline = {37/255, 37/255, 37/255},
			input = {132/255, 136/255, 150/255},
			light1 = {1, 1, 1},
			light2 = {132/255, 136/255, 150/255},
			dark = {0, 0, 0},
			selection = {0.3, 0.4, 0.8},
		}

		-- undo/redo datatypes
		datatypes = {
			pattern = 1,
			patterns = 2,
			addChannel = 3,
			removeChannel = 4,
			addBar = 5,
			removeBar = 6,
		}

		-- cursors
		cursor = {
			arrow = love.mouse.getSystemCursor("arrow"),
			hand = love.mouse.getSystemCursor("hand"),
			sizeew = love.mouse.getSystemCursor("sizewe"),
			sizens = love.mouse.getSystemCursor("sizens"),
			ibeam = love.mouse.getSystemCursor("ibeam"),
		}

		-- channel types
		channelTypes = {
			wave = 1
		}

		local dirFonts = "fonts/"

		-- sfx and sprites
		s_plus = love.graphics.newImage(dirSprites .. "plus.png")
		s_logo32 = love.graphics.newImage(dirSprites .. "logo32.png")
		s_logo320 = love.graphics.newImage(dirSprites .. "logo320.png")
		s_check = love.graphics.newImage(dirSprites .. "check.png")
		s_highlight1 = love.graphics.newImage(dirSprites .. "highlight0.png")
		s_highlight3 = love.graphics.newImage(dirSprites .. "highlight3.png")
		s_shadow = love.graphics.newImage(dirSprites .. "shadow.png")
		s_shadow_rect = love.graphics.newImage(dirSprites .. "shadow_rect.png")
		s_shadow_box = love.graphics.newImage(dirSprites .. "shadow_box.png")
		s_channel = love.graphics.newImage(dirSprites .. "channel.png")
		u_sfx = love.audio.newSource("sfx.wav", "static")
		timeburner26n = love.graphics.newFont(dirFonts .. "timeburnernormal.ttf", 26)
		timeburner17n = love.graphics.newFont(dirFonts .. "timeburnernormal.ttf", 17)
		timeburner40n = love.graphics.newFont(dirFonts .. "timeburnernormal.ttf", 40)

		
		--popups
		popups = {
			addChannel = 1,
			quit = 2,
			songSettings = 3,
			saveSettings = 4,
			renameChannel = 5,
		}
		
		-- resolution
		fullscreen = false
		updateRes()

		-- shaders
		moonshine = require("moonshine")
		effect = moonshine(res[1]*1.25, res[2]*1.25, moonshine.effects.gaussianblur)
		effect.gaussianblur.sigma = 3

		-- end setup
		setup = true
		u_sfx:play()
		u_sfx:release()
	end

	window = windows.song
end

-- update
function love.update(dt)
	-- song editor
	if window == windows.song then
		-- debug
		if debug and false then
			-- undo/redo log
			log = "undo:"
			for key, value in pairs(undos) do
				log = log .. "\n" .. value.datatype .. " \t|\t"
				if value.datatype == datatypes.patterns then
					log = log .. "x" .. value.data[1][1]
					log = log .. " y" .. value.data[1][2]
					log = log .. " x" .. value.data[2][1]
					log = log .. " y" .. value.data[2][2]
				elseif value.datatype == datatypes.pattern then
					log = log .. "v" .. value.data[2]
					log = log .. " x" .. value.data[1][1]
					log = log .. " x" .. value.data[1][2]
				else
					log = log .. tostring(value.data[#value.data])
				end
			end
			log = log .. "\nredo:"
			for key, value in pairs(redos) do
				log = log .. "\n" .. value.datatype .. " \t|\t"
				if value.datatype == datatypes.patterns then
					log = log .. "x" .. value.data[1][1]
					log = log .. " y" .. value.data[1][2]
					log = log .. " x" .. value.data[2][1]
					log = log .. " y" .. value.data[2][2]
				elseif value.datatype == datatypes.pattern then
					log = log .. "v" .. value.data[2]
					log = log .. " x" .. value.data[1][1]
					log = log .. " x" .. value.data[1][2]
				else
					log = log .. tostring(value.data[#value.data])
				end
			end
		end

		-- visualizer
		local curSound, curData
		if selectedPat[1] then
			if channels[selectedPat[1]] then
				curSound = channels[selectedPat[1]].instruments[channels[selectedPat[1]].instrument].source
				curData = channels[selectedPat[1]].instruments[channels[selectedPat[1]].instrument].soundData
			end
		end
		if curSound then
			for source = 1, song.chordSize do
				if not curSound[source] then break end
				local curSample = curSound[source]:tell("samples")
				local wave = {}
				local s = settings.visualizerAcc
				local size = next_possible_size(s)
				-- if channels == 2 then
				--     for i=curSample, (curSample+(size-1) / 2) do
				--         local sample = (curData:getSample(i * 2) + curData:getSample(i * 2 + 1)) * 0.5
				--         table.insert(wave,complex.new(sample,0))
				-- 	end
				-- else
				for i = curSample, curSample + (size - 1) do
					table.insert(wave, complex.new(curData[source]:getSample(math.max(0, i - s)), 0))
				end
		
				local spec = fft(wave, false)
				--local reconstructed = fft(spec,true)
		
				function divide(list, factor)
					for i, v in ipairs(list) do
						list[i] = list[i] / factor
					end
				end
		
				--divide(reconstructed,size)
				divide(spec, size / 2)
		
				visSpectrum[source] = spec
			end
		end

		-- dropdown
		if dropdown ~= "" then
			if string.match(hover, "(menu|)") == "menu|" then
				local sub = string.sub(hover, 6)
				if sub ~= dropdown then
					dropdown = sub
					delta.dropdown = 0
				end
			end
		end

		-- button cursor
		if hover == "addChannel" or hover == "nameChannel" then
			love.mouse.setCursor(cursor.hand)
			changedCursor = "button"
		elseif changedCursor == "button" then
			cursorReset = true
		end


		-- canMult
		if selection[2][1] ~= nil then
			local pos1 = {math.min(selection[1][2], selection[2][2]), math.min(selection[2][1], selection[1][1])}
			local pos2 = {math.max(selection[1][2], selection[2][2]), math.max(selection[2][1], selection[1][1])}

			local pass = true
			local first = channels[pos1[2]].slots[pos1[1]]
			for ih = pos1[2], pos2[2] do
				for iw = pos1[1], pos2[1] do
					if first ~= channels[ih].slots[iw] then
						pass = false
						break
					end
				end
				if pass == false then
					break
				end
			end
			if not pass then
				canMult = false
			end
		end

		-- select
		if not love.mouse.isDown(1) then
			if selection[1][1] == selection[2][1] then
				if selection[1][2] == selection[2][2] then
					selection = {{}, {}}
				end
			end
		end

		-- selected max
		if selectedPat[1] then
			selectedPat[1] = math.min(selectedPat[1], #channels)
			selectedPat[2] = math.min(selectedPat[2], song.length)
		end

		-- mouse
		xx, yy = love.mouse.getPosition()
		if slider == nil then
			xxx, yyy = love.mouse.getPosition()
		end

		local x = out*3+pat
		local y = res[2]-boxSize+out

		local w = channelCanvas:getWidth() 
		local h = channelCanvas:getHeight()

		hoverPattern = false
		if delta.channels < 0.001 then
			-- is hovering
			if xx > x and xx < x+w then
				if yy > y and yy < y+h then
					hoverPattern = true
				end
			end

			-- scrolling/selection reset
			if popup == "" and not settingsWindow then
				if hoverPattern then
					if not isScrolling then
						if love.mouse.isDown(2) then 
							isScrolling = true
							scrollStart = {{xx, yy}, scroll}
							love.mouse.setVisible(false)
						end
					else
						if not love.mouse.isDown(2) then 
							isScrolling = false
							love.mouse.setVisible(true)
						else
							scroll = {math.min(0, math.max(scrollMax[1], scrollStart[2][1]+(xx - scrollStart[1][1]))),
								math.min(0, math.max(scrollMax[2], scrollStart[2][2]+(yy - scrollStart[1][2])))
							}
							love.mouse.setPosition(scrollStart[1][1], scrollStart[1][2])
							scrollStart[2] = scroll
						end
					end
				else
					isScrolling = false
					love.mouse.setVisible(true)
				end
			else
				isScrolling = false
				love.mouse.setVisible(true)
			end
		end
	end
end

-- draw
function love.draw()
	sliders = 0
	lasthover = hover
	hover = ""
	ticks = 0

	-- song editor
	if window == windows.song then
		------------------------------
		
		-- set canvas
		if settings.shaders then
			love.graphics.setCanvas(screenCanvas)
		end
		love.graphics.clear(theme.bg)

		------------------------------

		-- bg

		hover = ""

		-- logo
		love.graphics.setColor(theme.bg[1]*1.2, theme.bg[2]*1.2, theme.bg[3]*1.2)
		love.graphics.draw(s_logo320, (res[1]-320*scale)/2+1, (res[2]-320*scale)/2+1, 0, scale, scale)
		love.graphics.setColor(theme.bg[1]*0.7, theme.bg[2]*0.71, theme.bg[3]*0.7)
		love.graphics.draw(s_logo320, (res[1]-320*scale)/2, (res[2]-320*scale)/2, 0, scale, scale)
		
		------------------------------

		-- editor
		-- outside
		love.graphics.setColor(theme.outside)
		love.graphics.rectangle("fill", 0, res[2]*(1-delta.editor)+res[2]/35, res[1]-boxSize, res[2]-boxSize)
		-- inside
		love.graphics.setColor(theme.inside)
		love.graphics.rectangle("fill", out, res[2]*(1-delta.editor)+res[2]/35+out, res[1]-boxSize-out*2, res[2]-boxSize-res[2]/35-out*2)
		-- outline
		love.graphics.setColor(theme.outline)
		love.graphics.rectangle("line", 0, res[2]*(1-delta.editor)+res[2]/35, res[1]-boxSize, res[2]-boxSize)
		love.graphics.rectangle("line", out, res[2]*(1-delta.editor)+res[2]/35+out, res[1]-boxSize-out*2, res[2]-boxSize-res[2]/35-out*2)
		
		if selectedPat[1] ~= nil and #channels > 0 and channels[selectedPat[1]] and delta.channels < 0.01 then
			if channels[selectedPat[1]].slots[selectedPat[2]] ~= 0 and channels[selectedPat[1]].slots[selectedPat[2]] ~= nil then
				delta.editor = Approach(delta.editor, 1, math.abs(delta.editor - 1)/5)
			else
				delta.editor = Approach(delta.editor, 0, math.abs(delta.editor)/6)
			end
		else
			delta.editor = Approach(delta.editor, 0, math.abs(delta.editor)/3)
		end

		---------------------------------------------

		-- instrument modification
		-- outside
		do
			local h = -(res[2]-boxSize-res[2]/35)*(1-delta.channels)
			local hh = math.min(h+out*2, 0)
			love.graphics.setColor(theme.outside)
			love.graphics.rectangle("fill", res[1]-boxSize, res[2]-boxSize, boxSize, h)
			-- inside
			love.graphics.setColor(theme.inside)
			love.graphics.rectangle("fill", res[1]-boxSize+out, res[2]-boxSize-out, boxSize-out*2, hh)

			love.graphics.setColor(theme.outline)
			love.graphics.rectangle("line", res[1]-boxSize, res[2]-boxSize, boxSize, h)
			love.graphics.rectangle("line", res[1]-boxSize+out, res[2]-boxSize-out, boxSize-out*2, hh)
		end

		---------------------------------------------

		-- channels and patterns
		-- outside
		love.graphics.setColor(theme.outside)
		love.graphics.rectangle("fill", res[1]*delta.channels, res[2]-boxSize, res[1]-boxSize, boxSize)
		-- inside
		love.graphics.setColor(theme.inside)
		love.graphics.rectangle("fill", res[1]*delta.channels+out, res[2]-boxSize+out, res[1]-boxSize-out*2, boxSize-out*7)

		-- channels, patterns AND the sliders from instrument modification cause code optimization
		if delta.channels < 0.001 then
			DrawInstrument()

			-- scroll
			scrollApp[1] = Approach(scrollApp[1], scroll[1], math.abs(scrollApp[1] - scroll[1])/3)
			scrollApp[2] = Approach(scrollApp[2], scroll[2], math.abs(scrollApp[2] - scroll[2])/3)

			-- draw on canvas
			love.graphics.setCanvas(channelCanvas)
			love.graphics.clear(0, 0, 0, 0)
			
			-- delta
			delta.patterns = Approach(delta.patterns, 1, math.abs(delta.patterns - 1)/5)
			delta.selectedPat = Approach(delta.selectedPat, 1, math.abs(delta.selectedPat - 1)/3)
			delta.hoveredPat = Approach(delta.hoveredPat, 1, math.abs(delta.hoveredPat - 1)/3)
			
			local sh = {false, false, false, false}

			-- inside
			-- outline
			love.graphics.setColor(theme.outline[1], theme.outline[2], theme.outline[3], delta.patterns)
			for ih = 1, #channels do
				for iw = 1, song.length do
					love.graphics.rectangle("fill", (pat+out)*(iw-1)+scrollApp[1]+1, (pat+out)*(ih-1)+out*2+scrollApp[2], pat, pat)
				end
			end
			for ih = 1, #channels do
				for iw = 1, song.length do
					if hoverPattern then
						buttonTopLeft((pat+out)*(iw-1)+out*3+math.ceil(boxSize/7)+scrollApp[1]+1,
							(pat+out)*(ih-1)+out*2+(res[2]-boxSize)+scrollApp[2], pat, pat, "ch" .. ih .. "sl" .. iw)
					end
					if channels[ih].slots[iw] == nil then
						channels[ih].slots[iw] = 0
					end
					local ccc
					if channels[ih].slots[iw] ~= 0 then
						ccc = theme.outside
					else
						ccc = theme.blank
					end
					love.graphics.setColor(ccc[1], ccc[2], ccc[3], delta.patterns)
					love.graphics.rectangle("fill", (pat+out)*(iw-1)+scrollApp[1]+3, (pat+out)*(ih-1)+out*2+scrollApp[2]+2, pat-4, pat-4)
				end
			end
			if isScrolling then
				hover = ""
			end

			-- selected
			if selectedPat[1] ~= nil then
				love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.selectedPat/8)
				love.graphics.rectangle("fill", (pat+out)*(selectedPat[2]-1)+scrollApp[1]+1, (pat+out)*(selectedPat[1]-1)+out*2+scrollApp[2], pat, pat)
			end

			-- numbers
			love.graphics.setFont(timeburner40n)
			for ih = 1, #channels do
				for iw = 1, song.length do
					if channels[ih].slots[iw] == nil then
						channels[ih].slots[iw] = 0
					end
					local ccc
					if channels[ih].patterns[channels[ih].slots[iw]] ~= nil then
						ccc = cc[ih][1]
					else
						ccc = cc[ih][2]
					end
					love.graphics.setColor(ccc[1]/255, ccc[2]/255, ccc[3]/255, ccc[4]/255)
					love.graphics.print(channels[ih].slots[iw], (pat+out)*(iw-1)+1 + pat/2-(timeburner40n:getWidth(channels[ih].slots[iw])*scale)/2+1+scrollApp[1],
					((pat+out)*(ih-1)+out*2) + (pat - 40*scale)/2-1+scrollApp[2], 0, scale, scale)
				end
			end

			-- hovered
			if hoverPattern then
				if popup == "" and not settingsWindow then
					if string.match(hover, "(ch)%d+") == "ch" then
						ph, pw = string.match(hover, "ch(%d+)sl(%d+)")
						love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.hoveredPat/8)
						love.graphics.rectangle("fill", (pat+out)*(pw-1)+scrollApp[1]+1, (pat+out)*(ph-1)+out*2+scrollApp[2], pat, pat)
					else
						delta.hoveredPat = 0
					end
				end
			end

			-- highlight
			if selectedPat[1] ~= nil then
				love.graphics.setBlendMode("add")
				love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.patterns/15)
				love.graphics.rectangle("fill", -out/2, (pat+out)*(selectedPat[1]-1)+out*1.5+scrollApp[2], channelCanvasSize[1]+pat+out, pat+out)
				love.graphics.setBlendMode("alpha")
			end

			-- selection
			if selection[1][1] ~= nil then
				local x, y, h, w
				if love.mouse.isDown(1) and hoverPattern then
					if string.match(hover, "(ch)%d+") == "ch" then
						ph, pw = string.match(hover, "ch(%d+)sl(%d+)")
					end
					ph = tonumber(ph)
					pw = tonumber(pw)
					selection[2] = {ph, pw}
				end
				if pw == nil then
					pw = selectedPat[2]
				end
				if ph == nil then
					ph = selectedPat[1]
				end
				if selection[2][1] == nil then
					if ph and pw then
						x = (pat+out)*(selection[1][2])+scrollApp[1]+1
						y = (pat+out)*(selection[1][1])+out*2+scrollApp[2]
						w = (pat+out)*(pw)+scrollApp[1]+1 - x
						h = (pat+out)*(ph)+out*2+scrollApp[2] - y - out
						
					end
				else
					x = (pat+out)*(selection[1][2])+scrollApp[1]+1
					y = (pat+out)*(selection[1][1])+out*2+scrollApp[2]
					w = (pat+out)*(selection[2][2])+scrollApp[1]+1 - x
					h = (pat+out)*(selection[2][1])+out*2+scrollApp[2] - y - out
				end

				local s = pat+out

				local side = {false, false}
				if w < 0 then
					side[1] = true
				end
				if h < 0 then
					side[2] = true
				end

				love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.patterns/10)
				if side[1] then
					if side[2] then
						x = x-out
						y = y-out
						w = w-s+out
						h = h-s+out*2
						love.graphics.rectangle("fill", x, y, w, h)
						love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.patterns)
						DrawLine(x+w, y, x, y)
						DrawLine(x, y, x, y+h)
						DrawLine(x, y+h, x+w, y+h)
						DrawLine(x+w, y+h, x+w, y)
					else
						x = x-out
						y = y-s
						w = w-s+out
						h = h+s
						love.graphics.rectangle("fill", x, y, w, h)
						love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.patterns)
						DrawLine(x, y, x+w, y)
						DrawLine(x, y+h, x, y)
						DrawLine(x+w, y+h, x, y+h)
						DrawLine(x+w, y, x+w, y+h)
					end
				else
					if side[2] then
						x = x-s
						y = y-out
						w = w+s-out
						h = h-s+out*2
						love.graphics.rectangle("fill", x, y, w, h)
						love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.patterns)
						DrawLine(x, y, x+w, y)
						DrawLine(x, y+h, x, y)
						DrawLine(x+w, y+h, x, y+h)
						DrawLine(x+w, y, x+w, y+h)
					else
						x = x-s
						y = y-s
						w = w+s-out
						h = h+s
						love.graphics.rectangle("fill", x, y, w, h)
						love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.patterns)
						DrawLine(x+w, y, x, y)
						DrawLine(x, y, x, y+h)
						DrawLine(x, y+h, x+w, y+h)
						DrawLine(x+w, y+h, x+w, y)
					end
				end
			end
			
			-- shadows l r u d
			if scrollApp[1] < -out*2 then
				delta.shadowL = Approach(delta.shadowL, 1, math.abs(delta.shadowL - 1)/3)
			else
				delta.shadowL = Approach(delta.shadowL, 0, math.abs(delta.shadowL)/3)
			end
			if scrollMax[1]+out*2 < scrollApp[1] then
				delta.shadowR = Approach(delta.shadowR, 1, math.abs(delta.shadowR - 1)/3)
			else
				delta.shadowR = Approach(delta.shadowR, 0, math.abs(delta.shadowR)/3)
			end
			if scrollApp[2] < -out*2 then
				delta.shadowU = Approach(delta.shadowU, 1, math.abs(delta.shadowU - 1)/3)
			else
				delta.shadowU = Approach(delta.shadowU, 0, math.abs(delta.shadowU)/3)
			end
			if scrollMax[2]+out*2 < scrollApp[2] then
				delta.shadowD = Approach(delta.shadowD, 1, math.abs(delta.shadowD - 1)/3)
			else
				delta.shadowD = Approach(delta.shadowD, 0, math.abs(delta.shadowD)/3)
			end
			love.graphics.setColor(1, 1, 1, delta.shadowL)
			love.graphics.draw(s_shadow, 0, (out+pat)*#channels+out+1, -90*degToRad, (out+pat)*#channels+out+1, scale*4)
			love.graphics.setColor(1, 1, 1, delta.shadowR)
			love.graphics.draw(s_shadow, channelCanvasSize[1], 0, 90*degToRad, (out+pat)*#channels+out+1, scale*4)
			love.graphics.setColor(1, 1, 1, delta.shadowU)
			love.graphics.draw(s_shadow, 0, 0, 0, channelCanvasSize[1], scale*4)
			love.graphics.setColor(1, 1, 1, delta.shadowD)
			love.graphics.draw(s_shadow, channelCanvasSize[1], channelCanvasSize[2], 180*degToRad, channelCanvasSize[1], scale*4)

			-- draw the canvas
			love.graphics.setColor(1, 1, 1)
			if settings.shaders then
				love.graphics.setCanvas(screenCanvas)
			else
				love.graphics.setCanvas()
			end
			love.graphics.draw(channelCanvas, out*3+pat, res[2]-boxSize+out)
			-- left canvas
			-- bars
			love.graphics.setCanvas(leftCanvas)
			love.graphics.clear(0, 0, 0, 0)
			
			for ih = 1, #channels do
				buttonTopLeft(out*3, (pat+out)*(ih-1)+out*4-scale+res[2]-boxSize+scrollApp[2], pat*0.75, pat*0.75, "channel" .. ih)
				if string.match(hover, "channel(%d+)") == tostring(ih) then
					if love.mouse.isDown(1) then
						love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.patterns)
					else
						love.graphics.setColor(theme.light2[1], theme.light2[2], theme.light2[3], delta.patterns)
					end
				else
					love.graphics.setColor(theme.outside[1], theme.outside[2], theme.outside[3], delta.patterns)
				end
				love.graphics.draw(s_channel, out, (pat+out)*(ih-1)+out*3-scale+scrollApp[2], 0, scale, scale, 0)
			end

			love.graphics.setColor(1, 1, 1)
			if settings.shaders then
				love.graphics.setCanvas(screenCanvas)
			else
				love.graphics.setCanvas()
			end
			love.graphics.draw(leftCanvas, out*2, res[2]-boxSize+out)
		end
		-- outline
		love.graphics.setColor(theme.outline)
		love.graphics.rectangle("line", res[1]*delta.channels, res[2]-boxSize, res[1]-boxSize, boxSize)
		love.graphics.rectangle("line", res[1]*delta.channels+out, res[2]-boxSize+out, res[1]-boxSize-out*2, boxSize-out*7)
		do
			local v = (keyboardMode == keyboardModes.note) and 1 or 0
			delta.notePreview = Approach(delta.notePreview, v, math.abs(delta.notePreview - v)/2)
		end
		love.graphics.setColor(theme.inside[1], theme.inside[2], theme.inside[3], delta.notePreview/1.5)
		love.graphics.rectangle("fill", res[1]*delta.channels+out, res[2]-boxSize+out, res[1]-boxSize-out*2, boxSize-out*7)

		------------------------------------------

		-- channel creation box

		-- add channel
		-- outside
		love.graphics.setColor(theme.outside)
		love.graphics.rectangle("fill", res[1]-boxSize, res[2]-boxSize, boxSize, boxSize)
		-- inside
		love.graphics.setColor(theme.inside)
		love.graphics.rectangle("fill", res[1]-boxSize+out, res[2]-boxSize+out, boxSize-out*2, boxSize-out*7)

		-- new channel button
		-- button
		if #channels < channelsMax then
			if popup == "" and not settingsWindow then
				buttonCenter(res[1]-boxSize/2, res[2]-out*3, out*16, out*5, "addChannel")
			end
		end
		if hover == "addChannel" then
			love.graphics.setColor(theme.light1)
			delta.addChannel = Approach(delta.addChannel, 1, math.abs(delta.addChannel - 1)/2)
		else
			love.graphics.setColor(theme.light2)
			delta.addChannel = Approach(delta.addChannel, 0, math.abs(delta.addChannel)/3)
		end
		if #channels >= channelsMax then
			love.graphics.setColor(theme.outline)
		end
		-- draw button
		love.graphics.draw(s_plus, res[1]-boxSize/1.95, res[2]-out*3.5, 0, out/7, out/7, 18/2*(out/7), 18/2*(out/7))
		love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.addChannel)
		love.graphics.draw(s_highlight1, res[1]-boxSize/2, math.ceil(res[2]-out*3.8), 0, scale*delta.addChannel*0.8, scale*0.73, 172/2, 30/2)
		love.graphics.draw(s_highlight3, res[1]-boxSize/2, math.ceil(res[2]-out*3.8), 0, scale*delta.addChannel*0.8, scale*0.73, 172/2, 30/2)

		-- channel 2. app and text 
		if #channels == 0 then
			-- new channel text
			love.graphics.setFont(timeburner40n)
			love.graphics.setColor(theme.light1)
			love.graphics.printf("Add a new channel", res[1]-boxSize*0.77, res[2]-boxSize*0.7, 200, "center", 0, scale, scale)
			delta.channels = Approach(delta.channels, 1, math.abs(delta.channels - 1)/5)
		else
			-- edit
			love.graphics.setFont(timeburner26n)
			love.graphics.setColor(theme.light1)
			love.graphics.setColor(theme.outline)
			love.graphics.draw(s_highlight1, res[1]-boxSize/2, res[2]-boxSize*0.8, 180*degToRad, scale*1.30, scale*1.01, 172/2, 35/2)
			if selectedPat[1] then
				local pass
				local t = channels[selectedPat[1]].name
				if selection[2][1] then
					if selection[1][1] ~= selection[2][1] then
						local start = math.min(selection[1][1], selection[2][1])
						local max = math.max(selection[1][1], selection[2][1])
						t = channels[start].name
						for i = start+1, max do
							t = t .. ", " .. channels[i].name
						end
					end
				end
				local w = timeburner26n:getWidth(t)*(scale*1.15)
				local wrap = false
				while w > boxSize-scale*50 do
					t = string.sub(t, 1, string.len(t)-2)
					w = timeburner26n:getWidth(t)*(scale*1.15)
					wrap = true
				end
				if wrap then
					t = t .. "..."
				end
				w = timeburner26n:getWidth(t)*(scale*1.15)
				local h = timeburner26n:getHeight("A")*(scale*1.1)
				local x, y = res[1]-boxSize/2-w/2, res[2]-boxSize*0.8-h/2
				PrintOutline(t, x, y, scale*1.15, scale*1.1, 1.15)
				if not pass then -- *if pass, just more convenient*
					buttonTopLeft(x, y, w, h, "renameChannel")
				end
				if hover == "renameChannel" then
					changedCursor = hover
					love.mouse.setCursor(cursor.ibeam)
				elseif changedCursor == "renameChannel" then
					changedCursor = ""
					cursorReset = true
				end
			end
			delta.channels = Approach(delta.channels, 0, math.abs(delta.channels)/5)

			-- visualizer
			do
				local sel = selectedPat[1]
				local ins = channels[sel].instruments[channels[sel].instrument]
				local vol = (ins.gain*(ins.active and 1 or 0))*3
				local vx, vy, vw, vh = res[1]-boxSize+out*1.25, res[2]-out*6, boxSize-out*4, boxSize/2
				local times = #visSpectrum[1]/2
				local dist = math.ceil(vw/times)
				local bw = dist*0.75
				for i = 1, times do
					local name = "visualizer" .. i
					if not delta[name] then
						delta[name] = 0
					end
					local nn = i
					local n = 0
					for ii = 1, song.chordSize do
						if not visSpectrum[ii] then break end
						if sel then
							local k = channels[sel].instruments[channels[sel].instrument].key[ii]
							if k then
								nn = (i-k)%times
							end
						end
						local v = visSpectrum[ii][nn] or visSpectrum[ii][i]
						n = math.min(1, n + v:abs())
					end
					delta[name] = Approach(delta[name], n*vol, math.abs(delta[name] - n*vol)/5)
					local nnn = math.max(1, 2-delta[name])
					love.graphics.setColor(cc[sel][1][1]/255*nnn, cc[sel][1][2]/255*nnn, cc[sel][1][3]/255*nnn, 0.35)
					love.graphics.rectangle("fill", (i - 1) * dist + vx, vy, bw, -math.min(boxSize-out*8, delta[name]*vh*0.85)*math.max(1, (settings.visualizerAcc/64)))
				end
			end
		end

		-- outline
		love.graphics.setColor(theme.outline)
		love.graphics.rectangle("line", res[1]-boxSize, res[2]-boxSize, boxSize, boxSize)
		love.graphics.rectangle("line", res[1]-boxSize+out, res[2]-boxSize+out, boxSize-out*2, boxSize-out*7)

		-------------------------------------------

		-- popups and blur
		if settings.shaders then
			love.graphics.setCanvas()
			love.graphics.setColor(1, 1, 1)
			if popup ~= "" or settingsWindow then
				effect(function() love.graphics.draw(screenCanvas) end)
			else
				love.graphics.draw(screenCanvas)
			end
			screenCanvas:renderTo(function() love.graphics.clear() end)
		end

		DrawSettings()

		DrawPopup(popups.addChannel)
		DrawPopup(popups.renameChannel)

		-----------------------------------------------

		-- upper bar
		love.graphics.setColor(theme.inside)
		love.graphics.rectangle("fill", 0, 0, res[1], res[2]/35)
		love.graphics.setColor(theme.outside)
		love.graphics.draw(s_logo32, out/2, out/3, 0, out/7, out/7)
		love.graphics.setColor(theme.outline)
		love.graphics.rectangle("line", 0, 0, res[1], res[2]/35)
		love.graphics.setFont(timeburner26n)
		love.graphics.print(appNameFull, (res[1] - timeburner26n:getWidth(appNameFull)*scale)/2, out/4, 0, scale, scale)
		barx = 32*(out/7) + out*3
		DrawMenuTop("File")
		DrawMenuTop("Edit")
		DrawMenuTop("View")
		DrawMenuTop("Help")

		---------------------------------------------

		-- menu dropdown
		if dropdowns[dropdown] then
			local s = #dropdowns[dropdown]

			www = 0
			local hhh = timeburner26n:getHeight("M")*scale*0.95
			for i = 1, s do
				local ww = timeburner26n:getWidth(dropdowns[dropdown][i])*scale
				if www < ww then www = ww end
			end
			www = www*2
			menuPos[dropdown] = menuPos[dropdown] - out*1.5
			love.graphics.setColor(theme.inside)
			love.graphics.rectangle("fill", menuPos[dropdown], res[2]/35, www, res[2]/35+hhh*(s-0.5))
			love.graphics.setColor(theme.outline)
			love.graphics.rectangle("line", menuPos[dropdown], res[2]/35, www, res[2]/35+hhh*(s-0.5))

			for i = 1, s do
				if dropdowns[dropdown][i] == "-" then
					love.graphics.setColor(theme.outline[1]*2.25, theme.outline[2]*2.25, theme.outline[3]*2.25)
					love.graphics.line(menuPos[dropdown]+out*2, res[2]/35+hhh*(i-1)+out*3.25, menuPos[dropdown]+www-out*2, res[2]/35+hhh*(i-1)+out*3.25)
				else
					love.graphics.setColor(theme.outline)
					--PrintOutline(dropdowns[dropdown][i], menuPos[dropdown]+out*3, res[2]/35+hhh*(i-1)+out, scale, scale, 1.15)
					love.graphics.print(dropdowns[dropdown][i], menuPos[dropdown]+out*3, res[2]/35+hhh*(i-1)+out, 0, scale, scale, 1.15)
					love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], 0.1)
					buttonTopLeft(menuPos[dropdown], res[2]/35+hhh*(i-1)+out, www, hhh, dropdowns[dropdown][i])
					if hover == dropdowns[dropdown][i] then
						love.graphics.rectangle("fill", menuPos[dropdown], res[2]/35+hhh*(i-1)+out, www, hhh+out/10)
					end
				end
			end
		end

		---------------------------------------------

		-- intro
		if delta.intro > 0 then
			-- logo
			love.graphics.setColor(0, 0, 0, delta.intro)
			love.graphics.rectangle("fill", 0, 0, res[1], res[2])
			love.graphics.setColor(theme.light1[1]/4, theme.light1[2]/4, theme.light1[3]/4, delta.intro)
			love.graphics.rectangle("fill", res[1]/3, res[2]/20*19.75, res[1]/3, 1)
			love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.intro)
			love.graphics.draw(s_logo320, (res[1]-320*scale)/2, (res[2]-320*scale)/2, 0, scale, scale)
			if delta.introW >= 0.99 then
				delta.intro = delta.intro - 0.025
			end
			if love.timer.getTime() - startTime >= 0.25 then
				delta.introW = Approach(delta.introW, 1, math.abs(delta.introW - 1)/10)
			end
			love.graphics.print(version, (res[1] - timeburner26n:getWidth(version)*(scale*1.25))/2, res[2]-res[2]/3.7, 0, scale*1.25, scale*1.25)
			love.graphics.setFont(timeburner40n)
			love.graphics.print("c h i p b o x", (res[1] - timeburner40n:getWidth("c h i p b o x")*(scale*1.5))/2, res[2]-res[2]/3, 0, scale*1.5, scale*1.5)
			love.graphics.rectangle("fill", res[1]/3, res[2]/20*19.75, res[1]/3*delta.introW, 1)
		end

		---------------------------------------------

		-- debug
		if debug then
			-- log
			love.graphics.setColor(1, 1, 1)
			love.graphics.setFont(timeburner26n)
			love.graphics.print(log, 0, 0, 0, res[1]/2000)
		end

		---------------------------------------------
	end

	-- end
	lxx, lyy = xx, yy
	if cursorReset then
		love.mouse.setCursor(cursor.arrow)
		cursorReset = false
	end
	sliderScroll = 0
	pressed = false
end

function DrawInstrument()
	if not selectedPat[1] then return end
	if not channels[selectedPat[1]] then return end
	local x = res[1]-boxSize
	local y = res[2]/35
	local w = boxSize-out*6
	local h = boxSize/2
	local ins = channels[selectedPat[1]].instruments[channels[selectedPat[1]].instrument]
	local pass, apply

	-- chip
	x = x + out*3
	y = y + out*3
	local ccc = cc[selectedPat[1]][1]
	love.graphics.setColor(ccc[1]/255, ccc[2]/255, ccc[3]/255, 0.075)
	love.graphics.rectangle("fill", x, y, w, h)
	love.graphics.setColor(theme.outside[1], theme.outside[2], theme.outside[3], 1/2)
	love.graphics.line(x, y+h/2, x+w, y+h/2)
	love.graphics.setColor(theme.outside[1], theme.outside[2], theme.outside[3], 1/6)
	love.graphics.line(x, y+h/4, x+w, y+h/4)
	love.graphics.line(x, y+h/4*3, x+w, y+h/4*3)
	love.graphics.setColor(theme.outline)
	love.graphics.rectangle("line", x, y, w, h)
	love.graphics.setColor(1, 1, 1, 0.35)
	love.graphics.draw(s_shadow_box, x, y, 0, w/128, h/128)

	-- gain
	y = y + out*5 + h
	w = boxSize/12
	h = w
	ins.active, pass = DrawTick(x, y, w, h, delta.instruments, ins.active, true)
	if pass then apply = true end

	x = x + w + out
	w = res[1]-x-out*3
	h = boxSize/18
	y = y + h/4
	ins.gain, pass = DrawSlider(x, y, w, h, ins.active, delta.instruments, ins.gain, 0.25, 0.5)
	if pass then apply = true end

	if apply then ApplyEffects() end
end

function ApplyEffects(ins, src)
	if not ins then
		if not selectedPat[1] then return end
		ins = channels[selectedPat[1]].instruments[channels[selectedPat[1]].instrument]
	end
	if src then
		Effects(ins, src)
	else
		for i = 1, song.chordSize do
			Effects(ins, i)
		end
	end
end

function Effects(ins, src)
	if not ins.source[src] then return end
	ins.source[src]:setVolume((ins.gain*(ins.active and 1 or 0)))
end

function DrawTick(x, y, w, h, a, value, default, tickName)
	local mouse = love.mouse.isDown(1)
	local def = love.mouse.isDown(3)
	local val = value and 1 or 0
	local sel = selectedPat[1]
	local tickName = "tick" .. ticks
	ticks = ticks + 1
	
	buttonTopLeft(x, y, w, h, tickName)

	-- tick
	love.graphics.setColor(theme.outside[1], theme.outside[2], theme.outside[3], a)
	love.graphics.rectangle("fill", x, y, w, h)
	love.graphics.setColor(cc[sel][1][1]/255, cc[sel][1][2]/255, cc[sel][1][3]/255, a*val)
	love.graphics.rectangle("fill", x, y, w, h)
	love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], a)
	love.graphics.draw(s_shadow_box, x, y, 0, w/128, h/128)

	-- highlight
	if hover == tickName then
		if def or mouse then
			love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], a/3)
		else
			love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], a/10)
		end
		love.graphics.rectangle("fill", x, y, w, h)
	end

	-- outline
	love.graphics.setColor(theme.inside)
	love.graphics.rectangle("fill", x+w/5, y+h/5, w/5*3, h/5*3)
	love.graphics.setColor(theme.outline[1], theme.outline[2], theme.outline[3], a)
	love.graphics.rectangle("line", x+w/5, y+h/5, w/5*3, h/5*3)
	love.graphics.rectangle("line", x, y, w, h)

	if hover == tickName then
		if def then return default, true end
		if pressed then
			return not value, true
		end
	end

	return value, false
end

function DrawSlider(x, y, w, h, cbool, a, value, default, max, min)
	-- setup
	local sel = selectedPat[1] or 1
	local ccc = cbool and 1 or 2
	if min ~= 0 and min ~= 1 then
		min = (min or 0)/max
	end
	local norm = ((value or 0)-(min or 0))/max
	sliders = sliders + 1
	local sliderName = "slider" .. tostring(sliders)
	local mouse = love.mouse.isDown(1)
	local def = love.mouse.isDown(3)

	buttonTopLeft(x, y, w, h, sliderName)
	if delta[sliderName] == nil then
		delta[sliderName] = 0
	end
	delta[sliderName] = Approach(delta[sliderName], norm, math.abs(delta[sliderName] - norm)/settings.sliderSmoothing)

	-- slider
	love.graphics.setColor(theme.outside[1], theme.outside[2], theme.outside[3], a)
	love.graphics.rectangle("fill", x, y, w, h)
	love.graphics.setColor(cc[sel][ccc][1]/255, cc[sel][ccc][2]/255, cc[sel][ccc][3]/255, a)
	love.graphics.rectangle("fill", x, y, w*delta[sliderName], h)
	love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], a/2)
	love.graphics.draw(s_shadow_rect, x, y, 0, w/128, h/64)

	-- highlight
	if slider == sliderName or sliderScroll ~= 0 or def then
		love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], a/6)
	elseif hover == sliderName then
		love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], a/20)
	end
	if hover == sliderName or slider == sliderName then
		love.graphics.rectangle("fill", x, y, w, h)
	end

	-- outline
	love.graphics.setColor(theme.outline[1], theme.outline[2], theme.outline[3], a)
	love.graphics.rectangle("line", x, y, w, h)

	-- default and return
	if hover ~= sliderName then
		if slider ~= sliderName then
			if changedCursor == sliderName then
				cursorReset = true
			end
			return value, false
		end
	end

	-- mouse scroll
	if sliderScroll ~= 0 then
		local div
		if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
			div = 100
		elseif love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
			div = 4
		else
			div = 20
		end
		return Clamp(value+(sliderScroll*max)/div, min, max), true
	end

	-- cursor
	if pressed then
		if hover == sliderName then
			slider = sliderName
		end
	end
	if not mouse then
		if hover == sliderName then
			if def then return default*max, true end
			love.mouse.setCursor(cursor.sizeew)
			changedCursor = sliderName
		elseif changedCursor == sliderName then
			cursorReset = true
		end
		if slider == sliderName then
			slider = nil
			love.mouse.setPosition(x+w*(value/max), yyy)
		end
	end

	-- value
	if slider == sliderName then
		love.mouse.setVisible(false)
		value = Clamp(value + (lxx-xxx)/600, min or 0, max)
		if mouse then
			love.mouse.setPosition(xxx, yyy)
		end
		return value, true
	else
		love.mouse.setVisible(true)
	end

	return value, false
end

function GenerateSamples(channel, freq, src)
	local pitch = freq/340
	local ins = channels[channel].instruments[channels[channel].instrument]
	local l = math.ceil(sampleSize/pitch)
	ins.soundData[src] = love.sound.newSoundData(l, 44100*(sampleSize/64), 16, 1)
	local data = ins.soundData[src]
	local preset = ins.preset
	for i = 1, l-1 do
		local norm = i/math.ceil(sampleSize/pitch)
		local n = preset[math.ceil(norm*#preset)]
		data:setSample(i, n)
	end
	WrapSource(channel, freq, src)
end

function WrapSource(channel, freq, src)
	local ins = channels[channel].instruments[channels[channel].instrument]
	if ins.source[src] then
		ins.source[src]:stop()
		ins.source[src]:release()
	end
	ins.source[src] = love.audio.newSource(ins.soundData[src])
	ins.key[src] = kfreq[freq]

	-- setup
	local s = ins.source[src]
	ApplyEffects(ins)
	s:setLooping(true)
end

function Play(channel, freq, key)
	if not freq then return end
	if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") or
	love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") or
	love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt") then return end

	local ins = channels[channel].instruments[channels[channel].instrument]

	local src
	for i = 1, song.chordSize do
		if src then break end
		if channels[channel].playing[i] == nil then
			src = i
		end
	end

	if not src then src = song.chordSize end

	channels[channel].playing[src] = key
	log = ""
	for i = 1, song.chordSize do
		log = log .. tostring(channels[channel].playing[i] or "-") .. "\n"
	end
	local s = ins.source[src]
	GenerateSamples(channel, freq, src)
	s = ins.source[src]
	s:play()
end

function Stop(channel, key)
	if not channels[channel] then return end
	local ins = channels[channel].instruments[channels[channel].instrument]
	local source
	for i = 1, #channels[channel].playing do
		if channels[channel].playing[i] == key then
			source = i
		end
	end
	if key == nil then
		channels[channel].playing = {}
		for i = 1, song.chordSize do
			if ins.source[i] then
				ins.source[i]:stop()
			end
		end
		return
	end
	if not ins.source[source] then
		channels[channel].playing = {}
		for i = 1, song.chordSize do
			if ins.source[i] then
				ins.source[i]:stop()
			end
		end
		source = song.chordSize
	end
	channels[channel].playing[source] = nil
	ins.source[source]:stop()

	log = ""
	for i = 1, song.chordSize do
		log = log .. tostring(channels[channel].playing[i] or "-") .. "\n"
	end
end

function NotePreview(key, play)
	love.keyboard.setKeyRepeat(false)
	if key:match("%c") then return end
	if keyboardMode ~= keyboardModes.note then return end
	if popup ~= "" then return end
	if not selectedPat[1] then return end
	if playing then return end

	local freq

	if key == "]" then
		freq = frequency["G5"]
	elseif key == "=" then
		freq = frequency["F#5"]
	elseif key == "[" then
		freq = frequency["F5"]
	elseif key == "p" then
		freq = frequency["E5"]
	elseif key == "0" then
		freq = frequency["D#5"]
	elseif key == "o" then
		freq = frequency["D5"]
	elseif key == "9" then
		freq = frequency["C#5"]
	elseif key == "i" then
		freq = frequency["C5"]
	elseif key == "u" then
		freq = frequency["B4"]
	elseif key == "7" then
		freq = frequency["A#4"]
	elseif key == "y" then
		freq = frequency["A4"]
	elseif key == "6" then
		freq = frequency["G#4"]
	elseif key == "t" then
		freq = frequency["G4"]
	elseif key == "5" then
		freq = frequency["F#4"]
	elseif key == "r" then
		freq = frequency["F4"]
	elseif key == "e" then
		freq = frequency["E4"]
	elseif key == "3" then
		freq = frequency["D#4"]
	elseif key == "w" then
		freq = frequency["D4"]
	elseif key == "2" then
		freq = frequency["C#4"]
	elseif key == "q" then
		freq = frequency["C4"]
	elseif key == "\\" then
		freq = frequency["F#4"]
	elseif key == "/" then
		freq = frequency["E4"]
	elseif key == ";" then
		freq = frequency["D#4"]
	elseif key == "." then
		freq = frequency["D4"]
	elseif key == "l" then
		freq = frequency["C#4"]
	elseif key == "," then
		freq = frequency["C4"]
	elseif key == "m" then
		freq = frequency["B3"]
	elseif key == "j" then
		freq = frequency["A#3"]
	elseif key == "n" then
		freq = frequency["A3"]
	elseif key == "h" then
		freq = frequency["G#3"]
	elseif key == "b" then
		freq = frequency["G3"]
	elseif key == "g" then
		freq = frequency["F#3"]
	elseif key == "v" then
		freq = frequency["F3"]
	elseif key == "c" then
		freq = frequency["E3"]
	elseif key == "d" then
		freq = frequency["D#3"]
	elseif key == "x" then
		freq = frequency["D3"]
	elseif key == "s" then
		freq = frequency["C#3"]
	elseif key == "z" then
		freq = frequency["C3"]
	end

	if not freq	then return end
	if not play then
		Stop(selectedPat[1], key)
	else
		Play(selectedPat[1], freq, key)
	end
end

function RenameChannel(noReset, t, n)
	t = t or text
	n = n or selectedPat[1]
	while string.sub(t, string.len(t)) == " " do
		t = string.sub(t, 1, string.len(t)-1)
	end
	if t ~= "" then
		if t ~= channels[n].name then
			channels[n].name = t
		end
	end
	popup = ""
end

function AddChannel(noReset, t, n)
	if #channels < channelsMax then
		t = t or text
		while string.sub(t, string.len(t)) == " " do
			t = string.sub(t, 1, string.len(t)-1)
		end
		if t ~= "" then
			local continue = true
			for i = 1, #channels do
				if channels[i].name == t then
					continue = false
					break
				end
			end
			if continue then
				local cch = n or #channels+1
				table.insert(channels, cch,
				{
					name 		= t,
					type 		= channelTypes.wave,
					slots 		= {},
					patterns 	= {},
					instrument	= 1,
					playing		= {},
					instruments = {
						{	-- 1
							active		  = true,
							preset		  = wavePresets.square,
							soundData	  = {},
							source		  = {},
							key			  = {},
							gain		  =	0.25,
							pan			  = 0,
							detune 		  = 1,
							chorus		  =	{active = false, waveform = "square", phase = 0, rate = 0, depth = 0, feedback = 0, delay = 0},
							compressor	  =	false,
							distortion	  =	{active = false, gain = 0, edge = 0, lowcut = 0, center = 0, bandwidth = 0},
							echo		  =	{active = false, delay = 0, tapdelay = 0, damping = 0, feedback = 0, spread = 0},
							equalizer	  = {active = false, lowgain = 0, lowcut = 0, lowmidgrain = 0, lowmidfrequency = 0, lowmidbandwidth = 0,
											highmidgain = 0, highmidfrequency = 0, highmidbandwidth = 0, highgain = 0, highcut = 0},
							flanger		  =	{active = false, waveform = "square", phase = 0, rate = 0, depth = 0, feedback = 0, delay = 0},
							reverb 		  =	{active = false, gain = 0, highgain = 0, density = 0, diffusion = 0, decaytime = 0, decayhighratio = 0,
											earlygain = 0, earlydelay = 0, lategain = 0, latedelay = 0, roomrolloff = 0, airabsorption = 0, highlimit = false},
							ringmodulator = {active = false, waveform = "square", frequency = 0, highcut = 0}
						}
					}
					
				})
				for i = 1, song.chordSize do
					GenerateSamples(cch, 1, i)
				end
				delta.patterns = 0
				popup = ""
				
				-- select
				selectedPat[1] = #channels
				if selectedPat[2] == nil then
					selectedPat[2] = 1
				end

				-- no reset
				if not noReset then
					AddUndo(datatypes.addChannel, {#channels, t})
				else
					delta.channels = 0
				end

				selection = {{}, {}}
				ScrollUpdate()
			end
		else
			popup = ""
		end
	end
end

function DrawSettings()
	-- setup
	local x, y, w, h
	x = res[1]/2
	y = res[2]/2
	w = res[1]/2.75
	h = res[2]/5

	-- app
	if settingsWindow then
		-- on
		if popup ~= "" then
			if popup ~= popups.saveSettings then
				popup = ""
			end
		end
		buttonCenter(x, y+h/2.4, out*16, out*5, "saveSettings")
		delta.popupSaveSettings = Approach(delta.popupSaveSettings, 1, math.abs(delta.popupSaveSettings - 1)/2)
		
	else
		-- off
		delta.popupSaveSettings = Approach(delta.popupSaveSettings, 0, math.abs(delta.popupSaveSettings)/2)
		
	end

	-- draw
	love.graphics.setColor(theme.dark[1], theme.dark[2], theme.dark[3], delta.popupSaveSettings/2)
	love.graphics.rectangle("fill", 0, 0, res[1], res[2])
	love.graphics.setColor(theme.outline[1], theme.outline[2], theme.outline[3], delta.popupSaveSettings)
	love.graphics.rectangle("fill", x-w/2-1, y-h/2-1, w+2, h+2)
	love.graphics.setColor(theme.outside[1], theme.outside[2], theme.outside[3], delta.popupSaveSettings)
	love.graphics.rectangle("fill", x-w/2, y-h/2, w, h)
	love.graphics.setColor(theme.outline[1], theme.outline[2], theme.outline[3], delta.popupSaveSettings)
	love.graphics.rectangle("fill", x-w/2+out-1, y-h/2+out-1, w-out*2+2, h-out*7+2)
	love.graphics.setColor(theme.inside[1], theme.inside[2], theme.inside[3], delta.popupSaveSettings)
	love.graphics.rectangle("fill", x-w/2+out, y-h/2+out, w-out*2, h-out*7)
	love.graphics.setColor(theme.outline[1], theme.outline[2], theme.outline[3], delta.popupSaveSettings)
	love.graphics.rectangle("fill", x-w/2+out*4, y+out*2, w-out*8, h/5)
	love.graphics.setColor(theme.input[1], theme.input[2], theme.input[3], delta.popupSaveSettings)
	love.graphics.rectangle("fill", x-w/2+out*4+1, y+out*2+1, w-out*8-2, h/5-2)
	love.graphics.setFont(timeburner40n)
	love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.popupSaveSettings)
	love.graphics.print("Channel name:", x-(timeburner40n:getWidth("Channel name:")*scale)/2, y-y/10, 0, scale, scale)
end

function DrawMenuTop(sss)
	local www = timeburner26n:getWidth(sss)
	local x, y, w, h =  barx-out*1.5, 0, out*3 + www*scale, res[2]/35
	love.graphics.print(sss, barx, out/4, 0, scale, scale)
	menuPos[sss] = barx
	buttonTopLeft(x, y, w, h, "menu|" .. sss)
	if hover == "menu|" .. sss then
		love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], 0.1)
		love.graphics.rectangle("fill", x, y, w, h)
		love.graphics.setColor(theme.outline)
	end
	-- https://musiclab.chromeexperiments.com/Song-Maker/song/6054126212349952
	barx = barx + out*3 + www*scale
end

function PrintOutline(t, x, y, sx, sy, offset)	
	love.graphics.setColor(theme.outline)
	love.graphics.print(t, x-offset, y-offset, 0, sx, sy)
	love.graphics.print(t, x-offset, y+offset, 0, sx, sy)
	love.graphics.print(t, x+offset, y+offset, 0, sx, sy)
	love.graphics.print(t, x+offset, y-offset, 0, sx, sy)
	love.graphics.setColor(theme.light1)
	love.graphics.print(t, x, y, 0, sx, sy)
end

function DrawPopup(p)
	if p == popups.addChannel then
		-- setup
		local x, y, w, h
		x = res[1]/2
		y = res[2]/2
		w = res[1]/2.75
		h = res[2]/5

		-- app
		if popup == p then
			-- on
			if #channels >= channelsMax then
				popup = ""
			else
				buttonCenter(x, y+h/2.4, out*16, out*5, "NameChannel")
				buttonTopLeft(x-w/2+out*4+1, y+out+1, w-out*8-2, h/4-2, "textInput")
				delta.popupAddChannel = Approach(delta.popupAddChannel, 1, math.abs(delta.popupAddChannel - 1)/2)
				if text == nil then
					text = ""
					textSelected = true
					cursorpos = string.len(text)
				end
			end
		else
			-- off
			delta.popupAddChannel = Approach(delta.popupAddChannel, 0, math.abs(delta.popupAddChannel)/2)
			if popup == "" then
				if text ~= nil then
					text = nil
					cursorpos = 0
					textSelected = false
				end
			end
		end

		-- draw
		love.graphics.setColor(theme.dark[1], theme.dark[2], theme.dark[3], delta.popupAddChannel/2)
		love.graphics.rectangle("fill", 0, 0, res[1], res[2])
		love.graphics.setColor(theme.outline[1], theme.outline[2], theme.outline[3], delta.popupAddChannel)
		love.graphics.rectangle("fill", x-w/2-1, y-h/2-1, w+2, h+2)
		love.graphics.setColor(theme.outside[1], theme.outside[2], theme.outside[3], delta.popupAddChannel)
		love.graphics.rectangle("fill", x-w/2, y-h/2, w, h)
		love.graphics.setColor(theme.outline[1], theme.outline[2], theme.outline[3], delta.popupAddChannel)
		love.graphics.rectangle("fill", x-w/2+out-1, y-h/2+out-1, w-out*2+2, h-out*7+2)
		love.graphics.setColor(theme.inside[1], theme.inside[2], theme.inside[3], delta.popupAddChannel)
		love.graphics.rectangle("fill", x-w/2+out, y-h/2+out, w-out*2, h-out*7)
		love.graphics.setColor(theme.outline[1], theme.outline[2], theme.outline[3], delta.popupAddChannel)
		love.graphics.rectangle("fill", x-w/2+out*4, y+out*2, w-out*8, h/5)
		love.graphics.setColor(theme.input[1], theme.input[2], theme.input[3], delta.popupAddChannel)
		love.graphics.rectangle("fill", x-w/2+out*4+1, y+out*2+1, w-out*8-2, h/5-2)
		love.graphics.setFont(timeburner40n)
		love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.popupAddChannel)
		love.graphics.print("Channel name:", x-(timeburner40n:getWidth("Channel name:")*scale)/2, y-y/10, 0, scale, scale)

		-- button
		local stop = false
		local t = text
		if t ~= nil then
			while string.sub(t, string.len(t)) == " " do
				t = string.sub(t, 1, string.len(t)-1)
			end
		end
		for i = 1, #channels do
			if channels[i].name == t then
				stop = true
			end
		end
		if not stop then
			if hover == "NameChannel" then
				love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.popupAddChannel)
				delta.nameChannel = Approach(delta.nameChannel, 1, math.abs(delta.nameChannel - 1)/2)
			else
				love.graphics.setColor(theme.light2[1], theme.light2[2], theme.light2[3], delta.popupAddChannel)
				delta.nameChannel = Approach(delta.nameChannel, 0, math.abs(delta.nameChannel)/3)
			end
		else
			love.graphics.setColor(theme.outline[1], theme.outline[2], theme.outline[3], delta.popupAddChannel)
			delta.nameChannel = Approach(delta.nameChannel, 0, math.abs(delta.nameChannel)/3)
		end
		love.graphics.draw(s_check, x-out*1.5, math.ceil(y+h/2.5)-out, 0, out/7*0.6, out/7*0.6)
		love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.nameChannel)
		love.graphics.draw(s_highlight1, x, math.ceil(y+h/2.5-1), 0, scale*delta.nameChannel*0.8, scale*0.73, 172/2, 28/2)
		love.graphics.draw(s_highlight3, x, math.ceil(y+h/2.5-1), 0, scale*delta.nameChannel*0.8, scale*0.73, 172/2, 28/2)
		
		-- text
		if text ~= nil then
			-- setup
			local tw = timeburner40n:getWidth(text)*scale*0.8
			local th = 40*scale*0.8
			local tx = x-tw/2
			local ty = y+y/30-th/2
			local tww = timeburner40n:getWidth(string.sub(text, 1, cursorpos))*scale*0.8
			local tcw

			-- text draw
			if text == "" and textSelected == false then
				love.graphics.setColor(theme.inside[1], theme.inside[2], theme.inside[3], delta.popupAddChannel)
				love.graphics.print("[ENTER to save]", x-(timeburner40n:getWidth("[ENTER to save]")*scale*0.75)/2, y+y/30, 0, scale*0.8, scale*0.8)
			else
				love.graphics.setColor(theme.outside[1], theme.outside[2], theme.outside[3], delta.popupAddChannel)
				love.graphics.print(text, x-tw/2, y+y/30, 0, scale*0.8, scale*0.8)
				tcw = timeburner40n:getWidth(string.sub(text, cursorpos-1, cursorpos))*scale*0.8
			end

			-- invisible
			if textSelected == false then
				love.graphics.setColor(0, 0, 0, 0)
			end

			-- draw
			if timer < 30 then
				love.graphics.rectangle("fill", tx+tww-1, ty+th/2, 1, th)
			end
			-- timer
			if timer >= 60 then
				timer = 0
			else
				timer = timer + 1
			end
		end
	elseif p == popups.renameChannel then
		-- setup
		local x, y, w, h
		x = res[1]/2
		y = res[2]/2
		w = res[1]/2.75
		h = res[2]/5

		-- app
		if popup == p then
			-- on
			if #channels >= channelsMax then
				popup = ""
			else
				buttonCenter(x, y+h/2.4, out*16, out*5, "RenameChannel")
				buttonTopLeft(x-w/2+out*4+1, y+out+1, w-out*8-2, h/4-2, "textInput")
				delta.popupRenameChannel = Approach(delta.popupRenameChannel, 1, math.abs(delta.popupRenameChannel - 1)/2)
				if text == nil then
					text = ""
					textSelected = true
					cursorpos = string.len(text)
				end
			end
		else
			-- off
			delta.popupRenameChannel = Approach(delta.popupRenameChannel, 0, math.abs(delta.popupRenameChannel)/2)
			if popup == "" then
				if text ~= nil then
					text = nil
					cursorpos = 0
					textSelected = false
				end
			end
		end

		-- draw
		love.graphics.setColor(theme.dark[1], theme.dark[2], theme.dark[3], delta.popupRenameChannel/2)
		love.graphics.rectangle("fill", 0, 0, res[1], res[2])
		love.graphics.setColor(theme.outline[1], theme.outline[2], theme.outline[3], delta.popupRenameChannel)
		love.graphics.rectangle("fill", x-w/2-1, y-h/2-1, w+2, h+2)
		love.graphics.setColor(theme.outside[1], theme.outside[2], theme.outside[3], delta.popupRenameChannel)
		love.graphics.rectangle("fill", x-w/2, y-h/2, w, h)
		love.graphics.setColor(theme.outline[1], theme.outline[2], theme.outline[3], delta.popupRenameChannel)
		love.graphics.rectangle("fill", x-w/2+out-1, y-h/2+out-1, w-out*2+2, h-out*7+2)
		love.graphics.setColor(theme.inside[1], theme.inside[2], theme.inside[3], delta.popupRenameChannel)
		love.graphics.rectangle("fill", x-w/2+out, y-h/2+out, w-out*2, h-out*7)
		love.graphics.setColor(theme.outline[1], theme.outline[2], theme.outline[3], delta.popupRenameChannel)
		love.graphics.rectangle("fill", x-w/2+out*4, y+out*2, w-out*8, h/5)
		love.graphics.setColor(theme.input[1], theme.input[2], theme.input[3], delta.popupRenameChannel)
		love.graphics.rectangle("fill", x-w/2+out*4+1, y+out*2+1, w-out*8-2, h/5-2)
		love.graphics.setFont(timeburner40n)
		love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.popupRenameChannel)
		love.graphics.print("Rename:", x-(timeburner40n:getWidth("Rename:")*scale)/2, y-y/10, 0, scale, scale)

		-- button
		local stop = false
		local t = text
		if t ~= nil then
			while string.sub(t, string.len(t)) == " " do
				t = string.sub(t, 1, string.len(t)-1)
			end
		end
		for i = 1, #channels do
			if channels[i].name == t then
				stop = true
			end
		end
		if not stop then
			if hover == "RenameChannel" then
				love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.popupRenameChannel)
				delta.renameChannel = Approach(delta.renameChannel, 1, math.abs(delta.renameChannel - 1)/2)
			else
				love.graphics.setColor(theme.light2[1], theme.light2[2], theme.light2[3], delta.popupRenameChannel)
				delta.renameChannel = Approach(delta.renameChannel, 0, math.abs(delta.renameChannel)/3)
			end
		else
			love.graphics.setColor(theme.outline[1], theme.outline[2], theme.outline[3], delta.popupRenameChannel)
			delta.renameChannel = Approach(delta.renameChannel, 0, math.abs(delta.renameChannel)/3)
		end
		love.graphics.draw(s_check, x-out*1.5, math.ceil(y+h/2.5)-out, 0, out/7*0.6, out/7*0.6)
		love.graphics.setColor(theme.light1[1], theme.light1[2], theme.light1[3], delta.renameChannel)
		love.graphics.draw(s_highlight1, x, math.ceil(y+h/2.5-1), 0, scale*delta.renameChannel*0.8, scale*0.73, 172/2, 28/2)
		love.graphics.draw(s_highlight3, x, math.ceil(y+h/2.5-1), 0, scale*delta.renameChannel*0.8, scale*0.73, 172/2, 28/2)
		
		-- text
		if text ~= nil then
			-- setup
			local tw = timeburner40n:getWidth(text)*scale*0.8
			local th = 40*scale*0.8
			local tx = x-tw/2
			local ty = y+y/30-th/2
			local tww = timeburner40n:getWidth(string.sub(text, 1, cursorpos))*scale*0.8
			local tcw

			-- text draw
			if text == "" and textSelected == false then
				love.graphics.setColor(theme.inside[1], theme.inside[2], theme.inside[3], delta.popupRenameChannel)
				love.graphics.print("[ENTER to save]", x-(timeburner40n:getWidth("[ENTER to save]")*scale*0.75)/2, y+y/30, 0, scale*0.8, scale*0.8)
			else
				love.graphics.setColor(theme.outside[1], theme.outside[2], theme.outside[3], delta.popupRenameChannel)
				love.graphics.print(text, x-tw/2, y+y/30, 0, scale*0.8, scale*0.8)
				tcw = timeburner40n:getWidth(string.sub(text, cursorpos-1, cursorpos))*scale*0.8
			end

			-- invisible
			if textSelected == false then
				love.graphics.setColor(0, 0, 0, 0)
			end

			-- draw
			if timer < 30 then
				love.graphics.rectangle("fill", tx+tww-1, ty+th/2, 1, th)
			end
			-- timer
			if timer >= 60 then
				timer = 0
			else
				timer = timer + 1
			end
		end
	else
		
	end
	
end

function love.textinput(tt)
	if textSelected then
		local t = {string.sub(text, 0, cursorpos), string.sub(text, cursorpos+1, string.len(text))}
		text = string.sub(t[1], 0, string.len(t[1])) .. tt .. t[2]
		text = string.sub(text, 0, 25)
		timer = 0
		cursorpos = math.min(cursorpos + 1, 25)
	elseif keyboardMode ~= keyboardModes.normal then return
	elseif selectedPat[1] ~= nil then
		if popup == "" and not settingsWindow then
			if string.match(tt, "(%d+)") == tt then
				if canMult then
					if channels[selectedPat[1]].slots[selectedPat[2]]/10 < 1 then
						if channels[selectedPat[1]].slots[selectedPat[2]]*10 + tonumber(tt) <= song.patterns then
							if selection[2][1] == nil then
								AddUndo(datatypes.pattern, {{selectedPat[1], selectedPat[2]}, channels[selectedPat[1]].slots[selectedPat[2]]})
								channels[selectedPat[1]].slots[selectedPat[2]] = channels[selectedPat[1]].slots[selectedPat[2]]*10 + tonumber(tt)
							else
								local pos1, pos2
								pos1 = {math.min(selection[1][2], selection[2][2]), math.min(selection[2][1], selection[1][1])}
								pos2 = {math.max(selection[1][2], selection[2][2]), math.max(selection[2][1], selection[1][1])}

								local d = {}
								for ih = pos1[2], pos2[2] do
									d[ih] = {}
									for iw = pos1[1], pos2[1] do
										d[ih][iw] = channels[ih].slots[iw]
										channels[ih].slots[iw] = channels[ih].slots[iw]*10 + tonumber(tt)
									end
								end
								AddUndo(datatypes.patterns, {{pos1[1], pos1[2]}, {pos2[1], pos2[2]}, d})
							end
						else
							if tonumber(tt) <= song.patterns then
								if selection[2][1] == nil then
									AddUndo(datatypes.pattern, {{selectedPat[1], selectedPat[2]}, channels[selectedPat[1]].slots[selectedPat[2]]})
									channels[selectedPat[1]].slots[selectedPat[2]] = tonumber(tt)
									canMult = true
								else
									local pos1, pos2
									pos1 = {math.min(selection[1][2], selection[2][2]), math.min(selection[2][1], selection[1][1])}
									pos2 = {math.max(selection[1][2], selection[2][2]), math.max(selection[2][1], selection[1][1])}

									local d = {}
									for ih = pos1[2], pos2[2] do
										d[ih] = {}
										for iw = pos1[1], pos2[1] do
											d[ih][iw] = channels[ih].slots[iw]
											channels[ih].slots[iw] = tonumber(tt)
										end
									end
									canMult = true
									AddUndo(datatypes.patterns, {{pos1[1], pos1[2]}, {pos2[1], pos2[2]}, d})
								end
							end
						end
					else
						if selection[2][1] == nil then
							AddUndo(datatypes.pattern, {{selectedPat[1], selectedPat[2]}, channels[selectedPat[1]].slots[selectedPat[2]]})
							channels[selectedPat[1]].slots[selectedPat[2]] = tonumber(tt)
						else
							local pos1, pos2
							pos1 = {math.min(selection[1][2], selection[2][2]), math.min(selection[2][1], selection[1][1])}
							pos2 = {math.max(selection[1][2], selection[2][2]), math.max(selection[2][1], selection[1][1])}

							local d = {}
							for ih = pos1[2], pos2[2] do
								d[ih] = {}
								for iw = pos1[1], pos2[1] do
									d[ih][iw] = channels[ih].slots[iw]
									channels[ih].slots[iw] = tonumber(tt)
								end
							end
							AddUndo(datatypes.patterns, {{pos1[1], pos1[2]}, {pos2[1], pos2[2]}, d})
						end
					end
				else
					if tonumber(tt) <= song.patterns then
						if selection[2][1] == nil then
							AddUndo(datatypes.pattern, {{selectedPat[1], selectedPat[2]}, channels[selectedPat[1]].slots[selectedPat[2]]})
							channels[selectedPat[1]].slots[selectedPat[2]] = tonumber(tt)
							canMult = true
						else
							local pos1, pos2
							pos1 = {math.min(selection[1][2], selection[2][2]), math.min(selection[2][1], selection[1][1])}
							pos2 = {math.max(selection[1][2], selection[2][2]), math.max(selection[2][1], selection[1][1])}

							local d = {}
							for ih = pos1[2], pos2[2] do
								d[ih] = {}
								for iw = pos1[1], pos2[1] do
									d[ih][iw] = channels[ih].slots[iw]
									channels[ih].slots[iw] = tonumber(tt)
								end
							end
							canMult = true
							AddUndo(datatypes.patterns, {{pos1[1], pos1[2]}, {pos2[1], pos2[2]}, d})
						end
					end
				end
			end
		end
	end
end

function buttonCenter(x, y, w, h, b)
	if delta.intro < 0.99 then
		if xx > x-w/2 and xx < x+w/2 then
			if yy > y-h/2 and yy < y+h/2 then
				hover = b
			end
		end
	end
end

function buttonTopLeft(x, y, w, h, b)
	if delta.intro <= 0.99 then
		if xx > x and xx < x+w then
			if yy > y and yy < y+h then
				hover = b
			end
		end
	end
end

function MovePattern(key)
	love.keyboard.setKeyRepeat(true)
	if textSelected then
		if key == "left" then
			cursorpos = math.max(0, cursorpos-1)
			timer = 0
		elseif key == "right" then
			cursorpos = math.min(string.len(text), cursorpos+1)
			timer = 0
		end
	elseif popup == "" and not settingsWindow then
		-- select
		local sel = false
		if key == "left" or key == "right" or key == "down" or key == "up" then
			if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
				sel = true
			else
				moveSelect = false
			end
		end

		if sel then
			if selection[1][1] == nil or not moveSelect then
				selection[1][1] = selectedPat[1]
				selection[1][2] = selectedPat[2]
				moveSelect = true
			end
		end

		if key == "left" then
			if selectedPat[2] ~= nil then
				canMult = false
				selectedPat[2] = selectedPat[2] - 1
				if selectedPat[2] < 1 then
					selectedPat[2] = song.length
				end
			elseif delta.channels < 0.001 then
				selectedPat = {1, 1}
			end
		elseif key == "right" then
			if selectedPat[2] ~= nil then
				canMult = false
				selectedPat[2] = selectedPat[2] + 1
				if selectedPat[2] > song.length then
					selectedPat[2] = 1
				end
			elseif delta.channels < 0.001 then
				selectedPat = {1, 1}
			end
		elseif key == "up" then
			if selectedPat[1] ~= nil then
				Stop(selectedPat[1])
				canMult = false
				selectedPat[1] = selectedPat[1] - 1
				if selectedPat[1] < 1 then
					selectedPat[1] = #channels
				end
			elseif delta.channels < 0.001 then
				selectedPat = {1, 1}
			end
		elseif key == "down" then
			if selectedPat[1] ~= nil then
				Stop(selectedPat[1])
				canMult = false
				selectedPat[1] = selectedPat[1] + 1
				if selectedPat[1] > #channels then
					selectedPat[1] = 1
				end
			elseif delta.channels < 0.001 then
				selectedPat = {1, 1}
			end
		end

		if sel then
			if selection[1][1] ~= nil then
				selection[2][1] = selectedPat[1]
				selection[2][2] = selectedPat[2]
				if selection[1][1] == selection[2][1] then
					if selection[1][2] == selection[2][2] then
						selection = {{}, {}}
					end
				end
			end
		else
			if key ~= "" then
				selection = {{}, {}}
			end
		end

		-- scroll
		ScrollSet()

		-- reset scrollApp
		if key == "" then
			scrollApp[1] = scroll[1]
			scrollApp[2] = scroll[2]
		end
		delta.selectedPat = 0.25
	end
end

function love.keypressed(key)
	NotePreview(key, true)
	if delta.intro <= 0.99 then
		if key == "backspace" then
			if textSelected then
				love.keyboard.setKeyRepeat(true)
				local t = {string.sub(text, 0, cursorpos), string.sub(text, cursorpos+1, string.len(text))}
				if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
					if string.sub(text, cursorpos, cursorpos) == " " then
						text = string.sub(t[1], 0, string.len(t[1])-1) .. t[2]
						cursorpos = math.max(0, cursorpos-1)
						t = {string.sub(text, 0, cursorpos), string.sub(text, cursorpos+1, string.len(text))}
					end
					while string.len(t[1]) > 0 and string.sub(text, cursorpos, cursorpos) ~= " " do
						text = string.sub(t[1], 0, string.len(t[1])-1) .. t[2]
						cursorpos = math.max(0, cursorpos-1)
						t = {string.sub(text, 0, cursorpos), string.sub(text, cursorpos+1, string.len(text))}
					end
				else
					text = string.sub(t[1], 0, string.len(t[1])-1) .. t[2]
					cursorpos = math.max(0, cursorpos-1)
				end
				timer = 0
			end
		elseif key == "delete" then
			if textSelected then
				local t = {string.sub(text, 0, cursorpos), string.sub(text, cursorpos+2, string.len(text))}
				text = t[1] .. t[2]
				timer = 0
			end
		elseif key == "left" then
			if not KeybindPass(dropdowns.Edit[13]) then MovePattern(key) else AddBar(selectedPat[2]) end
		elseif key == "right" then
			if not KeybindPass(dropdowns.Edit[14]) then MovePattern(key) else AddBar(selectedPat[2]+1) end
		elseif key == "up" or key == "down" then
			MovePattern(key)
		elseif key == "escape" then
			if settingsWindow then
				popup = popups.saveSettings
			elseif popup ~= "" then
				popup = ""
			else
				selection = {{}, {}}
			end
		elseif key == keybinds[dropdowns.Edit[10]][1] then		-- add channel
			if not KeybindPass(dropdowns.Edit[10]) then return end
			if popup ~= popups.addChannel and #channels < channelsMax then
				popup = popups.addChannel
			end
		elseif key == keybinds[dropdowns.Edit[17]][1] then	-- channel settings
			if not KeybindPass(dropdowns.Edit[17]) then return end
			if popup == "" and not settingsWindow then
				popup = popups.songSettings
			end
		elseif key == keybinds[dropdowns.File[9]][1] then	-- settings
			if not KeybindPass(dropdowns.File[9]) then return end
			settingsWindow = true
		elseif key == keybinds["Mute"][1] then	-- mute
			if not KeybindPass("Mute") then return end
			if not selectedPat[1] then return end
			channels[selectedPat[1]].instruments[channels[selectedPat[1]].instrument].active =
			not channels[selectedPat[1]].instruments[channels[selectedPat[1]].instrument].active
			ApplyEffects(selectedPat[1])
		elseif key == "return" then
			if textSelected then
				if popup == popups.addChannel then
					AddChannel()
				elseif popup == popups.renameChannel then
					RenameChannel()
				end
			elseif popup == "" then
				if keyboardMode == keyboardModes.normal then
					keyboardMode = keyboardModes.note
				elseif keyboardMode == keyboardModes.note then
					keyboardMode = keyboardModes.normal
				end
			end
		elseif key == "a" then
			if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
				SelectAll()
			end
		elseif key == "n" then
			if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
				NewFile()
			end
		end
	end
	if key == "f11" then
		fullscreen = not fullscreen
		updateRes()
	elseif key == "f4" then
		if love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt") then
			love.window.close()
		end
	elseif key == "f2" then
		if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
			debug = not debug
		else
			love.system.openURL(feedbackURL)
		end
	elseif key == "f1" then
		love.system.openURL(manualURL)
	elseif key == "l" then
		if love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt") then
			love.load()
		end
	elseif key == "z" then
		if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
			if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
				Redo()
			else
				Undo()
			end
		end
	end
end

function love.keyreleased(key)
	NotePreview(key, false)
end

function Approach(a, b, c)
	if a < b then
		a = a + c
	end
	if a > b then
		a = a - c
	end
	return a
end

function updateRes(flag)
	if not flag or not settings.resizable then
		local _, _, flags = love.window.getMode()
		local resW, resH = love.window.getDesktopDimensions(flags.display)
		--local resW = 768 local resH = 768
		if not fullscreen then
			resW = resW/1.25
			resH = resH/1.25
		end
		res = {resW, resH}
	
		love.window.setMode(res[1], res[2], {resizable = settings.resizable})
	else
		local resW, resH = love.window.getMode()
		res = {resW, resH}
	end

	if screenCanvas ~= nil then
		screenCanvas:release()
	end
	if channelCanvas ~= nil then
		channelCanvas:release()
	end
	if leftCanvas ~= nil then
		leftCanvas:release()
	end
	boxSize = math.min(res[1], res[2])/3.5
	out = boxSize/50
	scale = out/7
	pat = math.ceil(boxSize/7)
	screenCanvas = love.graphics.newCanvas(res[1], res[2])
	channelCanvas = love.graphics.newCanvas(math.floor(res[1]-boxSize-out*4+0.5)-math.ceil(boxSize/7), math.floor(boxSize-out*7+0.5))
	leftCanvas = love.graphics.newCanvas(pat+out*2, math.floor(boxSize-out*7+0.5))
	channelCanvasSize = {channelCanvas:getWidth(), channelCanvas:getHeight()}
	leftCanvasSize = {leftCanvas:getWidth(), leftCanvas:getHeight()}
	ScrollUpdate()
end

function love.resize()
	updateRes(true)	
end

function love.mousereleased(_, _, b)
	if b == 1 then
		if popup == "" and not settingsWindow then
			if hover == "" or string.match(hover, "(ch)%d+") == "ch" then
				if selection[1][1] ~= nil and selection[2][1] == nil then
					selection[2] = {tonumber(ph), tonumber(pw)}
					if selection[1][1] == selection[2][1] then
						if selection[1][2] == selection[2][2] then
							selection = {{}, {}}
						end
					end
				
					if string.match(hover, "(ch)%d+") == "ch" then
						ph, pw = string.match(hover, "ch(%d+)sl(%d+)")
					end
				end
			end
		end
	end
end

function love.mousepressed(xx, yy, b)
	if popup ~= "" then
		if popup == popups.addChannel or popup == popups.renameChannel then
			local x, y, w, h
			x = res[1]/2
			y = res[2]/2
			w = res[1]/2.75
			h = res[2]/5
			if (xx < x-w/2 or xx > x+w/2 or yy < y-h/2 or yy > y+h/2) and yy > res[2]/35 then
				popup = ""
			end
			x = res[1]/2-res[1]/2.75/2+out*4+1
			y = res[2]/2+out+1
			w = res[1]/2.75-out*8-2
			h = res[2]/5/4-2
			if (xx < x-w/2 or xx > x+w/2 or yy < y-h/2 or yy > y+h/2) and yy > res[2]/35 then
				textSelected = false
			end
		end
	end
	if b == 1 then
		if popup == "" then
			pressed = true
		end
		if hover == "addChannel" then
			popup = popups.addChannel
		elseif hover == "renameChannel" then
			popup = popups.renameChannel
		elseif hover == "textInput" then
			textSelected = true
		elseif hover == "NameChannel" then
			AddChannel()
		elseif hover == "RenameChannel" then
			RenameChannel()
		elseif string.match(hover, "(ch)%d+") == "ch" then
			if hoverPattern then
				if selection[1][1] ~= nil then
					if not love.mouse.isDown(1) then
						selection = {{}, {}}
					end
				end
				local ph, pw = string.match(hover, "ch(%d+)sl(%d+)")
				canMult = false
				selectedPat = {tonumber(ph), tonumber(pw)}
				delta.selectedPat = 0
				if selection[2][1] ~= nil then
					selection[2] = {}
				end
				selection[1] = {tonumber(ph), tonumber(pw)}
			end
		elseif hover == dropdowns.File[1] then	-- New File
			NewFile()
		elseif hover == dropdowns.File[2] then	-- Open File
			OpenFile()
		elseif hover == dropdowns.File[4] then	-- Save
			Save()
		elseif hover == dropdowns.File[5] then	-- Save As
			Save(true)
		elseif hover == dropdowns.File[9] then	-- Settings
			settingsWindow = true
		elseif hover == dropdowns.File[11] then	-- Exit
			Exit()
		elseif hover == dropdowns.Edit[1] then	-- Undo
			Undo()
		elseif hover == dropdowns.Edit[2] then	-- Redo
			Redo()
		elseif hover == dropdowns.Edit[8] then	-- select all
			SelectAll()
		elseif hover == dropdowns.Edit[10] then	-- Add Channel
			popup = popups.addChannel
		elseif hover == dropdowns.Edit[11] then	-- Remove Channels
			RemoveChannels()
		elseif hover == dropdowns.Edit[17] then	-- Song Settings
			if popup == "" and not settingsWindow then
				popup = popups.songSettings
			end
		elseif hover == dropdowns.Edit[13] then	-- insert left
			AddBar(selectedPat[2])
		elseif hover == dropdowns.Edit[14] then	-- insert right
			AddBar(selectedPat[2]+1)
		elseif hover == dropdowns.Edit[15] then	-- remove bar
			RemoveBar(selectedPat[2])
		end
		if string.match(hover, "(channel)%d+") == "channel" then
			dropdown = "ch" .. string.match(hover, "channel(%d+)")
			delta.dropdown = 0
		elseif string.match(hover, "(menu|)") == "menu|" then
			dropdown = string.sub(hover, 6)
			delta.dropdown = 0
		else
			dropdown = ""
			delta.dropdown = 0
		end
	end
end

-- Converts HSL to RGB. (input and output range: 0 - 255)
-- i dont know and i dont wanna know how the hell this fucking robot code works
-- whats most important is that it does work
function HSL(h, s, l, a)
	if s<=0 then return l,l,l,a end
	h, s, l = h/256*6, s/255, l/255
	local c = (1-math.abs(2*l-1))*s
	local x = (1-math.abs(h%2-1))*c
	local m,r,g,b = (l-.5*c), 0,0,0
	if h < 1     then r,g,b = c,x,0
	elseif h < 2 then r,g,b = x,c,0
	elseif h < 3 then r,g,b = 0,c,x
	elseif h < 4 then r,g,b = 0,x,c
	elseif h < 5 then r,g,b = x,0,c
	else              r,g,b = c,0,x
	end return (r+m)*255,(g+m)*255,(b+m)*255,a
end

function RemoveChannels()
	if selection[2][2] ~= nil and selection[1][1] ~= selection[2][1] then
		local start = math.min(selection[1][1], selection[2][1])
		local max = math.max(selection[1][1], selection[2][1])
		for i = max, start, -1 do
			local d = {}
			for iw = 1, song.length do
				d[iw] = channels[i].slots[iw]
			end
			AddUndo(datatypes.removeChannel, {i, channels[i].name, d})
			table.remove(channels, i)
		end
	elseif selectedPat[1] ~= nil then
		local d = {}
		for iw = 1, song.length do
			d[iw] = channels[selectedPat[1]].slots[iw]
		end
		AddUndo(datatypes.removeChannel, {selectedPat[1], channels[selectedPat[1]].name, d})
		table.remove(channels, selectedPat[1])
		selectedPat[1] = #channels
		if selectedPat[1] == 0 then
			selectedPat = {}
		end
	end
	selection = {{}, {}}
	selectedPat[1] = #channels
	if selectedPat[1] == 0 then
		selectedPat = {}
	end
	ScrollUpdate()
end

function love.wheelmoved(_, y)
	sliderScroll = sliderScroll + y
	if delta.channels < 0.001 then
		if popup == "" and not settingsWindow then
			if hoverPattern then
				if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
					scroll[1] = math.min(0, math.max(scrollMax[1], scroll[1] + y*(pat+out)))
				else
					scroll[2] = math.min(0, math.max(scrollMax[2], scroll[2] + y*(pat+out)))
				end
			end
		end
	end
end

function ScrollUpdate()
	scrollMax[1] = -((pat+out)*(song.length-(res[1]-boxSize)/(pat+out)+1)+out*4)
	scrollMax[2] = -((pat+out)*(#channels-boxSize/(pat+out)+1)+out*2)
	MovePattern("")
end

function ScrollSet()
	if selectedPat[1] ~= nil then
		scroll[1] = math.min(0, math.max(scrollMax[1], channelCanvasSize[1]/2-(selectedPat[2]-1)*(out+pat)))
		scroll[2] = math.min(0, math.max(scrollMax[2], channelCanvasSize[2]/2-(selectedPat[1])*(out+pat)))
	end
end

function SelectAll()
	if popup == "" and not settingsWindow then
		if #channels > 0 then
			selection = {{1, 1}, {#channels, song.length}}
		end
	end
end

function AddBar(n, v, noReset)
	song.length = song.length + 1
	for iw = song.length-1, n, -1 do
		for ih = 1, #channels do
			channels[ih].slots[iw+1] = channels[ih].slots[iw]
			channels[ih].slots[iw] = v and v[ih] or 0
		end
	end
	if not noReset then
		AddUndo(datatypes.addBar, {n, v})
	end
end

function RemoveBar(n, noReset)
	local v = {}
	for ih = 1, #channels do
		v[ih] = channels[ih].slots[n]
		for iw = n, song.length do
			channels[ih].slots[iw] = channels[ih].slots[iw+1]
		end
	end
	song.length = song.length - 1
	ScrollUpdate()
	if not noReset then
		AddUndo(datatypes.removeBar, {n, v})
	end
end

function NewFile()
	love.load()
	delta.introW = 1
end

function Save(flag)
	if song.path == "" or flag then
		-- select path
	end
	-- save
end

function OpenFile()
	log = "OpenFile()"
end

function Exit()
	love.window.close()
end

function DrawLine(x1, y1, x2, y2)
	love.graphics.setPointSize(scale*2)

	local x, y = x2 - x1, y2 - y1
	local len = math.sqrt(x^2 + y^2)
	local stepx, stepy = x/len, y/len
	x = x1
	y = y1

	for i = 1, len do
		if (i+(love.timer.getTime()*5-startTime*5)%2*5)%10 < 7 then
			love.graphics.points(x, y)
		end
		x = x + stepx
		y = y + stepy
	end
end

function AddUndo(datatype, data, noReset)
	if noReset == nil then
		redos = {}
	end
	table.insert(undos, 1, {datatype = datatype, data = data})
	if #undos > settings.undos then
		table.remove(undos)
	end
end

function AddRedo(datatype, data)
	table.insert(redos, 1, {datatype = datatype, data = data})
end

function Undo()
	if #undos > 0 then
		local this = undos[1]
		selection = {{}, {}}
		popup = ""

		if this.datatype == datatypes.addChannel then
			table.remove(channels, this.data[1])
		elseif this.datatype == datatypes.removeChannel then
			AddChannel(true, this.data[2], this.data[1])
			for i = 1, song.length do
				if this.data[3][i] == nil then break end
				channels[this.data[1]].slots[i] = this.data[3][i]
			end
		elseif this.datatype == datatypes.pattern then
			local pos = this.data[1]
			selectedPat[1] = pos[1]
			selectedPat[2] = pos[2]
			local p = channels[pos[1]].slots[pos[2]]
			channels[pos[1]].slots[pos[2]] = this.data[2]
			this.data[2] = p
		elseif this.datatype == datatypes.patterns then
			local pos = {this.data[1], this.data[2]}
			for ih = pos[1][2], pos[2][2] do
				for iw = pos[1][1], pos[2][1] do
					local p = channels[ih].slots[iw]
					channels[ih].slots[iw] = this.data[3][ih][iw]
					this.data[3][ih][iw] = p
					selection = {{pos[1][2], pos[1][1]}, {pos[2][2], pos[2][1]}}
				end
			end
		elseif this.datatype == datatypes.addBar then
			RemoveBar(this.data[1], true)
		elseif this.datatype == datatypes.removeBar then
			AddBar(this.data[1], this.data[2], true)
		end

		AddRedo(this.datatype, this.data)
		table.remove(undos, 1)
		ScrollUpdate()
	end
end

function Redo()
	if #redos > 0 then
		local this = redos[1]
		selection = {{}, {}}
		popup = ""

		if this.datatype == datatypes.addChannel then
			AddChannel(true, this.data[2])
		elseif this.datatype == datatypes.removeChannel then
			local d = {}
				for iw = 1, song.length do
					d[iw] = channels[this.data[1]].slots[iw]
				end
			table.remove(channels, this.data[1])
		elseif this.datatype == datatypes.pattern then
			local pos = this.data[1]
			selectedPat[1] = pos[1]
			selectedPat[2] = pos[2]
			local p = channels[pos[1]].slots[pos[2]]
			channels[pos[1]].slots[pos[2]] = this.data[2]
			this.data[2] = p
		elseif this.datatype == datatypes.patterns then
			local pos = {this.data[1], this.data[2]}
			for ih = pos[1][2], pos[2][2] do
				for iw = pos[1][1], pos[2][1] do
					local p = channels[ih].slots[iw]
					channels[ih].slots[iw] = this.data[3][ih][iw]
					this.data[3][ih][iw] = p
					selection = {{pos[1][2], pos[1][1]}, {pos[2][2], pos[2][1]}}
				end
			end
		elseif this.datatype == datatypes.addBar then
			AddBar(this.data[1], this.data[2], true)
		elseif this.datatype == datatypes.removeBar then
			RemoveBar(this.data[1], true)
		end

		AddUndo(this.datatype, this.data, true)
		
		table.remove(redos, 1)
		ScrollSet()
		ScrollUpdate()
	end
end