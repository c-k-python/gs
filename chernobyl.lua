

local ffi = require("ffi")

ffi.cdef[[
    typedef struct {
        unsigned short wYear;
        unsigned short wMonth;
        unsigned short wDayOfWeek;
        unsigned short wDay;
        unsigned short wHour;
        unsigned short wMinute;
        unsigned short wSecond;
        unsigned short wMilliseconds;
    } SYSTEMTIME, *LPSYSTEMTIME;
    void GetSystemTime(LPSYSTEMTIME lpSystemTime);
    void GetLocalTime(LPSYSTEMTIME lpSystemTime);

    typedef unsigned char BYTE;
    typedef void *PVOID;
    typedef PVOID HMODULE;
    typedef const char *LPCSTR;
    typedef int *FARPROC;
    
    HMODULE GetModuleHandleA(
        LPCSTR lpModuleName
    );
    
    FARPROC GetProcAddress(
        HMODULE hModule,
        LPCSTR  lpProcName
    );
    
    typedef struct{
        BYTE r, g, b, a;
    } Color;
    
    typedef void(__cdecl *ColorMsgFn)(Color&, const char*);

    typedef int(__thiscall* get_clipboard_text_count)(void*);
    typedef void(__thiscall* set_clipboard_text)(void*, const char*, int);
    typedef void(__thiscall* get_clipboard_text)(void*, int, const char*, int);
    bool CreateDirectoryA(const char* lpPathName, void* lpSecurityAttributes);
    void* __stdcall URLDownloadToFileA(void* LPUNKNOWN, const char* LPCSTR, const char* LPCSTR2, int a, int LPBINDSTATUSCALLBACK);
    void* __stdcall ShellExecuteA(void* hwnd, const char* op, const char* file, const char* params, const char* dir, int show_cmd);
    bool DeleteUrlCacheEntryA(const char* lpszUrlName);

    typedef int(__fastcall* clantag_t)(const char*, const char*);

    bool CreateDirectoryA(const char* lpPathName, void* lpSecurityAttributes);
    void* __stdcall URLDownloadToFileA(void* LPUNKNOWN, const char* LPCSTR, const char* LPCSTR2, int a, int LPBINDSTATUSCALLBACK);
    void* __stdcall ShellExecuteA(void* hwnd, const char* op, const char* file, const char* params, const char* dir, int show_cmd);
]]
local urlmon = ffi.load 'UrlMon'
local wininet = ffi.load 'WinInet'
local gdi = ffi.load 'Gdi32'
local ffi_cast = ffi.cast
local VGUI_System010 =  Utils.CreateInterface("vgui2.dll", "VGUI_System010")
local VGUI_System = ffi.cast(ffi.typeof('void***'), VGUI_System010 )
local get_clipboard_text_count = ffi.cast( "get_clipboard_text_count", VGUI_System[ 0 ][ 7 ] )
local set_clipboard_text = ffi.cast( "set_clipboard_text", VGUI_System[ 0 ][ 9 ] )
local get_clipboard_text = ffi.cast( "get_clipboard_text", VGUI_System[ 0 ][ 11 ] )

Download = function(from, to)
wininet.DeleteUrlCacheEntryA(from)
urlmon.URLDownloadToFileA(nil, from, to, 0,0)
end

CreateDir = function(path)
ffi.C.CreateDirectoryA(path, NULL)
end

ui = {
    tabs = Menu.Combo('Chernobyl [STABLE]', "Active Tab", {"Information", "RageBot", "Anti-Aim", "Visuals"}, 0),
    t1 = Menu.Text("Information", "Chernobyl.lua [STABLE] ver. 1.3.4\n\nLast update:\n\n[~] Script was full recoded and optimized.\n[+] Added Massive Fake exploit\n[+] New style chernobyl UI\n[+] Added presets\n[+] Added Ideal Tick\n[+] Added custom indicators.\n[-] Removed Custom AA tab.\n\nIf you have any problem or suggestions, join to our discord: discord.gg/chernobylnl"),
--rage
    da_enable = Menu.Switch("RageBot", "Dormant Aimbot", false),
    da_damage = Menu.SliderInt("RageBot", "Min. Damage", 1,1,130),
    customdt = Menu.Switch("RageBot", "Custom DT", false),
    customdtspeed = Menu.SliderInt("RageBot", "Custom DT Speed", 1,1,20),
    customdthit = Menu.Switch("RageBot", "Override Hitchance", false),
    customdthitair = Menu.SliderInt("RageBot", "in air", 0,0,100),
    customdthitnoscope = Menu.SliderInt("RageBot", "no scope", 0,0,100),
    idealtick = Menu.Switch("RageBot", "Ideal Tick", false),
    idealbind = Menu.SwitchColor("RageBot", "Ideal Tick (bind)", false, Color.new(1.0, 1.0, 1.0, 1.0)),
--visuals
    selected_ind = Menu.ComboColor("Visuals", "Indicators", {"Disable", "Acatel", "Chernobyl", "Prediction", "Priora", "Arctic", "New"}, 0, Color.RGBA(250, 166, 90, 255)),
    selected_ind_v = Menu.Switch("Visuals", "Altrenative scope indicators ", false),
    spread_circle = Menu.SwitchColor("Visuals", "Spread Circle", false, Color.RGBA(0, 0, 0, 50)),
    logs = Menu.SwitchColor("Visuals", "GS Logs", false, Color.new(1.0, 1.0, 1.0, 1.0)),

    CustomHitmarker = Menu.Switch("Visuals", "Hit Marker", false),
    CustomHitmarker_show_dmg = Menu.Switch("Visuals", "Hit Marker Dmg", false),
    CustomHitmarker_mode = Menu.Combo("Visuals", "Hit Marker Type", {"+", "x"}, 0),
    CustomHitmarker_color = Menu.ColorEdit("Visuals", "Hit Marker Color", Color.new(1.0, 1.0, 1.0, 1.0)),
    CustomHitmarker_color_dmg = Menu.ColorEdit("Visuals", "Damage Color", Color.new(1.0, 1.0, 1.0, 1.0)),

    selected_arr = Menu.Combo("Visuals", "Arrows Type", {"Disable","1", "2", "3", "4"}, 0),
    active = Menu.ColorEdit("Visuals", "Active", Color.RGBA(138, 157, 239, 255)),
    inactive = Menu.ColorEdit("Visuals", "Inactive", Color.RGBA(255, 255, 255, 175)),

    old_or_new = Menu.Combo('Chernobyl UI', 'Version', {'Old', 'New'}, 0),
    el = Menu.MultiCombo('Chernobyl UI', 'Elements', {'Watermark', 'Keybinds', 'Spectators',}, 0),
    color = Menu.ColorEdit('Chernobyl UI', 'Color', Color.RGBA(250, 166, 90, 255)),
    name = Menu.Combo('Chernobyl UI', 'Name',{'Cheat username', 'In-game', 'Custom'}, 0),
    name_custom = Menu.TextBox('Chernobyl UI', 'Custom name', 50, 'Chernobyl'),

    custom_scope = Menu.Switch("Visuals", "Сustom Scope", false),
    color_picker = Menu.ColorEdit("Visuals", "Scope Lines Color", Color.new(0.0, 0.0, 0.0, 1.0)),
    overlay_position = Menu.SliderInt("Visuals", "Scope Lines Pos", 0, 0, 500),
    overlay_offset = Menu.SliderInt("Visuals", "Scope Lines Offset", 0, 0, 500),
    fade_time = Menu.SliderInt("Visuals", "Fade Animation", 0, 0, 20),

--aa
    enableFakeExtension = Menu.Switch("Chernobyl [STABLE]", "Massive Fake", false),
    fake_m = Menu.MultiCombo('Chernobyl [STABLE]', 'Fake Conditions', {'Stay', 'Move', 'Air', 'Slow Walk'}, 0),
    invertFake = Menu.Switch("Chernobyl [STABLE]", "Inverter", false),
    legitaa = Menu.Switch("Chernobyl [STABLE]", "Legit AA on use", false),
    backstab_butt = Menu.Switch("Chernobyl [STABLE]", "Anti Backstab", false),
    air_teleport = Menu.Switch("Chernobyl [STABLE]", "Teleport Cross", false),

    --кастом аашки
    Custom_conditions = Menu.Combo("Chernobyl [STABLE]", "Conditions", {"Stay", "Move", "Air", "Slow Walk", "Crouch", "FD", "Anti-Bruteforce"}, 0),

    Stay_Custom_Enable = Menu.Switch("AA", "Enable Override Stay", true),
    Stay_Custom_yaw_add_L = Menu.SliderInt("AA", "[1]Yaw Add Left", 0,-180,180),
    Stay_Custom_yaw_add_R = Menu.SliderInt("AA", "[1]Yaw Add Right", 0,-180,180),
    Stay_Custom_yaw_modifier_mode = Menu.Combo("AA", "[1]Yaw Modifier Mode", {"Static", "Random"}, 0),
    Stay_Custom_yaw_modifier = Menu.Combo("AA", "[1]Yaw Modifier", {"Disable", "Center", "Offset", "Random", "Spin"}, 0),
    Stay_Custom_modifier_degree = Menu.SliderInt("AA", "[1]Modifier Degree", 0,-180,180),
    Stay_Custom_modifier_degree_min = Menu.SliderInt("AA", "[1]Modifier Degree Min", 0,-180,180),
    Stay_Custom_modifier_degree_max = Menu.SliderInt("AA", "[1]Modifier Degree Max", 0,-180,180),
    Stay_Custom_inverter = Menu.Switch("AA", "[1]Inverter", false),
    Stay_Custom_limit_mode = Menu.Combo("AA", "[1]Limit Mode", {"Static", "Random"}, 0),
    Stay_Custom_limit1 = Menu.SliderInt("AA", "[1]Fake Limit Left", 0,0,60),
    Stay_Custom_limit2 = Menu.SliderInt("AA", "[1]Fake Limit Right", 0,0,60),
    Stay_Custom_limit3 = Menu.SliderInt("AA", "[1]Max Limit Left", 0,0,60),
    Stay_Custom_limit4 = Menu.SliderInt("AA", "[1]Max Limit Right", 0,0,60),
    Stay_Custom_fake_options = Menu.MultiCombo("AA", "[1]Fake Options", {"Avoid Overlap", "Jitter", "Randomize Jitter"}, 0),
    Stay_Custom_lby_mode = Menu.Combo("AA", "[1]LBY Mode", {"Disable", "Opposite", "Sway"}, 0),
    Stay_Custom_freestand_dsy = Menu.Combo("AA", "[1]Freestand Desync", {"Disable", "Peek Fake", "Peek Real"}, 0),
    Stay_Custom_dsy_on_shot = Menu.Combo("AA", "[1]Desync On Shot", {"Off", "Opposite", "Freestanding", "Switch"}, 0),
    roll_on_stay = Menu.Switch("AA", "[1]Roll On Stay  ", false),

    -- когда идешь
    Move_Custom_Enable = Menu.Switch("AA", "Enable Override Move", true),
    Move_Custom_yaw_add_L = Menu.SliderInt("AA", "[2]Yaw Add Left ", 0,-180,180),
    Move_Custom_yaw_add_R = Menu.SliderInt("AA", "[2]Yaw Add Right ", 0,-180,180),
    Move_Custom_yaw_modifier_mode = Menu.Combo("AA", "[2]Yaw Modifier Mode", {"Static", "Random"}, 0),
    Move_Custom_yaw_modifier = Menu.Combo("AA", "[2]Yaw Modifier ", {"Disable", "Center", "Offset", "Random", "Spin"}, 0),
    Move_Custom_modifier_degree = Menu.SliderInt("AA", "[2]Modifier Degree ", 0,-180,180),
    Move_Custom_modifier_degree_min = Menu.SliderInt("AA", "[2]Modifier Degree Min", 0,-180,180),
    Move_Custom_modifier_degree_max = Menu.SliderInt("AA", "[2]Modifier Degree Max", 0,-180,180),
    Move_Custom_inverter = Menu.Switch("AA", "[2]Inverter ", false),
    Move_Custom_limit_mode = Menu.Combo("AA", "[2]Limit Mode ", {"Static", "Random"}, 0),
    Move_Custom_limit1 = Menu.SliderInt("AA", "[2]Fake Limit Left", 0,0,60),
    Move_Custom_limit2 = Menu.SliderInt("AA", "[2]Fake Limit Right", 0,0,60),
    Move_Custom_limit3 = Menu.SliderInt("AA", "[2]Max Limit Left", 0,0,60),
    Move_Custom_limit4 = Menu.SliderInt("AA", "[2]Max Limit Right", 0,0,60),
    Move_Custom_fake_options = Menu.MultiCombo("AA", "[2]Fake Options ", {"Avoid Overlap", "Jitter", "Randomize Jitter"}, 0),
    Move_Custom_lby_mode = Menu.Combo("AA", "[2]LBY Mode ", {"Disable", "Opposite", "Sway"}, 0),
    Move_Custom_freestand_dsy = Menu.Combo("AA", "[2]Freestand Desync ", {"Disable", "Peek Fake", "Peek Real"}, 0),
    Move_Custom_dsy_on_shot = Menu.Combo("AA", "[2]Desync On Shot ", {"Off", "Opposite", "Freestanding", "Switch"}, 0),
    roll_on_move = Menu.Switch("AA", "[2]Roll On Move  ", false),

    -- когда летишь
    Air_Custom_Enable = Menu.Switch("AA", "Enable Override Air", true),
    Air_Custom_yaw_add_L = Menu.SliderInt("AA", "[3]Yaw Add Left  ", 0,-180,180),
    Air_Custom_yaw_add_R = Menu.SliderInt("AA", "[3]Yaw Add Right  ", 0,-180,180),
    Air_Custom_yaw_modifier_mode = Menu.Combo("AA", "[3]Yaw Modifier Mode", {"Static", "Random"}, 0),
    Air_Custom_yaw_modifier = Menu.Combo("AA", "[3]Yaw Modifier  ", {"Disable", "Center", "Offset", "Random", "Spin"}, 0),
    Air_Custom_modifier_degree = Menu.SliderInt("AA", "[3]Modifier Degree  ", 0,-180,180),
    Air_Custom_modifier_degree_min = Menu.SliderInt("AA", "[3]Modifier Degree Min", 0,-180,180),
    Air_Custom_modifier_degree_max = Menu.SliderInt("AA", "[3]Modifier Degree Max", 0,-180,180),
    Air_Custom_inverter = Menu.Switch("AA", "[3]Inverter  ", false),
    Air_Custom_limit_mode = Menu.Combo("AA", "[3]Limit Mode  ", {"Static", "Random"}, 0),
    Air_Custom_limit1 = Menu.SliderInt("AA", "[3]Fake Limit Left", 0,0,60),
    Air_Custom_limit2 = Menu.SliderInt("AA", "[3]Fake Limit Right", 0,0,60),
    Air_Custom_limit3 = Menu.SliderInt("AA", "[3]Max Limit Left", 0,0,60),
    Air_Custom_limit4 = Menu.SliderInt("AA", "[3]Max Limit Right", 0,0,60),
    Air_Custom_fake_options = Menu.MultiCombo("AA", "[3]Fake Options  ", {"Avoid Overlap", "Jitter", "Randomize Jitter"}, 0),
    Air_Custom_lby_mode = Menu.Combo("AA", "[3]LBY Mode  ", {"Disable", "Opposite", "Sway"}, 0),
    Air_Custom_freestand_dsy = Menu.Combo("AA", "[3]Freestand Desync  ", {"Disable", "Peek Fake", "Peek Real"}, 0),
    Air_Custom_dsy_on_shot = Menu.Combo("AA", "[3]Desync On Shot  ", {"Off", "Opposite", "Freestanding", "Switch"}, 0),
    roll_on_air = Menu.Switch("AA", "[3]Roll On Air  ", false),

    -- шифт
    Walk_Custom_Enable = Menu.Switch("AA", "Enable Override Walk", true),
    Walk_Custom_yaw_add_L = Menu.SliderInt("AA", "[4]Yaw Add Left  ", 0,-180,180),
    Walk_Custom_yaw_add_R = Menu.SliderInt("AA", "[4]Yaw Add Right  ", 0,-180,180),
    Walk_Custom_yaw_modifier_mode = Menu.Combo("AA", "[4]Yaw Modifier Mode", {"Static", "Random"}, 0),
    Walk_Custom_yaw_modifier = Menu.Combo("AA", "[4]Yaw Modifier  ", {"Disable", "Center", "Offset", "Random", "Spin"}, 0),
    Walk_Custom_modifier_degree = Menu.SliderInt("AA", "[4]Modifier Degree  ", 0,-180,180),
    Walk_Custom_modifier_degree_min = Menu.SliderInt("AA", "[4]Modifier Degree Min", 0,-180,180),
    Walk_Custom_modifier_degree_max = Menu.SliderInt("AA", "[4]Modifier Degree Max", 0,-180,180),
    Walk_Custom_inverter = Menu.Switch("AA", "[4]Inverter  ", false),
    Walk_Custom_limit_mode = Menu.Combo("AA", "[4]Limit Mode  ", {"Static", "Random"}, 0),
    Walk_Custom_limit1 = Menu.SliderInt("AA", "[4]Fake Limit Left", 0,0,60),
    Walk_Custom_limit2 = Menu.SliderInt("AA", "[4]Fake Limit Right", 0,0,60),
    Walk_Custom_limit3 = Menu.SliderInt("AA", "[4]Max Limit Left", 0,0,60),
    Walk_Custom_limit4 = Menu.SliderInt("AA", "[4]Max Limit Right", 0,0,60),
    Walk_Custom_fake_options = Menu.MultiCombo("AA", "[4]Fake Options  ", {"Avoid Overlap", "Jitter", "Randomize Jitter"}, 0),
    Walk_Custom_lby_mode = Menu.Combo("AA", "[4]LBY Mode  ", {"Disable", "Opposite", "Sway"}, 0),
    Walk_Custom_freestand_dsy = Menu.Combo("AA", "[4]Freestand Desync  ", {"Disable", "Peek Fake", "Peek Real"}, 0),
    Walk_Custom_dsy_on_shot = Menu.Combo("AA", "[4]Desync On Shot  ", {"Off", "Opposite", "Freestanding", "Switch"}, 0),
    roll_on_walk = Menu.Switch("AA", "[4]Roll On Walk  ", false),

    --крауч
    Crouch_Custom_Enable = Menu.Switch("AA", "Enable Override Crouch", true),
    Crouch_Custom_yaw_add_L = Menu.SliderInt("AA", "[5]Yaw Add Left  ", 0,-180,180),
    Crouch_Custom_yaw_add_R = Menu.SliderInt("AA", "[5]Yaw Add Right  ", 0,-180,180),
    Crouch_Custom_yaw_modifier_mode = Menu.Combo("AA", "[5]Yaw Modifier Mode", {"Static", "Random"}, 0),
    Crouch_Custom_yaw_modifier = Menu.Combo("AA", "[5]Yaw Modifier  ", {"Disable", "Center", "Offset", "Random", "Spin"}, 0),
    Crouch_Custom_modifier_degree = Menu.SliderInt("AA", "[5]Modifier Degree  ", 0,-180,180),
    Crouch_Custom_modifier_degree_min = Menu.SliderInt("AA", "[5]Modifier Degree Min", 0,-180,180),
    Crouch_Custom_modifier_degree_max = Menu.SliderInt("AA", "[5]Modifier Degree Max", 0,-180,180),
    Crouch_Custom_inverter = Menu.Switch("AA", "[5]Inverter  ", false),
    Crouch_Custom_limit_mode = Menu.Combo("AA", "[5]Limit Mode  ", {"Static", "Random"}, 0),
    Crouch_Custom_limit1 = Menu.SliderInt("AA", "[5]Fake Limit Left", 0,0,60),
    Crouch_Custom_limit2 = Menu.SliderInt("AA", "[5]Fake Limit Right", 0,0,60),
    Crouch_Custom_limit3 = Menu.SliderInt("AA", "[5]Max Limit Left", 0,0,60),
    Crouch_Custom_limit4 = Menu.SliderInt("AA", "[5]Max Limit Right", 0,0,60),
    Crouch_Custom_fake_options = Menu.MultiCombo("AA", "[5]Fake Options  ", {"Avoid Overlap", "Jitter", "Randomize Jitter"}, 0),
    Crouch_Custom_lby_mode = Menu.Combo("AA", "[5]LBY Mode  ", {"Disable", "Opposite", "Sway"}, 0),
    Crouch_Custom_freestand_dsy = Menu.Combo("AA", "[5]Freestand Desync  ", {"Disable", "Peek Fake", "Peek Real"}, 0),
    Crouch_Custom_dsy_on_shot = Menu.Combo("AA", "[5]Desync On Shot  ", {"Off", "Opposite", "Freestanding", "Switch"}, 0),
    roll_on_crouch = Menu.Switch("AA", "[5]Roll On Crouch  ", false),

    FD_Custom_Enable = Menu.Switch("AA", "Enable Override FD", true),
    FD_Custom_yaw_add_L = Menu.SliderInt("AA", "[6]Yaw Add Left  ", 0,-180,180),
    FD_Custom_yaw_add_R = Menu.SliderInt("AA", "[6]Yaw Add Right  ", 0,-180,180),
    FD_Custom_yaw_modifier_mode = Menu.Combo("AA", "[6]Yaw Modifier Mode", {"Static", "Random"}, 0),
    FD_Custom_yaw_modifier = Menu.Combo("AA", "[6]Yaw Modifier  ", {"Disable", "Center", "Offset", "Random", "Spin"}, 0),
    FD_Custom_modifier_degree = Menu.SliderInt("AA", "[6]Modifier Degree  ", 0,-180,180),
    FD_Custom_modifier_degree_min = Menu.SliderInt("AA", "[6]Modifier Degree Min", 0,-180,180),
    FD_Custom_modifier_degree_max = Menu.SliderInt("AA", "[6]Modifier Degree Max", 0,-180,180),
    FD_Custom_inverter = Menu.Switch("AA", "[6]Inverter  ", false),
    FD_Custom_limit_mode = Menu.Combo("AA", "[6]Limit Mode  ", {"Static", "Random"}, 0),
    FD_Custom_limit1 = Menu.SliderInt("AA", "[6]Fake Limit Left", 0,0,60),
    FD_Custom_limit2 = Menu.SliderInt("AA", "[6]Fake Limit Right", 0,0,60),
    FD_Custom_limit3 = Menu.SliderInt("AA", "[6]Max Limit Left", 0,0,60),
    FD_Custom_limit4 = Menu.SliderInt("AA", "[6]Max Limit Right", 0,0,60),
    FD_Custom_fake_options = Menu.MultiCombo("AA", "[6]Fake Options  ", {"Avoid Overlap", "Jitter", "Randomize Jitter"}, 0),
    FD_Custom_lby_mode = Menu.Combo("AA", "[6]LBY Mode  ", {"Disable", "Opposite", "Sway"}, 0),
    FD_Custom_freestand_dsy = Menu.Combo("AA", "[6]Freestand Desync  ", {"Disable", "Peek Fake", "Peek Real"}, 0),
    FD_Custom_dsy_on_shot = Menu.Combo("AA", "[6]Desync On Shot  ", {"Off", "Opposite", "Freestanding", "Switch"}, 0),

    brute_aa = Menu.Switch("AA", "[AB]Enable Anti-Bruteforce", false),
    brute_aa_conditions = Menu.MultiCombo("AA", "[AB]Brute Conditions", {"Stay", "Move", "Air", "Crouch", "SlowWalk"}, 0),
    AB_miss_enable_1 = Menu.Switch("AA", "[AB1]Enable miss 1  ", false),
    AB_miss_yawL_1 = Menu.SliderInt("AA", "[AB1]Yaw Add Left", 0,-180,180),
    AB_miss_yawR_1 = Menu.SliderInt("AA", "[AB1]Yaw Add Right", 0,-180,180),
    AB_miss_yaw_modifier_1 = Menu.Combo("AA", "[AB1]Yaw Modifier  ", {"Disable", "Center", "Offset", "Random", "Spin"}, 0),
    AB_miss_modifier_1 = Menu.SliderInt("AA", "[AB1]Modifier Degree  ", 0,-180,180),
    AB_miss_lby_1 = Menu.Combo("AA", "[AB1]LBY Mode  ", {"Disable", "Opposite", "Sway"}, 0),

    AB_miss_enable_2 = Menu.Switch("AA", "[AB2]Enable miss 2  ", false),
    AB_miss_yawL_2 = Menu.SliderInt("AA", "[AB2]Yaw Add Left", 0,-180,180),
    AB_miss_yawR_2 = Menu.SliderInt("AA", "[AB2]Yaw Add Right", 0,-180,180),
    AB_miss_yaw_modifier_2 = Menu.Combo("AA", "[AB2]Yaw Modifier  ", {"Disable", "Center", "Offset", "Random", "Spin"}, 0),
    AB_miss_modifier_2 = Menu.SliderInt("AA", "[AB2]Modifier Degree  ", 0,-180,180),
    AB_miss_lby_2 = Menu.Combo("AA", "[AB2]LBY Mode  ", {"Disable", "Opposite", "Sway"}, 0),

    AB_miss_enable_3 = Menu.Switch("AA", "[AB3]Enable miss 3  ", false),
    AB_miss_yawL_3 = Menu.SliderInt("AA", "[AB3]Yaw Add Left", 0,-180,180),
    AB_miss_yawR_3 = Menu.SliderInt("AA", "[AB3]Yaw Add Right", 0,-180,180),
    AB_miss_yaw_modifier_3 = Menu.Combo("AA", "[AB3]Yaw Modifier  ", {"Disable", "Center", "Offset", "Random", "Spin"}, 0),
    AB_miss_modifier_3 = Menu.SliderInt("AA", "[AB3]Modifier Degree  ", 0,-180,180),
    AB_miss_lby_3 = Menu.Combo("AA", "[AB3]LBY Mode  ", {"Disable", "Opposite", "Sway"}, 0),

    manuals = Menu.Combo("Chernobyl [STABLE]", "Roll Manual", {"Disable", "Left", "Right"}, 0),
    ex_for_run = Menu.Switch("Chernobyl [STABLE]", "More Velocity On Roll Manual AA", false, "for running"),
--misc
    TrashTalk = Menu.Switch("Visuals", "TrashTalk", false),

    get_discord = Menu.Button("Chernobyl [STABLE]","Discord","Discord", function()
        Panorama.Open().SteamOverlayAPI.OpenExternalBrowserURL("https://discord.gg/chernobylnl")
    end),
    button = Menu.Button("Chernobyl [STABLE]", "Download Font", "Download Font", function()
        CreateDir("nl\\Chernobyl")
        CreateDir("nl\\Chernobyl\\fonts\\")
        Download('https://cdn.discordapp.com/attachments/976869884464095232/976876923588337684/pixel.ttf', 'nl\\Chernobyl\\fonts\\pixel.ttf')
        Download('https://cdn.discordapp.com/attachments/976869884464095232/976876821796761710/arrows.ttf', 'nl\\Chernobyl\\fonts\\arrows.ttf')
        Download('https://cdn.discordapp.com/attachments/976869884464095232/976876923588337684/pixel.ttf', 'nl\\Chernobyl\\fonts\\unsave.ttf')
        Cheat.AddNotify("Chernobyl | Indicators font", "Font downloaded, restart script!")
    end),
}

local anti_hit = {}
local legs = Menu.FindVar("Aimbot", "Anti Aim", "Misc", "Leg Movement")
local walk = Menu.FindVar("Aimbot", "Anti Aim", "Misc", "Slow Walk")
local fl = Menu.FindVar("Aimbot", "Anti Aim", "Fake Lag", "Limit")
local pitch = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Pitch")
local yaw_base = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Base")
local yaw_add = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Add")
local dsyL = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Left Limit")
local dsyR = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Right Limit")
local inverter = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Inverter")
local fake_opt = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Fake Options")
local freestand_dsy = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Freestanding Desync")
local dsy_on_shot = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Desync On Shot")
local lby_mode = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "LBY Mode")
local yaw_modifier = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Modifier")
local modifier_degree = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Modifier Degree")
local BA = Menu.FindVar("Aimbot","Ragebot","Misc","Body Aim")
local SP = Menu.FindVar("Aimbot","Ragebot","Misc","Safe Points")
local DT = Menu.FindVar("Aimbot","Ragebot","Exploits","Double Tap")
local HS = Menu.FindVar("Aimbot","Ragebot","Exploits","Hide Shots")
local FD = Menu.FindVar("Aimbot","Anti Aim","Misc","Fake Duck")
local Thirdperson = Menu.FindVar("Visuals","View","Thirdperson","Enable Thirdperson")
local nl_hit_marker = Menu.FindVar("Visuals","World","Misc","Damage Indicator")
local auto_peek = Menu.FindVar("Miscellaneous","Main","Movement","Auto Peek")
local fake_ping = Menu.FindVar("Miscellaneous","Main","Other","Fake Ping")
local AutoPeek = Menu.FindVar("Miscellaneous", "Main", "Movement", "Auto Peek")
local nl_logs = Menu.FindVar("Miscellaneous", "Main", "Other", "Event Log")

local font_size2 = 23
local font_size3 = 11
local font = {
tahoma = Render.InitFont("Tahoma", 12, {'b'}),
pixel = Render.InitFont("nl\\Chernobyl\\fonts\\pixel.ttf", 10),
acta_arrows = Render.InitFont("nl\\Chernobyl\\fonts\\arrows.ttf", 24),
acta_arrows2 = Render.InitFont("nl\\Chernobyl\\fonts\\arrows.ttf", 16),
unsave = Render.InitFont("nl\\Chernobyl\\fonts\\unsave.ttf", 11),
bold = Render.InitFont("Verdana", 11, {'b'}),
verdanabold = Render.InitFont("Verdana Bold", 11, {' '} ),
verdanabold2 = Render.InitFont("Verdana Bold", 12, {' '} ),
verdanar = Render.InitFont("Verdana", 11, {'r'}),
warning = Render.InitFont("Tahoma", font_size2),
verdana2 = Render.InitFont("Verdana Bold", 11),
}
local x, y = EngineClient.GetScreenSize().x / 2, EngineClient.GetScreenSize().y / 2

local image_size = Vector2.new(30, 30)
local url = "https://cdn.discordapp.com/attachments/939885285485998100/952977373727428658/image.png"
local bytes = Http.Get(url)
local image_loaded = Render.LoadImage(bytes, image_size)
function tabs()
    Render.Image(image_loaded, Vector2.new(5, 5), image_size)
    if not Cheat.IsMenuVisible() then return end
    local tab = ui.tabs:GetInt()

    ui.t1:SetVisible(tab == 0)
    ui.air_teleport:SetVisible(tab == 2)

    ui.da_enable:SetVisible(tab == 1)
    ui.da_damage:SetVisible(tab == 1 and ui.da_enable:Get())
    ui.customdt:SetVisible(tab == 1)
    ui.customdtspeed:SetVisible(tab == 1 and ui.customdt:Get())
    ui.customdthit:SetVisible(tab == 1)
    ui.customdthitair:SetVisible(tab == 1 and ui.customdthit:Get())
    ui.customdthitnoscope:SetVisible(tab == 1 and ui.customdthit:Get())
    ui.idealtick:SetVisible(tab == 1)
    ui.idealbind:SetVisible(tab == 1 and ui.idealtick:Get())

    ui.selected_ind:SetVisible(tab == 3)
    ui.selected_ind_v:SetVisible(tab == 3 and ui.selected_ind:Get() > 1)

    ui.spread_circle:SetVisible(tab == 3)

    ui.selected_arr:SetVisible(tab == 3)
    ui.active:SetVisible(tab == 3 and ui.selected_arr:Get() > 0)
    ui.inactive:SetVisible(tab == 3 and ui.selected_arr:Get() > 0)

    ui.CustomHitmarker:SetVisible(tab == 3)
    ui.CustomHitmarker_mode:SetVisible(tab == 3 and ui.CustomHitmarker:Get())
    ui.CustomHitmarker_color:SetVisible(tab == 3 and ui.CustomHitmarker:Get())
    ui.CustomHitmarker_show_dmg:SetVisible(tab == 3 and ui.CustomHitmarker:Get())
    ui.CustomHitmarker_color_dmg:SetVisible(tab == 3 and ui.CustomHitmarker:Get())

    ui.old_or_new:SetVisible(tab == 3)
    ui.el:SetVisible(tab == 3)
    ui.color:SetVisible(tab == 3)
    ui.name:SetVisible(tab == 3)
    ui.name_custom:SetVisible(tab == 3)

    ui.custom_scope:SetVisible(tab == 3)
    ui.color_picker:SetVisible(tab == 3 and ui.custom_scope:Get())
    ui.overlay_position:SetVisible(tab == 3 and ui.custom_scope:Get())
    ui.overlay_offset:SetVisible(tab == 3 and ui.custom_scope:Get())
    ui.fade_time:SetVisible(tab == 3 and ui.custom_scope:Get())

    ui.enableFakeExtension:SetVisible(tab == 2)
    ui.fake_m:SetVisible(tab == 2 and ui.enableFakeExtension:Get())
    ui.invertFake:SetVisible(tab == 2 and ui.enableFakeExtension:Get())
    ui.backstab_butt:SetVisible(tab == 2)
    ui.legitaa:SetVisible(tab == 2)

    ui.manuals:SetVisible(tab == 2)
    ui.ex_for_run:SetVisible(tab == 2)

    ui.TrashTalk:SetVisible(tab == 3)
    ui.logs:SetVisible(tab == 3)
end

-- таб элементы кастом аа(чтобы все нахуй не перепутать)
function tab_elements_stay()
    if not Cheat.IsMenuVisible() then return end
    local tab = ui.tabs:GetInt()

    ui.Custom_conditions:SetVisible(tab == 2)

    ui.Stay_Custom_Enable:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0)
    ui.Stay_Custom_yaw_add_L:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_Enable:Get())
    ui.Stay_Custom_yaw_add_R:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_Enable:Get())
    ui.Stay_Custom_yaw_modifier:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_Enable:Get())
    ui.Stay_Custom_yaw_modifier_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_Enable:Get())
    ui.Stay_Custom_modifier_degree_min:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_yaw_modifier:Get() > 0 and ui.Stay_Custom_yaw_modifier_mode:Get() == 1 and ui.Stay_Custom_Enable:Get())
    ui.Stay_Custom_modifier_degree_max:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_yaw_modifier:Get() > 0 and ui.Stay_Custom_yaw_modifier_mode:Get() == 1 and ui.Stay_Custom_Enable:Get())
    ui.Stay_Custom_modifier_degree:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_yaw_modifier:Get() > 0 and ui.Stay_Custom_yaw_modifier_mode:Get() == 0 and ui.Stay_Custom_Enable:Get())
    ui.Stay_Custom_inverter:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_Enable:Get())
    ui.Stay_Custom_limit_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_Enable:Get())
    ui.Stay_Custom_limit1:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_Enable:Get())
    ui.Stay_Custom_limit2:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_Enable:Get())
    ui.Stay_Custom_limit3:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_limit_mode:Get() == 1 and ui.Stay_Custom_Enable:Get())
    ui.Stay_Custom_limit4:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_limit_mode:Get() == 1 and ui.Stay_Custom_Enable:Get())
    ui.Stay_Custom_fake_options:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_Enable:Get())
    ui.Stay_Custom_lby_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_Enable:Get())
    ui.Stay_Custom_freestand_dsy:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_Enable:Get())
    ui.Stay_Custom_dsy_on_shot:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_Enable:Get())
    ui.roll_on_stay:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 0 and ui.Stay_Custom_Enable:Get())
end

function tab_elements_move()
    if not Cheat.IsMenuVisible() then return end
    local tab = ui.tabs:GetInt()

    ui.Move_Custom_Enable:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1)
    ui.Move_Custom_yaw_add_L:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_Enable:Get())
    ui.Move_Custom_yaw_add_R:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_Enable:Get())
    ui.Move_Custom_yaw_modifier_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_Enable:Get())
    ui.Move_Custom_modifier_degree_min:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_yaw_modifier:Get() > 0 and ui.Move_Custom_yaw_modifier_mode:Get() == 1 and ui.Move_Custom_Enable:Get())
    ui.Move_Custom_modifier_degree_max:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_yaw_modifier:Get() > 0 and ui.Move_Custom_yaw_modifier_mode:Get() == 1 and ui.Move_Custom_Enable:Get())
    ui.Move_Custom_yaw_modifier:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_Enable:Get())
    ui.Move_Custom_modifier_degree:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_yaw_modifier:Get() > 0 and ui.Move_Custom_yaw_modifier_mode:Get() == 0 and ui.Move_Custom_Enable:Get())
    ui.Move_Custom_inverter:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_Enable:Get())
    ui.Move_Custom_limit_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_Enable:Get())
    ui.Move_Custom_limit1:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_Enable:Get())
    ui.Move_Custom_limit2:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_Enable:Get())
    ui.Move_Custom_limit3:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_limit_mode:Get() == 1 and ui.Move_Custom_Enable:Get())
    ui.Move_Custom_limit4:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_limit_mode:Get() == 1 and ui.Move_Custom_Enable:Get())
    ui.Move_Custom_fake_options:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_Enable:Get())
    ui.Move_Custom_lby_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_Enable:Get())
    ui.Move_Custom_freestand_dsy:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_Enable:Get())
    ui.Move_Custom_dsy_on_shot:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_Enable:Get())
    ui.roll_on_move:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 1 and ui.Move_Custom_Enable:Get())
end

function tab_elements_air()
    if not Cheat.IsMenuVisible() then return end
    local tab = ui.tabs:GetInt()

    ui.Air_Custom_Enable:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2)
    ui.Air_Custom_yaw_add_L:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_Enable:Get())
    ui.Air_Custom_yaw_add_R:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_Enable:Get())
    ui.Air_Custom_yaw_modifier:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_Enable:Get())
    ui.Air_Custom_yaw_modifier_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_Enable:Get())
    ui.Air_Custom_modifier_degree_min:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_yaw_modifier:Get() > 0 and ui.Air_Custom_yaw_modifier_mode:Get() == 1 and ui.Air_Custom_Enable:Get())
    ui.Air_Custom_modifier_degree_max:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_yaw_modifier:Get() > 0 and ui.Air_Custom_yaw_modifier_mode:Get() == 1 and ui.Air_Custom_Enable:Get())
    ui.Air_Custom_modifier_degree:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_yaw_modifier:Get() > 0 and ui.Air_Custom_yaw_modifier_mode:Get() == 0 and ui.Air_Custom_Enable:Get())
    ui.Air_Custom_inverter:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_Enable:Get())
    ui.Air_Custom_limit_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_Enable:Get())
    ui.Air_Custom_limit1:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_Enable:Get())
    ui.Air_Custom_limit2:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_Enable:Get())
    ui.Air_Custom_limit3:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_limit_mode:Get() == 1 and ui.Air_Custom_Enable:Get())
    ui.Air_Custom_limit4:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_limit_mode:Get() == 1 and ui.Air_Custom_Enable:Get())
    ui.Air_Custom_fake_options:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_Enable:Get())
    ui.Air_Custom_lby_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_Enable:Get())
    ui.Air_Custom_freestand_dsy:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_Enable:Get())
    ui.Air_Custom_dsy_on_shot:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_Enable:Get())
    ui.roll_on_air:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 2 and ui.Air_Custom_Enable:Get())
end

function tab_elements_walk()
    if not Cheat.IsMenuVisible() then return end
    local tab = ui.tabs:GetInt()

    ui.Walk_Custom_Enable:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3)
    ui.Walk_Custom_yaw_add_L:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_Enable:Get())
    ui.Walk_Custom_yaw_add_R:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_Enable:Get())
    ui.Walk_Custom_yaw_modifier:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_Enable:Get())
    ui.Walk_Custom_yaw_modifier_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_Enable:Get())
    ui.Walk_Custom_modifier_degree_min:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_yaw_modifier:Get() > 0 and ui.Walk_Custom_yaw_modifier_mode:Get() == 1 and ui.Walk_Custom_Enable:Get())
    ui.Walk_Custom_modifier_degree_max:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_yaw_modifier:Get() > 0 and ui.Walk_Custom_yaw_modifier_mode:Get() == 1 and ui.Walk_Custom_Enable:Get())
    ui.Walk_Custom_modifier_degree:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_yaw_modifier:Get() > 0 and ui.Walk_Custom_yaw_modifier_mode:Get() == 0 and ui.Walk_Custom_Enable:Get())
    ui.Walk_Custom_inverter:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_Enable:Get())
    ui.Walk_Custom_limit_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_Enable:Get())
    ui.Walk_Custom_limit1:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_Enable:Get())
    ui.Walk_Custom_limit2:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_Enable:Get())
    ui.Walk_Custom_limit3:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_limit_mode:Get() == 1 and ui.Walk_Custom_Enable:Get())
    ui.Walk_Custom_limit4:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_limit_mode:Get() == 1 and ui.Walk_Custom_Enable:Get())
    ui.Walk_Custom_fake_options:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_Enable:Get())
    ui.Walk_Custom_lby_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_Enable:Get())
    ui.Walk_Custom_freestand_dsy:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_Enable:Get())
    ui.Walk_Custom_dsy_on_shot:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_Enable:Get())
    ui.roll_on_walk:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 3 and ui.Walk_Custom_Enable:Get())
end

function tab_elements_crouch()
    if not Cheat.IsMenuVisible() then return end
    local tab = ui.tabs:GetInt()

    ui.Crouch_Custom_Enable:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4)
    ui.Crouch_Custom_yaw_add_L:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_Enable:Get())
    ui.Crouch_Custom_yaw_add_R:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_Enable:Get())
    ui.Crouch_Custom_yaw_modifier:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_Enable:Get())
    ui.Crouch_Custom_yaw_modifier_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_Enable:Get())
    ui.Crouch_Custom_modifier_degree_min:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_yaw_modifier:Get() > 0 and ui.Crouch_Custom_yaw_modifier_mode:Get() == 1 and ui.Crouch_Custom_Enable:Get())
    ui.Crouch_Custom_modifier_degree_max:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_yaw_modifier:Get() > 0 and ui.Crouch_Custom_yaw_modifier_mode:Get() == 1 and ui.Crouch_Custom_Enable:Get())
    ui.Crouch_Custom_modifier_degree:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_yaw_modifier:Get() > 0 and ui.Crouch_Custom_yaw_modifier_mode:Get() == 0 and ui.Crouch_Custom_Enable:Get())
    ui.Crouch_Custom_inverter:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_Enable:Get())
    ui.Crouch_Custom_limit_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_Enable:Get())
    ui.Crouch_Custom_limit1:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_Enable:Get())
    ui.Crouch_Custom_limit2:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_Enable:Get())
    ui.Crouch_Custom_limit3:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_limit_mode:Get() == 1 and ui.Crouch_Custom_Enable:Get())
    ui.Crouch_Custom_limit4:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_limit_mode:Get() == 1 and ui.Crouch_Custom_Enable:Get())
    ui.Crouch_Custom_fake_options:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_Enable:Get())
    ui.Crouch_Custom_lby_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_Enable:Get())
    ui.Crouch_Custom_freestand_dsy:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_Enable:Get())
    ui.Crouch_Custom_dsy_on_shot:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_Enable:Get())
    ui.roll_on_crouch:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 4 and ui.Crouch_Custom_Enable:Get())
end

function tab_elements_air_crouch()
    if not Cheat.IsMenuVisible() then return end
    local tab = ui.tabs:GetInt()

    ui.FD_Custom_Enable:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5)
    ui.FD_Custom_yaw_add_L:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_Enable:Get())
    ui.FD_Custom_yaw_add_R:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_Enable:Get())
    ui.FD_Custom_yaw_modifier:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_Enable:Get())
    ui.FD_Custom_yaw_modifier_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_Enable:Get())
    ui.FD_Custom_modifier_degree_min:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_yaw_modifier:Get() > 0 and ui.FD_Custom_yaw_modifier_mode:Get() == 1 and ui.FD_Custom_Enable:Get())
    ui.FD_Custom_modifier_degree_max:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_yaw_modifier:Get() > 0 and ui.FD_Custom_yaw_modifier_mode:Get() == 1 and ui.FD_Custom_Enable:Get())
    ui.FD_Custom_modifier_degree:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_yaw_modifier:Get() > 0 and ui.FD_Custom_Enable:Get())
    ui.FD_Custom_inverter:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_Enable:Get())
    ui.FD_Custom_limit_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_Enable:Get())
    ui.FD_Custom_limit1:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_Enable:Get())
    ui.FD_Custom_limit2:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_Enable:Get())
    ui.FD_Custom_limit3:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_limit_mode:Get() == 1 and ui.FD_Custom_Enable:Get())
    ui.FD_Custom_limit4:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_limit_mode:Get() == 1 and ui.FD_Custom_Enable:Get())
    ui.FD_Custom_fake_options:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_Enable:Get())
    ui.FD_Custom_lby_mode:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_Enable:Get())
    ui.FD_Custom_freestand_dsy:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_Enable:Get())
    ui.FD_Custom_dsy_on_shot:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 5 and ui.FD_Custom_Enable:Get())

    ui.brute_aa:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6)
    ui.brute_aa_conditions:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.brute_aa:Get())
    ui.AB_miss_enable_1:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.brute_aa:Get())
    ui.AB_miss_yawL_1:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.AB_miss_enable_1:Get() and ui.brute_aa:Get())
    ui.AB_miss_yawR_1:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.AB_miss_enable_1:Get() and ui.brute_aa:Get())
    ui.AB_miss_yaw_modifier_1:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.AB_miss_enable_1:Get() and ui.brute_aa:Get())
    ui.AB_miss_modifier_1:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.AB_miss_enable_1:Get() and ui.brute_aa:Get())
    ui.AB_miss_lby_1:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.AB_miss_enable_1:Get() and ui.brute_aa:Get())

    ui.AB_miss_enable_2:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.brute_aa:Get())
    ui.AB_miss_yawL_2:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.AB_miss_enable_2:Get() and ui.brute_aa:Get())
    ui.AB_miss_yawR_2:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.AB_miss_enable_2:Get() and ui.brute_aa:Get())
    ui.AB_miss_yaw_modifier_2:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.AB_miss_enable_2:Get() and ui.brute_aa:Get())
    ui.AB_miss_modifier_2:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.AB_miss_enable_2:Get() and ui.brute_aa:Get())
    ui.AB_miss_lby_2:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.AB_miss_enable_2:Get() and ui.brute_aa:Get())

    ui.AB_miss_enable_3:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.brute_aa:Get())
    ui.AB_miss_yawL_3:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.AB_miss_enable_3:Get() and ui.brute_aa:Get())
    ui.AB_miss_yawR_3:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.AB_miss_enable_3:Get() and ui.brute_aa:Get())
    ui.AB_miss_yaw_modifier_3:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.AB_miss_enable_3:Get() and ui.brute_aa:Get())
    ui.AB_miss_modifier_3:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.AB_miss_enable_3:Get() and ui.brute_aa:Get())
    ui.AB_miss_lby_3:SetVisible(tab == 2 and ui.Custom_conditions:Get() == 6 and ui.AB_miss_enable_3:Get() and ui.brute_aa:Get())
end

local function is_crouching(player)
    if player == nil then return end
    local flags = player:GetProp("m_fFlags")
    if bit.band(flags, 4) == 4 then
        return true
    end
    return false
end

local function in_air(player)
    if player == nil then return end
    local flags = player:GetProp("m_fFlags")
    if bit.band(flags, 1) == 0 then
        return true
    end
    return false
end

ping = function()
    local netchannel_info = EngineClient.GetNetChannelInfo()
    if netchannel_info == nil then return '' end
    local latency = netchannel_info:GetLatency(0)
    return string.format("delay: %1.fms   ", math.max(0, latency) * 1000)
end

IsAlive = function(player)
    if player == nil then
        return false
    else
        if player:GetProp('m_iHealth') > 0 then
            return true
        else
            return false
        end
    end
end

WatermarkName = function(mode, custom)
    if mode == 0 then return Cheat.GetCheatUserName() .. '   '
    elseif mode == 1 then return IsAlive(EntityList.GetLocalPlayer()) == true and EntityList.GetLocalPlayer():GetName() or ' ?' .. '   '
    else
        if custom == '' then
            return ''
        else
            return custom .. '   '
        end
    end
end

RenderGradientBox = function(x,y,w,h1,h2,c,alpha,transp)
    color1 = Color.RGBA(math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255), math.floor(alpha))
    color2 = Color.RGBA(math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255), math.floor(c.b*0))
    if ui.old_or_new:Get() == 0 then
        Render.BoxFilled(Vector2.new(x, y), Vector2.new(x + w, y + h1), Color.RGBA(17, 17, 17, math.floor(0)), 4)
        Render.Blur(Vector2.new(x, y), Vector2.new(x + w, y + h1))
        Render.Circle(Vector2.new(x + 3 , y + 5), 4, 32, color1, 2, 270, 180)
        Render.GradientBoxFilled(Vector2.new(x - 2 , y + 5), Vector2.new(x, y + h1 -2 ), color1, color1, color2, color2)
        Render.Circle(Vector2.new(x + w - 3, y + 5), 4, 32, color1, 2, 0, -90)
        Render.GradientBoxFilled(Vector2.new(x + w, y + 5), Vector2.new(x + w + 2, y + h1 - 2), color1, color1, color2, color2)
        Render.BoxFilled(Vector2.new(x + 3, y), Vector2.new(x + w - 3, y + h2), Color.RGBA(math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255), math.floor(alpha)))
    else
        Render.BoxFilled(Vector2.new(x, y), Vector2.new(x + w, y + h1), Color.RGBA(17, 17, 17, math.floor(90)), 4)
        Render.Circle(Vector2.new(x + 3 , y + 4), 4, 32, color1, 2, 250, 180)
        Render.GradientBoxFilled(Vector2.new(x - 2 , y + 3), Vector2.new(x - 0.5, y + h1 -1 ), color1, color1, Color.RGBA(math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255),math.floor(alpha*0.3)), Color.RGBA(math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255),math.floor(alpha*0.3)))
        Render.Circle(Vector2.new(x + w -3.5, y + 4), 4, 32, color1, 2, 5, -70)
        Render.GradientBoxFilled(Vector2.new(x + w, y + 3), Vector2.new(x + w + 1.5, y + h1 - 1), color1, color1, Color.RGBA(math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255),math.floor(alpha*0.3)), Color.RGBA(math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255),math.floor(alpha*0.3)))
        Render.BoxFilled(Vector2.new(x + 2, y), Vector2.new(x + w -2, y + h2 - 1), Color.RGBA(math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255), math.floor(alpha)))
        Render.BoxFilled(Vector2.new(x+2,y+h1+1.5),Vector2.new(x+w-3,y+h1),Color.RGBA(math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255),math.floor(alpha*0.3)))
        Render.Circle(Vector2.new(x + 3 , y + 15), 4, 32, Color.RGBA(math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255),math.floor(alpha*0.3)), 2, -250, -180)
        Render.Circle(Vector2.new(x + w - 4, y + 15.5), 4, 32, Color.RGBA(math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255),math.floor(alpha*0.3)), 2, -5, 70)
    end
end

Render_Text = function(x, y, cent, text, color, font, size, alpha)
    Render.Text(text,Vector2.new(x + 1, y + 1), Color.RGBA(0, 0, 0, alpha), size, font, false, cent)
    Render.Text(text,Vector2.new(x, y), color, size, font, false, cent)
end

function Render_TextOutline(text, pos, clr, size, font)
    clr_2 = Color.new(0,0,0,clr.a*0.5)
    Render.Text(text, pos + Vector2:new(1,1), clr_2, size, font)
    Render.Text(text, pos + Vector2:new(1,-1), clr_2, size, font)
    Render.Text(text, pos + Vector2:new(1,0), clr_2, size, font)
    Render.Text(text, pos + Vector2:new(-1,1), clr_2, size, font)
    Render.Text(text, pos + Vector2:new(-1,-1), clr_2, size, font)
    Render.Text(text, pos + Vector2:new(-1,0), clr_2, size, font)
    Render.Text(text, pos + Vector2:new(0,1), clr_2, size, font)
    Render.Text(text, pos + Vector2:new(0,-1), clr_2, size, font)
    Render.Text(text, pos, clr, size, font)
end

function C_BaseEntity:m_iHealth()
    return self:GetProp("DT_BasePlayer", "m_iHealth")
end

function normalize_yaw(yaw)
    while yaw > 180 do yaw = yaw - 360 end
    while yaw < -180 do yaw = yaw + 360 end
    return yaw
end

local function world2scren(xdelta, ydelta)
    if xdelta == 0 and ydelta == 0 then
        return 0
    end
    return math.deg(math.atan2(ydelta, xdelta))
end

--rage

function rage()
    local me = EntityList.GetLocalPlayer()
    if me == nil then return end
    local lp = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
    if lp == nil then return end
    local localp = EntityList.GetLocalPlayer()
    local active_weapon = localp:GetPlayer():GetActiveWeapon()
    if active_weapon == nil then return end
    local weapon_id = active_weapon:GetWeaponID()
    local players = EntityList.GetPlayers()
    local player = EntityList.GetLocalPlayer()
    local scoped = player:GetProp("m_bIsScoped")   
    if ui.customdthit:Get() then
        for _, player in ipairs(players) do
            if not player:IsTeamMate() then
                local user_index = player:EntIndex()
                if weapon_id == 40 then
                    RageBot.OverrideHitchance(user_index, ui.customdthitair:Get())
                end
                if weapon_id == 11 or weapon_id == 38 and not scoped then
                    RageBot.OverrideHitchance(user_index, ui.customdthitnoscope:Get())
                end
            end
        end
    end
    if ui.customdt:Get() then
        Exploits.OverrideDoubleTapSpeed(ui.customdtspeed:Get())
    end
    if ui.idealtick:Get() then
        if ui.idealbind:Get() then
            auto_peek:Set(true)
            DT:Set(true)
            if Exploits.GetCharge() > 0 then
                Render.Text("+/-CHARGED", Vector2.new(x -50, y - 25), Color.new(ui.idealbind:GetColor().r, ui.idealbind:GetColor().g, ui.idealbind:GetColor().b, 255), 10, font.pixel, true)
                Render.Text("IDEAL", Vector2.new(x, y - 25), Color.new(ui.idealbind:GetColor().r, ui.idealbind:GetColor().g, ui.idealbind:GetColor().b, 255), 10, font.pixel, true)
                Render.Text("TICK", Vector2.new(x +25, y - 25), Color.new(ui.idealbind:GetColor().r, ui.idealbind:GetColor().g, ui.idealbind:GetColor().b, 255), 10, font.pixel, true)
            end
        else
            auto_peek:Set(false)
            DT:Set(false)
        end
    end
end

--ANTI-AIM
local switcher = true
local globalData = 0
local yawval = 0
anti_hit.system = function(cmd)
    local me = EntityList.GetLocalPlayer()
    if me == nil then return end
    local lp = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
    if lp == nil then return end
    local localp = EntityList.GetLocalPlayer()
    local localplayer = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
    local velocity = math.floor(Vector.new(localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[0]"), localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[1]"), localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[2]") ):Length());
    render_angles = localplayer:GetRenderAngles()
    yawval = render_angles.yaw
    local sv_maxusrcmdprocessticks = CVar.FindVar("sv_maxusrcmdprocessticks")
    if not (DT:Get()) then
        if ui.enableFakeExtension:Get() then
            if ui.fake_m:Get(1) and velocity < 5 then
                switcher = cmd.tick_count % 2 == 0 and true or false
                if switcher then
                    sv_maxusrcmdprocessticks:SetInt(17)
                else
                    sv_maxusrcmdprocessticks:SetInt(18)
                end
                if ClientState.m_choked_commands < 17 then
                    FakeLag.SetState(false)
                end
                if ClientState.m_choked_commands >= 16 and ClientState.m_choked_commands < 17 then
                    cmd.viewangles.yaw = render_angles.yaw + (ui.invertFake:GetBool() and -117 or 117)
                end
            end
            if ui.fake_m:Get(2) and velocity > 5 and not in_air(localp) then
                switcher = cmd.tick_count % 2 == 0 and true or false
                if switcher then
                    sv_maxusrcmdprocessticks:SetInt(17)
                else
                    sv_maxusrcmdprocessticks:SetInt(18)
                end
                if ClientState.m_choked_commands < 17 then
                    FakeLag.SetState(false)
                end
                if ClientState.m_choked_commands >= 16 and ClientState.m_choked_commands < 17 then
                    cmd.viewangles.yaw = render_angles.yaw + (ui.invertFake:GetBool() and -117 or 117)
                end
            end
            if ui.fake_m:Get(3) and velocity > 5 and in_air(localp) then
                switcher = cmd.tick_count % 2 == 0 and true or false
                if switcher then
                    sv_maxusrcmdprocessticks:SetInt(17)
                else
                    sv_maxusrcmdprocessticks:SetInt(18)
                end
                if ClientState.m_choked_commands < 17 then
                    FakeLag.SetState(false)
                end
                if ClientState.m_choked_commands >= 16 and ClientState.m_choked_commands < 17 then
                    cmd.viewangles.yaw = render_angles.yaw + (ui.invertFake:GetBool() and -117 or 117)
                end
            end
            if ui.fake_m:Get(4) and walk:Get() and not in_air(localp) then
                switcher = cmd.tick_count % 2 == 0 and true or false
                if switcher then
                    sv_maxusrcmdprocessticks:SetInt(17)
                else
                    sv_maxusrcmdprocessticks:SetInt(18)
                end
                if ClientState.m_choked_commands < 17 then
                    FakeLag.SetState(false)
                end
                if ClientState.m_choked_commands >= 16 and ClientState.m_choked_commands < 17 then
                    cmd.viewangles.yaw = render_angles.yaw + (ui.invertFake:GetBool() and -117 or 117)
                end
            end
        end
    end
    globalData = cmd.viewangles.yaw
end

--антибрут
local misscount = 0
local aim_nextshots = 0
local aim_shots_reset = false

function test()
    local tickcount = GlobalVars.tickcount
    if misscount > 0 then
        if tickcount % 400 == 1 then
            misscount = 0
        end
    end
end

local missprint = 0
function brute_aa_e(event)
    local localplayer = EntityList.GetLocalPlayer()
    local velocity = math.floor(Vector.new(localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[0]"), localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[1]"), localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[2]") ):Length());
    local localp = EntityList.GetLocalPlayer()
    if ui.brute_aa:Get() then
        local localplayer = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
        if not localplayer then return end

        local me = EntityList.GetClientEntity(EngineClient.GetLocalPlayer()):GetPlayer()
        if not me then return end

        if EngineClient.IsConnected() and me:IsAlive() then
            if event:GetName() ~= "bullet_impact" then return end

            local me = EntityList.GetLocalPlayer()
            local attacker = EntityList.GetPlayerForUserID(event:GetInt("userid"))

            if attacker == me or attacker:IsTeamMate() then
                return
            end

            local my_position = me:GetHitboxCenter(0)
            local b_vector = Vector.new(event:GetInt("x"), event:GetInt("y"), event:GetInt("z"))

            local my_origin = me:GetRenderOrigin()
            local attacker_o = attacker:GetRenderOrigin()

            local check_wall = Cheat.FireBullet(attacker, b_vector, my_position)
            if check_wall.damage < 5 then return end

            local p_head_and_origin = {my_position.x - attacker_o.x, my_position.y - attacker_o.y}
            local p_bullet_and_origin = {b_vector.x - attacker_o.x, b_vector.y - attacker_o.y}

            local decrease_bullet_points = p_bullet_and_origin[1] ^ 2 + p_bullet_and_origin[2] ^ 2
            local create_dot_points = (
                p_head_and_origin[1] * p_bullet_and_origin[1] +
                p_head_and_origin[2] * p_bullet_and_origin[2]
            )

            local dots = create_dot_points / decrease_bullet_points
            local distance = {
                attacker_o.x + p_bullet_and_origin[1] * dots,
                attacker_o.y + p_bullet_and_origin[2] * dots
            }

            local my_value = {my_position.x - distance[1], my_position.y - distance[2]}
            local my_world = math.abs(math.sqrt(my_value[1] ^ 2 + my_value[2] ^ 2))

            local distance_to_trigger = my_origin:DistTo(attacker_o) / 4
            if my_world <= distance_to_trigger then
                if ui.brute_aa_conditions:Get(1) and velocity < 5 then
                    misscount = misscount + 1
                end
                if ui.brute_aa_conditions:Get(2) and velocity > 5 and not in_air(localp) then
                    misscount = misscount + 1
                end
                if ui.brute_aa_conditions:Get(3) and in_air(localp) then
                    misscount = misscount + 1
                end
                if ui.brute_aa_conditions:Get(4) and is_crouching(localp) and not in_air(localp) then
                    misscount = misscount + 1
                end
                if ui.brute_aa_conditions:Get(5) and walk:Get() then
                    misscount = misscount + 1
                end
                missprint = missprint + 1
                print("[".. missprint .."]".."[Chernobyl.lua]switch to next stage due to miss")
            end
        end
    end
end

-------------------------------------------AA---------------------------------------------
function Stay()
    local player = EntityList.GetLocalPlayer()
    if player == nil then return end
    local health = player:GetProp("m_iHealth")
    local body_yaw = AntiAim.GetInverterState()
    if not EngineClient.GetLocalPlayer() then
        return
    end
    local localplayer = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
    if localplayer == nil then return end
    local velocity = math.floor(Vector.new(localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[0]"), localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[1]"), localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[2]") ):Length());
    local localp = EntityList.GetLocalPlayer()
    if localp == nil then return end
    local tickcount = GlobalVars.tickcount
    if ui.enableFakeExtension:Get() then
        yaw_add:Set(0)
        yaw_modifier:Set(0)
        fake_opt:Set(0)
        dsyL:Set(60)
        dsyR:Set(60)
    end
    if ui.Stay_Custom_Enable:Get() and not (ui.FD_Custom_Enable:Get() and FD:Get() or ui.enableFakeExtension:Get()) then
        if velocity < 5 then
            if body_yaw then
                if ui.AB_miss_enable_1:Get() and misscount_stay == 1 then
                    yaw_add:Set(ui.AB_miss_yawR_1:Get())
                elseif ui.AB_miss_enable_2:Get() and misscount_stay == 2 then
                    yaw_add:Set(ui.AB_miss_yawR_2:Get())
                elseif ui.AB_miss_enable_3:Get() and misscount_stay == 3 then
                    yaw_add:Set(ui.AB_miss_yawR_3:Get())
                else
                    yaw_add:Set(ui.Stay_Custom_yaw_add_R:Get())
                end
            else
                if ui.AB_miss_enable_1:Get() and misscount_stay == 1 then
                    yaw_add:Set(ui.AB_miss_yawL_1:Get())
                elseif ui.AB_miss_enable_2:Get() and misscount_stay == 2 then
                    yaw_add:Set(ui.AB_miss_yawL_2:Get())
                elseif ui.AB_miss_enable_3:Get() and misscount_stay == 3 then
                    yaw_add:Set(ui.AB_miss_yawL_3:Get())
                else
                    yaw_add:Set(ui.Stay_Custom_yaw_add_L:Get())
                end
            end
            if ui.AB_miss_enable_1:Get() and misscount_stay == 1 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount_stay == 2 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount_stay == 3 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_3:Get())
            else
                yaw_modifier:Set(ui.Stay_Custom_yaw_modifier:Get())
            end
            if ui.AB_miss_enable_1:Get() and misscount_stay == 1 then
                modifier_degree:Set(ui.AB_miss_modifier_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount_stay == 2 then
                modifier_degree:Set(ui.AB_miss_modifier_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount_stay == 3 then
                modifier_degree:Set(ui.AB_miss_modifier_3:Get())
            else
                if ui.Stay_Custom_yaw_modifier_mode:Get() == 0 then
                    modifier_degree:Set(ui.Stay_Custom_modifier_degree:Get())
                else
                    modifier_degree:Set(math.random(ui.Stay_Custom_modifier_degree_min:Get(), ui.Stay_Custom_modifier_degree_max:Get()))
                end
            end
            inverter:Set(ui.Stay_Custom_inverter:Get())
            if ui.Stay_Custom_limit_mode:Get() == 0 then
                dsyL:Set(ui.Stay_Custom_limit1:Get())
                dsyR:Set(ui.Stay_Custom_limit2:Get())
            else
                dsyL:Set(math.random(ui.Stay_Custom_limit1:Get(), ui.Stay_Custom_limit3:Get()))
                dsyR:Set(math.random(ui.Stay_Custom_limit2:Get(), ui.Stay_Custom_limit4:Get()))
            end
            fake_opt:Set(ui.Stay_Custom_fake_options:Get())
            if ui.AB_miss_enable_1:Get() and misscount_stay == 1 then
                lby_mode:Set(ui.AB_miss_lby_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount_stay == 2 then
                lby_mode:Set(ui.AB_miss_lby_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount_stay == 3 then
                lby_mode:Set(ui.AB_miss_lby_3:Get())
            else
                lby_mode:Set(ui.Stay_Custom_lby_mode:Get())
            end
            freestand_dsy:Set(ui.Stay_Custom_freestand_dsy:Get())
            dsy_on_shot:Set(ui.Stay_Custom_dsy_on_shot:Get())
            if ui.manuals:Get() > 0 then
                yaw_modifier:Set(4)
                modifier_degree:Set(-6)
                fake_opt:Set(0)
                lby_mode:Set(1)
                yaw_add:Set(0)
            end
        end
    end
end

--кастом аа когда идешь и летишь
function Move_and_Air()
    local player = EntityList.GetLocalPlayer()
    if player == nil then return end
    local health = player:GetProp("m_iHealth")
    local body_yaw = AntiAim.GetInverterState()
    if not EngineClient.GetLocalPlayer() then
        return
    end
    local localplayer = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
    if not localplayer then
        return
    end
    local velocity = math.floor(Vector.new(localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[0]"), localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[1]"), localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[2]") ):Length());
    local localp = EntityList.GetLocalPlayer()
    local tickcount = GlobalVars.tickcount
    if ui.Move_Custom_Enable:Get() and not (ui.FD_Custom_Enable:Get() and FD:Get() or ui.enableFakeExtension:Get()) then
        if velocity > 5 then
            if body_yaw then
                if ui.AB_miss_enable_1:Get() and misscount_move == 1 then
                    yaw_add:Set(ui.AB_miss_yawR_1:Get())
                elseif ui.AB_miss_enable_2:Get() and misscount_move == 2 then
                    yaw_add:Set(ui.AB_miss_yawR_2:Get())
                elseif ui.AB_miss_enable_3:Get() and misscount_move == 3 then
                    yaw_add:Set(ui.AB_miss_yawR_3:Get())
                else
                    yaw_add:Set(ui.Move_Custom_yaw_add_R:Get())
                end
            else
                if ui.AB_miss_enable_1:Get() and misscount_move == 1 then
                    yaw_add:Set(ui.AB_miss_yawL_1:Get())
                elseif ui.AB_miss_enable_2:Get() and misscount_move == 2 then
                    yaw_add:Set(ui.AB_miss_yawL_2:Get())
                elseif ui.AB_miss_enable_3:Get() and misscount_move == 3 then
                    yaw_add:Set(ui.AB_miss_yawL_3:Get())
                else
                    yaw_add:Set(ui.Move_Custom_yaw_add_L:Get())
                end
            end
            if ui.AB_miss_enable_1:Get() and misscount_move == 1 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount_move == 2 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount_move == 3 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_3:Get())
            else
                yaw_modifier:Set(ui.Move_Custom_yaw_modifier:Get())
            end
            if ui.AB_miss_enable_1:Get() and misscount_move == 1 then
                modifier_degree:Set(ui.AB_miss_modifier_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount_move == 2 then
                modifier_degree:Set(ui.AB_miss_modifier_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount_move == 3 then
                modifier_degree:Set(ui.AB_miss_modifier_3:Get())
            else
                if ui.Move_Custom_yaw_modifier_mode:Get() == 0 then
                    modifier_degree:Set(ui.Move_Custom_modifier_degree:Get())
                else
                    modifier_degree:Set(math.random(ui.Move_Custom_modifier_degree_min:Get(), ui.Move_Custom_modifier_degree_max:Get()))
                end
            end
            inverter:Set(ui.Move_Custom_inverter:Get())
            if ui.Move_Custom_limit_mode:Get() == 0 then
                dsyL:Set(ui.Move_Custom_limit1:Get())
                dsyR:Set(ui.Move_Custom_limit2:Get())
            else
                dsyL:Set(math.random(ui.Move_Custom_limit1:Get(), ui.Move_Custom_limit3:Get()))
                dsyR:Set(math.random(ui.Move_Custom_limit2:Get(), ui.Move_Custom_limit4:Get()))
            end
            fake_opt:Set(ui.Move_Custom_fake_options:Get())
            if ui.AB_miss_enable_1:Get() and misscount_move == 1 then
                lby_mode:Set(ui.AB_miss_lby_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount_move == 2 then
                lby_mode:Set(ui.AB_miss_lby_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount_move == 3 then
                lby_mode:Set(ui.AB_miss_lby_3:Get())
            else
                lby_mode:Set(ui.Move_Custom_lby_mode:Get())
            end
            freestand_dsy:Set(ui.Move_Custom_freestand_dsy:Get())
            dsy_on_shot:Set(ui.Move_Custom_dsy_on_shot:Get())
            if ui.manuals:Get() > 0 then
                yaw_modifier:Set(4)
                modifier_degree:Set(-6)
                fake_opt:Set(0)
                lby_mode:Set(1)
            end
        end
    end
    if ui.Air_Custom_Enable:Get() then
        if in_air(localp) or Cheat.IsKeyDown(0x20) and not (ui.FD_Custom_Enable:Get() and FD:Get() or ui.enableFakeExtension:Get()) then
            if body_yaw then
                if ui.AB_miss_enable_1:Get() and misscount_air == 1 then
                    yaw_add:Set(ui.AB_miss_yawR_1:Get())
                elseif ui.AB_miss_enable_2:Get() and misscount_air == 2 then
                    yaw_add:Set(ui.AB_miss_yawR_2:Get())
                elseif ui.AB_miss_enable_3:Get() and misscount_air == 3 then
                    yaw_add:Set(ui.AB_miss_yawR_3:Get())
                else
                    yaw_add:Set(ui.Air_Custom_yaw_add_R:Get())
                end
            else
                if ui.AB_miss_enable_1:Get() and misscount_air == 1 then
                    yaw_add:Set(ui.AB_miss_yawL_1:Get())
                elseif ui.AB_miss_enable_2:Get() and misscount_air == 2 then
                    yaw_add:Set(ui.AB_miss_yawL_2:Get())
                elseif ui.AB_miss_enable_3:Get() and misscount_air == 3 then
                    yaw_add:Set(ui.AB_miss_yawL_3:Get())
                else
                    yaw_add:Set(ui.Air_Custom_yaw_add_L:Get())
                end
            end
            if ui.AB_miss_enable_1:Get() and misscount_air == 1 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount_air == 2 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount_air == 3 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_3:Get())
            else
                yaw_modifier:Set(ui.Air_Custom_yaw_modifier:Get())
            end
            if ui.AB_miss_enable_1:Get() and misscount_air == 1 then
                modifier_degree:Set(ui.AB_miss_modifier_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount_air == 2 then
                modifier_degree:Set(ui.AB_miss_modifier_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount_air == 3 then
                modifier_degree:Set(ui.AB_miss_modifier_3:Get())
            else
                if ui.Air_Custom_yaw_modifier_mode:Get() == 0 then
                    modifier_degree:Set(ui.Air_Custom_modifier_degree:Get())
                else
                    modifier_degree:Set(math.random(ui.Air_Custom_modifier_degree_min:Get(), ui.Air_Custom_modifier_degree_max:Get()))
                end
            end
            inverter:Set(ui.Air_Custom_inverter:Get())
            if ui.Air_Custom_limit_mode:Get() == 0 then
                dsyL:Set(ui.Air_Custom_limit1:Get())
                dsyR:Set(ui.Air_Custom_limit2:Get())
            else
                dsyL:Set(math.random(ui.Air_Custom_limit1:Get(), ui.Air_Custom_limit3:Get()))
                dsyR:Set(math.random(ui.Air_Custom_limit2:Get(), ui.Air_Custom_limit4:Get()))
            end
            fake_opt:Set(ui.Air_Custom_fake_options:Get())
            if ui.AB_miss_enable_1:Get() and misscount_air == 1 then
                lby_mode:Set(ui.AB_miss_lby_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount_air == 2 then
                lby_mode:Set(ui.AB_miss_lby_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount_air == 3 then
                lby_mode:Set(ui.AB_miss_lby_3:Get())
            else
                lby_mode:Set(ui.Air_Custom_lby_mode:Get())
            end
            freestand_dsy:Set(ui.Air_Custom_freestand_dsy:Get())
            dsy_on_shot:Set(ui.Air_Custom_dsy_on_shot:Get())
        end
    end
end

-- кастом аа когда на шифте
function Walk()
    local player = EntityList.GetLocalPlayer()
    if player == nil then return end
    local health = player:GetProp("m_iHealth")
    local body_yaw = AntiAim.GetInverterState()
    if not EngineClient.GetLocalPlayer() then
        return
    end
    local localplayer = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
    if not localplayer then
        return
    end
    local velocity = math.floor(Vector.new(localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[0]"), localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[1]"), localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[2]") ):Length());
    local localp = EntityList.GetLocalPlayer()
    local tickcount = GlobalVars.tickcount
    if ui.Walk_Custom_Enable:Get() and not ui.enableFakeExtension:Get() then
        if walk:Get() then
            if body_yaw then
                if ui.AB_miss_enable_1:Get() and misscount_walk == 1 then
                    yaw_add:Set(ui.AB_miss_yawR_1:Get())
                elseif ui.AB_miss_enable_2:Get() and misscount_walk == 2 then
                    yaw_add:Set(ui.AB_miss_yawR_2:Get())
                elseif ui.AB_miss_enable_3:Get() and misscount_walk == 3 then
                    yaw_add:Set(ui.AB_miss_yawR_3:Get())
                else
                    yaw_add:Set(ui.Walk_Custom_yaw_add_R:Get())
                end
            else
                if ui.AB_miss_enable_1:Get() and misscount_walk == 1 then
                    yaw_add:Set(ui.AB_miss_yawL_1:Get())
                elseif ui.AB_miss_enable_2:Get() and misscount_walk == 2 then
                    yaw_add:Set(ui.AB_miss_yawL_2:Get())
                elseif ui.AB_miss_enable_3:Get() and misscount_walk == 3 then
                    yaw_add:Set(ui.AB_miss_yawL_3:Get())
                else
                    yaw_add:Set(ui.Walk_Custom_yaw_add_L:Get())
                end
            end
            if ui.AB_miss_enable_1:Get() and misscount_walk == 1 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount_walk == 2 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount_walk == 3 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_3:Get())
            else
                yaw_modifier:Set(ui.Walk_Custom_yaw_modifier:Get())
            end
            if ui.AB_miss_enable_1:Get() and misscount_walk == 1 then
                modifier_degree:Set(ui.AB_miss_modifier_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount_walk == 2 then
                modifier_degree:Set(ui.AB_miss_modifier_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount_walk == 3 then
                modifier_degree:Set(ui.AB_miss_modifier_3:Get())
            else
                if ui.Walk_Custom_yaw_modifier_mode:Get() == 0 then
                    modifier_degree:Set(ui.Walk_Custom_modifier_degree:Get())
                else
                    modifier_degree:Set(math.random(ui.Walk_Custom_modifier_degree_min:Get(), ui.Walk_Custom_modifier_degree_max:Get()))
                end
            end
            inverter:Set(ui.Walk_Custom_inverter:Get())
            if ui.Walk_Custom_limit_mode:Get() == 0 then
                dsyL:Set(ui.Walk_Custom_limit1:Get())
                dsyR:Set(ui.Walk_Custom_limit2:Get())
            else
                dsyL:Set(math.random(ui.Walk_Custom_limit1:Get(), ui.Walk_Custom_limit3:Get()))
                dsyR:Set(math.random(ui.Walk_Custom_limit2:Get(), ui.Walk_Custom_limit4:Get()))
            end
            fake_opt:Set(ui.Walk_Custom_fake_options:Get())
            if ui.AB_miss_enable_1:Get() and misscount_walk == 1 then
                lby_mode:Set(ui.AB_miss_lby_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount_walk == 2 then
                lby_mode:Set(ui.AB_miss_lby_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount_walk == 3 then
                lby_mode:Set(ui.AB_miss_lby_3:Get())
            else
                lby_mode:Set(ui.Walk_Custom_lby_mode:Get())
            end
            freestand_dsy:Set(ui.Walk_Custom_freestand_dsy:Get())
            dsy_on_shot:Set(ui.Walk_Custom_dsy_on_shot:Get())
            if ui.manuals:Get() > 0 then
                yaw_modifier:Set(4)
                modifier_degree:Set(-6)
                fake_opt:Set(0)
                lby_mode:Set(1)
                yaw_add:Set(0)
            end
        end
    end
    if ui.Crouch_Custom_Enable:Get() and not (ui.FD_Custom_Enable:Get() and FD:Get()) then
        if is_crouching(localp) and not (in_air(localp) or ui.enableFakeExtension:Get()) then
            if body_yaw then
                if ui.AB_miss_enable_1:Get() and misscount_cr == 1 then
                    yaw_add:Set(ui.AB_miss_yawR_1:Get())
                elseif ui.AB_miss_enable_2:Get() and misscount_cr == 2 then
                    yaw_add:Set(ui.AB_miss_yawR_2:Get())
                elseif ui.AB_miss_enable_3:Get() and misscount_cr == 3 then
                    yaw_add:Set(ui.AB_miss_yawR_3:Get())
                else
                    yaw_add:Set(ui.Crouch_Custom_yaw_add_R:Get())
                end
            else
                if ui.AB_miss_enable_1:Get() and misscount_cr == 1 then
                    yaw_add:Set(ui.AB_miss_yawL_1:Get())
                elseif ui.AB_miss_enable_2:Get() and misscount_cr == 2 then
                    yaw_add:Set(ui.AB_miss_yawL_2:Get())
                elseif ui.AB_miss_enable_3:Get() and misscount_cr == 3 then
                    yaw_add:Set(ui.AB_miss_yawL_3:Get())
                else
                    yaw_add:Set(ui.Crouch_Custom_yaw_add_L:Get())
                end
            end
            if ui.AB_miss_enable_1:Get() and misscount_cr == 1 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount_cr == 2 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount_cr == 3 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_3:Get())
            else
                yaw_modifier:Set(ui.Crouch_Custom_yaw_modifier:Get())
            end
            if ui.AB_miss_enable_1:Get() and misscount_cr == 1 then
                modifier_degree:Set(ui.AB_miss_modifier_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount_cr == 2 then
                modifier_degree:Set(ui.AB_miss_modifier_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount_cr == 3 then
                modifier_degree:Set(ui.AB_miss_modifier_3:Get())
            else
                if ui.Crouch_Custom_yaw_modifier_mode:Get() == 0 then
                    modifier_degree:Set(ui.Crouch_Custom_modifier_degree:Get())
                else
                    modifier_degree:Set(math.random(ui.Crouch_Custom_modifier_degree_min:Get(), ui.Crouch_Custom_modifier_degree_max:Get()))
                end
            end
            inverter:Set(ui.Crouch_Custom_inverter:Get())
            if ui.Crouch_Custom_limit_mode:Get() == 0 then
                dsyL:Set(ui.Crouch_Custom_limit1:Get())
                dsyR:Set(ui.Crouch_Custom_limit2:Get())
            else
                dsyL:Set(math.random(ui.Crouch_Custom_limit1:Get(), ui.Crouch_Custom_limit3:Get()))
                dsyR:Set(math.random(ui.Crouch_Custom_limit2:Get(), ui.Crouch_Custom_limit4:Get()))
            end
            fake_opt:Set(ui.Crouch_Custom_fake_options:Get())
            if ui.AB_miss_enable_1:Get() and misscount_cr == 1 then
                lby_mode:Set(ui.AB_miss_lby_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount_cr == 2 then
                lby_mode:Set(ui.AB_miss_lby_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount_cr == 3 then
                lby_mode:Set(ui.AB_miss_lby_3:Get())
            else
                lby_mode:Set(ui.Crouch_Custom_lby_mode:Get())
            end
            freestand_dsy:Set(ui.Crouch_Custom_freestand_dsy:Get())
            dsy_on_shot:Set(ui.Crouch_Custom_dsy_on_shot:Get())
            if ui.manuals:Get() > 0 then
                yaw_modifier:Set(0)
                fake_opt:Set(0)
                lby_mode:Set(1)
                yaw_add:Set(0)
            end
        end
    end
end

function Crouch_in_air()
    local player = EntityList.GetLocalPlayer()
    if player == nil then return end
    local health = player:GetProp("m_iHealth")
    local body_yaw = AntiAim.GetInverterState()
    if not EngineClient.GetLocalPlayer() then
        return
    end
    local localplayer = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
    if not localplayer then
        return
    end
    local velocity = math.floor(Vector.new(localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[0]"), localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[1]"), localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[2]") ):Length());
    local localp = EntityList.GetLocalPlayer()
    local tickcount = GlobalVars.tickcount
    if ui.FD_Custom_Enable:Get() then
        if ui.FD_Custom_Enable:Get() and FD:Get() and not ui.enableFakeExtension:Get() then
            if body_yaw then
                if ui.AB_miss_enable_1:Get() and misscount == 1 then
                    yaw_add:Set(ui.AB_miss_yawR_1:Get())
                elseif ui.AB_miss_enable_2:Get() and misscount == 2 then
                    yaw_add:Set(ui.AB_miss_yawR_2:Get())
                elseif ui.AB_miss_enable_3:Get() and misscount == 3 then
                    yaw_add:Set(ui.AB_miss_yawR_3:Get())
                else
                    yaw_add:Set(ui.FD_Custom_yaw_add_R:Get())
                end
            else
                if ui.AB_miss_enable_1:Get() and misscount == 1 then
                    yaw_add:Set(ui.AB_miss_yawL_1:Get())
                elseif ui.AB_miss_enable_2:Get() and misscount == 2 then
                    yaw_add:Set(ui.AB_miss_yawL_2:Get())
                elseif ui.AB_miss_enable_3:Get() and misscount == 3 then
                    yaw_add:Set(ui.AB_miss_yawL_3:Get())
                else
                    yaw_add:Set(ui.FD_Custom_yaw_add_L:Get())
                end
            end
            if ui.AB_miss_enable_1:Get() and misscount == 1 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount == 2 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount == 3 then
                yaw_modifier:Set(ui.AB_miss_yaw_modifier_3:Get())
            else
                yaw_modifier:Set(ui.FD_Custom_yaw_modifier:Get())
            end
            if ui.AB_miss_enable_1:Get() and misscount == 1 then
                modifier_degree:Set(ui.AB_miss_modifier_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount == 2 then
                modifier_degree:Set(ui.AB_miss_modifier_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount == 3 then
                modifier_degree:Set(ui.AB_miss_modifier_3:Get())
            else
                if ui.FD_Custom_yaw_modifier_mode:Get() == 0 then
                    modifier_degree:Set(ui.FD_Custom_modifier_degree:Get())
                else
                    modifier_degree:Set(math.random(ui.FD_Custom_modifier_degree_min:Get(), ui.FD_Custom_modifier_degree_max:Get()))
                end
            end
            inverter:Set(ui.FD_Custom_inverter:Get())
            if ui.FD_Custom_limit_mode:Get() == 0 then
                dsyL:Set(ui.FD_Custom_limit1:Get())
                dsyR:Set(ui.FD_Custom_limit2:Get())
            else
                dsyL:Set(math.random(ui.FD_Custom_limit1:Get(), ui.FD_Custom_limit3:Get()))
                dsyR:Set(math.random(ui.FD_Custom_limit2:Get(), ui.FD_Custom_limit4:Get()))
            end
            fake_opt:Set(ui.FD_Custom_fake_options:Get())
            if ui.AB_miss_enable_1:Get() and misscount == 1 then
                lby_mode:Set(ui.AB_miss_lby_1:Get())
            elseif ui.AB_miss_enable_2:Get() and misscount == 2 then
                lby_mode:Set(ui.AB_miss_lby_2:Get())
            elseif ui.AB_miss_enable_3:Get() and misscount == 3 then
                lby_mode:Set(ui.AB_miss_lby_3:Get())
            else
                lby_mode:Set(ui.FD_Custom_lby_mode:Get())
            end
            freestand_dsy:Set(ui.FD_Custom_freestand_dsy:Get())
            dsy_on_shot:Set(ui.FD_Custom_dsy_on_shot:Get())
            if ui.manuals:Get() > 0 then
                yaw_modifier:Set(0)
                fake_opt:Set(0)
                lby_mode:Set(1)
                yaw_add:Set(0)
            end
        end
    end
end

--INDICATORS

function get_target()
    local me = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
    if me == nil then
        return nil
    end
    local lpos = me:GetRenderOrigin()
    local viewangles = EngineClient.GetViewAngles()
    local players = EntityList.GetPlayers()
    if players == nil or #players == 0 then
        return nil
    end
    local data = {}
    fov = 180
    for i = 1, #players do
        if players[i] == nil or players[i]:IsTeamMate() or players[i] == me or players[i]:IsDormant() or players[i]:m_iHealth() <= 0 then goto skip end
        local epos = players[i]:GetProp("m_vecOrigin")
        local cur_fov = math.abs(normalize_yaw(world2scren(lpos.x - epos.x, lpos.y - epos.y) - viewangles.yaw + 180))
        if cur_fov <= fov then
            data = {
                id = players[i],
                fov = cur_fov
            }
            fov = cur_fov
        end
            ::skip::
    end
    return data
end

function indicators()
    local body_yaw = AntiAim.GetInverterState()
    local size_i, cn, modifier = 10, 20, 8
    local alpha = math.min(math.floor(math.sin((GlobalVars.realtime % 3) * 4) * 125 + 200), 255)
    local desync = math.min(math.abs(AntiAim.GetCurrentRealRotation() - AntiAim.GetFakeRotation()), AntiAim.GetMaxDesyncDelta())
    local me = EntityList.GetLocalPlayer()
    if me == nil then return end
    local lp = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
    if lp == nil then return end
    local screen_size = EngineClient.GetScreenSize()
    local red_to_green = Color.RGBA(150 - math.floor(desync / 1.41), 50 + math.floor(desync / 0.565), 41, 255)
    local velocity = math.floor(Vector.new(lp:GetProp("DT_BasePlayer", "m_vecVelocity[0]"), lp:GetProp("DT_BasePlayer", "m_vecVelocity[1]"), lp:GetProp("DT_BasePlayer", "m_vecVelocity[2]") ):Length());
    local localp = EntityList.GetLocalPlayer()
    local dmg_get_value = Menu.FindVar("Aimbot", "Ragebot", "Accuracy", "Minimum Damage")
    local base = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Base"):GetInt("base")
    local arr_inactive  = ui.inactive:GetColor()
    local arr_active = ui.active:GetColor()
    local tsv  = Render.CalcTextSize("v", 20)
    local tsl  = Render.CalcTextSize("<", 20)
    local tsr  = Render.CalcTextSize(">", 20)
    local real_yaw = AntiAim.GetCurrentRealRotation()
    local fake_yaw = AntiAim.GetFakeRotation()
    local body_yaw = AntiAim.GetInverterState()
    local body_yaw = real_yaw - fake_yaw
    local desync_norm = math.min(math.abs(body_yaw), AntiAim.GetMaxDesyncDelta())
    local lydi = EntityList.GetPlayers()
    local active_weapon = localp:GetPlayer():GetActiveWeapon()
    if active_weapon == nil then return end
    local weapon_id = active_weapon:GetWeaponID()
    local tickcount = GlobalVars.tickcount

    local me = lp:GetPlayer()
    local scoped = me:GetProp("m_bIsScoped")

    if ui.air_teleport:Get() and in_air(localp) and not HS:Get() then
        for i = 1, #lydi do
            local origin = localp:GetPlayer():GetRenderOrigin()
            local origin_players = lydi[i]:GetRenderOrigin()
            local is_visible = lydi[i]:IsVisible(origin_players)
            if lydi[i]:IsAlive() and not lydi[i]:IsTeamMate() and lydi[i]:IsAlive() and not lydi[i]:IsDormant() and is_visible and not active_weapon:IsKnife() then
                Exploits.ForceTeleport()
            end
        end
    end

    if EngineClient.IsConnected() and EngineClient.IsInGame() and lp:GetProp("m_iHealth") > 0 and lp:GetPlayer() ~= nil then
        local add_y = 0
        if ui.selected_ind:Get() == 1 then
            Render.Text("chernobyl", Vector2.new(x + 1, y + 15), Color.new(1,1,1,1), size_i, font.pixel, true)
            Render.Text("staBLE", Vector2.new(x + 46, y + 15), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, alpha / 255), size_i, font.pixel, true)
            Render.Text("FAKE", Vector2.new(x + 1, y + 25), Color.new(149/255,180/255,252/255,1), size_i, font.pixel, true)
            Render.Text("YAW:", Vector2.new(x + 23, y + 25), Color.new(149/255,180/255,252/255,1), size_i, font.pixel, true)
            Render.Text("STATE:", Vector2.new(x + 1, y + 35), Color.new(255/255,156/255,142/255,200), size_i, font.pixel, true)
            Render.Text("Custom", Vector2.new(x + 28, y + 35), Color.new(255/255,156/255,142/255,200), size_i, font.pixel, true)
            Render.Text(body_yaw == false and "R" or "L", Vector2.new(x + 42, y + 25), Color.new(1,1,1,1), size_i, font.pixel, true)
            if AutoPeek:Get() then
                add_y = 10
                Render.Text("AUTO", Vector2.new(x + 1, y + 45), Color.RGBA(0, 173, 117, 200), size_i, font.pixel, true)
                Render.Text("PEEK", Vector2.new(x + 20, y + 45), Color.RGBA(0, 173, 117, 200), size_i, font.pixel, true)
            end
            if DT:GetBool() then
                if Exploits.GetCharge() > 0 then
                    Render.Text("DT", Vector2.new(x + 1, y + 45+add_y), Color.RGBA(71, 232, 35, 255), size_i, font.pixel, true)
                else
                    Render.Text("DT", Vector2.new(x + 1, y + 45+add_y), Color.RGBA(255, 67, 50, 255), size_i, font.pixel, true)
                end
            end
            if HS:GetBool() then
                Render.Text("HS", Vector2.new(x + 1, y + 45+add_y), Color.RGBA(244, 232, 35, 255), size_i, font.pixel, true)
            end
        end
        if ui.selected_ind:Get() == 2 then
            if scoped and ui.selected_ind_v:Get() then
                Render.Text("chernobyl.lua", Vector2.new(x + 1, y + 24), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                if FD:Get() then
                    Render.Text("*FAKE DUCK*", Vector2.new(x + 1, y + 34), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                else
                    if is_crouching(me) then
                        Render.Text("*crouching*", Vector2.new(x + 1, y + 34), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                    else
                        if in_air(me) or Cheat.IsKeyDown(0x20) then
                            Render.Text("*aerobic*", Vector2.new(x + 1, y + 34), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                        else
                            if velocity > 5 then
                                Render.Text("*running*", Vector2.new(x + 1, y + 34), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                            else
                                Render.Text("*dynamic*", Vector2.new(x + 1, y + 34), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                            end
                        end
                    end
                end
            else
                Render.Text("chernobyl.lua", Vector2.new(x -30, y + 24), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                if FD:Get() then
                    Render.Text("*FAKE DUCK*", Vector2.new(x -25, y + 34), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                else
                    if is_crouching(me) then
                        Render.Text("*crouching*", Vector2.new(x -25, y + 34), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                    else
                        if in_air(me) or Cheat.IsKeyDown(0x20) then
                            Render.Text("*aerobic*", Vector2.new(x -20, y + 34), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                        else
                            if velocity > 5 then
                                Render.Text("*running*", Vector2.new(x -20, y + 34), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                            else
                                Render.Text("*dynamic*", Vector2.new(x -20, y + 34), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                            end
                        end
                    end
                end
            end
            if scoped and ui.selected_ind_v:Get() then
                if DT:Get() then
                    if Exploits.GetCharge() > 0 then
                        Render.Text("DT", Vector2.new(x + 1, y + 44), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                    else
                        Render.Text("DT", Vector2.new(x + 1, y + 44), Color.RGBA(255, 67, 50, 255), 10, font.pixel, true)
                    end
                else
                    Render.Text("DT", Vector2.new(x + 1, y + 44), Color.RGBA(90, 90, 90, 100), 10, font.pixel, true)
                end
                if HS:Get() then
                    Render.Text("HS", Vector2.new(x + 12, y + 44), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                else
                    Render.Text("HS", Vector2.new(x + 12, y + 44), Color.RGBA(90, 90, 90, 100), 10, font.pixel, true)
                end
                if BA:Get() == 2 then
                    Render.Text("BA", Vector2.new(x + 25, y + 44), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                else
                    Render.Text("BA", Vector2.new(x + 25, y + 44), Color.RGBA(90, 90, 90, 100), 10, font.pixel, true)
                end
            else
                if DT:Get() then
                    if Exploits.GetCharge() > 0 then
                        Render.Text("DT", Vector2.new(x - 16, y + 44), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                    else
                        Render.Text("DT", Vector2.new(x - 16, y + 44), Color.RGBA(255, 67, 50, 255), 10, font.pixel, true)
                    end
                else
                    Render.Text("DT", Vector2.new(x -16, y + 44), Color.RGBA(90, 90, 90, 100), 10, font.pixel, true)
                end
                if HS:Get() then
                    Render.Text("HS", Vector2.new(x -5, y + 44), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                else
                    Render.Text("HS", Vector2.new(x -5, y + 44), Color.RGBA(90, 90, 90, 100), 10, font.pixel, true)
                end
                if BA:Get() == 2 then
                    Render.Text("BA", Vector2.new(x + 7, y + 44), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                else
                    Render.Text("BA", Vector2.new(x + 7, y + 44), Color.RGBA(90, 90, 90, 100), 10, font.pixel, true)
                end
            end
        end
        if ui.selected_ind:Get() == 3 then
            if body_yaw == true then
                Render.Text("chern", Vector2.new(x - 27, y + 12), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 11, font.verdanabold, false)
                Render.Text("obyl°", Vector2.new(x + 3, y + 12), Color.RGBA(255, 255, 255, 255), 11, font.verdanabold, false)
            else
                Render.Text("chern", Vector2.new(x - 27, y + 12), Color.RGBA(255, 255, 255, 255), 11, font.verdanabold, false)
                Render.Text("obyl°", Vector2.new(x + 3, y + 12), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 11, font.verdanabold, false)
            end

            if FD:Get() then
                Render.Text("dynamic", Vector2.new(x -15, y + 26), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
            else
                if is_crouching(me) then
                    Render.Text("tank", Vector2.new(x -8, y + 26), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                else
                    if in_air(me) or Cheat.IsKeyDown(0x20) then
                        Render.Text("aerobic", Vector2.new(x -15, y + 26), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                    else
                        Render.Text("dynamic", Vector2.new(x -15, y + 26), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                    end
                end
            end
            if DT:GetBool() then
                Render.Text("DOUBLE", Vector2.new(x -20, y + 36), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                Render.Text("TAP", Vector2.new(x + 12, y + 36), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
            else
                Render.Text("DOUBLE", Vector2.new(x -20, y + 36), Color.RGBA(120, 120, 120, 180), 10, font.pixel, true)
                Render.Text("TAP", Vector2.new(x + 12, y + 36), Color.RGBA(120, 120, 120, 180), 10, font.pixel, true)
            end
            if HS:GetBool() then
                Render.Text("HIDE", Vector2.new(x -20, y + 46), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                Render.Text("SHOTS", Vector2.new(x + 1, y + 46), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
            else
                Render.Text("HIDE", Vector2.new(x -20, y + 46), Color.RGBA(120, 120, 120, 180), 10, font.pixel, true)
                Render.Text("SHOTS", Vector2.new(x + 1, y + 46), Color.RGBA(120, 120, 120, 180), 10, font.pixel, true)
            end
            if FD:GetBool() then
                Render.Text("Duck", Vector2.new(x -8, y + 56), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
            else
                Render.Text("Duck", Vector2.new(x -8, y + 56), Color.RGBA(120, 120, 120, 180), 10, font.pixel, true)
            end
        end
        if ui.selected_ind:GetInt() == 4 then
            local label2 = ""
            if FD:GetBool() then
                label2 = "DUCK"
            else
                if is_crouching(me) then
                    label2 = "TANK"
                else
                    if in_air(me) or Cheat.IsKeyDown(0x20) then
                        label2 = "AIR"
                    else
                        if velocity > 5 then
                            label2 = "MOVING"
                        else
                            label2 = "STAND"
                        end
                    end
                end
            end
            Render.Text("Chernobyl", Vector2.new(x + 2, y + 20), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 1), size_i, font.pixel, true);
            Render_TextOutline(label2, Vector2.new(x + 2, y + 28), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, ui.selected_ind:GetColor().a*0.85), size_i, font.pixel, true)
            Render_TextOutline(math.floor(tostring(desync_norm*1.7)) .. "%", Vector2.new(x + 2, y + 36), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, ui.selected_ind:GetColor().a*0.65), size_i, font.pixel, true)
        end
        if ui.selected_ind:Get() == 5 then
            if scoped and ui.selected_ind_v:Get() then
                Render.Text("Chernobyl", Vector2.new(x + 1, y + 12), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                if FD:GetBool() then
                    Render.Text("Duck", Vector2.new(x + 1, y + 21), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                else
                    if is_crouching(me) then
                        Render.Text("crouching", Vector2.new(x + 1, y + 21), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                    else
                        if in_air(me) or Cheat.IsKeyDown(0x20) then
                            Render.Text("air", Vector2.new(x + 1, y + 21), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                        else
                            if velocity > 5 then
                                Render.Text("moving", Vector2.new(x + 1, y + 21), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                            else
                                Render.Text("stand", Vector2.new(x + 1, y + 21), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                            end
                        end
                    end
                end
                if DT:Get() then
                    if Exploits.GetCharge() > 0 then
                        Render.Text("DT", Vector2.new(x + 1, y + 30), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                    else
                        Render.Text("DT", Vector2.new(x + 1, y + 30), Color.RGBA(255, 67, 50, 255), 10, font.pixel, true)
                    end
                else
                    Render.Text("DT", Vector2.new(x + 1, y + 30), Color.RGBA(90, 90, 90, 255), 10, font.pixel, true)
                end
                if HS:Get() then
                    Render.Text("HS", Vector2.new(x + 12, y + 30), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                else
                    Render.Text("HS", Vector2.new(x + 12, y + 30), Color.RGBA(90, 90, 90, 255), 10, font.pixel, true)
                end
                if BA:Get() == 2 then
                    Render.Text("BA", Vector2.new(x + 25, y + 30), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                else
                    Render.Text("BA", Vector2.new(x + 25, y + 30), Color.RGBA(90, 90, 90, 255), 10, font.pixel, true)
                end
            else
                Render.Text("Chernobyl", Vector2.new(x -20, y + 12), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                if FD:GetBool() then
                    Render.Text("Duck", Vector2.new(x -14, y + 21), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                else
                    if is_crouching(me) then
                        Render.Text("crouching", Vector2.new(x -21, y + 21), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                    else
                        if in_air(me) or Cheat.IsKeyDown(0x20) then
                            Render.Text("air", Vector2.new(x -7, y + 21), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                        else
                            if velocity > 5 then
                                Render.Text("moving", Vector2.new(x -14, y + 21), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                            else
                                Render.Text("stand", Vector2.new(x -11, y + 21), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                            end
                        end
                    end
                end
                if DT:Get() then
                    if Exploits.GetCharge() > 0 then
                        Render.Text("DT", Vector2.new(x -16, y + 30), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                    else
                        Render.Text("DT", Vector2.new(x -16, y + 30), Color.RGBA(255, 67, 50, 255), 10, font.pixel, true)
                    end
                else
                    Render.Text("DT", Vector2.new(x -16, y + 30), Color.RGBA(90, 90, 90, 255), 10, font.pixel, true)
                end
                if HS:Get() then
                    Render.Text("HS", Vector2.new(x -5, y + 30), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                else
                    Render.Text("HS", Vector2.new(x -5, y + 30), Color.RGBA(90, 90, 90, 255), 10, font.pixel, true)
                end
                if BA:Get() == 2 then
                    Render.Text("BA", Vector2.new(x + 7, y + 30), Color.new(ui.selected_ind:GetColor().r, ui.selected_ind:GetColor().g, ui.selected_ind:GetColor().b, 255), 10, font.pixel, true)
                else
                    Render.Text("BA", Vector2.new(x + 7, y + 30), Color.RGBA(90, 90, 90, 255), 10, font.pixel, true)
                end
            end
        end
        local color = ui.selected_ind:GetColor()
        local text_a = Render.CalcTextSize("chernobyl", 12)
        if ui.selected_ind:Get() == 6 then
            Render.Text("chernobyl", Vector2.new(x - text_a.x/2 - 3, y + 20), color, 12, font.verdanabold2, false)
            Render.BoxFilled(Vector2.new(x - 33, y + 33), Vector2.new(x + 33, y + 34.5), Color.new(color.r, color.g, color.b, 1.0))
            Render.GradientBoxFilled(Vector2.new(x - 33.5, y + 25), Vector2.new(x - 32, y + 34), Color.new(color.r, color.g, color.b, 0), Color.new(color.r, color.g, color.b, 0), Color.new(color.r, color.g, color.b, 1), Color.new(color.r, color.g, color.b, 1))
            Render.GradientBoxFilled(Vector2.new(x + 33.5, y + 25), Vector2.new(x + 32, y + 34), Color.new(color.r, color.g, color.b, 0), Color.new(color.r, color.g, color.b, 0), Color.new(color.r, color.g, color.b, 1), Color.new(color.r, color.g, color.b, 1))
            local add_y = 0
            if DT:GetBool() then
                if Exploits.GetCharge() > 0 then
                    Render.Text("Double-Tap", Vector2.new(x - 23, y + 37), Color.new(color.r, color.g, color.b, 1), size_i, font.pixel, true)
                else
                    Render.Text("Double-Tap", Vector2.new(x - 23, y + 37), Color.RGBA(255, 67, 50, 255), size_i, font.pixel, true)
                end
                add_y = 9
            end
            if HS:GetBool() then
                Render.Text("hide-shots", Vector2.new(x - 22.5, y + 37+add_y), Color.new(color.r, color.g, color.b, 1), size_i, font.pixel, true)
            end
        end
    end
end

--ARROWS

function arrows()
    local me = EntityList.GetLocalPlayer()
    if me == nil then return end
    local lp = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
    if lp == nil then return end
    local base = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Base")
    local arr_inactive  = ui.inactive:GetColor()
    local arr_active = ui.active:GetColor()
    local tsv  = Render.CalcTextSize("v", 20)
    local tsl  = Render.CalcTextSize("<", 20)
    local tsr  = Render.CalcTextSize(">", 20)
    local desync = math.min(math.abs(AntiAim.GetCurrentRealRotation() - AntiAim.GetFakeRotation()), AntiAim.GetMaxDesyncDelta())
    local real_yaw = AntiAim.GetCurrentRealRotation()
    local fake_yaw = AntiAim.GetFakeRotation()
    local body_yawW = real_yaw - fake_yaw
    if EngineClient.IsConnected() and EngineClient.IsInGame() and lp:GetProp("m_iHealth") > 0 and lp:GetPlayer() ~= nil then
        if ui.selected_arr:GetInt() == 1 then
            Render.Text("h", Vector2.new(x-tsr.x/2 + 47, y-9), Color.new(0,0,0,arr_inactive.a / 2), 24, font.acta_arrows)
            Render.Text("g", Vector2.new(x-tsl.x/2 - 55, y-9), Color.new(0,0,0,arr_inactive.a / 2), 24, font.acta_arrows)
            
            Render.Text("h", Vector2.new(x-tsr.x/2 + 48, y-10), arr_inactive, 24, font.acta_arrows)
            Render.Text("g", Vector2.new(x-tsl.x/2 - 56, y-10), arr_inactive, 24, font.acta_arrows)
            if base == 2 then
                Render.Text("h", Vector2.new(x-tsr.x/2 + 48, y-10), arr_active, 24, font.acta_arrows)
            end
            if base == 3 then
                Render.Text("g", Vector2.new(x-tsl.x/2 - 56, y-10), arr_active, 24, font.acta_arrows)
            end             
        end         
        if ui.selected_arr:GetInt() == 2 then
            Render.Text("x", Vector2.new(x-tsr.x/2 + 55, y-5), Color.new(0,0,0,arr_inactive.a / 2), 16, font.acta_arrows2)
            Render.Text("w", Vector2.new(x-tsl.x/2 - 55, y-5), Color.new(0,0,0,arr_inactive.a / 2), 16, font.acta_arrows2)
            
            Render.Text("x", Vector2.new(x-tsr.x/2 + 56, y-6), arr_inactive, 16, font.acta_arrows2)
            Render.Text("w", Vector2.new(x-tsl.x/2 - 56, y-6), arr_inactive, 16, font.acta_arrows2)
            if base == 2 then
                Render.Text("x", Vector2.new(x-tsr.x/2 + 56, y-6), arr_active, 16, font.acta_arrows2)
            end
            if base == 3 then
                Render.Text("w", Vector2.new(x-tsl.x/2 - 56, y-6), arr_active, 16, font.acta_arrows2)
            end
        end
        if ui.selected_arr:GetInt() == 3 then
            Render.Text("Z", Vector2.new(x-tsr.x/2 + 55, y-5), Color.new(0,0,0,arr_inactive.a / 2), 16, font.acta_arrows2)
            Render.Text("X", Vector2.new(x-tsl.x/2 - 60, y-5), Color.new(0,0,0,arr_inactive.a / 2), 16, font.acta_arrows2)
            
            Render.Text("Z", Vector2.new(x-tsr.x/2 + 56, y-6), arr_inactive, 16, font.acta_arrows2)
            Render.Text("X", Vector2.new(x-tsl.x/2 - 60, y-6), arr_inactive, 16, font.acta_arrows2)
            if base == 2 then
                Render.Text("Z", Vector2.new(x-tsr.x/2 + 56, y-6), arr_active, 16, font.acta_arrows2)
            end
            if base == 3 then
                Render.Text("X", Vector2.new(x-tsl.x/2 - 60, y-6), arr_active, 16, font.acta_arrows2)
            end
        end
        if ui.selected_arr:GetInt() == 4 then
            local gray = Color.RGBA(25,25,25,150)

            Render.PolyFilled(
            gray,
            Vector2.new(x - 62, y),
            Vector2.new(x - 45, y - 9),
            Vector2.new(x - 45, y + 9))                     
            
            Render.PolyFilled(
            gray,
            Vector2.new(x + 45, y + 9),
            Vector2.new(x + 45, y - 9),
            Vector2.new(x + 62, y))
            
            if base == 2 then --right
                Render.PolyFilled(
                man_active,
                Vector2.new(x + 45, y + 9),
                Vector2.new(x + 45, y - 9),
                Vector2.new(x + 62, y))
            end
            
            if base == 3 then --left
                Render.PolyFilled(
                man_active,
                Vector2.new(x - 62, y),
                Vector2.new(x - 45, y - 9),
                Vector2.new(x - 45, y + 9))         
            end

            Render.BoxFilled(Vector2.new(x + 41, y - 9), Vector2.new(x + 43, y + 9), gray)
            Render.BoxFilled(Vector2.new(x - 43, y - 9), Vector2.new(x - 41, y + 9), gray) 
            
            if body_yawW < 0 then
                Render.BoxFilled(Vector2.new(x + 41, y - 9), Vector2.new(x + 43, y + desync / 6.6666666666), arr_active)
            else
                Render.BoxFilled(Vector2.new(x - 43, y - 9), Vector2.new(x - 41, y + desync / 6.6666666666), arr_active)
            end
        end
    end
end

--VISUALS

function all_visuals()
    local me = EntityList.GetLocalPlayer()
    if me == nil then return end
    local lp = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
    if lp == nil then return end
    if EngineClient.IsConnected() and EngineClient.IsInGame() and lp:GetProp("m_iHealth") > 0 and lp:GetPlayer() ~= nil then
        local weap = me:GetActiveWeapon()
        local accuracy = 0.0;
        if weap ~= nil then
            accuracy = weap:GetInaccuracy(weap) * 550.0;
            if ui.spread_circle:GetBool() then
                Render.CircleFilled(Vector2.new(EngineClient.GetScreenSize().x / 2, EngineClient.GetScreenSize().y / 2), accuracy, 60, ui.spread_circle:GetColor())
            end
        else
            accuracy = 0.0
        end
    end
end

local function get_phrase()
    local phrases = {
        "здесь могла быть ваша реклама",
        "ебать ты взорвался хахах",
        "нихуя тебе переебало конечно",
        "пиздуй в подвал",
        "пипец ты умер как ракообразный",
        "Я твоей матери напихал тараканов в жопу",
        "че попасть не можешь да",
        "долбаеб ты дозиметр с собой взял?",
        "законтрен еблан, by chernobyl.lua",
        "по немногу вытаскиваю атомы из твоей пустой черепной коробки",
        "Нихуя ты как скитюзер выдвинулся",
        "Ну тут даже колпик бы убил",
        "9l npocTo 3acTpeJll-o Te69l e6y4um kapa6uHom",
        "до уровня chernobyl.lua тебе далеко конечно",
        "даже доллар ахуел от твоих попрыгушек",
        "Не волнуйся, у тебя обязательно получится меня убить в следующем раунде.",
        "ахахах я такой плейстайл с начала 19 не видел",
        "скриптик подбустил оп оп",
        "ебало на орбиту улетело хахах",
        "ложись спатки, завтра рано вставать",
        "иди на огород картошку копай долбаеб ",
        "chernobyl.lua забустил лошпендос",
        "ебать ты немощный, тебя тут даже chernobyl.lua не забустит",
    }
    return phrases[Utils.RandomInt(1, #phrases)]:gsub('\"', '')
end

function tt(event)
    if ui.TrashTalk:Get() then
        if event:GetName() ~= "player_death" then return end

        local me = EntityList.GetLocalPlayer()
        local victim = EntityList.GetPlayerForUserID(event:GetInt("userid"))
        local attacker = EntityList.GetPlayerForUserID(event:GetInt("attacker"))

        if victim == attacker or attacker ~= me then return end

        EngineClient.ExecuteClientCmd('say "' .. get_phrase() .. '"')
    end
end

local bulletImpactData = { }
local hitmarkerQueue = { }

function vectordistance(x1,y1,z1,x2,y2,z2)
    return math.sqrt(math.pow(x1 - x2, 2) + math.pow( y1 - y2, 2) + math.pow( z1 - z2 , 2) )
end

function reset_pos()
    for i in ipairs(bulletImpactData) do
        bulletImpactData[i] = { 0 , 0 , 0 , 0 }
    end

    for i in ipairs(hitmarkerQueue) do
        hitmarkerQueue[i] = { 0 , 0 , 0 , 0, 0}
    end
end

function on_bullet_impact(e)
    if EntityList.GetPlayerForUserID(e:GetInt("userid", 0)) == EntityList.GetLocalPlayer() then
        local impactX = e:GetInt("x", 0)
        local impactY = e:GetInt("y", 0)
        local impactZ = e:GetInt("z", 0)
        table.insert(bulletImpactData, { impactX, impactY, impactZ, GlobalVars.realtime })
    end
end

function on_player_hurt(e)
    local bestX, bestY, bestZ = 0, 0, 0
    local bestdistance = 100
    local realtime = GlobalVars.realtime
    --check if i shot at the player
    if EntityList.GetPlayerForUserID(e:GetInt("attacker", 0)) == EntityList.GetLocalPlayer() then
        local victim = EntityList.GetPlayerForUserID(e:GetInt("userid", 0))
        if victim ~= nil then
            local victimOrigin = victim:GetProp("m_vecOrigin")
            local victimDamage = e:GetInt("dmg_health", 0)

            for i in ipairs(bulletImpactData) do
                if bulletImpactData[i][4] + (4) >= realtime then
                    local impactX = bulletImpactData[i][1]
                    local impactY = bulletImpactData[i][2]
                    local impactZ = bulletImpactData[i][3]

                    local distance = vectordistance(victimOrigin.x, victimOrigin.y, victimOrigin.z, impactX, impactY, impactZ)
                    if distance < bestdistance then
                        bestdistance = distance
                        bestX = impactX
                        bestY = impactY
                        bestZ = impactZ
                    end
                end
            end

            if bestX == 0 and bestY == 0 and bestZ == 0 then
                victimOrigin.z = victimOrigin.z + 50
                bestX = victimOrigin.x
                bestY = victimOrigin.y
                bestZ = victimOrigin.z
            end

            for k in ipairs(bulletImpactData) do
                bulletImpactData[k] = { 0 , 0 , 0 , 0 }
            end
            table.insert(hitmarkerQueue, {bestX, bestY, bestZ, realtime, victimDamage} )
        end
    end
end

function on_player_spawned(e)
    if EntityList.GetPlayerForUserID(e:GetInt("userid", 0)) == EntityList.GetLocalPlayer() then
        reset_pos()
    end
end

function betterhitmarker_event(event)
    if event:GetName() == "player_hurt" then
        on_player_hurt(event)
    elseif event:GetName() == "bullet_impact" then
        on_bullet_impact(event)
    elseif event:GetName() == "player_spawned" then
        on_player_spawned(event)
    end
end

local font_new = Render.InitFont("Tahoma", 10)

function hitmarker_draw()
    local HIT_MARKER_DURATION = 4
    local realtime = GlobalVars.realtime
    local maxTimeDelta = HIT_MARKER_DURATION / 2
    local maxtime = realtime - maxTimeDelta / 2
    for i in ipairs(hitmarkerQueue) do
        if hitmarkerQueue[i][4] + HIT_MARKER_DURATION > maxtime then
            if hitmarkerQueue[i][1] ~= nil then
                local add = 0
                if ui.CustomHitmarker_show_dmg:Get() then
                    add = (hitmarkerQueue[i][4] - realtime) * 100
                end
                local w2c = Render.WorldToScreen(Vector.new((hitmarkerQueue[i][1]), (hitmarkerQueue[i][2]), (hitmarkerQueue[i][3])))
                local w2c2 = Render.WorldToScreen(Vector.new((hitmarkerQueue[i][1]), (hitmarkerQueue[i][2]), (hitmarkerQueue[i][3]) - add))
                if w2c.x ~= nil and w2c.y ~= nil then
                    local alpha = 255     
                    if (hitmarkerQueue[i][4] - (realtime - HIT_MARKER_DURATION)) < (HIT_MARKER_DURATION / 2) then                         
                        alpha = math.floor((hitmarkerQueue[i][4] - (realtime - HIT_MARKER_DURATION)) / (HIT_MARKER_DURATION / 2) * 255)
                        if alpha < 5 then
                            hitmarkerQueue[i] = { 0 , 0 , 0 , 0, 0 }
                        end             
                    end
                    local HIT_MARKER_SIZE = 4
                    local col = ui.CustomHitmarker_color:GetColor()
                    if ui.CustomHitmarker_show_dmg:Get() then
                        Render.Text(tostring(hitmarkerQueue[i][5]), Vector2.new(w2c2.x, w2c2.y), ui.CustomHitmarker_color_dmg:GetColor(), 10, font_new)
                    end
                    if ui.CustomHitmarker_mode:Get() == 0 then
                        Render.Line(Vector2.new(w2c.x, w2c.y - HIT_MARKER_SIZE), Vector2.new(w2c.x, w2c.y), Color.new(col.r, col.g, col.b, alpha/255))
                        Render.Line(Vector2.new(w2c.x - HIT_MARKER_SIZE, w2c.y), Vector2.new(w2c.x, w2c.y), Color.new(col.r, col.g, col.b, alpha/255))
                        Render.Line(Vector2.new(w2c.x, w2c.y + HIT_MARKER_SIZE), Vector2.new(w2c.x, w2c.y), Color.new(col.r, col.g, col.b, alpha/255))
                        Render.Line(Vector2.new(w2c.x + HIT_MARKER_SIZE, w2c.y), Vector2.new(w2c.x, w2c.y), Color.new(col.r, col.g, col.b, alpha/255))
                    else
                        Render.Line(Vector2.new(w2c.x, w2c.y ), Vector2.new(w2c.x - ( HIT_MARKER_SIZE ), w2c.y - ( HIT_MARKER_SIZE )), Color.new(col.r, col.g, col.b, alpha/255))
                        Render.Line(Vector2.new(w2c.x, w2c.y ), Vector2.new(w2c.x - ( HIT_MARKER_SIZE ), w2c.y + ( HIT_MARKER_SIZE )), Color.new(col.r, col.g, col.b, alpha/255))
                        Render.Line(Vector2.new(w2c.x, w2c.y ), Vector2.new(w2c.x + ( HIT_MARKER_SIZE ), w2c.y + ( HIT_MARKER_SIZE )), Color.new(col.r, col.g, col.b, alpha/255))
                        Render.Line(Vector2.new(w2c.x, w2c.y ), Vector2.new(w2c.x + ( HIT_MARKER_SIZE ), w2c.y - ( HIT_MARKER_SIZE )), Color.new(col.r, col.g, col.b, alpha/255))
                    end
                end
            end
        end
    end
end

local font_size = 11
local verdana = Render.InitFont('Verdana', font_size, {'r'})

local  bind_type = {
    [0] = 'toggled',
    [1] = 'holding',
}

local random_ms = 0
local kona = {
    k = {
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    },
    o = 66,
    water = 0.0,
    global = 0.0,
    xxx = 0.0,
}
local IsDragging = 0
local memory = Vector2.new(0, 0)
local x, y  = 150, 500
local IsDragging_spec = 0
local memory_spec = Vector2.new(0, 0)
local x_spec, y_spec  = 1450, 500
local function spec()
    if (ui.el:Get(3) == true) then
        local spectators = {}
        local players = EntityList.GetPlayers()
        if not players then return end
        local me = EntityList.GetLocalPlayer()
        local frames = 8 * GlobalVars.frametime
        local xx = 75 + 66
        local text = 'spectators'
        for _, player in pairs(players) do
            if not player:IsDormant() and player:GetProp("m_iHealth") < 1 then
                local target = EntityList.GetPlayerFromHandle(player:GetProp("m_hObserverTarget"))

                if target == me then
                    spectators[#spectators + 1] = { name = player:GetName() }
                end
            end
        end
        for i = 0, #spectators do
            if #spectators > 0 or Cheat.IsMenuVisible() == true then
                kona.xxx = kona.xxx + frames
                if kona.xxx > 1 then kona.xxx = 1 end
            elseif #spectators < 1 or Cheat.IsMenuVisible() == false then
                kona.xxx = kona.xxx - frames
                if kona.xxx < 0 then kona.xxx = 0 end
            end
            if spectators[i] ~= nil then
                Render_Text(x_spec + 5, y_spec + 7 + 15 * i, false, spectators[i].name, Color.RGBA(255,255,255,255), verdana, font_size, 120)
            end
        end
        if Cheat.GetMousePos().x >= x_spec and Cheat.GetMousePos().x <= x_spec + xx and Cheat.GetMousePos().y >= y_spec and Cheat.GetMousePos().y <= y_spec + 20 then
            if Cheat.IsKeyDown(1) and IsDragging_spec == 0 and Cheat.GetMousePos().x < x_spec + xx and Cheat.GetMousePos().y < y_spec + 20 then
                IsDragging_spec = 1;
                memory_spec.x = x_spec - Cheat.GetMousePos().x
                memory_spec.y = y_spec - Cheat.GetMousePos().y
            end
        end
        if not Cheat.IsKeyDown(1) then
            IsDragging_spec = 0
        end
        if IsDragging_spec == 1 and Cheat.IsMenuVisible() then
            x_spec = (Cheat.GetMousePos().x + memory_spec.x)
            y_spec = (Cheat.GetMousePos().y + memory_spec.y)
        end
        if #spectators > 0 or Cheat.IsMenuVisible() == true then
            RenderGradientBox(x_spec, y_spec, xx, 18, 2, ui.color:Get(), math.floor(kona.xxx*255), kona.xxx*0)
        end
        Render_Text(x_spec - Render.CalcTextSize(text, font_size, verdana).x / 2 + xx / 2, y_spec + 4, false, text, Color.RGBA(255, 255, 255, math.floor(kona.xxx*255)), verdana, font_size, math.floor(kona.xxx*120))
    end
end

local function paint()
    local local_time = ffi.new("SYSTEMTIME")
    ffi.C.GetLocalTime(local_time)
    system_time = string.format("%02d:%02d:%02d", local_time.wHour, local_time.wMinute, local_time.wSecond)
    if (ui.el:Get(1) == true) then
        if GlobalVars.tickcount % 8 == 0 then
            random_ms = math.random(1,5)
        end
        local engine = EngineClient.GetScreenSize()
        text_WM = 'chern          ' .. '' .. WatermarkName(ui.name:Get(),ui.name_custom:Get()) .. '' .. ping() .. '' .. system_time
        local h_WM, w_WM = 18, Render.CalcTextSize(text_WM, font_size, verdana).x + 8
        local x_WM, y_WM = engine.x, 10 + (25*0)
        x_WM = x_WM - w_WM - 10
        RenderGradientBox(x_WM, y_WM, w_WM, h_WM, 2, ui.color:Get(), 255, 0)
        Render_Text(x_WM + 4, y_WM + 4, false, text_WM, Color.RGBA(255, 255, 255, 255), verdana, font_size, 120)
        Render_Text(x_WM + 4 + Render.CalcTextSize('chern', font_size, verdana).x + 1, y_WM + 4, false, "obyl" , ui.color:Get(), verdana, font_size, 120)
    end
    local frames = 8 * GlobalVars.frametime
    local max_offset = 66
    local text = 'keybinds'
    local hOffset = 23
    local w, h = 75 + max_offset, 50
    if (ui.el:Get(2) == true) then
        local binds = Cheat.GetBinds()
        for i = 0, #binds do
            if #binds > 0 or Cheat.IsMenuVisible() == true then
                kona.global = kona.global + frames
                if kona.global > 1 then kona.global = 1 end
            elseif #binds < 1 or Cheat.IsMenuVisible() == false then
                kona.global = kona.global - frames
                if kona.global < 0 then kona.global = 0 end
            end
        end
        for f = 1, #binds do
            local key_type = '[' .. bind_type[binds[f]:GetMode()] .. ']'
            if binds[f]:IsActive() == true and kona.global > 0 then
                kona.k[f] = kona.k[f] + frames
                if kona.k[f] > 1 then kona.k[f] = 1 end
            elseif binds[f]:IsActive() == false or kona.global == 0 then
                kona.k[f] = kona.k[f] - frames
                if kona.k[f] < 0 then kona.k[f] = 0 end
            end                   
            local bind_width = Render.CalcTextSize(binds[f]:GetName(),font_size,verdana).x
            if bind_width > 0 then
                if bind_width > 75 then
                    max_offset = bind_width
                end
            end
            Render_Text(x + 5, y + hOffset, false, binds[f]:GetName(), Color.RGBA(255, 255, 255, math.floor(kona.k[f]*255)), verdana, font_size, math.floor(kona.k[f]*120))
            Render_Text(x + (75 + kona.o) - Render.CalcTextSize(key_type, font_size, verdana).x - 5, y + hOffset, false, key_type, Color.RGBA(255, 255, 255, math.floor(kona.k[f]*255)), verdana, font_size, math.floor(kona.k[f]*120))
            hOffset = hOffset + 15
        end
        if kona.o ~= max_offset then
            if kona.o > max_offset then kona.o = kona.o - 1.2 end
            if kona.o < max_offset then kona.o = kona.o + 1.2 end
        end
        local to = math.max(66,kona.o)
        if Cheat.GetMousePos().x >= x and Cheat.GetMousePos().x <= x + 75 + to and Cheat.GetMousePos().y >= y and Cheat.GetMousePos().y <= y + 20 then
            if Cheat.IsKeyDown(1) and IsDragging == 0 and Cheat.GetMousePos().x < x + 75 + to and Cheat.GetMousePos().y < y + 20 then
                IsDragging = 1;
                memory.x = x - Cheat.GetMousePos().x
                memory.y = y - Cheat.GetMousePos().y
            end
        end
        if not Cheat.IsKeyDown(1) then
            IsDragging = 0
        end
        if IsDragging == 1 and Cheat.IsMenuVisible() then
            x = (Cheat.GetMousePos().x + memory.x)
            y = (Cheat.GetMousePos().y + memory.y)
        end
        if #binds > 0 or Cheat.IsMenuVisible() == true then
            RenderGradientBox(x, y, (75 + to), 18, 2, ui.color:Get(), math.floor(kona.global*255), kona.global*0)
        end
        Render_Text(x - Render.CalcTextSize(text, font_size, verdana).x / 2 + (75 + to) / 2, y+ 4, false, text, Color.RGBA(255, 255, 255, math.floor(kona.global*255)), verdana, font_size, math.floor(kona.global*120))
    end
end

--DORMANT

function calc_angle(src, dst)
    local vecdelta = Vector.new(dst.x - src.x, dst.y - src.y, dst.z - src.z)
    local angles = QAngle.new(math.atan2(-vecdelta.z, vecdelta:Length2D()) * 180.0 / math.pi, (math.atan2(vecdelta.y, vecdelta.x) * 180.0 / math.pi), 0.0)
    return angles
end

function autostop(cmd)
    local vecvelocity1 = Vector.new(get_localplayer():GetProp("m_vecVelocity[0]"), get_localplayer():GetProp("m_vecVelocity[1]"), 0.0)
    local viewangles = get_localplayer():GetEyePosition()
    local direction = Cheat.VectorToAngle(vecvelocity1)
    direction.yaw = cmd.viewangles.yaw - direction.yaw
    local forward = Cheat.AngleToForward(direction)
    local negative = Vector2.new(forward.x * -200, forward.y * -200)
    cmd.forwardmove = negative.x
    cmd.sidemove = negative.y
end

function get_localplayer()
    local local_index = EngineClient.GetLocalPlayer()
    local localplayer = EntityList.GetClientEntity(local_index)
    if localplayer == nil then return end
    local me = localplayer:GetPlayer()
    return me
end

function get_dormant_enemy()
    local target_correct = true
    local players = EntityList.GetEntitiesByName("CCSPlayer")
    for i = 1, #players do
        local enemies = players[i];
        local enemy = enemies:GetPlayer()
        target_correct = enemy:GetNetworkState() ~= -1
        if enemy ~= get_localplayer() and not enemy:IsTeamMate() and enemy:GetProp("DT_BasePlayer", "m_iHealth") > 0 and enemy:IsDormant() and target_correct then
            return i
        end
    end
end

function is_in_air(entity)
    local flags = entity:GetProp("DT_BasePlayer", "m_fFlags")
    return bit.band(flags, 1) == 0
end

function dormantaim(cmd)
    local min = Vector.new()
    local max = Vector.new()
    local players = EntityList.GetEntitiesByName("CCSPlayer")
    local weap = get_localplayer():GetActiveWeapon()
    if weap ~= nil then
        local weapon_id = weap:GetWeaponID()
    end

    if ui.da_enable:GetBool() and get_dormant_enemy() then
        local dormant_target = players[get_dormant_enemy()]:GetPlayer()
        local weap_delay = (weapon_id == 9 or weapon_id == 40) and 0.15 or 0.0
        if dormant_target and weap_delay and weap:GetProp("m_flNextPrimaryAttack") and GlobalVars.curtime and weap:GetProp("m_flNextPrimaryAttack") + weap_delay <= GlobalVars.curtime and get_localplayer():GetProp("m_bIsScoped") and not is_in_air(get_localplayer()) then
            local bounds = dormant_target:GetRenderBounds(min, max)
            local pos = dormant_target:GetProp("m_vecOrigin") + Vector.new((min.x + max.x)/4, (min.y + max.y)/16, (min.z + max.z/2))
            if Cheat.FireBullet(get_localplayer(), get_localplayer():GetEyePosition(), pos).damage >= ui.da_damage:GetInt() then
                autostop(cmd)

                if 1 / weap:GetInaccuracy(weap) >= 75 then
                    local getaimpunch = get_localplayer():GetProp("DT_BasePlayer", "m_aimPunchAngle")
                    local aimpunch = QAngle.new(getaimpunch.x, getaimpunch.y, 0.0)
                    local aim_angle = calc_angle(get_localplayer():GetEyePosition(), pos)
                    cmd.viewangles.pitch = aim_angle.pitch - aimpunch.pitch * 2
                    cmd.viewangles.yaw = aim_angle.yaw - aimpunch.yaw * 2
                    cmd.buttons = bit.bor(cmd.buttons, 1)
                end
            end
        end
    end
    orig_move = {cmd.forwardmove, cmd.sidemove, QAngle.new(0, cmd.viewangles.yaw, 0)}
    if ui.manuals:Get() > 0 then
        orig_move = {cmd.forwardmove - 1, cmd.sidemove - 1, QAngle.new(0, cmd.viewangles.yaw, 0)}
    end
end

--антибакстап
normalize_yaw = function(yaw)
    while yaw > 180 do yaw = yaw - 360 end
    while yaw < -180 do yaw = yaw + 360 end
    return yaw
end

update_enemies = function()
    local localplayer = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
    if not localplayer then return end
    
    local my_index = EntityList.GetClientEntity(EngineClient.GetLocalPlayer()):GetPlayer()
    if not my_index then return end

    if EngineClient.IsConnected() and my_index:IsAlive() then
        local players = EntityList.GetEntitiesByName("CCSPlayer")
        local fov_enemy, maximum_fov = nil, 180
        
        for i = 1, #players do
            local enemy = players[i]:GetPlayer()
            if enemy ~= my_index and not enemy:IsTeamMate() and enemy:IsAlive() then
                local my_origin = my_index:GetRenderOrigin()
                local enemy_origin = enemy:GetRenderOrigin()

                local world_to_screen = (
                    my_origin.x - enemy_origin.x == 0 and my_origin.y - enemy_origin.z == 0
                ) and 0 or math.deg(
                    math.atan2(
                        my_origin.y - enemy_origin.y, my_origin.x - enemy_origin.x
                    )
                ) - EngineClient.GetViewAngles().yaw + 180

                local calculated_fov = math.abs(normalize_yaw(world_to_screen))
                if not fov_enemy or calculated_fov <= maximum_fov then
                    fov_enemy = enemy
                    maximum_fov = calculated_fov
                end
            end
        end

        return ({
            enemy = fov_enemy,
            fov = maximum_fov
        })
    end
end

function backstab()
    local local_player = EntityList.GetLocalPlayer()
    if not local_player then return end
    local my_index = EntityList.GetClientEntity(EngineClient.GetLocalPlayer()):GetPlayer()
    if not my_index then return end
    if EngineClient.IsConnected() and my_index:IsAlive() then
        local data, current_enemy = update_enemies(), nil
        if data ~= nil then
            current_enemy = data.enemy
        end
        
        if current_enemy ~= nil and current_enemy:IsAlive() then
            if not current_enemy:IsDormant() then
                local my_origin = my_index:GetRenderOrigin()
                local enemy_origin = current_enemy:GetRenderOrigin()

                local enemy_weapon = current_enemy:GetActiveWeapon()
                if not enemy_weapon then return end

                local our_distance = my_origin:DistTo(enemy_origin)
                local minimum_distance = 200

                if enemy_weapon:IsKnife() then
                    if our_distance <= minimum_distance then
                        AntiAim.OverrideYawOffset(180)
                    end
                end
            end
        end
    end
end

--legit aa
one_time_legit_aa = false
function legit_aa_on_e(cmd)
    local localplayer = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
    if not localplayer then return end
    
    local my_index = EntityList.GetClientEntity(EngineClient.GetLocalPlayer()):GetPlayer()
    if not my_index then return end

    if EngineClient.IsConnected() and my_index:IsAlive() and ui.legitaa then
        local is_active = function()
            local maximum_distance = 99999999
            local my_origin = my_index:GetRenderOrigin()

            local doors = EntityList.GetEntitiesByClassID(143)
            local bomb = EntityList.GetEntitiesByClassID(129)
            local hostages = EntityList.GetEntitiesByClassID(97)

            local my_view_angles = EngineClient.GetViewAngles()
            local my_angles = Vector2.new(my_view_angles.yaw, my_view_angles.pitch)
            my_angles.y = -my_angles.y

            for k, v in pairs(doors) do
                local doors_origin = v:GetRenderOrigin()
                local current_distance = my_origin:DistTo(doors_origin)

                if current_distance <= maximum_distance then maximum_distance = current_distance end
            end

            for k, v in pairs(bomb) do 
                local bomb_origin = v:GetRenderOrigin()
                local current_distance = my_origin:DistTo(bomb_origin)

                if current_distance <= maximum_distance then maximum_distance = current_distance end
            end

            for k, v in pairs(hostages) do 
                local hostages_origin = v:GetRenderOrigin()
                local current_distance = my_origin:DistTo(hostages_origin)

                if current_distance <= maximum_distance then maximum_distance = current_distance end
            end

            if maximum_distance <= 100 or (my_angles.y <= -25 and my_angles.y > -70) then
                return false
            end
            return true
        end

        if bit.band(cmd.buttons, 32) == 32 then
            if not one_time_legit_aa then
                one_time_legit_aa = true
            end

            if is_active() then
                if Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Base"):GetInt() == 5 then
                    Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Base"):SetInt(4)
                end

                local yaw_base = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Base"):GetInt()
                local yaw_value = (
                    yaw_base == 1 and 180 or yaw_base == 2 and 90 or yaw_base == 3 and -90 or
                    yaw_base == 4 and 180 or 0
                )

                AntiAim.OverridePitch(0)
                AntiAim.OverrideYawOffset(yaw_value)
                AntiAim.OverrideLimit(60)

                cmd.buttons = bit.band(cmd.buttons, bit.bnot(32))
            end
        else
            if one_time_legit_aa then
                one_time_legit_aa = false
            end
        end
    end
end

--roll aa
local orig_move = {0, 0, 0}


local sincos = function(ang)
    return Vector2.new(math.cos(ang), math.sin(ang))
end


local AngleToVector = function(angles)
    local fr, rt = Vector.new(0, 0, 0), Vector.new(0, 0, 0)

    local pitch = sincos(angles.pitch * 0.017453292519943)
    local yaw = sincos(angles.yaw * 0.017453292519943)
    local roll = sincos(angles.roll * 0.017453292519943)

    fr.x = pitch.x * yaw.x
    fr.y = pitch.x * yaw.y

    rt.x = -1 * roll.y * pitch.y * yaw.x + -1 * roll.x * -yaw.y
    rt.y = -1 * roll.y * pitch.y * yaw.y + -1 * roll.x * yaw.x

    return fr / #fr, rt / #rt
end

local function fixmove(cmd)
    if ui.ex_for_run:Get() then
        local front_left, roght_lefthyh = AngleToVector(orig_move[3])
        local front_center, roght_centerhyh = AngleToVector(cmd.viewangles)

        local center = front_left * orig_move[1] + roght_lefthyh * orig_move[2]
        local div = roght_centerhyh.y * front_center.x - roght_centerhyh.x * front_center.y
        cmd.sidemove = (front_center.x * center.y - front_center.y * center.x) / div
        cmd.forwardmove = (roght_centerhyh.y * center.x - roght_centerhyh.x * center.y) / div
    else
        if ui.roll_on_stay:Get() or ui.roll_on_air:Get() or ui.roll_on_move:Get() or ui.roll_on_walk:Get() then
            local front_left, roght_lefthyh = AngleToVector(orig_move[3])
            local front_center, roght_centerhyh = AngleToVector(cmd.viewangles)

            local center = front_left * orig_move[1] + roght_lefthyh * orig_move[2]
            local div = roght_centerhyh.y * front_center.x - roght_centerhyh.x * front_center.y
            cmd.sidemove = (front_center.x * center.y - front_center.y * center.x) / div
            cmd.forwardmove = (roght_centerhyh.y * center.x - roght_centerhyh.x * center.y) / div   
        end
        if ui.manuals:Get() > 0 then
            local front_left, roght_lefthyh = AngleToVector(orig_move[3])
            local front_center, roght_centerhyh = AngleToVector(cmd.viewangles)

            local center = front_left * orig_move[1] + roght_lefthyh * orig_move[2]
            local div = roght_centerhyh.y * front_center.x - roght_centerhyh.x * front_center.y - 0.5
            cmd.sidemove = (front_center.x * center.y - front_center.y * center.x) / div
            cmd.forwardmove = (roght_centerhyh.y * center.x - roght_centerhyh.x * center.y) / div
        end
    end
end

local rol = 0
Cheat.RegisterCallback("pre_prediction", function(cmd)
    local body_yaw = AntiAim.GetInverterState()
    local tickcount = GlobalVars.tickcount
    rolls = false

    if not EngineClient.GetLocalPlayer() then
        return
    end
    local localplayer = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
    if not localplayer then
        return
    end
    local localp = EntityList.GetLocalPlayer()
    local velocity = math.floor(Vector.new(localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[0]"), localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[1]"), localplayer:GetProp("DT_BasePlayer", "m_vecVelocity[2]") ):Length());
    local manual = ui.manuals:Get()
    if manual > 0 then
        AntiAim.OverrideInverter(true)
        AntiAim.OverrideYawOffset(manual == 1 and -90 or 90)
        if body_yaw then
            cmd.viewangles.roll = 44
            rol = -44
        else
            cmd.viewangles.roll = -44
            rol = 44
        end
        rolls = true
        dsyL:Set(60)
        dsyR:Set(60)
        return
    end

    if walk:Get() and ui.roll_on_walk:Get() then
        cmd.viewangles.roll = not AntiAim.GetInverterState() and 44 or -44
        rol = cmd.viewangles.roll
        rolls = true
    end

    if velocity > 5 and ui.roll_on_move:Get() then
        cmd.viewangles.roll = not AntiAim.GetInverterState() and 30 or -30
        rol = cmd.viewangles.roll
        rolls = true
    end

    if velocity < 5 and ui.roll_on_stay:Get() then
        cmd.viewangles.roll = not AntiAim.GetInverterState() and 44 or -44
        rol = cmd.viewangles.roll
        rolls = true
    end

    if in_air(localp) and ui.roll_on_air:Get() then
        cmd.viewangles.roll = not AntiAim.GetInverterState() and 44 or -44
        rol = cmd.viewangles.roll
        rolls = true
    end

    if ui.roll_on_crouch:Get() and is_crouching(localp) and not in_air(localp) then
        cmd.viewangles.roll = not AntiAim.GetInverterState() and 44 or -44
        rol = cmd.viewangles.roll
        rolls = true
    end

    if rolls then
        AntiAim.OverrideLimit(AntiAim.GetMaxDesyncDelta())
    end
end)

--LOGS

local ConsolePrint = function(label, r, g, b, a)
    local ConColorMsg = ffi.cast("ColorMsgFn", ffi.C.GetProcAddress(ffi.C.GetModuleHandleA("tier0.dll"), "?ConColorMsg@@YAXABVColor@@PBDZZ"))
    
    local col = ffi.new("Color")
    col.r = r
    col.g = g
    col.b = b
    col.a = a

    ConColorMsg(col, label)
end
local log = {
}
local console = Render.InitFont("lucida console", 10, {"r"})
local hitboxes = {
    [0] = "generic",
    [1] = "head",
    [2] = "chest",
    [3] = "stomach",
    [4] = "left arm",
    [5] = "right arm",
    [6] = "left leg",
    [7] = "right leg",
    [10] = "gear",
}
local reasons = {
    "resolver",
    "spread",
    "occlusion",
    "prediction error",
}

local drawlog = function(prefix, prefix_r, prefix_g, prefix_b, prefix_a, text, print_text)
    log[#log + 1] = {
        text,
        255,
        math.floor(GlobalVars.curtime),
    }
    ConsolePrint(prefix, prefix_r, prefix_g, prefix_b, prefix_a)
    print(print_text)
end

function logs(event)
    local localplayer = EntityList.GetLocalPlayer()
    if event:GetName() == "item_purchase" then
        if event:GetName() ~= "item_purchase" then
            return
        end
        local buyerid = EntityList.GetPlayerForUserID(event:GetInt("userid"))
        local item = event:GetString("weapon")
        if buyerid ~= localplayer and item ~= "weapon_unknown" and buyerid ~= nil then
            local buyer = buyerid:GetName()
            drawlog("[Chernobyl.log] ", 180, 230, 20, 255, string.format("%s bought %s", buyer, item), string.format("%s bought %s\r", buyer, item))
        end
    end
    if event:GetName() == "player_hurt" then
        local target = EntityList.GetPlayerForUserID(event:GetInt("userid"))
        if target == nil then return end
        local attacker = EntityList.GetPlayerForUserID(event:GetInt("attacker"))
        local target_name = target:GetName()
        local dmghealth = event:GetInt("dmg_health")
        local healthremain = event:GetInt("health")
        local hitbox = hitboxes[event:GetInt("hitgroup")]
        if attacker == localplayer then
            drawlog("[Chernobyl.log] ", 180, 230, 20, 255, string.format("Hit %s aimed = %s for %s damage (%s health remaining)", target_name, hitbox, dmghealth, healthremain), string.format("Hit %s aimed = %s for %s damage (%s health remaining)\r", target_name, hitbox, dmghealth, healthremain))
        end
    end
end

Cheat.RegisterCallback("registered_shot", function(reg)
    local missreason = reasons[reg.reason]
    if reg.reason == 0 then
        return
    end
    drawlog("[Chernobyl.log] ", 180, 230, 20, 255, string.format("Missed shot due to %s", missreason), string.format("Missed shot due to %s\r", missreason))
end)

local clearlog = function()
    if #log ~= 0 then
        if EngineClient:IsConnected() == false then
            table.remove(log, #log)
        end
        if #log > 6 then
            table.remove(log, 1)
        end
        if log[1][3] + 5 < math.floor(GlobalVars.curtime) then
            log[1][2] = log[1][2] - math.floor(GlobalVars.frametime * 600)
            if log[1][2] < 0 then
                table.remove(log, 1)
            end
        end
    end
end
local drawlog = function()
    clearlog()
    color = ui.logs:GetColor()
    if ui.logs:Get() then
        nl_logs:Set(0)
    end
    for i = 1, #log do
        if ui.logs:Get() then
            Render.Text("[Chernobyl.log] " .. ""..log[i][1].."", Vector2.new(7 + 1, 5 + i * 12 + 1 - 12), Color.RGBA(0, 0, 0, log[i][2]), 10, console)
            Render.Text("[Chernobyl.log] " .. ""..log[i][1].."", Vector2.new(7, 5 + i * 12 - 12), Color.new(color.r, color.g, color.b, log[i][2]), 10, console)
        end
    end
end

local function str_to_sub(input, sep)
    local t = {}
    for str in string.gmatch(input, "([^"..sep.."]+)") do
        t[#t + 1] = string.gsub(str, "\n", "")
    end
    return t
end

local function arr_to_string(arr)
    arr = arr:Get()
    local str = ""
    for i=1, #arr do
        str = str .. arr[i] .. (i == #arr and "" or ",")
    end

    if str == "" then
        str = "-"
    end

    return str
end

local function to_boolean(str)
    if str == "true" or str == "false" then
        return (str == "true")
    else
        return str
    end
end

local function clipboard_import()
    local clipboard_text_length = get_clipboard_text_count( VGUI_System )
    local clipboard_data = ""

    if clipboard_text_length > 0 then
        buffer = ffi.new("char[?]", clipboard_text_length)
        size = clipboard_text_length * ffi.sizeof("char[?]", clipboard_text_length)

        get_clipboard_text( VGUI_System, 0, buffer, size )

        clipboard_data = ffi.string( buffer, clipboard_text_length-1 )
    end
    return clipboard_data
end

local function clipboard_export(string)
    if string then
        set_clipboard_text(VGUI_System, string, string:len())
    end
end


local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function enc(data)
    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function dec(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
            return string.char(c)
    end))
end


function export()
    str = tostring(ui.Stay_Custom_yaw_add_L:Get()) .. "|"
    .. tostring(ui.Stay_Custom_yaw_add_R:Get()) .. "|"
    .. tostring(ui.Stay_Custom_yaw_modifier_mode:Get()) .. "|"
    .. tostring(ui.Stay_Custom_yaw_modifier:Get()) .. "|"
    .. tostring(ui.Stay_Custom_modifier_degree:Get()) .. "|"
    .. tostring(ui.Stay_Custom_modifier_degree_min:Get()) .. "|"
    .. tostring(ui.Stay_Custom_modifier_degree_max:Get()) .. "|"
    .. tostring(ui.Stay_Custom_limit_mode:Get()) .. "|"
    .. tostring(ui.Stay_Custom_limit1:Get()) .. "|"
    .. tostring(ui.Stay_Custom_limit2:Get()) .. "|"
    .. tostring(ui.Stay_Custom_limit3:Get()) .. "|"
    .. tostring(ui.Stay_Custom_limit4:Get()) .. "|"
    .. tostring(ui.Stay_Custom_fake_options:Get()) .. "|"
    .. tostring(ui.Stay_Custom_lby_mode:Get()) .. "|"
    .. tostring(ui.Stay_Custom_freestand_dsy:Get()) .. "|"
    .. tostring(ui.Stay_Custom_dsy_on_shot:Get()) .. "|"

    .. tostring(ui.Move_Custom_yaw_add_L:Get()) .. "|"
    .. tostring(ui.Move_Custom_yaw_add_R:Get()) .. "|"
    .. tostring(ui.Move_Custom_yaw_modifier_mode:Get()) .. "|"
    .. tostring(ui.Move_Custom_yaw_modifier:Get()) .. "|"
    .. tostring(ui.Move_Custom_modifier_degree:Get()) .. "|"
    .. tostring(ui.Move_Custom_modifier_degree_min:Get()) .. "|"
    .. tostring(ui.Move_Custom_modifier_degree_max:Get()) .. "|"
    .. tostring(ui.Move_Custom_limit_mode:Get()) .. "|"
    .. tostring(ui.Move_Custom_limit1:Get()) .. "|"
    .. tostring(ui.Move_Custom_limit2:Get()) .. "|"
    .. tostring(ui.Move_Custom_limit3:Get()) .. "|"
    .. tostring(ui.Move_Custom_limit4:Get()) .. "|"
    .. tostring(ui.Move_Custom_fake_options:Get()) .. "|"
    .. tostring(ui.Move_Custom_lby_mode:Get()) .. "|"
    .. tostring(ui.Move_Custom_freestand_dsy:Get()) .. "|"
    .. tostring(ui.Move_Custom_dsy_on_shot:Get()) .. "|"
end

function export2()
    str2 = str .. tostring(ui.Air_Custom_yaw_add_L:Get()) .. "|"
    .. tostring(ui.Air_Custom_yaw_add_R:Get()) .. "|"
    .. tostring(ui.Air_Custom_yaw_modifier_mode:Get()) .. "|"
    .. tostring(ui.Air_Custom_yaw_modifier:Get()) .. "|"
    .. tostring(ui.Air_Custom_modifier_degree:Get()) .. "|"
    .. tostring(ui.Air_Custom_modifier_degree_min:Get()) .. "|"
    .. tostring(ui.Air_Custom_modifier_degree_max:Get()) .. "|"
    .. tostring(ui.Air_Custom_limit_mode:Get()) .. "|"
    .. tostring(ui.Air_Custom_limit1:Get()) .. "|"
    .. tostring(ui.Air_Custom_limit2:Get()) .. "|"
    .. tostring(ui.Air_Custom_limit3:Get()) .. "|"
    .. tostring(ui.Air_Custom_limit4:Get()) .. "|"
    .. tostring(ui.Air_Custom_fake_options:Get()) .. "|"
    .. tostring(ui.Air_Custom_lby_mode:Get()) .. "|"
    .. tostring(ui.Air_Custom_freestand_dsy:Get()) .. "|"
    .. tostring(ui.Air_Custom_dsy_on_shot:Get()) .. "|"

    .. tostring(ui.Walk_Custom_yaw_add_L:Get()) .. "|"
    .. tostring(ui.Walk_Custom_yaw_add_R:Get()) .. "|"
    .. tostring(ui.Walk_Custom_yaw_modifier_mode:Get()) .. "|"
    .. tostring(ui.Walk_Custom_yaw_modifier:Get()) .. "|"
    .. tostring(ui.Walk_Custom_modifier_degree:Get()) .. "|"
    .. tostring(ui.Walk_Custom_modifier_degree_min:Get()) .. "|"
    .. tostring(ui.Walk_Custom_modifier_degree_max:Get()) .. "|"
    .. tostring(ui.Walk_Custom_limit_mode:Get()) .. "|"
    .. tostring(ui.Walk_Custom_limit1:Get()) .. "|"
    .. tostring(ui.Walk_Custom_limit2:Get()) .. "|"
    .. tostring(ui.Walk_Custom_limit3:Get()) .. "|"
    .. tostring(ui.Walk_Custom_limit4:Get()) .. "|"
    .. tostring(ui.Walk_Custom_fake_options:Get()) .. "|"
    .. tostring(ui.Walk_Custom_lby_mode:Get()) .. "|"
    .. tostring(ui.Walk_Custom_freestand_dsy:Get()) .. "|"
    .. tostring(ui.Walk_Custom_dsy_on_shot:Get()) .. "|"
end

function export3()
    str3 = str2 .. tostring(ui.Crouch_Custom_yaw_add_L:Get()) .. "|"
    .. tostring(ui.Crouch_Custom_yaw_add_R:Get()) .. "|"
    .. tostring(ui.Crouch_Custom_yaw_modifier_mode:Get()) .. "|"
    .. tostring(ui.Crouch_Custom_yaw_modifier:Get()) .. "|"
    .. tostring(ui.Crouch_Custom_modifier_degree:Get()) .. "|"
    .. tostring(ui.Crouch_Custom_modifier_degree_min:Get()) .. "|"
    .. tostring(ui.Crouch_Custom_modifier_degree_max:Get()) .. "|"
    .. tostring(ui.Crouch_Custom_limit_mode:Get()) .. "|"
    .. tostring(ui.Crouch_Custom_limit1:Get()) .. "|"
    .. tostring(ui.Crouch_Custom_limit2:Get()) .. "|"
    .. tostring(ui.Crouch_Custom_limit3:Get()) .. "|"
    .. tostring(ui.Crouch_Custom_limit4:Get()) .. "|"
    .. tostring(ui.Crouch_Custom_fake_options:Get()) .. "|"
    .. tostring(ui.Crouch_Custom_lby_mode:Get()) .. "|"
    .. tostring(ui.Crouch_Custom_freestand_dsy:Get()) .. "|"
    .. tostring(ui.Crouch_Custom_dsy_on_shot:Get()) .. "|"

    .. tostring(ui.FD_Custom_yaw_add_L:Get()) .. "|"
    .. tostring(ui.FD_Custom_yaw_add_R:Get()) .. "|"
    .. tostring(ui.FD_Custom_yaw_modifier_mode:Get()) .. "|"
    .. tostring(ui.FD_Custom_yaw_modifier:Get()) .. "|"
    .. tostring(ui.FD_Custom_modifier_degree:Get()) .. "|"
    .. tostring(ui.FD_Custom_modifier_degree_min:Get()) .. "|"
    .. tostring(ui.FD_Custom_modifier_degree_max:Get()) .. "|"
    .. tostring(ui.FD_Custom_limit_mode:Get()) .. "|"
    .. tostring(ui.FD_Custom_limit1:Get()) .. "|"
    .. tostring(ui.FD_Custom_limit2:Get()) .. "|"
    .. tostring(ui.FD_Custom_limit3:Get()) .. "|"
    .. tostring(ui.FD_Custom_limit4:Get()) .. "|"
    .. tostring(ui.FD_Custom_fake_options:Get()) .. "|"
    .. tostring(ui.FD_Custom_lby_mode:Get()) .. "|"
    .. tostring(ui.FD_Custom_freestand_dsy:Get()) .. "|"
    .. tostring(ui.FD_Custom_dsy_on_shot:Get()) .. "|"

    .. tostring(ui.brute_aa:Get()) .. "|"
    .. tostring(ui.brute_aa_conditions:Get()) .. "|"
    .. tostring(ui.AB_miss_enable_1:Get()) .. "|"
    .. tostring(ui.AB_miss_yawL_1:Get()) .. "|"
    .. tostring(ui.AB_miss_yawR_1:Get()) .. "|"
    .. tostring(ui.AB_miss_yaw_modifier_1:Get()) .. "|"
    .. tostring(ui.AB_miss_modifier_1:Get()) .. "|"
    .. tostring(ui.AB_miss_lby_1:Get()) .. "|"
    .. tostring(ui.AB_miss_enable_2:Get()) .. "|"
    .. tostring(ui.AB_miss_yawL_2:Get()) .. "|"
    .. tostring(ui.AB_miss_yawR_2:Get()) .. "|"
    .. tostring(ui.AB_miss_yaw_modifier_2:Get()) .. "|"
    .. tostring(ui.AB_miss_modifier_2:Get()) .. "|"
    .. tostring(ui.AB_miss_lby_2:Get()) .. "|"
    .. tostring(ui.AB_miss_enable_3:Get()) .. "|"
    .. tostring(ui.AB_miss_yawL_3:Get()) .. "|"
    .. tostring(ui.AB_miss_yawR_3:Get()) .. "|"
    .. tostring(ui.AB_miss_yaw_modifier_3:Get()) .. "|"
    .. tostring(ui.AB_miss_modifier_3:Get()) .. "|"
    .. tostring(ui.AB_miss_lby_3:Get()) .. "|"

    .. tostring(ui.Stay_Custom_Enable:Get()) .. "|"
    .. tostring(ui.Move_Custom_Enable:Get()) .. "|"
    .. tostring(ui.Air_Custom_Enable:Get()) .. "|"
    .. tostring(ui.Walk_Custom_Enable:Get()) .. "|"
    .. tostring(ui.Crouch_Custom_Enable:Get()) .. "|"
    .. tostring(ui.FD_Custom_Enable:Get()) .. "|"
    clipboard_export(enc(str3))
end

function import(input)
    local tbl = str_to_sub(input, "|")
    ui.Stay_Custom_yaw_add_L:SetInt(tonumber(tbl[1]))
    ui.Stay_Custom_yaw_add_R:SetInt(tonumber(tbl[2]))
    ui.Stay_Custom_yaw_modifier_mode:SetInt(tonumber(tbl[3]))
    ui.Stay_Custom_yaw_modifier:SetInt(tonumber(tbl[4]))
    ui.Stay_Custom_modifier_degree:SetInt(tonumber(tbl[5]))
    ui.Stay_Custom_modifier_degree_min:SetInt(tonumber(tbl[6]))
    ui.Stay_Custom_modifier_degree_max:SetInt(tonumber(tbl[7]))
    ui.Stay_Custom_limit_mode:SetInt(tonumber(tbl[8]))
    ui.Stay_Custom_limit1:SetInt(tonumber(tbl[9]))
    ui.Stay_Custom_limit2:SetInt(tonumber(tbl[10]))
    ui.Stay_Custom_limit3:SetInt(tonumber(tbl[11]))
    ui.Stay_Custom_limit4:SetInt(tonumber(tbl[12]))
    ui.Stay_Custom_fake_options:SetInt(tonumber(tbl[13]))
    ui.Stay_Custom_lby_mode:SetInt(tonumber(tbl[14]))
    ui.Stay_Custom_freestand_dsy:SetInt(tonumber(tbl[15]))
    ui.Stay_Custom_dsy_on_shot:SetInt(tonumber(tbl[16]))

    ui.Move_Custom_yaw_add_L:SetInt(tonumber(tbl[17]))
    ui.Move_Custom_yaw_add_R:SetInt(tonumber(tbl[18]))
    ui.Move_Custom_yaw_modifier_mode:SetInt(tonumber(tbl[19]))
    ui.Move_Custom_yaw_modifier:SetInt(tonumber(tbl[20]))
    ui.Move_Custom_modifier_degree:SetInt(tonumber(tbl[21]))
    ui.Move_Custom_modifier_degree_min:SetInt(tonumber(tbl[22]))
    ui.Move_Custom_modifier_degree_max:SetInt(tonumber(tbl[23]))
    ui.Move_Custom_limit_mode:SetInt(tonumber(tbl[24]))
    ui.Move_Custom_limit1:SetInt(tonumber(tbl[25]))
    ui.Move_Custom_limit2:SetInt(tonumber(tbl[26]))
    ui.Move_Custom_limit3:SetInt(tonumber(tbl[27]))
    ui.Move_Custom_limit4:SetInt(tonumber(tbl[28]))
    ui.Move_Custom_fake_options:SetInt(tonumber(tbl[29]))
    ui.Move_Custom_lby_mode:SetInt(tonumber(tbl[30]))
    ui.Move_Custom_freestand_dsy:SetInt(tonumber(tbl[31]))
    ui.Move_Custom_dsy_on_shot:SetInt(tonumber(tbl[32]))
end

function import2(input)
    local tbl = str_to_sub(input, "|")
    ui.Air_Custom_yaw_add_L:SetInt(tonumber(tbl[33]))
    ui.Air_Custom_yaw_add_R:SetInt(tonumber(tbl[34]))
    ui.Air_Custom_yaw_modifier_mode:SetInt(tonumber(tbl[35]))
    ui.Air_Custom_yaw_modifier:SetInt(tonumber(tbl[36]))
    ui.Air_Custom_modifier_degree:SetInt(tonumber(tbl[37]))
    ui.Air_Custom_modifier_degree_min:SetInt(tonumber(tbl[38]))
    ui.Air_Custom_modifier_degree_max:SetInt(tonumber(tbl[39]))
    ui.Air_Custom_limit_mode:SetInt(tonumber(tbl[40]))
    ui.Air_Custom_limit1:SetInt(tonumber(tbl[41]))
    ui.Air_Custom_limit2:SetInt(tonumber(tbl[42]))
    ui.Air_Custom_limit3:SetInt(tonumber(tbl[43]))
    ui.Air_Custom_limit4:SetInt(tonumber(tbl[44]))
    ui.Air_Custom_fake_options:SetInt(tonumber(tbl[45]))
    ui.Air_Custom_lby_mode:SetInt(tonumber(tbl[46]))
    ui.Air_Custom_freestand_dsy:SetInt(tonumber(tbl[47]))
    ui.Air_Custom_dsy_on_shot:SetInt(tonumber(tbl[48]))

    ui.Walk_Custom_yaw_add_L:SetInt(tonumber(tbl[49]))
    ui.Walk_Custom_yaw_add_R:SetInt(tonumber(tbl[50]))
    ui.Walk_Custom_yaw_modifier_mode:SetInt(tonumber(tbl[51]))
    ui.Walk_Custom_yaw_modifier:SetInt(tonumber(tbl[52]))
    ui.Walk_Custom_modifier_degree:SetInt(tonumber(tbl[53]))
    ui.Walk_Custom_modifier_degree_min:SetInt(tonumber(tbl[54]))
    ui.Walk_Custom_modifier_degree_max:SetInt(tonumber(tbl[55]))
    ui.Walk_Custom_limit_mode:SetInt(tonumber(tbl[56]))
    ui.Walk_Custom_limit1:SetInt(tonumber(tbl[57]))
    ui.Walk_Custom_limit2:SetInt(tonumber(tbl[58]))
    ui.Walk_Custom_limit3:SetInt(tonumber(tbl[59]))
    ui.Walk_Custom_limit4:SetInt(tonumber(tbl[60]))
    ui.Walk_Custom_fake_options:SetInt(tonumber(tbl[61]))
    ui.Walk_Custom_lby_mode:SetInt(tonumber(tbl[62]))
    ui.Walk_Custom_freestand_dsy:SetInt(tonumber(tbl[63]))
    ui.Walk_Custom_dsy_on_shot:SetInt(tonumber(tbl[64]))
end

function import3(input)
    local tbl = str_to_sub(input, "|")
    ui.Crouch_Custom_yaw_add_L:SetInt(tonumber(tbl[65]))
    ui.Crouch_Custom_yaw_add_R:SetInt(tonumber(tbl[66]))
    ui.Crouch_Custom_yaw_modifier_mode:SetInt(tonumber(tbl[67]))
    ui.Crouch_Custom_yaw_modifier:SetInt(tonumber(tbl[68]))
    ui.Crouch_Custom_modifier_degree:SetInt(tonumber(tbl[69]))
    ui.Crouch_Custom_modifier_degree_min:SetInt(tonumber(tbl[70]))
    ui.Crouch_Custom_modifier_degree_max:SetInt(tonumber(tbl[71]))
    ui.Crouch_Custom_limit_mode:SetInt(tonumber(tbl[72]))
    ui.Crouch_Custom_limit1:SetInt(tonumber(tbl[73]))
    ui.Crouch_Custom_limit2:SetInt(tonumber(tbl[74]))
    ui.Crouch_Custom_limit3:SetInt(tonumber(tbl[75]))
    ui.Crouch_Custom_limit4:SetInt(tonumber(tbl[76]))
    ui.Crouch_Custom_fake_options:SetInt(tonumber(tbl[77]))
    ui.Crouch_Custom_lby_mode:SetInt(tonumber(tbl[78]))
    ui.Crouch_Custom_freestand_dsy:SetInt(tonumber(tbl[79]))
    ui.Crouch_Custom_dsy_on_shot:SetInt(tonumber(tbl[80]))

    ui.FD_Custom_yaw_add_L:SetInt(tonumber(tbl[81]))
    ui.FD_Custom_yaw_add_R:SetInt(tonumber(tbl[82]))
    ui.FD_Custom_yaw_modifier_mode:SetInt(tonumber(tbl[83]))
    ui.FD_Custom_yaw_modifier:SetInt(tonumber(tbl[84]))
    ui.FD_Custom_modifier_degree:SetInt(tonumber(tbl[85]))
    ui.FD_Custom_modifier_degree_min:SetInt(tonumber(tbl[86]))
    ui.FD_Custom_modifier_degree_max:SetInt(tonumber(tbl[87]))
    ui.FD_Custom_limit_mode:SetInt(tonumber(tbl[88]))
    ui.FD_Custom_limit1:SetInt(tonumber(tbl[89]))
    ui.FD_Custom_limit2:SetInt(tonumber(tbl[90]))
    ui.FD_Custom_limit3:SetInt(tonumber(tbl[91]))
    ui.FD_Custom_limit4:SetInt(tonumber(tbl[92]))
    ui.FD_Custom_fake_options:SetInt(tonumber(tbl[93]))
    ui.FD_Custom_lby_mode:SetInt(tonumber(tbl[94]))
    ui.FD_Custom_freestand_dsy:SetInt(tonumber(tbl[95]))
    ui.FD_Custom_dsy_on_shot:SetInt(tonumber(tbl[96]))

    ui.brute_aa:Set(to_boolean(tbl[97]))
    ui.brute_aa_conditions:SetInt(tonumber(tbl[98]))
    ui.AB_miss_enable_1:Set(to_boolean(tbl[99]))
    ui.AB_miss_yawL_1:SetInt(tonumber(tbl[100]))
    ui.AB_miss_yawR_1:SetInt(tonumber(tbl[101]))
    ui.AB_miss_yaw_modifier_1:SetInt(tonumber(tbl[102]))
    ui.AB_miss_modifier_1:SetInt(tonumber(tbl[103]))
    ui.AB_miss_lby_1:SetInt(tonumber(tbl[104]))
    ui.AB_miss_enable_2:Set(to_boolean(tbl[105]))
    ui.AB_miss_yawL_2:SetInt(tonumber(tbl[106]))
    ui.AB_miss_yawR_2:SetInt(tonumber(tbl[107]))
    ui.AB_miss_yaw_modifier_2:SetInt(tonumber(tbl[108]))
    ui.AB_miss_modifier_2:SetInt(tonumber(tbl[109]))
    ui.AB_miss_lby_2:SetInt(tonumber(tbl[110]))
    ui.AB_miss_enable_3:Set(to_boolean(tbl[111]))
    ui.AB_miss_yawL_3:SetInt(tonumber(tbl[112]))
    ui.AB_miss_yawR_3:SetInt(tonumber(tbl[113]))
    ui.AB_miss_yaw_modifier_3:SetInt(tonumber(tbl[114]))
    ui.AB_miss_modifier_3:SetInt(tonumber(tbl[115]))
    ui.AB_miss_lby_3:SetInt(tonumber(tbl[116]))

    ui.Stay_Custom_Enable:Set(to_boolean(tbl[117]))
    ui.Move_Custom_Enable:Set(to_boolean(tbl[118]))
    ui.Air_Custom_Enable:Set(to_boolean(tbl[119]))
    ui.Walk_Custom_Enable:Set(to_boolean(tbl[120]))
    ui.Crouch_Custom_Enable:Set(to_boolean(tbl[121]))
    ui.FD_Custom_Enable:Set(to_boolean(tbl[122]))
end

local button1 = Menu.Button("Settings","Export Current Anti-Aim State", "Export Settings", function()
    export()
    export2()
    export3()
    Cheat.AddNotify("Chernobyl.lua", "Settings copied!")
end)
local button2 = Menu.Button("Settings","Import Current Anti-Aim State", "Import Settings", function()
    import(dec(clipboard_import()))
    import2(dec(clipboard_import()))
    import3(dec(clipboard_import()))
    Cheat.AddNotify("Chernobyl.lua", "Settings loaded!")
end)

local Preset2 = Menu.Button("Settings","Defalut Preset","Preset", function()
    Cheat.AddNotify("Chernobyl.lua", "Settings loaded!")
    import(dec("NnwtNnwwfDB8NDd8MHwwfDB8NTB8NjB8MHwwfDJ8MXwwfDB8LTF8MXwwfDF8ODV8MHwwfDF8NTV8NTV8NjB8NjB8MnwxfDB8M3wtNXw1fDB8MXw4NXwtMTN8NDV8MXw2MHw2MHw1NXw1NXwyfDF8MHwzfC0xNHwwfDB8MHwwfDB8MHwwfDU4fDU4fDB8MHwwfDF8MHwwfC01fDI4fDB8MXwtMTl8MHwwfDB8NjB8NjB8MHwwfDJ8MXwwfDB8MHwwfDB8NHwzM3wwfDB8MHw2MHw2MHw2MHw2MHwyNnwxfDB8MnxmYWxzZXwyfHRydWV8LTE0fDEzfDB8OTB8MXx0cnVlfC0xMnwyNHwwfDkwfDF8dHJ1ZXwxOHwtMTh8MHw2NnwwfHRydWV8dHJ1ZXx0cnVlfHRydWV8dHJ1ZXx0cnVlfA=="))
    import2(dec("NnwtNnwwfDB8NDd8MHwwfDB8NTB8NjB8MHwwfDJ8MXwwfDB8LTF8MXwwfDF8ODV8MHwwfDF8NTV8NTV8NjB8NjB8MnwxfDB8M3wtNXw1fDB8MXw4NXwtMTN8NDV8MXw2MHw2MHw1NXw1NXwyfDF8MHwzfC0xNHwwfDB8MHwwfDB8MHwwfDU4fDU4fDB8MHwwfDF8MHwwfC01fDI4fDB8MXwtMTl8MHwwfDB8NjB8NjB8MHwwfDJ8MXwwfDB8MHwwfDB8NHwzM3wwfDB8MHw2MHw2MHw2MHw2MHwyNnwxfDB8MnxmYWxzZXwyfHRydWV8LTE0fDEzfDB8OTB8MXx0cnVlfC0xMnwyNHwwfDkwfDF8dHJ1ZXwxOHwtMTh8MHw2NnwwfHRydWV8dHJ1ZXx0cnVlfHRydWV8dHJ1ZXx0cnVlfA=="))
    import3(dec("NnwtNnwwfDB8NDd8MHwwfDB8NTB8NjB8MHwwfDJ8MXwwfDB8LTF8MXwwfDF8ODV8MHwwfDF8NTV8NTV8NjB8NjB8MnwxfDB8M3wtNXw1fDB8MXw4NXwtMTN8NDV8MXw2MHw2MHw1NXw1NXwyfDF8MHwzfC0xNHwwfDB8MHwwfDB8MHwwfDU4fDU4fDB8MHwwfDF8MHwwfC01fDI4fDB8MXwtMTl8MHwwfDB8NjB8NjB8MHwwfDJ8MXwwfDB8MHwwfDB8NHwzM3wwfDB8MHw2MHw2MHw2MHw2MHwyNnwxfDB8MnxmYWxzZXwyfHRydWV8LTE0fDEzfDB8OTB8MXx0cnVlfC0xMnwyNHwwfDkwfDF8dHJ1ZXwxOHwtMTh8MHw2NnwwfHRydWV8dHJ1ZXx0cnVlfHRydWV8dHJ1ZXx0cnVlfA=="))
end)

function tab_elements_cfg()
    if not Cheat.IsMenuVisible() then return end
    local tab = ui.tabs:GetInt()
    button1:SetVisible(tab == 2)
    button2:SetVisible(tab == 2)
    Preset2:SetVisible(tab == 2)
end

local function clamp(v, min, max) local num = v; num = num < min and min or num; num = num > max and max or num; return num end
local function linear(t, b, c, d) return c * t / d + b end

local m_alpha = 0
local lines = Menu.FindVar("Visuals", "View", "Camera", "Remove Scope");
local screen_size = EngineClient.GetScreenSize()
local function custom_scope()
    local localplayer = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
    if not localplayer then return end
    if localplayer:GetProp("DT_BasePlayer", "m_iHealth") > 0 then
        local screen_size = EngineClient.GetScreenSize()
        local width, height = screen_size.x, screen_size.y

        local offset, initial_position, speed, color =
        ui.overlay_offset:Get() * screen_size.y / 1080,
        ui.overlay_position:Get() * screen_size.y / 1080,
        ui.fade_time:Get(),
        ui.color_picker:GetColor()

        local me = localplayer:GetPlayer()
        local wpn = me:GetActiveWeapon()
        if wpn == nil then return end

        local scope_level, scoped, resume_zoom =
        wpn:GetProp("m_zoomLevel"),
        me:GetProp("m_bIsScoped"),
        me:GetProp("m_bResumeZoom")

        local act = wpn ~= nil and scope_level ~= nil and scope_level > 0 and scoped and not resume_zoom

        local FT = speed > 3 and GlobalVars.frametime * speed or 1
        local alpha = linear(m_alpha, 0, 1, 1)
        if ui.custom_scope:Get() then
            lines:Set(2)
            Render.GradientBoxFilled(Vector2.new(width / 2 - initial_position + 2, height / 2), Vector2.new(width / 2 + 2 - offset, height / 2 + 1), Color.new(color.r, color.g, color.b, color.a * alpha), Color.new(color.r, color.g, color.b, 0), Color.new(color.r, color.g, color.b, color.a * alpha), Color.new(color.r, color.g, color.b, 0)) -- LEFT
            Render.GradientBoxFilled(Vector2.new(width / 2 + offset, height / 2), Vector2.new(width / 2 + initial_position, height / 2 + 1), Color.new(color.r, color.g, color.b, 0), Color.new(color.r, color.g, color.b, color.a * alpha), Color.new(color.r, color.g, color.b, 0), Color.new(color.r, color.g, color.b, color.a * alpha)) -- RIGHT
            Render.GradientBoxFilled(Vector2.new(width / 2, height / 2 - initial_position + 2), Vector2.new(width / 2 + 1, height / 2 + 2 - offset), Color.new(color.r, color.g, color.b, color.a * alpha), Color.new(color.r, color.g, color.b, color.a * alpha), Color.new(color.r, color.g, color.b, 0), Color.new(color.r, color.g, color.b, 0)) -- TOP
            Render.GradientBoxFilled(Vector2.new(width / 2, height / 2 + offset), Vector2.new(width / 2 + 1, height / 2 + initial_position), Color.new(color.r, color.g, color.b, 0), Color.new(color.r, color.g, color.b, 0), Color.new(color.r, color.g, color.b, color.a * alpha), Color.new(color.r, color.g, color.b, color.a * alpha))
            m_alpha = clamp(m_alpha + (act and FT or -FT), 0, 1)
        end
    end
end

function drawa()
    indicators()
    arrows()
    all_visuals()
    tabs()
    rage()
    hitmarker_draw()
    paint()
    spec()
    if EngineClient.IsConnected() and EngineClient.IsInGame() then
        drawlog()
    end
    test()
    Stay()
    Move_and_Air()
    Walk()
    Crouch_in_air()

    tab_elements_stay()
    tab_elements_move()
    tab_elements_air()
    tab_elements_walk()
    tab_elements_crouch()
    tab_elements_air_crouch()
    tab_elements_cfg()

    custom_scope()
end

Cheat.RegisterCallback("prediction", function(cmd)
    if EngineClient:IsConnected() then
      anti_hit.system(cmd)
    end
    backstab()
    legit_aa_on_e(cmd)
end)

Cheat.RegisterCallback("events", function(event)
    if ui.CustomHitmarker:Get() then betterhitmarker_event(event) end
    if EntityList.GetLocalPlayer() == nil then return end
    tt(event)
    logs(event)
    brute_aa_e(event)
end)

function createmov(cmd)
    dormantaim(cmd)
    orig_move = {cmd.forwardmove, cmd.sidemove, QAngle.new(0, cmd.viewangles.yaw, 0)}
    if ui.manuals:Get() > 0 then
        orig_move = {cmd.forwardmove - 1, cmd.sidemove - 1, QAngle.new(0, cmd.viewangles.yaw, 0)}
    end
    fixmove(cmd)
end

Cheat.RegisterCallback("draw", drawa)
Cheat.RegisterCallback("createmove", createmov)

