--[[
	API: https://docs.gamesense.gs/docs/api
]]

local render = renderer


client.exec('play music/kill_03')

local ffi = require 'ffi'
local vector = require 'vector'
local antiaim_data = require 'gamesense/antiaim_funcs'
local base64 = require 'gamesense/base64'

local lua = {}

lua.sub = '_' --'lifetime' 

local software = {}
local motion = {}
local backup = {}
local timer = {}
local ragebot = {}
local gui = {}
local g_ctx = {}
local builder = {}
local indicators = {}
local corrections = {}
local cwar = {}
local round = {}


do
	function software.init()
		software.rage = {
			binds = {
				minimum_damage = ui.reference('rage', 'aimbot', 'Minimum damage'),
				minimum_damage_override = {ui.reference('rage', 'aimbot', 'Minimum damage override')},
				minimum_hitchance = ui.reference('rage', 'aimbot', 'minimum hit chance'),
				double_tap = {ui.reference('rage', 'aimbot', 'Double tap')},
				ps = { ui.reference('MISC', 'Miscellaneous', 'Ping spike') },
				quickpeek = {ui.reference('rage', 'other', 'quick peek assist')},
				on_shot_anti_aim = {ui.reference('AA', 'Other', 'On shot anti-aim')}
			}
		}
		software.antiaim = {
			angles = {
				enabled = ui.reference('AA', 'Anti-aimbot angles', 'Enabled'),
				pitch = { ui.reference('AA', 'Anti-aimbot angles', 'Pitch') },
				roll = ui.reference('AA', 'Anti-aimbot angles', 'Roll'),
				yaw_base = ui.reference('AA', 'Anti-aimbot angles', 'Yaw base'),
				yaw = { ui.reference('AA', 'Anti-aimbot angles', 'Yaw') },
				freestanding_body_yaw = ui.reference('AA', 'anti-aimbot angles', 'Freestanding body yaw'),
				edge_yaw = ui.reference('AA', 'Anti-aimbot angles', 'Edge yaw'),
				yaw_jitter = { ui.reference('AA', 'Anti-aimbot angles', 'Yaw jitter') },
				body_yaw = { ui.reference('AA', 'Anti-aimbot angles', 'Body yaw') },
				freestanding = { ui.reference('AA', 'Anti-aimbot angles', 'Freestanding') },
				roll_aa = ui.reference('AA', 'Anti-aimbot angles', 'Roll')
			},
			fakelag = {
				on = {ui.reference('AA', 'Fake lag', 'Enabled')},
				amount = ui.reference('AA', 'Fake lag', 'Amount'),
				variance = ui.reference('AA', 'Fake lag', 'Variance'),
				limit = ui.reference('AA', 'Fake lag', 'Limit')
			},
			other = {
				slide = {ui.reference('AA','other','slow motion')},
				fakeduck = ui.reference('rage','other','duck peek assist'),
				slow_motion = {ui.reference('AA', 'Other', 'Slow motion')},
				fake_peek = {ui.reference('AA', 'Other', 'Fake peek')},
				leg_movement = ui.reference('AA', 'Other', 'Leg movement')
			}
		}
		software.visuals = {
			effects = {
				thirdperson = { ui.reference('VISUALS', 'Effects', 'Force third person (alive)') }
			}
		}
	end
end

do
	local function linear(t, b, c, d)
		return c * t / d + b
	end

	local function get_deltatime()
		return globals.frametime()
	end

	local function solve(easing_fn, prev, new, clock, duration)
		if clock <= 0 then return new end
		if clock >= duration then return new end

		prev = easing_fn(clock, prev, new - prev, duration)

		if type(prev) == 'number' then
			if math.abs(new - prev) < 0.001 then
				return new
			end

			local remainder = math.fmod(prev, 1.0)

			if remainder < 0.001 then
				return math.floor(prev)
			end

			if remainder > 0.999 then
				return math.ceil(prev)
			end
		end

		return prev
	end

	function motion.interp(a, b, t, easing_fn)
		easing_fn = easing_fn or linear

		if type(b) == 'boolean' then
			b = b and 1 or 0
		end

		return solve(easing_fn, a, b, get_deltatime(), t)
	end

	function motion.lerp(a, b, t)
		return (b - a) * t + a
	end

	function motion.lerp_color(r1, g1, b1, a1, r2, g2, b2, a2, t)
		local r = motion.lerp(r1, r2, t)
		local g = motion.lerp(g1, g2, t)
		local b = motion.lerp(b1, b2, t)
		local a = motion.lerp(a1, a2, t)

		return r, g, b, a
	end

	motion.clamp = function (x, a, b) if a > x then return a elseif b < x then return b else return x end end
    motion.normalize_yaw = function (yaw) return (yaw + 180) % -360 + 180 end
    motion.normalize_pitch = function (pitch) return motion.clamp(pitch, -89, 89) end
end

do
    local ctx = {}

    function timer.add(time, fn, ...)
        if not ctx.timers then
            ctx.timers = {}
        end

        ctx.timers[#ctx.timers + 1] = {
            time = globals.realtime() + time,
            fn = fn,
            args = ...
        }
    end

    function timer.render()
        for i, timer in ipairs(ctx.timers) do
            if globals.realtime() >= timer.time then
                timer.fn(timer.args)
                table.remove(ctx.timers, i)
            end
        end
    end
end

do
	gui.hide_aa_tab = function (boolean)
		ui.set_visible(software.antiaim.angles.enabled, not boolean)
        ui.set_visible(software.antiaim.angles.pitch[1], not boolean)
        ui.set_visible(software.antiaim.angles.pitch[2], not boolean)
        ui.set_visible(software.antiaim.angles.roll, not boolean)
        ui.set_visible(software.antiaim.angles.yaw_base, not boolean)
        ui.set_visible(software.antiaim.angles.yaw[1], not boolean)
        ui.set_visible(software.antiaim.angles.yaw[2], not boolean)
        ui.set_visible(software.antiaim.angles.yaw_jitter[1], not boolean)
        ui.set_visible(software.antiaim.angles.yaw_jitter[2], not boolean)
        ui.set_visible(software.antiaim.angles.body_yaw[1], not boolean)
        ui.set_visible(software.antiaim.angles.body_yaw[2], not boolean)
        ui.set_visible(software.antiaim.angles.freestanding[1], not boolean)
        ui.set_visible(software.antiaim.angles.freestanding[2], not boolean)
        ui.set_visible(software.antiaim.angles.freestanding_body_yaw, not boolean)
        ui.set_visible(software.antiaim.angles.edge_yaw, not boolean)
		ui.set_visible(software.antiaim.fakelag.on[1], not boolean)
		ui.set_visible(software.antiaim.fakelag.on[2], not boolean)
		ui.set_visible(software.antiaim.fakelag.variance, not boolean)
		ui.set_visible(software.antiaim.fakelag.amount, not boolean)
		ui.set_visible(software.antiaim.fakelag.limit, not boolean)
		ui.set_visible(software.rage.binds.on_shot_anti_aim[1], not boolean)	
		ui.set_visible(software.rage.binds.on_shot_anti_aim[2], not boolean)
		ui.set_visible(software.antiaim.other.slow_motion[1], not boolean)
		ui.set_visible(software.antiaim.other.slow_motion[2], not boolean)
		ui.set_visible(software.antiaim.other.fake_peek[1], not boolean)
		ui.set_visible(software.antiaim.other.fake_peek[2], not boolean)
		ui.set_visible(software.antiaim.other.leg_movement, not boolean)

	end

	function gui.init()
		--g_ctx.antarctica = render.load_image(network.get('https://cdn.discordapp.com/attachments/1122444059387109386/1211014267159974069/image.png'), vector(350, 350))
		gui.aa = 'aa'
		gui.ab = 'anti-aimbot angles'
		gui.abc = 'fake lag'
		gui.abcd = 'other'

		--gui.ff0000 = gui.b:label('@javasense')

		gui.builderanim = {'off', '1', '.5', '.0', 'bsod'}

		gui.LUA = ui.new_combobox(gui.aa, gui.ab, 'zenith.gs ~ best skeet lua', 'rage', 'antiaim', 'visuals', 'misc')

		gui.thirdperson = ui.new_slider(gui.aa,gui.ab, 'thirdperson distance', 30, 300, 150)
		gui.aspectratio = ui.new_slider(gui.aa,gui.ab, 'aspectratio', .0, 30, .0, true, nil, .1)
		gui.debug = ui.new_checkbox(gui.aa,gui.abcd, 'debug features')

		gui.miscellaneous = ui.new_combobox(gui.aa, gui.ab, 'miscellaneous', 'main', 'fakelag', 'other')

		gui.animbreaker = ui.new_combobox(gui.aa, gui.abc, 'animations', '12 anim layer', '6 anim layer', '7 pose parameter', '6 pose parameter', '0 pose parameter')

		gui.twelve_layer = ui.new_combobox(gui.aa, gui.abc, '12 anim layer',  gui.builderanim)
		gui.six_layer =    ui.new_combobox(gui.aa, gui.abc, '6 anim layer ',  gui.builderanim)

		gui.seven_pose = ui.new_combobox(gui.aa, gui.abc, '7 pose parameter', gui.builderanim)
		gui.six_pose = ui.new_combobox(gui.aa, gui.abc,   '6 pose parameter', gui.builderanim)
		gui.zero_pose = ui.new_combobox(gui.aa, gui.abc,  '0 pose parameter', gui.builderanim)


	end

	function gui.shut()
		gui.hide_aa_tab(false)
	end

	function gui.render()
		local luatabrage = ui.get(gui.LUA) == 'rage'
		local luatabaa = ui.get(gui.LUA) == 'antiaim'
		local luatabvis = ui.get(gui.LUA) == 'visuals'
		local luatabmisc = ui.get(gui.LUA) == 'misc'
		local manul = ui.get(gui.indicators.manual2arrows)
		local ind = ui.get(gui.indicators.ind)
		local res = ui.get(gui.corrections.custom_resolver)
		local over = ui.get(gui.corrections.over)
		
		ui.set_visible(gui.corrections.fix_defensive, luatabrage)
		ui.set_visible(gui.corrections.gradus, luatabrage and res and over)
		ui.set_visible(gui.corrections.espind, luatabrage and res)
		ui.set_visible(gui.corrections.over, luatabrage and res)
		ui.set_visible(gui.corrections.custom_resolver, luatabrage)
		ui.set_visible(gui.indicators.ind, luatabvis)
		ui.set_visible(gui.indicators.manual2arrows, luatabvis)
		ui.set_visible(gui.indicators.manualcolor, luatabvis and manul)
		ui.set_visible(gui.indicators.desynccolor, luatabvis and manul)
		ui.set_visible(gui.indicators.backcolor, luatabvis and manul)
		ui.set_visible(gui.thirdperson, luatabmisc)
		ui.set_visible(gui.aspectratio, luatabmisc)
		ui.set_visible(gui.debug, luatabmisc)
		ui.set_visible(gui.miscellaneous, luatabaa)
	end

	function gui.animbuilder()
		local luatabmisc = ui.get(gui.LUA) == 'misc'
		local luabuilder = ui.get(gui.animbreaker)
		
		ui.set_visible(gui.animbreaker, luatabmisc)

		ui.set_visible(gui.twelve_layer, luatabmisc and luabuilder == '12 anim layer')
		ui.set_visible(gui.six_layer, luatabmisc and luabuilder == '6 anim layer')

		ui.set_visible(gui.seven_pose, luatabmisc and luabuilder == '7 pose parameter')
		ui.set_visible(gui.six_pose, luatabmisc and luabuilder == '6 pose parameter')
		ui.set_visible(gui.zero_pose, luatabmisc and luabuilder == '0 pose parameter')

	end
end

do 
	function g_ctx.render()
		g_ctx.lp = entity.get_local_player()
		g_ctx.screen = {client.screen_size()}
	end
end

local def = {}

do

	def.defensive = {
		cmd = 0,
		check = 0,
		defensive = 0,
		run = function(arg)
			def.defensive.cmd = arg.command_number
		end,
		predict = function(arg)
			if arg.command_number == def.defensive.cmd then
				local tickbase = entity.get_prop(entity.get_local_player(), 'm_nTickBase')
				def.defensive.defensive = math.abs(tickbase - def.defensive.check)
				def.defensive.check = math.max(tickbase, def.defensive.check or 0)
				def.defensive.cmd = 0
			end
		end
	}
	client.set_event_callback('level_init', function()
		def.defensive.check, def.defensive.defensive = 0, 0
	end)
end

do
	local ctx = {}

	local function run_direction()

		ui.set(gui.manual_left, 'On hotkey')
		ui.set(gui.manual_right, 'On hotkey')

		if ui.get(software.antiaim.angles.freestanding[1]) then
			g_ctx.selected_manual = 0
		end

		if g_ctx.selected_manual == nil then
			g_ctx.selected_manual = 0
		end
	
		local left_pressed = ui.get(gui.manual_left)
		if left_pressed and not g_ctx.left_pressed then
			if g_ctx.selected_manual == 1 then
				g_ctx.selected_manual = 0
			else
				g_ctx.selected_manual = 1
			end
		end
	
		local right_pressed = ui.get(gui.manual_right)
		if right_pressed and not g_ctx.right_pressed then
			if g_ctx.selected_manual == 2 then
				g_ctx.selected_manual = 0
			else
				g_ctx.selected_manual = 2
			end
		end
		
		g_ctx.left_pressed = left_pressed
		g_ctx.right_pressed = right_pressed

	end

	function builder.init()
		ctx.onground = false
		ctx.ticks = -1
		ctx.state = 'shared'
		ctx.condition_names = { 'shared', 'manual left', 'manual right', 'stand', 'move', 'slowwalk', 'crouch', 'crouch-move', 'air', 'air-crouch' }
		
		gui.conditions = {}
		gui.conditions.state = ui.new_combobox(gui.aa, gui.ab, 'state', 'shared', 'manual left', 'manual right', 'stand', 'move', 'slowwalk', 'crouch', 'crouch-move', 'air', 'air-crouch')
		
		gui.fl_amount = ui.new_combobox(gui.aa, gui.ab, 'amount', 'dynamic', 'maximum', 'fluctuate')
		gui.fl_variance = ui.new_slider(gui.aa, gui.ab, 'variance', 0, 100, 0)
		gui.fl_limit = ui.new_slider(gui.aa, gui.ab, 'limit', 1, 15, 0)
		gui.fl_break = ui.new_slider(gui.aa, gui.ab, 'break (0 - off, > 0 - on, work on limit)', 0, 15, 0)

		gui.ot_leg = ui.new_combobox(gui.aa, gui.ab, 'leg movement', 'off', 'never slide', 'always slide')

		gui.manual_left = ui.new_hotkey(gui.aa, gui.ab, 'manual left')
		gui.manual_right = ui.new_hotkey(gui.aa, gui.ab, 'manual right')

		gui.freestand = ui.new_hotkey(gui.aa, gui.ab, 'freestand')
		gui.hideshots = ui.new_hotkey(gui.aa, gui.ab, 'hideshots')

		gui.ladder = ui.new_slider(gui.aa, gui.ab, 'ladder yaw', 0, 360, 0)

		for i, name in pairs(ctx.condition_names) do
			gui.conditions[name] = {
				state_label = ui.new_label(gui.aa,gui.ab,''..name..''),
				override = ui.new_checkbox(gui.aa,gui.ab, name..' override'),
				pitch = ui.new_slider(gui.aa,gui.ab, name..' pitch', -89, 89, 0),
				yaw_base = ui.new_combobox(gui.aa,gui.ab, name..' yaw base', 'local view', 'at targets'),
				yaw = ui.new_combobox(gui.aa,gui.ab, name..' yaw', 'off', '180'),
				yaw_valuel = ui.new_slider(gui.aa,gui.ab, name..' yaw offset left', -180, 180, 0),
				yaw_valuer = ui.new_slider(gui.aa,gui.ab, name..' yaw offset right', -180, 180, 0),
				yaw_jitterz = ui.new_combobox(gui.aa,gui.ab, name..' yaw jitter', 'off', 'offset', 'center', 'random', 'skitter'),
				yaw_jitter_valuez = ui.new_slider(gui.aa,gui.ab,name..' yaw jitter value', -180, 180, 0),
				body_yaw = ui.new_combobox(gui.aa,gui.ab, name..' body yaw', 'off', 'opposite', 'jitter', 'static', 'randomize'),
				body_yaw_value = ui.new_slider(gui.aa,gui.ab, name..' body yaw value ', -180, 180, 0),
				freestand_body_yaw = ui.new_checkbox(gui.aa,gui.ab, name..' freestanding body yaw'),
				roll  = ui.new_slider(gui.aa,gui.ab, name..' roll yaw value ', -45, 45, 0),

				defensive_on = ui.new_checkbox(gui.aa,gui.ab, name..' defensive always on'),
				defensive_aa_on = ui.new_checkbox(gui.aa,gui.ab, name..' enable defensive antiaim'),

				pitch2 = ui.new_slider(gui.aa,gui.abc, name..' defensive pitch', -89, 89, 0),
				yaw_base2 = ui.new_combobox(gui.aa,gui.abc, name..'defensive yaw base', 'local view', 'at targets'),
				yaw2 = ui.new_combobox(gui.aa,gui.abc, name..' defensive yaw', 'off', '180', 'spin', 'static', '180 z', 'crosshair'),
				yaw_value2 = ui.new_slider(gui.aa,gui.abc, name..' defensive yaw offset', -180, 180, 0),
				yaw_jitter2 = ui.new_combobox(gui.aa,gui.abc, name..' defensive yaw jitter', 'off', 'offset', 'center', 'random', 'skitter'),
				yaw_jitter_value2 = ui.new_slider(gui.aa,gui.abc, name..' defensive yaw jitter value', -180, 180, 0),
				body_yaw2 = ui.new_combobox(gui.aa,gui.abc, name..' defensive body yaw', 'off', 'opposite', 'jitter', 'static', 'randomize'),
				body_yaw_value2 = ui.new_slider(gui.aa,gui.abc, name..' defensive body yaw value ', -180, 180, 0),
				freestand_body_yaw2 = ui.new_checkbox(gui.aa,gui.abc, name..' defensive freestanding body yaw'),
				roll2  = ui.new_slider(gui.aa,gui.abc, name..' defensive roll yaw value ', -45, 45, 0),
			}
		end
	end

	function builder.render() 
		local selected_state = ui.get(gui.conditions.state)

		for i, name in pairs(ctx.condition_names) do
			local enabled = name == selected_state
			
			local luatabaa = ui.get(gui.LUA) == 'antiaim' and ui.get(gui.miscellaneous) == 'main'
			local luatabaafl = ui.get(gui.LUA) == 'antiaim' and ui.get(gui.miscellaneous) == 'fakelag'
			local luatabaaot = ui.get(gui.LUA) == 'antiaim' and ui.get(gui.miscellaneous) == 'other'

			local dchk = ui.get(gui.conditions[name].defensive_aa_on)
			local ik = ui.get(gui.conditions[name].body_yaw) == 'randomize'
			local ik2 = ui.get(gui.conditions[name].body_yaw2) == 'randomize'	

			ui.set_visible(gui.conditions[name].state_label, enabled and luatabaa)
			ui.set_visible(gui.conditions[name].override, enabled and i > 1 and luatabaa)
			ui.set_visible(gui.conditions.state, luatabaa)

			ui.set_visible(gui.fl_amount, luatabaafl)
			ui.set_visible(gui.fl_break, luatabaafl)
			ui.set_visible(gui.fl_variance, luatabaafl)
			ui.set_visible(gui.fl_limit, luatabaafl)
			ui.set_visible(gui.ot_leg, luatabaaot)
			ui.set_visible(gui.manual_left, luatabaaot)
			ui.set_visible(gui.manual_right, luatabaaot)
			ui.set_visible(gui.freestand, luatabaaot)	
			ui.set_visible(gui.hideshots, luatabaaot)	
			ui.set_visible(gui.ladder, luatabaaot)	

			local overriden = i == 1 or ui.get(gui.conditions[name].override)

			gui.hide_aa_tab(true)

			ui.set_visible(gui.conditions[name].pitch, enabled and overriden and luatabaa)
			ui.set_visible(gui.conditions[name].yaw_base, enabled and overriden and luatabaa)
			ui.set_visible(gui.conditions[name].yaw, enabled and overriden and luatabaa)
			ui.set_visible(gui.conditions[name].yaw_valuel, enabled and overriden and luatabaa)
			ui.set_visible(gui.conditions[name].yaw_valuer, enabled and overriden and luatabaa)		
			ui.set_visible(gui.conditions[name].yaw_jitterz, enabled and overriden and luatabaa)
			ui.set_visible(gui.conditions[name].yaw_jitter_valuez, enabled and overriden and luatabaa)
			ui.set_visible(gui.conditions[name].body_yaw, enabled and overriden and luatabaa )--
			ui.set_visible(gui.conditions[name].body_yaw_value, enabled and overriden and luatabaa and not ik)
			ui.set_visible(gui.conditions[name].freestand_body_yaw, enabled and overriden and luatabaa)
			ui.set_visible(gui.conditions[name].roll, enabled and overriden and luatabaa)

			ui.set_visible(gui.conditions[name].defensive_on, enabled and overriden and luatabaa)
			ui.set_visible(gui.conditions[name].defensive_aa_on, enabled and overriden and luatabaa)

			ui.set_visible(gui.conditions[name].pitch2, enabled and overriden and luatabaa and dchk)
			ui.set_visible(gui.conditions[name].yaw_base2, enabled and overriden and luatabaa and dchk)
			ui.set_visible(gui.conditions[name].yaw2, enabled and overriden and luatabaa and dchk)
			ui.set_visible(gui.conditions[name].yaw_value2, enabled and overriden and luatabaa and dchk)
			ui.set_visible(gui.conditions[name].yaw_jitter2, enabled and overriden and luatabaa and dchk)
			ui.set_visible(gui.conditions[name].yaw_jitter_value2, enabled and overriden and luatabaa and dchk)
			ui.set_visible(gui.conditions[name].body_yaw2, enabled and overriden and luatabaa and dchk)
			ui.set_visible(gui.conditions[name].body_yaw_value2, enabled and overriden and luatabaa and dchk and not ik2)--
			ui.set_visible(gui.conditions[name].freestand_body_yaw2, enabled and overriden and luatabaa and dchk)
			ui.set_visible(gui.conditions[name].roll2, enabled and overriden and luatabaa and dchk)

		end
	end

	function fast_ladder(cmd)
	
		local pitch,yaw = client.camera_angles()
	
		local m_MoveType = entity.get_prop(g_ctx.lp, 'm_MoveType')
	
		if m_MoveType == 9 then --fixed
			cmd.yaw = math.floor(cmd.yaw+0.5)
			cmd.roll = 0
			if true then
				if cmd.forwardmove == 0 then
					cmd.pitch = 89
					cmd.yaw = cmd.yaw + ui.get(gui.ladder)
					if math.abs(ui.get(gui.ladder)) > 0 and math.abs(ui.get(gui.ladder)) < 180 and cmd.sidemove ~= 0 then
						cmd.yaw = cmd.yaw - ui.get(gui.ladder)
					end
					if math.abs(ui.get(gui.ladder)) == 180 then
						if cmd.sidemove < 0 then
							cmd.in_moveleft = 0
							cmd.in_moveright = 1
						end
						if cmd.sidemove > 0 then
							cmd.in_moveleft = 1
							cmd.in_moveright = 0
						end
					end
				end
			end
	
			if true then
				if cmd.forwardmove > 0 then
					if pitch < 45 then
						cmd.pitch = 89
						cmd.in_moveright = 1
						cmd.in_moveleft = 0
						cmd.in_forward = 0
						cmd.in_back = 1
						if cmd.sidemove == 0 then
							cmd.yaw = cmd.yaw + 90
						end
						if cmd.sidemove < 0 then
							cmd.yaw = cmd.yaw + 150
						end
						if cmd.sidemove > 0 then
							cmd.yaw = cmd.yaw + 30
						end
					end 
				end
			end
	
			if true then
				if cmd.forwardmove < 0 then
					cmd.pitch = 89
					cmd.in_moveleft = 1
					cmd.in_moveright = 0
					cmd.in_forward = 1
					cmd.in_back = 0
					if cmd.sidemove == 0 then
						cmd.yaw = cmd.yaw + 90
					end
					if cmd.sidemove > 0 then
						cmd.yaw = cmd.yaw + 150
					end
					if cmd.sidemove < 0 then
						cmd.yaw = cmd.yaw + 30
					end
				end
			end
	
		end
	end

	function get_velocity()
		
		if not entity.is_alive(g_ctx.lp) then return end

		local first_velocity, second_velocity = entity.get_prop(g_ctx.lp, 'm_vecVelocity')
		local speed = math.floor(math.sqrt(first_velocity*first_velocity+second_velocity*second_velocity))
		
		return speed
	end

	function get_state(speed)

		if not entity.is_alive(g_ctx.lp) then
			return 'shared'
		end

		if g_ctx.selected_manual == 1 then
			return 'manual left'
		end

		if g_ctx.selected_manual == 2 then
			return 'manual right'
		end

		if entity.get_prop(g_ctx.lp, 'm_hGroundEntity') == 0 then
			ctx.ticks = ctx.ticks + 1
		else
			ctx.ticks = 0
		end
		
		ctx.onground = ctx.ticks >= 1
		
		if not ctx.onground then
			if entity.get_prop(g_ctx.lp, 'm_flDuckAmount') == 1 then
				return 'air-crouch'
			end
	
			return 'air'
		end
		
		if entity.get_prop(g_ctx.lp, 'm_flDuckAmount') == 1 then
			if speed > 5 then
				return 'crouch-move'
			end
	
			return 'crouch'
		end
	
		if ui.get(software.antiaim.other.slide[2]) then
			return 'slowwalk'
		end
	
		if speed > 5 then
			return 'move'
		end
	
		return 'stand'
	end

	local is_active = false
	local AVOID_BACKSTAB_MAX_DISTANCE_SQR = 220 * 220

	local function get_enemies_with_knife()
		local enemies = entity.get_players(true)
		if next(enemies) == nil then return { } end

		local list = { }

		for i = 1, #enemies do
			local enemy = enemies[i]
			local wpn = entity.get_player_weapon(enemy)

			if wpn == nil then
				goto continue
			end

			local wpn_class = entity.get_classname(wpn)

			if wpn_class == 'CKnife' then
				list[#list + 1] = enemy
			end

			::continue::
		end

		return list
	end

	local function get_closest_target(me)
		local targets = get_enemies_with_knife()
		if next(targets) == nil then return end

		local best_delta
		local best_target

		local my_origin = vector(entity.get_origin(me))
		local best_distance = AVOID_BACKSTAB_MAX_DISTANCE_SQR

		for i = 1, #targets do
			local target = targets[i]

			local origin = vector(entity.get_origin(target))
			local delta = origin - my_origin

			local distance = delta:lengthsqr()

			if distance < best_distance then
				best_delta = delta
				best_target = target

				best_distance = distance
			end
		end

		return best_distance, best_delta
	end

	function builder.createmove(cmd)

		if not entity.is_alive(g_ctx.lp) then
			return
		end

		ctx.state = get_state(get_velocity())

		if not ui.get(gui.conditions[ctx.state].override) then
			ctx.state = 'shared'
		end

		ui.set(software.antiaim.angles.freestanding[2], 'always on')
		ui.set(software.antiaim.angles.freestanding[1], ui.get(gui.freestand))

		ui.set(software.rage.binds.on_shot_anti_aim[2], 'always on')
		ui.set(software.rage.binds.on_shot_anti_aim[1], ui.get(gui.hideshots))

		local players = entity.get_players(true)

		local bodyyaw = entity.get_prop(g_ctx.lp, 'm_flPoseParameter', 11) * 120 - 60
		local side = bodyyaw > 0 and 1 or -1

		ui.set( software.antiaim.angles.pitch[1],              'custom')

		local distance, delta = get_closest_target(g_ctx.lp)

		if distance ~= nil and distance < 25000 then
			ui.set( software.antiaim.angles.pitch[2],              ui.get( gui.conditions[ctx.state].pitch ))
			ui.set( software.antiaim.angles.yaw_base,              'at targets')
			ui.set( software.antiaim.angles.yaw[1],                '180' )
			ui.set( software.antiaim.angles.yaw[2],                180)
			ui.set( software.antiaim.angles.yaw_jitter[1],         'off')
			ui.set( software.antiaim.angles.yaw_jitter[2],         0)
		else
			if def.defensive.defensive > 3 and def.defensive.defensive < 11 and ui.get(gui.conditions[ctx.state].defensive_aa_on) then
				ui.set( software.antiaim.angles.pitch[2],              ui.get( gui.conditions[ctx.state].pitch2 ))
				ui.set( software.antiaim.angles.yaw_base,              ui.get( gui.conditions[ctx.state].yaw_base2 ))
				ui.set( software.antiaim.angles.yaw[1],                ui.get( gui.conditions[ctx.state].yaw2 ))
				ui.set( software.antiaim.angles.yaw[2],                ui.get( gui.conditions[ctx.state].yaw_value2 ))
				ui.set( software.antiaim.angles.yaw_jitter[1],         ui.get( gui.conditions[ctx.state].yaw_jitter2 ))
				ui.set( software.antiaim.angles.yaw_jitter[2],         ui.get( gui.conditions[ctx.state].yaw_jitter_value2 ))
				if ui.get( gui.conditions[ctx.state].body_yaw2 ) == 'randomize' then
					ui.set( software.antiaim.angles.body_yaw[2],       ui.get(software.rage.binds.double_tap[2]) and client.random_int(-30, 30) or ui.get(software.rage.binds.on_shot_anti_aim[2]) and client.random_int(-30, 30) or 49) 
					ui.set( software.antiaim.angles.body_yaw[1],       ui.get(software.rage.binds.double_tap[2]) and 'static' or ui.get(software.rage.binds.on_shot_anti_aim[2]) and 'static' or 'jitter')
				else
					ui.set( software.antiaim.angles.body_yaw[2],           ui.get( gui.conditions[ctx.state].body_yaw_value2 ))
					ui.set( software.antiaim.angles.body_yaw[1],           ui.get( gui.conditions[ctx.state].body_yaw2 ))
				end
				ui.set( software.antiaim.angles.freestanding_body_yaw, ui.get( gui.conditions[ctx.state].freestand_body_yaw2 ))
				ui.set( software.antiaim.angles.roll, ui.get( gui.conditions[ctx.state].roll2 ))
			else
			    if g_ctx.selected_manual == 1 and not ui.get(gui.conditions['manual left'].override) then
					ui.set( software.antiaim.angles.pitch[2],              ui.get( gui.conditions[ctx.state].pitch ))
					ui.set( software.antiaim.angles.yaw_base,              'local view')
					ui.set( software.antiaim.angles.yaw[1],                '180' )
					ui.set( software.antiaim.angles.yaw[2],                -90)
					ui.set( software.antiaim.angles.yaw_jitter[1],         'off')
					ui.set( software.antiaim.angles.yaw_jitter[2],         0)
					ui.set( software.antiaim.angles.body_yaw[1],           'opposite')
					ui.set( software.antiaim.angles.body_yaw[2],           40)
					ui.set( software.antiaim.angles.freestanding_body_yaw, true)
	
				elseif g_ctx.selected_manual == 2 and not ui.get(gui.conditions['manual right'].override) then
					ui.set( software.antiaim.angles.pitch[2],              ui.get( gui.conditions[ctx.state].pitch ))
					ui.set( software.antiaim.angles.yaw_base,              'local view')
					ui.set( software.antiaim.angles.yaw[1],                '180' )
					ui.set( software.antiaim.angles.yaw[2],                90)
					ui.set( software.antiaim.angles.yaw_jitter[1],         'off')
					ui.set( software.antiaim.angles.yaw_jitter[2],         0)
					ui.set( software.antiaim.angles.body_yaw[1],           'opposite')
					ui.set( software.antiaim.angles.body_yaw[2],           40)
					ui.set( software.antiaim.angles.freestanding_body_yaw, true)
	
				elseif ui.get(software.antiaim.angles.freestanding[2]) and ui.get(software.antiaim.angles.freestanding[1]) then
					ui.set( software.antiaim.angles.pitch[2],              ui.get( gui.conditions[ctx.state].pitch ))
					ui.set( software.antiaim.angles.yaw[1],                '180' )
					ui.set( software.antiaim.angles.yaw[2],                0)
					ui.set( software.antiaim.angles.yaw_jitter[1],         'off')
					ui.set( software.antiaim.angles.yaw_jitter[2],         0)
					ui.set( software.antiaim.angles.body_yaw[1],           'opposite')
					ui.set( software.antiaim.angles.body_yaw[2],           0)
					ui.set( software.antiaim.angles.freestanding_body_yaw, true)
				else
					ui.set( software.antiaim.angles.pitch[2],              ui.get( gui.conditions[ctx.state].pitch ))
					ui.set( software.antiaim.angles.yaw_base,              ui.get( gui.conditions[ctx.state].yaw_base ))
					ui.set( software.antiaim.angles.yaw[1],                ui.get( gui.conditions[ctx.state].yaw ) )
					ui.set( software.antiaim.angles.yaw[2],                side == 1 and ui.get( gui.conditions[ctx.state].yaw_valuel ) or ui.get( gui.conditions[ctx.state].yaw_valuer ))
					ui.set( software.antiaim.angles.yaw_jitter[1],         ui.get( gui.conditions[ctx.state].yaw_jitterz ))
					ui.set( software.antiaim.angles.yaw_jitter[2],         ui.get( gui.conditions[ctx.state].yaw_jitter_valuez ))
					if ui.get(gui.conditions[ctx.state].body_yaw) == 'randomize' then
						ui.set( software.antiaim.angles.body_yaw[2],       ui.get(software.rage.binds.double_tap[2]) and client.random_int(-30, 30) or ui.get(software.rage.binds.on_shot_anti_aim[1]) and client.random_int(-30, 30) or 49) 
						ui.set( software.antiaim.angles.body_yaw[1],       ui.get(software.rage.binds.double_tap[2]) and 'static' or ui.get(software.rage.binds.on_shot_anti_aim[1]) and 'static' or 'jitter')
					else
						ui.set( software.antiaim.angles.body_yaw[2],   ui.get( gui.conditions[ctx.state].body_yaw_value ))
						ui.set( software.antiaim.angles.body_yaw[1],   ui.get( gui.conditions[ctx.state].body_yaw ))
					end
					ui.set( software.antiaim.angles.freestanding_body_yaw, ui.get( gui.conditions[ctx.state].freestand_body_yaw ))
					ui.set( software.antiaim.angles.roll, ui.get( gui.conditions[ctx.state].roll ))
				end
			end
	    end

		ui.set( software.antiaim.fakelag.amount,         ui.get( gui.fl_amount   ))
		ui.set( software.antiaim.fakelag.variance,       ui.get( gui.fl_variance ))
		if ui.get(gui.fl_break) > 0 then
			ui.set( software.antiaim.fakelag.limit,          client.random_int(ui.get( gui.fl_break    ), ui.get( gui.fl_limit    )))
		else
			ui.set( software.antiaim.fakelag.limit,          ui.get( gui.fl_limit    ))
		end
		ui.set( software.antiaim.other.leg_movement,     ui.get( gui.ot_leg      ))

		run_direction()
		fast_ladder(cmd)
	end
end

do
	local ctx = {}

	local function add_bind(name, ref, gradient_fn, r,g,b,a, r1,g1,b1,a1)
		ctx.crosshair_indicator.binds[#ctx.crosshair_indicator.binds + 1] = { name = string.sub(name, 1, 2), full_name = name, ref = ref, color = r,g,b,a, color1 = r1,g1,b1,a1, r,g,b,a = r,g,b,a, chars = 0, alpha = 0, gradient_progress = 0, gradient_fn = gradient_fn }
	end

	local function state()
		ctx.state = get_state(get_velocity())

		if not ui.get(gui.conditions[ctx.state].override) then
			ctx.state = 'shared'
		end

		return ctx.state

	end

	local function doubletap()
			if software.rage.binds.double_tap[2] then 
				if def.defensive.defensive > 3 then
					return 'doubletap+'
				end
				return 'doubletap'
			end
	
		return 'doubletap'
	end

	function indicators.init()
		gui.indicators = {}
		
		ctx.anims = {
			a = 0,
			b = 0,
			c = 0,
			d = 0,
			e = 0,
			f = 0,
			g = 0,
			h = 0,
			i = 0,
			j = 0,
			k = 0,
			l = 0,
			m = 0,
			n = 0,
			o = 0,
			p = 0,
			q = 0,
			r = 0,
			s = 0,
			t = 0,
			u = 0,
			v = 0,
			w = 0,
			x = 0,
			y = 0,
			z = 0,
		}

		--gui.indicators.debug = gui.b:checkbox('debug', false)
		gui.indicators.ind   = ui.new_checkbox(gui.aa,gui.ab,'indicator')
		gui.indicators.manual2arrows   = ui.new_checkbox(gui.aa,gui.ab,'manual arrows')
		gui.indicators.manualcolor   = ui.new_color_picker(gui.aa,gui.ab, '[manual] manual color', 215, 215, 215, 255)
		gui.indicators.desynccolor   = ui.new_color_picker(gui.aa,gui.ab, '[manual] desync color', 215, 215, 215, 255)
		gui.indicators.backcolor   = ui.new_color_picker(gui.aa,gui.ab, '[manual] back color', 0, 0, 0, 255)
		--gui.indicators.manul = gui.b:checkbox('manual arrows')
		--gui.indicators.scope = gui.b:checkbox('custom scope lines', false)
		--gui.indicators.scope_lenght = gui.b:slider('custom scope lines lenght', -580, 580, 240)
		--gui.indicators.ap = gui.b:checkbox('custom render auto peek')
		--gui.indicators.watermark = gui.b:checkbox('watermark', false)
		--gui.indicators.cesp = gui.b:checkbox('custom render esp', false)

		ctx.crosshair_indicator = {}
		ctx.crosshair_indicator.binds = {}

		local white_color =  {215, 215, 215, 255}
		local green_color =  {55, 255, 55, 255}
		local yellow_color = {255, 255, 55, 255}
		local red_color =    {255, 0, 55, 255}

		local always_on = function() return true end
		--local enemy_is_dormant = function() return rage.get_antiaim_target( end
		local on_exploit = function() return software.rage.binds.double_tap[2] or software.rage.binds.on_shot_anti_aim[2] end --and not ragebot.defensive.active

		add_bind('release', gui.indicators.ind, always_on, 215,215,215,255, 0,0,0,255)
		add_bind('zenith.gs', gui.indicators.ind, always_on, 215,215,215,255, 0,0,0,255)
		add_bind('doubletap', software.rage.binds.double_tap[2], always_on, 215,215,215,255, 0,0,0,255) 
		add_bind('hide', software.rage.binds.on_shot_anti_aim[1], always_on, 215,215,215,255, 0,0,0,255)
		add_bind('ping', software.rage.binds.ps[2], always_on, 215,215,215,255, 0,0,0,255)
		add_bind('dmg', software.rage.binds.minimum_damage_override[2], always_on, 215,215,215,255, 0,0,0,255)
		add_bind('fs', software.antiaim.angles.freestanding[1], always_on, 215,215,215,255, 0,0,0,255)
	end

	local function interlerpfuncs()
		
		backup.visual = {}

		--ctx.anims.b = motion.interp(ctx.anims.b, gui.indicators.ind:get() and not utils.is_key_pressed(0x09), 0.2)
		ctx.anims.c = motion.interp(ctx.anims.c, entity.get_prop(g_ctx.lp, 'm_bIsScoped'), 0.1)
		ctx.anims.n = motion.interp(ctx.anims.n, entity.get_prop(g_ctx.lp, 'm_bResumeZoom'), 0.1)
		ctx.anims.d = motion.interp(ctx.anims.d, ui.get(software.visuals.effects.thirdperson[2]), 0.1)
		ctx.anims.e = motion.interp(ctx.anims.e, ui.get(gui.indicators.manual2arrows), 0.1)

		--backup.visual.indicator = ctx.anims.b
		backup.visual.scoped = ctx.anims.c + ctx.anims.n
		backup.visual.thirdperson = ctx.anims.d
		backup.visual.manualenable = ctx.anims.e
	end

	local function auto_peek()

	--	if backup.visual.auto_peek == 0 then
	--		apeekorigin = g_ctx.lp:get_abs_origin()
	--	end

		--render.text(3, vector(10, g_ctx.screen.y / 2 - 50), color(215, 215, 215, 255), 'o', tostring(apeekorigin) .. ' color.a(' .. backup.visual.auto_peek .. ')')
	
	--	render.circle_3d_outline(apeekorigin, color(255,255,255,155 * backup.visual.auto_peek), 20 * backup.visual.auto_peek)
	end

	local function custom_scope_lines()

		--render.gradient(vector(g_ctx.screen.x / 2 + gui.indicators.scope_lenght:get()*(1.0 - backup.visual.scoped), g_ctx.screen.y / 2 + .1), vector(g_ctx.screen.x / 2 + gui.indicators.scope_lenght:get()/3*(1.0 - backup.visual.scoped), g_ctx.screen.y / 2 - .1), color(255,255,255,0*(1.0 - backup.visual.scoped)), color(255,255,255,215*(1.0 - backup.visual.scoped)), color(255,255,255,0*(1.0 - backup.visual.scoped)), color(255,255,255,215*(1.0 - backup.visual.scoped)))
		--render.gradient(vector(g_ctx.screen.x / 2 - gui.indicators.scope_lenght:get()*(1.0 - backup.visual.scoped), g_ctx.screen.y / 2 - .1), vector(g_ctx.screen.x / 2 - gui.indicators.scope_lenght:get()/3*(1.0 - backup.visual.scoped), g_ctx.screen.y / 2 + .1), color(255,255,255,0*(1.0 - backup.visual.scoped)), color(255,255,255,215*(1.0 - backup.visual.scoped)), color(255,255,255,0*(1.0 - backup.visual.scoped)), color(255,255,255,215*(1.0 - backup.visual.scoped)))
		--render.gradient(vector(g_ctx.screen.x / 2 - .1*(1.0 - backup.visual.scoped), g_ctx.screen.y / 2 + gui.indicators.scope_lenght:get()*(1.0 - backup.visual.scoped)), vector(g_ctx.screen.x / 2 + .1, g_ctx.screen.y / 2 + gui.indicators.scope_lenght:get()/3*(1.0 - backup.visual.scoped)), color(255,255,255,0*(1.0 - backup.visual.scoped)), color(255,255,255,0*(1.0 - backup.visual.scoped)), color(255,255,255,215*(1.0 - backup.visual.scoped)), color(255,255,255,215*(1.0 - backup.visual.scoped)))
		--render.gradient(vector(g_ctx.screen.x / 2 - .1*(1.0 - backup.visual.scoped), g_ctx.screen.y / 2 - gui.indicators.scope_lenght:get()*(1.0 - backup.visual.scoped)), vector(g_ctx.screen.x / 2 + .1, g_ctx.screen.y / 2 - gui.indicators.scope_lenght:get()/3*(1.0 - backup.visual.scoped)), color(255,255,255,0*(1.0 - backup.visual.scoped)), color(255,255,255,0*(1.0 - backup.visual.scoped)), color(255,255,255,215*(1.0 - backup.visual.scoped)), color(255,255,255,215*(1.0 - backup.visual.scoped)))
	end

	local function manual_arrows()

		local bodyyaw = entity.get_prop(g_ctx.lp, 'm_flPoseParameter', 11) * 120 - 60

		local r, g, b, a = ui.get(gui.indicators.manualcolor)
		local r1, g1, b1, a1 = ui.get(gui.indicators.desynccolor)
		local r12, g12, b12, a12 = ui.get(gui.indicators.backcolor)

		local sx, sy = client.screen_size()
		local cx, cy = sx / 2, sy / 2 - 2

		render.text(cx + 55, cy - 2, 
		g_ctx.selected_manual == 2 and r or r12, 
		g_ctx.selected_manual == 2 and g or g12, 
		g_ctx.selected_manual == 2 and b or b12, 
		g_ctx.selected_manual == 2 and a * backup.visual.manualenable * (1.0 - backup.visual.scoped) or a12 * backup.visual.manualenable * (1.0 - backup.visual.scoped),
	    'c+',
	    nil,
	    '❱')--❯

		render.text(cx - 55, cy - 2,
		g_ctx.selected_manual == 1 and r or r12, 
		g_ctx.selected_manual == 1 and g or g12, 
		g_ctx.selected_manual == 1 and b or b12, 
		g_ctx.selected_manual == 1 and a * backup.visual.manualenable * (1.0 - backup.visual.scoped) or a12 * backup.visual.manualenable * (1.0 - backup.visual.scoped),
	    'c+',
	    nil,
	    '❰')--❮

		render.text(cx + 45, cy - 2, 
		bodyyaw < -10 and r1 or r12,
		bodyyaw < -10 and g1 or g12,
		bodyyaw < -10 and b1 or b12,
		bodyyaw < -10 and a1 * backup.visual.manualenable * (1.0 - backup.visual.scoped) or a12 * backup.visual.manualenable * (1.0 - backup.visual.scoped),
	    'c+',
	    nil,
	    '❱')

		render.text(cx - 45, cy - 2,
		bodyyaw > 10 and r1 or r12,
		bodyyaw > 10 and g1 or g12,
		bodyyaw > 10 and b1 or b12,
		bodyyaw > 10 and a1 * backup.visual.manualenable * (1.0 - backup.visual.scoped) or a12 * backup.visual.manualenable * (1.0 - backup.visual.scoped),
	    'c+',
	    nil,
	    '❰')
		
	end

	local function add_crosshair_text(x, y, r, g, b, a, fl, opt, text,alpha)

		if not entity.is_alive(g_ctx.lp) then
			return
		end

		if alpha == nil then
			alpha = 1
		end

		if alpha <= 0 then
			return
		end
		
		local offset = 1
		if ctx.crosshair_indicator.scope > 0 then
			offset = offset - ctx.crosshair_indicator.scope
		end
			
		local text_size = render.measure_text(fl, text)
		x = x - text_size * offset / 2 + 5 * ctx.crosshair_indicator.scope
		
		render.text(x, y, r, g, b, a, fl, opt, text)
		
		ctx.crosshair_indicator.y = ctx.crosshair_indicator.y + 10 * alpha
	end

	local function watermark()

		--render.gradient(vector(160, g_ctx.screen.y / 2 + 10), vector(0, g_ctx.screen.y / 2), color(21,21,21,21), color(21,21,21,255), color(21,21,21,21), color(21,21,21,255))

		ctx.crosshair_indicator.scope = backup.visual.scoped

		local name = 'zenith.gs'

		local text_size = render.measure_text('b', name)
		--print(name)

		render.text(g_ctx.screen[1] / 2 - text_size / 2 + (text_size / 2 + 5) * ctx.crosshair_indicator.scope, g_ctx.screen[2] - 15, 215, 215, 215, 255, 'b', nil, name)
	end

	local function indicator()
		
		if not entity.is_alive(g_ctx.lp) then
			return
		end
		
		ctx.crosshair_indicator.y = 15
		ctx.crosshair_indicator.scope = backup.visual.scoped

		for index, bind in ipairs(ctx.crosshair_indicator.binds) do

			local alpha = motion.interp(bind.alpha, ui.get(gui.indicators.ind) and ui.get(bind.ref), 0.1)
			local chars = motion.interp(bind.chars, ui.get(gui.indicators.ind) and ui.get(bind.ref), 0.1)
			--local x = motion.interp(state(), ui.get(gui.indicators.ind) and state(), 0.1)
			local gradient_progress = motion.interp(bind.gradient_progress, bind.gradient_fn(), 0.1)
			local name = string.sub(bind.full_name, 1, math.floor(0.5 + #bind.full_name * chars))

			if bind.full_name == 'doubletap' then
				name = string.sub(doubletap(), 1, math.floor(0.5 + #doubletap() * chars)) --('\a%x%x%x%x'):format(215,215,215,255) .. 
			end

			add_crosshair_text(g_ctx.screen[1] / 2, g_ctx.screen[2] / 2 + ctx.crosshair_indicator.y, 255 * alpha, 255 * alpha, 255 * alpha, 255 * alpha, '-', nil, string.upper(name), alpha)
			
			ctx.crosshair_indicator.binds[index].alpha = alpha
			ctx.crosshair_indicator.binds[index].name = name
			ctx.crosshair_indicator.binds[index].chars = chars
			ctx.crosshair_indicator.binds[index].gradient_progress = gradient_progress
			--ctx.crosshair_indicator.binds[index].color = color
		end
	end

	function indicators.render()

		if not entity.is_alive(g_ctx.lp) then
			return
		end

		state()
		interlerpfuncs()
		watermark()
		indicator() 
		manual_arrows()

		--render.indicator(215, 215, 215, 255, 'ПОД АМКАЛОМ')
	end
end

do
	local ctx = {}

	local native_GetClientEntity = vtable_bind('client.dll', 'VClientEntityList003', 3, 'void*(__thiscall*)(void*, int)')

	local char_ptr = ffi.typeof('char*')
	local nullptr = ffi.new('void*')
	local class_ptr = ffi.typeof('void***')

	local animation_layer_t = ffi.typeof([[
    struct {										char pad0[0x18];
        uint32_t	sequence;
        float		prev_cycle;
        float		weight;
        float		weight_delta_rate;
        float		playback_rate;
        float		cycle;
        void		*entity;						char pad1[0x4];
    } **
	]])

	function corrections.init()
		gui.corrections = {}
		gui.corrections.fix_defensive = ui.new_checkbox(gui.aa,gui.ab,'custom defensive')
		gui.corrections.custom_resolver = ui.new_checkbox(gui.aa,gui.abc, 'custom resolver')
		gui.corrections.espind = ui.new_checkbox(gui.aa,gui.abc, 'esp info')
		gui.corrections.over = ui.new_checkbox(gui.aa,gui.abc, 'override [> 6 misses]')
		gui.corrections.gradus = ui.new_slider(gui.aa,gui.abc, '[> 6 misses]', -58, 58, 0)
	end

	local function is_peeking()

		if not entity.is_alive(g_ctx.lp) then
			return
		end

		local enemies = entity.get_players( true )
		if not enemies then
			return false
		end

		local predict_amt = 0.25
		
		local eye_position = vector( client.eye_position( ) )
		local velocity_prop_local = vector( entity.get_prop( entity.get_local_player( ), 'm_vecVelocity' ) )
		local predicted_eye_position = vector( eye_position.x + velocity_prop_local.x * predict_amt, eye_position.y + velocity_prop_local.y * predict_amt, eye_position.z + velocity_prop_local.z * predict_amt )
	
		for i = 1, #enemies do
			local player = enemies[ i ]
			
			local velocity_prop = vector( entity.get_prop( player, 'm_vecVelocity' ) )
			
			-- Store and predict player origin
			local origin = vector( entity.get_prop( player, 'm_vecOrigin' ) )
			local predicted_origin = vector( origin.x + velocity_prop.x * predict_amt, origin.y + velocity_prop.y * predict_amt, origin.z + velocity_prop.z * predict_amt )
			
			-- Set their origin to their predicted origin so we can run calculations on it
			entity.get_prop( player, 'm_vecOrigin', predicted_origin )
			
			-- Predict their head position and fire an autowall trace to see if any damage can be dealt
			local head_origin = vector( entity.hitbox_position( player, 0 ) )
			local predicted_head_origin = vector( head_origin.x + velocity_prop.x * predict_amt, head_origin.y + velocity_prop.y * predict_amt, head_origin.z + velocity_prop.z * predict_amt )
			local trace_entity, damage = client.trace_bullet( entity.get_local_player( ), predicted_eye_position.x, predicted_eye_position.y, predicted_eye_position.z, predicted_head_origin.x, predicted_head_origin.y, predicted_head_origin.z )
			
			-- Restore their origin to their networked origin
			entity.get_prop( player, 'm_vecOrigin', origin )
			
			-- Check if damage can be dealt to their predicted head
			if damage > 0 then
				return true
			end
		end
		
		return false
	end

	local function fix_defensive(cmd)

		ctx.state = get_state(get_velocity())

		if not ui.get(gui.conditions[ctx.state].override) then
			ctx.state = 'shared'
		end

		if not ui.get(software.rage.binds.double_tap[2]) then
			return
		end
	
		if ui.get( gui.conditions[ctx.state].defensive_on ) then
			cmd.force_defensive = true
		elseif is_peeking() and ui.get(gui.corrections.fix_defensive) then
			cmd.force_defensive = true
		else
			cmd.force_defensive = false
		end

	end

	local misses = {}

	client.set_event_callback('aim_miss', function(enemy) 

		if enemy.reason ~= '?' then
			return
		end
	
		if not misses[enemy.target] then
			misses[enemy.target] = 0
		end
	
		misses[enemy.target] = misses[enemy.target] + 1
	end)
	
	client.set_event_callback('player_connect', function(e) 
		misses[client.userid_to_entindex(enemy.userid)] = 0
	end)

	function esp()

		if not ui.get(gui.corrections.custom_resolver) then 
			return false  
		end
			
		return true
		
	end

	local function proper_resolver()

		if not entity.is_alive(g_ctx.lp) then
			return
		end
		local enemies = entity.get_players(true)
	
		for i, enemy in ipairs(enemies) do
			if entity.is_dormant(enemy) then
				return
			end

			if not misses[enemy] then
                misses[enemy] = 0
            end

			ctx.proper = entity.get_prop(enemy, 'm_flPoseParameter', 11) * 120 - 60

			ctx.enemy = 0

			misses.brut = '[DEF]'

			if misses[enemy] == 1 or misses[enemy] == 2 then
				ctx.enemy = ctx.proper
				misses.brut = '[FIX]'
			elseif misses[enemy] == 3 then
			    ctx.enemy = 30
				misses.brut = '[30]'
			elseif misses[enemy] == 4 then
			    ctx.enemy = -30
				misses.brut = '[-30]'
			elseif misses[enemy] == 5 then
			    ctx.enemy = 0
				misses.brut = '[0]'
			elseif misses[enemy] == 6 and ui.get(gui.corrections.over) or misses[enemy] == 7 and ui.get(gui.corrections.over) then
				ctx.enemy = ui.get(gui.corrections.gradus)
				misses.brut = '[OVR]'
			elseif misses[enemy] > 7 and ui.get(gui.corrections.over) or misses[enemy] > 5 then
			    misses[enemy] = 0
				misses.brut = '[DEF+]'
		    end

			plist.set(enemy, 'Force body yaw', ui.get(gui.corrections.custom_resolver) and misses[enemy] ~= 0)
			plist.set(enemy, 'Force body yaw value', ctx.enemy)
		end
	end

	client.register_esp_flag('f', 255, 255, 255, function(enemy)
	if ui.get(gui.corrections.custom_resolver) and ui.get(gui.corrections.espind) then
		return true, misses.brut
	end
end)  

	function corrections.createmove(cmd)
		if not entity.is_alive(g_ctx.lp) then
			return
		end
		fix_defensive(cmd)
		--hitchance_override()
	end

	function corrections.update()
		proper_resolver()
	end

	function corrections.anim()

		if not entity.is_alive(g_ctx.lp) then
			return
		end
	
		local player_ptr = ffi.cast(class_ptr, native_GetClientEntity(g_ctx.lp))
		if player_ptr == nullptr then
			return
		end
	
		local anim_layers = ffi.cast(animation_layer_t, ffi.cast(char_ptr, player_ptr) + 0x2990)[0]
	
		local a12 = ui.get(gui.twelve_layer)
		local a6 = ui.get(gui.six_layer)

		local p7 = ui.get(gui.seven_pose)
		local p6 = ui.get(gui.six_pose)
		local p0 = ui.get(gui.zero_pose)
	
		if a12 == '1' then
			anim_layers[12]['weight'] = 1
		elseif a12 == '.5' then
			anim_layers[12]['weight'] = .5
		elseif a12 == '.0' then
			anim_layers[12]['weight'] = .0
		elseif a12 == 'bsod' then
			anim_layers[12]['weight'] = client.random_float(0, 1)	
		end

		if a6 == '1' then
			anim_layers[6]['weight'] = 1
		elseif a6 == '.5' then
			anim_layers[6]['weight'] = .5
		elseif a6 == '.0' then
			anim_layers[6]['weight'] = .0
		elseif a6 == 'bsod' then
			anim_layers[6]['weight'] = client.random_float(0, 1)	
		end

		if p7 == '1' then
			entity.set_prop(g_ctx.lp, 'm_flPoseParameter', 1, 7)
		elseif p7 == '.5' then
			entity.set_prop(g_ctx.lp, 'm_flPoseParameter', .5, 7)
		elseif p7 == '.0' then
			entity.set_prop(g_ctx.lp, 'm_flPoseParameter', .0, 7)
		elseif p7 == 'bsod' then
			entity.set_prop(g_ctx.lp, 'm_flPoseParameter', client.random_float(0, 1), 7)
		end

		if p6 == '1' then
			entity.set_prop(g_ctx.lp, 'm_flPoseParameter', 1, 6)
		elseif p6 == '.5' then
			entity.set_prop(g_ctx.lp, 'm_flPoseParameter', .5, 6)
		elseif p6 == '.0' then
			entity.set_prop(g_ctx.lp, 'm_flPoseParameter', .0, 6)
		elseif p6 == 'bsod' then
			entity.set_prop(g_ctx.lp, 'm_flPoseParameter', client.random_float(0, 1), 6)
		end

		if p0 == '1' then
			entity.set_prop(g_ctx.lp, 'm_flPoseParameter', 1, 0)
		elseif p0 == '.5' then
			entity.set_prop(g_ctx.lp, 'm_flPoseParameter', .5, 0)
		elseif p0 == '.0' then
			entity.set_prop(g_ctx.lp, 'm_flPoseParameter', .0, 0)
		elseif p0 == 'bsod' then
			entity.set_prop(g_ctx.lp, 'm_flPoseParameter', client.random_float(0, 1), 0)
		end
	end
end

if lua.sub == '_' then
	timer.add(0.0, function(cock) client.exec(cock) end, 'clear')
	timer.add(0.0, function(cock) client.log(cock) end, 'By Lioceron')
	timer.add(2.0, function(cock) client.log(cock) end, 'Welcome to the zenith.gs!')
	timer.add(4.0, function(cock) client.log(cock) end, 'Logging as a user.')
	timer.add(6.0, function(cock) client.log(cock) end, 'Our Discord: dsc.gg/antariusgg\n')
end

do

	function round.start()
		if not ui.get(gui.debug) then
			return
		end

		client.exec('clear')
		client.exec('play buttons/light_power_on_switch_01')
	end

	function round.eng()
		if not ui.get(gui.debug) then
			return
		end

		client.exec('play buttons/light_power_on_switch_01')
	end

	function round.break_prop()
		if not ui.get(gui.debug) then
			return
		end

		client.exec('play buttons/light_power_on_switch_01')
	end

	function round.player_hurt()
		if not ui.get(gui.debug) then
			return
		end

		client.exec('play buttons/arena_switch_press_02')
	end

end

do
	function cwar.createmove()
		--console filter
		cvar.con_filter_enable:set_int(1)
		--cvar.con_filter_text:set_string('dsc.gg/antariusgg')
	    --end

		--sv_airaccelerate
		cvar.sv_airaccelerate:set_int(100)
		--end

		--r_aspectratio
		cvar.r_aspectratio:set_float(ui.get(gui.aspectratio) * 0.1)
	    --end

		if entity.is_alive(g_ctx.lp) then
		--cam_idealdist
		cvar.cam_idealdist:set_float(ui.get(gui.thirdperson) * backup.visual.thirdperson)
	    --end
		end

	end

	function cwar.shutdown()
		--console filter
		cvar.con_filter_enable:set_int(0)
		cvar.con_filter_text:set_string('')
		--end

		--sv_airaccelerate
		cvar.sv_airaccelerate:set_int(12)
		--end

		--r_aspectratio
		cvar.r_aspectratio:set_int(0)
	    --end

		--cam_idealdist
		cvar.cam_idealdist:set_int(100)
		--end
	end
end

do
	software.init()
	gui.init()
	builder.init()
	indicators.init()
	corrections.init()

	client.set_event_callback('paint', g_ctx.render)
	client.set_event_callback('paint_ui', gui.render)
	client.set_event_callback('paint_ui', gui.animbuilder)
	client.set_event_callback('paint', indicators.render)
	client.set_event_callback('paint_ui', builder.render)
	client.set_event_callback('paint', timer.render)
	
	client.set_event_callback('setup_command', builder.createmove)
	client.set_event_callback('setup_command', corrections.createmove)
	client.set_event_callback('run_command', def.defensive.run)
	client.set_event_callback('predict_command', def.defensive.predict)

	client.set_event_callback('shutdown', gui.shut)

	client.set_event_callback('setup_command', cwar.createmove)
	client.set_event_callback('shutdown', cwar.createmove)

	client.set_event_callback('round_start',  round.start)
	client.set_event_callback('round_end',    round.eng)
	client.set_event_callback('break_prop',   round.break_prop)
	client.set_event_callback('player_hurt',  round.player_hurt)

	client.set_event_callback('net_update_end', corrections.update)
	client.set_event_callback('pre_render', corrections.anim)

end