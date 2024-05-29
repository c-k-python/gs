
local start_time = Utils.UnixTime()
local DEBUG = false

local script_name = "exscord beta"

local font_check = false

function print_dbg(...) 
    if DEBUG then print("[DEBUG] ".. ...) end
end

local game_dir = string.sub(EngineClient.GetGameDirectory() , 0 , -5)

local function fontcheck()
    local filesys = ffi.cast("void***", Utils.CreateInterface("filesystem_stdio.dll", "VBaseFileSystem011"))
    local FileExists = ffi.cast("bool(__thiscall*)(void*, const char*, const char*)", filesys[0][10])
    
    local game = EngineClient.GetGameDirectory()

    local errors = 0

    errors = errors + (FileExists(filesys,game_dir.."nl\\exscord\\smallest_pixel-7.ttf" , nil) and 0 or 1)

    if errors > 0 then
        Cheat.AddNotify(script_name, "Required font not found. Click download button to install it")
    end
end
local engine_client = Utils.CreateInterface("vstdlib.dll", "VEngineCvar007") or error("(")
local engine_client_class = ffi.cast(ffi.typeof("void***"), engine_client) or error("(")
local console_print_color_cast = ffi.cast("void(__cdecl*)(void*, void*, const char*)", engine_client_class[0][25]) or error("(")
fontcheck()


--#region png_lib

local Png = {}
Png.__index = Png
local png_ihdr_t = ffi.typeof([[
struct {
	char type[4];
	uint32_t width;
	uint32_t height;
	char bitDepth;
	char colorType;
	char compression;
	char filter;
	char interlace;
} *
]])

local jpg_segment_t = ffi.typeof([[
struct {
	char type[2];
	uint16_t size;
} *
]])

local jpg_segment_sof0_t = ffi.typeof([[
struct {
	uint16_t size;
	char precision;
	uint16_t height;
	uint16_t width;
} __attribute__((packed)) *
]])

local uint16_t_ptr = ffi.typeof("uint16_t*")
local charbuffer = ffi.typeof("unsigned char[?]")
local uintbuffer = ffi.typeof("unsigned int[?]")

--
-- constants
--

local INVALID_TEXTURE = -1
local PNG_MAGIC = "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A"

local JPG_MAGIC_1 = "\xFF\xD8\xFF\xDB"
local JPG_MAGIC_2 = "\xFF\xD8\xFF\xE0\x00\x10\x4A\x46\x49\x46\x00\x01"

local JPG_SEGMENT_SOI = "\xFF\xD8"
local JPG_SEGMENT_SOF0 = "\xFF\xC0"
local JPG_SEGMENT_SOS = "\xFF\xDA"
local JPG_SEGMENT_EOI = "\xFF\xD9"



local DEFLATE_MAX_BLOCK_SIZE = 65535

local function putBigUint32(val, tbl, index)
    for i=0,3 do
        tbl[index + i] = bit.band(bit.rshift(val, (3 - i) * 8), 0xFF)
    end
end

function Png:writeBytes(data, index, len)
    index = index or 1
    len = len or #data
    for i=index,index+len-1 do
        table.insert(self.output, string.char(data[i]))
    end
end

function Png:write(pixels)
    local count = #pixels  -- Byte count
    local pixelPointer = 1
    while count > 0 do
        if self.positionY >= self.height then
            error("All image pixels already written")
        end

        if self.deflateFilled == 0 then -- Start DEFLATE block
            local size = DEFLATE_MAX_BLOCK_SIZE;
            if (self.uncompRemain < size) then
                size = self.uncompRemain
            end
            local header = {  -- 5 bytes long
                bit.band((self.uncompRemain <= DEFLATE_MAX_BLOCK_SIZE and 1 or 0), 0xFF),
                bit.band(bit.rshift(size, 0), 0xFF),
                bit.band(bit.rshift(size, 8), 0xFF),
                bit.band(bit.bxor(bit.rshift(size, 0), 0xFF), 0xFF),
                bit.band(bit.bxor(bit.rshift(size, 8), 0xFF), 0xFF),
            }
            self:writeBytes(header)
            self:crc32(header, 1, #header)
        end
        assert(self.positionX < self.lineSize and self.deflateFilled < DEFLATE_MAX_BLOCK_SIZE);

        if (self.positionX == 0) then  -- Beginning of line - write filter method byte
            local b = {0}
            self:writeBytes(b)
            self:crc32(b, 1, 1)
            self:adler32(b, 1, 1)
            self.positionX = self.positionX + 1
            self.uncompRemain = self.uncompRemain - 1
            self.deflateFilled = self.deflateFilled + 1
        else -- Write some pixel bytes for current line
            local n = DEFLATE_MAX_BLOCK_SIZE - self.deflateFilled;
            if (self.lineSize - self.positionX < n) then
                n = self.lineSize - self.positionX
            end
            if (count < n) then
                n = count;
            end
            assert(n > 0);

            self:writeBytes(pixels, pixelPointer, n)

            -- Update checksums
            self:crc32(pixels, pixelPointer, n);
            self:adler32(pixels, pixelPointer, n);

            -- Increment positions
            count = count - n;
            pixelPointer = pixelPointer + n;
            self.positionX = self.positionX + n;
            self.uncompRemain = self.uncompRemain - n;
            self.deflateFilled = self.deflateFilled + n;
        end

        if (self.deflateFilled >= DEFLATE_MAX_BLOCK_SIZE) then
            self.deflateFilled = 0; -- End current block
        end

        if (self.positionX == self.lineSize) then  -- Increment line
            self.positionX = 0;
            self.positionY = self.positionY + 1;
            if (self.positionY == self.height) then -- Reached end of pixels
                local footer = {  -- 20 bytes long
                    0, 0, 0, 0,  -- DEFLATE Adler-32 placeholder
                    0, 0, 0, 0,  -- IDAT CRC-32 placeholder
                    -- IEND chunk
                    0x00, 0x00, 0x00, 0x00,
                    0x49, 0x45, 0x4E, 0x44,
                    0xAE, 0x42, 0x60, 0x82,
                }
                putBigUint32(self.adler, footer, 1)
                self:crc32(footer, 1, 4)
                putBigUint32(self.crc, footer, 5)
                self:writeBytes(footer)
                self.done = true
            end
        end
    end
end

function Png:crc32(data, index, len)
    self.crc = bit.bnot(self.crc)
    for i=index,index+len-1 do
        local byte = data[i]
        for j=0,7 do  -- Inefficient bitwise implementation, instead of table-based
            local nbit = bit.band(bit.bxor(self.crc, bit.rshift(byte, j)), 1);
            self.crc = bit.bxor(bit.rshift(self.crc, 1), bit.band((-nbit), 0xEDB88320));
        end
    end
    self.crc = bit.bnot(self.crc)
end
function Png:adler32(data, index, len)
    local s1 = bit.band(self.adler, 0xFFFF)
    local s2 = bit.rshift(self.adler, 16)
    for i=index,index+len-1 do
        s1 = (s1 + data[i]) % 65521
        s2 = (s2 + s1) % 65521
    end
    self.adler = bit.bor(bit.lshift(s2, 16), s1)
end

local function begin(width, height, colorMode)
    -- Default to rgb
    colorMode = colorMode or "rgb"

    -- Determine bytes per pixel and the PNG internal color type
    local bytesPerPixel, colorType
    if colorMode == "rgb" then
        bytesPerPixel, colorType = 3, 2
    elseif colorMode == "rgba" then
        bytesPerPixel, colorType = 4, 6
    else
        error("Invalid colorMode")
    end

    local state = setmetatable({ width = width, height = height, done = false, output = {} }, Png)

    -- Compute and check data siezs
    state.lineSize = width * bytesPerPixel + 1
    -- TODO: check if lineSize too big

    state.uncompRemain = state.lineSize * height

    local numBlocks = math.ceil(state.uncompRemain / DEFLATE_MAX_BLOCK_SIZE)

    -- 5 bytes per DEFLATE uncompressed block header, 2 bytes for zlib header, 4 bytes for zlib Adler-32 footer
    local idatSize = numBlocks * 5 + 6
    idatSize = idatSize + state.uncompRemain;

    -- TODO check if idatSize too big

    local header = {  -- 43 bytes long
        -- PNG header
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        -- IHDR chunk
        0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52,
        0, 0, 0, 0,  -- 'width' placeholder
        0, 0, 0, 0,  -- 'height' placeholder
        0x08, colorType, 0x00, 0x00, 0x00,
        0, 0, 0, 0,  -- IHDR CRC-32 placeholder
        -- IDAT chunk
        0, 0, 0, 0,  -- 'idatSize' placeholder
        0x49, 0x44, 0x41, 0x54,
        -- DEFLATE data
        0x08, 0x1D,
    }
    putBigUint32(width, header, 17)
    putBigUint32(height, header, 21)
    putBigUint32(idatSize, header, 34)

    state.crc = 0
    state:crc32(header, 13, 17)
    putBigUint32(state.crc, header, 30)
    state:writeBytes(header)

    state.crc = 0
    state:crc32(header, 38, 6);  -- 0xD7245B6B
    state.adler = 1

    state.positionX = 0
    state.positionY = 0
    state.deflateFilled = 0

    return state
end



--#endregion
--#region panorama_stuff

--credits lenin or whoever he took it from
local time = Panorama.LoadString([[
    return {
        get: () => {
            var now     = new Date(); 

            var hour    = now.getHours();
            var minute  = now.getMinutes();
            var second  = now.getSeconds(); 

            if(hour.toString().length == 1) {
                 hour = '0'+hour;
            }
            if(minute.toString().length == 1) {
                 minute = '0'+minute;
            }
            if(second.toString().length == 1) {
                 second = '0'+second;
            }   
            var dateTime = hour+':'+minute+':'+second;   

            return dateTime;
        },
        get_as_table: () => {
            var now     = new Date(); 

            var hour    = now.getHours();
            var minute  = now.getMinutes();
            var second  = now.getSeconds(); 

            if(hour.toString().length == 1) {
                 hour = '0'+hour;
            }
            if(minute.toString().length == 1) {
                 minute = '0'+minute;
            }
            if(second.toString().length == 1) {
                 second = '0'+second;
            }   
            var dateTime = hour+':'+minute+':'+second;   

            return {wHour: hour, wMinute: minute, wSecond: second};
        }
    }
]])()

--#endregion


--#region ffi_stuff


ffi.cdef [[
    int VirtualProtect(void* lpAddress, unsigned long dwSize, unsigned long flNewProtect, unsigned long* lpflOldProtect);
    void* VirtualAlloc(void* lpAddress, unsigned long dwSize, unsigned long  flAllocationType, unsigned long flProtect);
    int VirtualFree(void* lpAddress, unsigned long dwSize, unsigned long dwFreeType);

    typedef uintptr_t (__thiscall* GetClientEntity_4242425_t)(void*, int);
    typedef bool ( __thiscall* setupbones_t)( void*, void*, int, int, float );
	typedef struct 
	{
		float x;
		float y;
		float z;
    } Vector_t;

    typedef struct
  {
      char	pad0[0x60]; // 0x00
      void* pEntity; // 0x60
      void* pActiveWeapon; // 0x64
      void* pLastActiveWeapon; // 0x68
      float		flLastUpdateTime; // 0x6C
      int			iLastUpdateFrame; // 0x70
      float		flLastUpdateIncrement; // 0x74
      float		flEyeYaw; // 0x78
      float		flEyePitch; // 0x7C
      float		flGoalFeetYaw; // 0x80
      float		flLastFeetYaw; // 0x84
      float		flMoveYaw; // 0x88
      float		flLastMoveYaw; // 0x8C // changes when moving/jumping/hitting ground
      float		flLeanAmount; // 0x90
      char	pad1[0x4]; // 0x94
      float		flFeetCycle; // 0x98 0 to 1
      float		flMoveWeight; // 0x9C 0 to 1
      float		flMoveWeightSmoothed; // 0xA0
      float		flDuckAmount; // 0xA4
      float		flHitGroundCycle; // 0xA8
      float		flRecrouchWeight; // 0xAC
      Vector_t		vecOrigin; // 0xB0
      Vector_t		vecLastOrigin;// 0xBC
      Vector_t		vecVelocity; // 0xC8
      Vector_t		vecVelocityNormalized; // 0xD4
      Vector_t		vecVelocityNormalizedNonZero; // 0xE0
      float		flVelocityLenght2D; // 0xEC
      float		flJumpFallVelocity; // 0xF0
      float		flSpeedNormalized; // 0xF4 // clamped velocity from 0 to 1 
      float		flRunningSpeed; // 0xF8
      float		flDuckingSpeed; // 0xFC
      float		flDurationMoving; // 0x100
      float		flDurationStill; // 0x104
      bool		bOnGround; // 0x108
      bool		bHitGroundAnimation; // 0x109
      char	pad2[0x2]; // 0x10A
      float		flNextLowerBodyYawUpdateTime; // 0x10C
      float		flDurationInAir; // 0x110
      float		flLeftGroundHeight; // 0x114
      float		flHitGroundWeight; // 0x118 // from 0 to 1, is 1 when standing
      float		flWalkToRunTransition; // 0x11C // from 0 to 1, doesnt change when walking or crouching, only running
      char	pad3[0x4]; // 0x120
      float		flAffectedFraction; // 0x124 // affected while jumping and running, or when just jumping, 0 to 1
      char	pad4[0x208]; // 0x128
      float		flMinBodyYaw; // 0x330
      float		flMaxBodyYaw; // 0x334
      float		flMinPitch; //0x338
      float		flMaxPitch; // 0x33C
      int			iAnimsetVersion; // 0x340
  } CCSGOPlayerAnimationState_534535_t;

  struct animlayer_s {
    float   m_anim_time;
    float   m_fade_out_time;
    int     m_flags;
    int     m_activty;  
    int     m_priority;
    int     m_order;      
    int     m_sequence;
    float   m_prev_cycle;
    float   m_weight;
    float   m_weight_delta_rate;
    float   m_playback_rate;
    float   m_cycle;
    int     m_owner;
    int     m_bits;
};
]]

ffi.cdef [[
  typedef unsigned long DWORD;
  typedef
  const char * LPCSTR;
  typedef unsigned char BYTE;
  typedef unsigned short WORD;
  typedef long LONG;

  typedef struct _POINTL {
    LONG x;
    LONG y;
  }
  POINTL, * PPOINTL;

  typedef struct _devicemodeA {
    BYTE dmDeviceName[32];
    WORD dmSpecVersion;
    WORD dmDriverVersion;
    WORD dmSize;
    WORD dmDriverExtra;
    DWORD dmFields;
    union {
      struct {
        short dmOrientation;
        short dmPaperSize;
        short dmPaperLength;
        short dmPaperWidth;
        short dmScale;
        short dmCopies;
        short dmDefaultSource;
        short dmPrintQuality;
      }
      DUMMYSTRUCTNAME;
      POINTL dmPosition;
      struct {
        POINTL dmPosition;
        DWORD dmDisplayOrientation;
        DWORD dmDisplayFixedOutput;
      }
      DUMMYSTRUCTNAME2;
    }
    DUMMYUNIONNAME;
    short dmColor;
    short dmDuplex;
    short dmYResolution;
    short dmTTOption;
    short dmCollate;
    BYTE dmFormName[32];
    WORD dmLogPixels;
    DWORD dmBitsPerPel;
    DWORD dmPelsWidth;
    DWORD dmPelsHeight;
    union {
      DWORD dmDisplayFlags;
      DWORD dmNup;
    }
    DUMMYUNIONNAME2;
    DWORD dmDisplayFrequency;
    DWORD dmICMMethod;
    DWORD dmICMIntent;
    DWORD dmMediaType;
    DWORD dmDitherType;
    DWORD dmReserved1;
    DWORD dmReserved2;
    DWORD dmPanningWidth;
    DWORD dmPanningHeight;
  }
  DEVMODEA, * PDEVMODEA, * NPDEVMODEA, * LPDEVMODEA;

  bool EnumDisplaySettingsA(
    int lpszDeviceName,
    DWORD iModeNum,
    DEVMODEA * lpDevMode
  );
]]


local ENTITY_LIST_POINTER = ffi.cast("void***", Utils.CreateInterface("client.dll", "VClientEntityList003")) or error("Failed to find VClientEntityList003!")
local GET_CLIENT_ENTITY_FN = ffi.cast("uintptr_t (__thiscall*)(void*, int)", ENTITY_LIST_POINTER[0][3])

ffi.cdef([[
	typedef struct
	{
		void* steam_client;
		void* steam_user;
		void* steam_friends;
		void* steam_utils;
		void* steam_matchmaking;
		void* steam_user_stats;
		void* steam_apps;
		void* steam_matchmakingservers;
		void* steam_networking;
		void* steam_remotestorage;
		void* steam_screenshots;
		void* steam_http;
		void* steam_unidentifiedmessages;
		void* steam_controller;
		void* steam_ugc;
		void* steam_applist;
		void* steam_music;
		void* steam_musicremote;
		void* steam_htmlsurface;
		void* steam_inventory;
		void* steam_video;
	} S_steamApiCtx_t;
]])

local pS_SteamApiCtx = ffi.cast(
	"S_steamApiCtx_t**", ffi.cast(
		"char*",
		Utils.PatternScan(
			"client.dll",
			"FF 15 ?? ?? ?? ?? B9 ?? ?? ?? ?? E8 ?? ?? ?? ?? 6A"
		)
	) + 7
)[0] or error("invalid interface", 2)

local native_ISteamFriends = ffi.cast("void***", pS_SteamApiCtx.steam_friends)
local native_ISteamUtils = ffi.cast("void***", pS_SteamApiCtx.steam_utils)
local native_ISteamFriends_GetSmallFriendAvatar = ffi.cast("int(__thiscall*)(void*, uint64_t)" ,native_ISteamFriends[0][34] )
local native_ISteamUtils_GetImageSize = ffi.cast("bool(__thiscall*)(void*, int, uint32_t*, uint32_t*)" , native_ISteamUtils[0][5])
local native_ISteamUtils_GetImageRGBA =  ffi.cast("bool(__thiscall*)(void*, int, unsigned char*, int)" , native_ISteamUtils[0][6])



ffi.cdef [[
    typedef struct {
        uint8_t r;
        uint8_t g;
        uint8_t b;
        uint8_t a;
    } color_struct_t;

    typedef void (*console_color_print)(void*, const color_struct_t&, const char*, ...);
]]

local engine_client = Utils.CreateInterface("vstdlib.dll", "VEngineCvar007") or error("(")
local engine_client_class = ffi.cast(ffi.typeof("void***"), engine_client) or error("(")
local console_print_color_cast = ffi.cast("void(__cdecl*)(void*, void*, const char*)", engine_client_class[0][25]) or error("(")
--#endregion

--#region ui_and_stuff
Render.Texts = function(text, pos, col, size, font, bool)
    if font == nil then
        Render.Text(text, pos + Vector2.new(1, 1), Color.new(0, 0, 0, col.a), size, false , bool)
        Render.Text(text, pos, col, size, false , bool)
    else
        Render.Text(text, pos + Vector2.new(1, 1), Color.new(0, 0, 0, col.a), size, font, false , bool and bool or false)
        Render.Text(text, pos, col, size, font, false , bool and bool or false )
    end
end

local function get_value(val , n)
    return bit.band(bit.lshift(1, n-1), val) == bit.lshift(1, n-1)
end

local handlers = {
    callbacks = {
        ["draw"] = {},
        ["prediction"] = {},
        ["pre_prediction"] = {},
        ["createmove"] = {},
        ["destroy"] = {},
        ["frame_stage"] = {},
        ["events"] = {},
        ["ragebot_shot"] = {},
        ["registered_shot"] = {},
    },

    fn_data = {

    },

    update = function(self)
        for callback , func_table in pairs(self.callbacks) do
            Cheat.RegisterCallback(callback, function(...)
                for _,func_data in ipairs(func_table) do
                    local start =  Utils.UnixTime()
                    func_data[1](...)
                    self.fn_data[func_data[2]] =  self.fn_data[func_data[2]] + Utils.UnixTime() - start
                end
            end)
        end
    end, 

    add = function(self , callback , func , func_name)
        self.callbacks[callback][#self.callbacks[callback]+1] = {func , func_name }
        self.fn_data[func_name] = 0 
    end,

    log = function(self)
        local all_time = Utils.UnixTime() - start_time
        for fn_name, time in pairs(self.fn_data) do print_dbg("Function " ..fn_name .. " took " .. time .. " ms in total to execute all calls. Average execution time is " .. time/all_time .. " ms") end
    end
}

local refs = {
    dt = Menu.FindVar("Aimbot", "Ragebot", "Exploits", "Double Tap"),
    yawbase = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Base"),
    hs = Menu.FindVar("Aimbot", "Ragebot", "Exploits", "Hide Shots"),
    fd = Menu.FindVar("Aimbot", "Anti Aim", "Misc", "Fake Duck"),
    sw = Menu.FindVar("Aimbot", "Anti Aim", "Misc", "Slow Walk"),
    left_limit = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Left Limit"),
    lbymode = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "LBY Mode"),
    hc = Menu.FindVar("Aimbot", "Ragebot","Accuracy" ,"Hit Chance"),
    right_limit = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Right Limit"),
    fakeopt = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Fake Options"),
    invert = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Inverter"),
    baim = Menu.FindVar("Aimbot", "Ragebot", "Misc", "Body Aim"),
    safe = Menu.FindVar("Aimbot", "Ragebot", "Misc", "Safe Points"),
    free_dsy = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Freestanding Desync"),
    shot_dsy = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Desync On Shot"),
    yaw_b = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Base"),
    yaw_add = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Add"),
    desync = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Enable Fake Angle"),
    yaw_mod = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Modifier"),
    yaw_mod_deg = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Modifier Degree"),
    peek = Menu.FindVar("Miscellaneous", "Main", "Movement", "Auto Peek"),
    stop = Menu.FindVar("Aimbot", "Ragebot", "Misc", "Conditions"),
    fl_limit = Menu.FindVar("Aimbot", "Anti Aim", "Fake Lag", "Limit"),
    wind = Menu.FindVar("Miscellaneous", "Main", "Other", "Windows"),
    logs = Menu.FindVar("Miscellaneous", "Main", "Other", "Event Log"),
    hitsound = Menu.FindVar("Visuals" , "World" , "Hit" , "Hit Sound"),
    lines = Menu.FindVar("Visuals" , "View" , "Camera" , "Remove Scope"),
    aa_main = Menu.FindVar("Aimbot" , "Anti Aim" , "Main" , "Enable Anti Aim"),
    rb = Menu.FindVar("Aimbot" , "Ragebot" , "Main" , "Enable Ragebot"),
}


local refs_v = {}

for k,v in pairs(refs) do 
    refs_v[k] = v:Get() 
    v:RegisterCallback( function (val) 
        refs_v[k] = val 
    end) 
end

local fonts = {
    verdana_10 = Render.InitFont("Verdana", 11, {'r'}),
    degree = Render.InitFont("Tahoma", 11, {'r'}),
    font_log = Render.InitFont("Lucida Console", 10 , {"r"}),
}

local globals = {
    global_enabled = false,
    visuals_enabled = false,
    misc_enabled = false,
    watermark_enabled = false,
    custom_name_string = "",
    palette = 0, 
    screen_size = EngineClient.GetScreenSize(),
    legit_aa_on = false,
    low_delta_on = false,     
    username = Cheat.GetCheatUserName(),
    bounds_offset = 24,
    spectators_moving = false,
    keybinds_moving = false,
    hitboxes = {"generic", "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "?"},
    screen_center = EngineClient.GetScreenSize() / 2,
    fake_height = 0,
    watermark_h = 0,
    in_antibrute = false,
    in_antibrute2 = false,
    abrute_timer = 0,
    abrute_phase = -1,
    abrute_phases = 2,
    flick = false,
    predicted_pos = Vector.new(0,0,0),
    predicted_pos_after_dt = Vector.new(0,0,0),
    teleported_last_tick = false,
    manual_keys = {

    },
    build = (Cheat.GetCheatUserName() == "Kikron" or Cheat.GetCheatUserName() == "Mishkat" or Cheat.GetCheatUserName() == "lenin") and "dev" or (Cheat.GetCheatUserName() == "fipp" and "паренёк" or "beta"),
    cur_yaw_base = 0,
    aa_dis = false,
}

function color(r, g, b, a)
    if not a then
        a = 255
    end
    if not b then
        b = 0
    end
    return Color.new(r / 255, g / 255, b / 255, a / 255)
end



local helpers = {
    set_visibility = function(array, visibility, iskluchenie)
        for i, element in pairs(array) do
            if iskluchenie and i == iskluchenie then
                goto continue
            end
            element:SetVisible(visibility)
            ::continue::
        end
    end,
    get_origin = function (ent)
        if not ent then return Vector.new(0,0,0) end
        return ent:GetProp("m_vecOrigin")
    end,
    round = function(x)
        return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
    end,
    lerp = function(self ,start,end_pos,time,delta)
        if (math.abs(start-end_pos) < (delta or 0.01)) then return end_pos end

        time = GlobalVars.frametime * (time * 175) 
        if time < 0 then
          time = 0.01
        elseif time > 1 then
          time = 1
        end
        return ((end_pos - start)*time +start)
    end,
    sine3 = function(start , end_p , time , d) -- p
        local delta = end_p - start

        if math.abs(delta)< d then return end_p end

        if delta > 0 then
            return start + (math.sin(delta)^3 +delta )*time
        else
            return start - (math.sin(delta)^3- delta  )*time
        end
    end,
    lerp_color = function (self , start_pos, end_pos, time)
        time = GlobalVars.frametime * (time * 175) 
        if time < 0 then
            time = 0.01
        elseif time > 1 then
            time = 1
        end

        local r, g, b, a = start_pos.r, start_pos.g, start_pos.b, start_pos.a
        local r1, g1, b1, a1 = end_pos.r, end_pos.g, end_pos.b, end_pos.a
        
        return Color.new( self:lerp(r , r1 , 0.095 , 0.01), self:lerp(g , g1 , 0.095 , 0.01), self:lerp(b , b1 , 0.095 , 0.01), self:lerp(a , a1 , 0.095 , 0.01))

    end,
    extrapolate = function(ent , origin , ticks , air)
        local tickinterval = GlobalVars.interval_per_tick
        local sv_gravity = CVar.FindVar("sv_gravity"):GetFloat() * tickinterval*0.5
        local sv_jump_impulse = CVar.FindVar("sv_jump_impulse"):GetFloat() * tickinterval*0.5
        local sv_air_acc = CVar.FindVar("sv_airaccelerate"):GetFloat()
        local velocity = Vector.new(ent:GetProp("DT_BasePlayer", "m_vecVelocity[0]"), ent:GetProp("DT_BasePlayer", "m_vecVelocity[1]"), ent:GetProp("DT_BasePlayer", "m_vecVelocity[2]"))
        local orig , extrapolated = origin,origin
    
        
        local air_check = (bit.band(ent:GetProp("m_fFlags") , 1 ) == 0) and 1 or 0
        local up_velmod = velocity.z  + sv_jump_impulse*ticks*tickinterval*air_check
        extrapolated = Vector.new(origin.x + velocity.x*tickinterval*ticks,origin.y + velocity.y*tickinterval*ticks,origin.z + up_velmod*ticks*tickinterval*air)
        

        return extrapolated
    
    end,
    HSVToRGB = function(h, s, v)
        local r, g, b

        local i = math.floor(h * 6);
        local f = h * 6 - i;
        local p = v * (1 - s);
        local q = v * (1 - f * s);
        local t = v * (1 - (1 - f) * s);

        i = i % 6

        if i == 0 then
            r, g, b = v, t, p
        elseif i == 1 then
            r, g, b = q, v, p
        elseif i == 2 then
            r, g, b = p, v, t
        elseif i == 3 then
            r, g, b = p, q, v
        elseif i == 4 then
            r, g, b = t, p, v
        elseif i == 5 then
            r, g, b = v, p, q
        end

        return Color.new(r, g, b, 1)
    end,
    calc_angle = function(src, dst)
        local vecdelta = Vector.new(dst.x - src.x, dst.y - src.y, dst.z - src.z)
        local angles = QAngle.new(math.atan2(-vecdelta.z, vecdelta:Length2D()) * 180.0 / math.pi, (math.atan2(vecdelta.y, vecdelta.x) * 180.0 / math.pi), 0.0)
        return angles
    end,
    get_entity_address = function(entity_index)
        local addr = GET_CLIENT_ENTITY_FN(ENTITY_LIST_POINTER, entity_index)
        return addr
    end,
    is_entity_alive = function(entity)
        if not entity then
            return false
        end
        local hp = entity:GetProp("m_iHealth")
        if not hp then
            return false
        end
        return entity:GetProp("m_iHealth") > 0
    end,
    json = Panorama.LoadString([[
        return {
            stringify: JSON.stringify,
            parse: JSON.parse
        };
    ]])(),
    get_steam_id_fn = function (ent_idx)
        local panorama_handle = Panorama.Open()
        local huy = panorama_handle.GameStateAPI.GetPlayerXuidStringFromEntIndex(ent_idx)
    
        return huy
    end,
    color_print = function (str, color)
        local color_struct = ffi.new("color_struct_t")

        color_struct.r = color.r * 255
        color_struct.g = color.g * 255
        color_struct.b = color.b * 255
        color_struct.a = 255

        return console_print_color_cast(engine_client_class , color_struct, tostring(str))
    end,
    normalize_angles = function(angles)
        while (angles.pitch > 89.0) do
            angles.pitch = angles.pitch - 180.0
        end
        while (angles.pitch < -89.0) do
            angles.pitch = angles.pitch + 180.0
        end
        while (angles.yaw < -180.0) do
            angles.yaw = angles.yaw + 360.0
        end
        while (angles.yaw > 180.0) do
            angles.yaw = angles.yaw - 360
        end
        angles.roll = 0

        return angles
    end,

    normalize_angle = function (angle)
        if angle < -180 then angle = angle + 360 end
        if angle > 180 then angle = angle - 360 end
        return angle
    end,
    closest_point_on_ray = function(ray_from, ray_to, desired_point)
        local to = desired_point - ray_from
        local direction = ray_to - ray_from
        local ray_length = direction:Length()
    
        direction.x = direction.x / ray_length
        direction.y = direction.y / ray_length
        direction.z = direction.z / ray_length
    
        local direction_along = direction.x * to.x + direction.y * to.y + direction.z * to.z
        if direction_along < 0 then
            return ray_from
        end
        if direction_along > ray_length then
            return ray_to
        end
    
        return Vector.new(ray_from.x + direction.x * direction_along, ray_from.y + direction.y * direction_along,
            ray_from.z + direction.z * direction_along)
    end,
    clamp = function(value, min, max)
        return math.max(math.min(value , max) , min)
    end,
    cm_check = function()
        local IsConnected = EngineClient.IsConnected()
        if (not IsConnected) then
            return false
        end
        local localplayer = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
        if localplayer == nil then
            return
        end
        local player = localplayer:GetPlayer()
        local health = localplayer:GetProp("m_iHealth")
        if (health == 0) then
            return false
        end
        return true
    end,
    

    data_crypt = {
        json = Panorama.LoadString([[
            return {
                stringify: JSON.stringify,
                parse: JSON.parse
            };
        ]])(),

        base64 = {
            codes = {'=/+9876543210zyxwvutsrqponmlkjihgfedcbaZYXWVUTSRQPONMLKJIHGFEDCBA', 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=', "AaGpJ3HxhkVCQ6g5TRb/MdSE9qjc24rOYWD1yXwtufleFI0sP7n8+NiULovBmzZK="},
            encode = function (self, str, type_c)
                local b = self.codes[type_c or 1]
                return ((str:gsub('.', function(x) 
                    local r,b='',x:byte()
                    for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
                    return r;
                end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
                    if (#x < 6) then return '' end
                    local c=0
                    for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
                    return b:sub(c+1,c+1)
                end)..({ '', '==', '=' })[#str%3+1])
            end,
            decode = function (self, data, type_c)
                local b = self.codes[type_c or 1]

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
        }
    },

    in_bounds = function(vec1, vec2)
        local mouse_pos = Cheat.GetMousePos()
        return mouse_pos.x >= vec1.x and mouse_pos.x <= vec2.x and mouse_pos.y >= vec1.y and mouse_pos.y <= vec2.y 
    end,
    get_relative_position = function(pos)
        local mouse_pos = Cheat.GetMousePos()
        return mouse_pos-pos
    end, 

}


local cur_id = 0
local draggables = { windows = {}}
draggables.__index = draggables

function draggables:new(id, size, pos, ui_x, ui_y)
    local draggable = {}
    setmetatable(draggable, draggables)

    draggable.id = id
    draggable.size = size
    draggable.pos = pos
    draggable.rel_pos = Vector2.new(0,0)
    draggable.drag = false
    draggable.ui = {ui_x, ui_y}
    self.windows[#self.windows+1] = draggable
    return draggable
end

function draggables:update()
  
    if not Cheat.IsKeyDown(1)  then 
        cur_id = 0 
        self.rel_pos = Vector2.new(0,0)   
        self.drag = false
        return 
    end
    if not self.drag then    
        self.drag = helpers.in_bounds(self.pos,self.pos + self.size)
    end
    
    if not (helpers.in_bounds(self.pos,self.pos + self.size) or  self.drag) or not Cheat.IsMenuVisible() or (cur_id~=self.id and cur_id~=0) then return end

    if self.rel_pos:Length()==0 then
        self.rel_pos = helpers.get_relative_position(self.pos)
    end

    cur_id = self.id

    self.pos = Cheat.GetMousePos() -  self.rel_pos
    self.ui[1]:Set(self.pos.x)
    self.ui[2]:Set(self.pos.y)
end    

function draggables.adjust_pos(self)
    for _, window in pairs(self.windows) do
        window.pos = Vector2.new(window.ui[1]:Get(), window.ui[2]:Get())
    end
end
ffi.cdef[[
     void* CreateFileA(
          const char*                lpFileName,
          unsigned long                 dwDesiredAccess,
          unsigned long                 dwShareMode,
          unsigned long lpSecurityAttributes,
          unsigned long                 dwCreationDisposition,
          unsigned long                 dwFlagsAndAttributes,
          void*                hTemplateFile
          );
     bool ReadFile(
               void*       hFile,
               char*       lpBuffer,
               unsigned long        nNumberOfBytesToRead,
               unsigned long*      lpNumberOfBytesRead,
               int lpOverlapped
               );
     bool WriteFile(
               void*       hFile,
               char*      lpBuffer,
               unsigned long        nNumberOfBytesToWrite,
               unsigned long*      lpNumberOfBytesWritten,
               void* lpOverlapped
          );
    bool DeleteFileA(
        const char* lpFileName
      );

     unsigned long GetFileSize(
          void*  hFile,
          unsigned long* lpFileSizeHigh
     );
     bool CreateDirectoryA(
          const char*                lpPathName,
          void* lpSecurityAttributes
     );
     void* CloseHandle(void *hFile);
     typedef int(__fastcall* clantag_t)(const char*, const char*);

     typedef struct _OVERLAPPED {
          unsigned long* Internal;
          unsigned long* InternalHigh;
          union {
               struct {
               unsigned long Offset;
               unsigned long OffsetHigh;
               } DUMMYSTRUCTNAME;
               void* Pointer;
          } DUMMYUNIONNAME;
          void*    hEvent;
          } OVERLAPPED, *LPOVERLAPPED;

     typedef struct _class
     {
          void** this;
     }aclass;
]]
ffi.C.CreateDirectoryA("nl\\exscord", nil)


local ui = {

    info = {
        text1 = Menu.Text("Global", script_name.. " - Information", "Welcome,  GJ MISHKAT AXAXAX!"),
        text2 = Menu.Text("Global", script_name.. " - Information", "Current Build: GJ MISHKAT AXAXAX!"),
        text3 = Menu.Text("Global", script_name.. " - Information", "Latest update date: GJ MISHKAT AXAXAX! "),
        text4 = Menu.Text("Global", script_name.. " - Information", "Update log can be found on marketplace / GJ MISHKAT AXAXAX!."),
        discord = Menu.Button("Global", script_name.. " - Information", "exscord official discord", "Click button to join exscord discord server."),
        font = Menu.Button("Global" , script_name..  " - Information" , "Download Font" , "" , function()
            local bytes = Http.Get("https://fontsforyou.com/downloads/99851-smallestpixel7")
            local pfile = ffi.cast("void*", ffi.C.CreateFileA(ffi.cast("const char *", "nl\\exscord\\smallest_pixel-7.ttf"), 0xC0000000, 0x00000003, 0, 0x4, 0x80, nil))
            if (not pfile) then 
                Cheat.AddNotify(script_name, "Failed to create font file, please restart the script or create a ticket.") 
                return
            end
            local overlapped = ffi.new("OVERLAPPED")
            overlapped.DUMMYUNIONNAME.DUMMYSTRUCTNAME.Offset = 0xFFFFFFFF
            overlapped.DUMMYUNIONNAME.DUMMYSTRUCTNAME.OffsetHigh = 0xFFFFFFFF
            ffi.C.WriteFile(pfile, ffi.cast("char*" , bytes) , 25600 , nil ,  ffi.cast("void*", overlapped))
            ffi.C.CloseHandle(pfile)
            Cheat.AddNotify(script_name , "Font has been succesfully downloaded, please restart script!")
        end),
        def_cfg = Menu.Button("Global", script_name.. " - Configuration", "Load default config", "Loads mishkat's settings."),
        export_cfg = Menu.Button("Global", script_name.. " - Configuration" , "Export to clipboard", "Exports your current lua settings to clipboard."),
        import_cfg = Menu.Button("Global", script_name.. " - Configuration" , "Import from clipboard", "Imports copied settings from your clipboard.")

    },

    rage = {
        master_rage = Menu.Switch("Ragebot", script_name.. " - Ragebot", "Master Switch", false, "Enable exscord rage functions"),
        hc_main = Menu.MultiCombo("Ragebot", script_name.. " - Ragebot", "Custom hitchance", {"In-Air", "Noscope"}, 0, "Overrides your hitchance on selected conditions. \n In-Air HitChance Works only for Revolver, Scout. \n No-Scope HitChance works only for Auto."),
        ahc = Menu.SliderInt("Ragebot", script_name.. " - Ragebot", "In-Air Hitchance", 20, 0, 100),
        nhc = Menu.SliderInt("Ragebot", script_name.. " - Ragebot", "Noscope Hitchance", 40, 0, 100),
        logs = Menu.Switch("Ragebot", script_name.. " - Ragebot", "Aimbot logs", false, "Prints aimbot logs in-game console."),
        logs_type = Menu.MultiCombo("Ragebot" ,  script_name.. " - Ragebot" , "Logs to print" , {"Fire logs" , "Hit logs" , "Miss logs" , "Harmed logs"} , 0),
    
        shtu4ka = Menu.Switch("Ragebot", script_name.. " - Ragebot", "Automatic Teleport Exploit in Air" , false),
        teleport_wps = Menu.MultiCombo("Ragebot", script_name.. " - Ragebot", "Teleport Weapons" , {"AWP" , "AutoSnipers" ,"Scout" ,"Heavy Pistols" , "Pistols" , "Nades" , "Taser" , "Other"} , 0),
    
        anti_mishkat = Menu.Switch("Ragebot", script_name.. " - Ragebot" , "Anti-Defensive" , false, "Exploit makes you predict defensive doubletap."),


        d_switch = Menu.Switch("Ragebot", script_name.. " - Ragebot", "Dormant Aimbot", false, "Makes Aimbot shoots at dormant targets."),
        d_min_damage = Menu.SliderInt("Ragebot", script_name.. " - Ragebot", "Mindamage", 1, 1, 100),

    },
    aa = {



        aa_main = Menu.Switch("Anti-Aim", script_name.. " - Anti-aims", "Master Switch", false, "Enable exscord anti-aim functions"),
        warmup_disablers = Menu.Switch("Anti-Aim", script_name.. " - Anti-aims", "Disable on warmup" , false),
        gandon_ui = Menu.SliderInt("Anti-Aim", script_name.. "" , "",2, 2 , 10 ),
      


        edge = Menu.Switch("Anti-Aim", script_name.. " - Anti-aims", "Edge Yaw", false, "Hides your head in the nearest wall."),
        abstab = Menu.Switch("Anti-Aim", script_name.. " - Anti-aims" , "Anti Backstab" , false, "Changes your anti-aims to prevent you from knife backstab."),
        legit_aa = Menu.Switch("Anti-Aim", script_name.. " - Anti-aims", "Legit Anti-Aim On E", false, "Enables Legit AA on E key."),

        animfuck = Menu.Switch("Anti-Aim" ,  script_name.. " - Anti-aims" , "Animation Breakers" , false),
        legfuc = Menu.MultiCombo("Anti-Aim", script_name.. " - Anti-aims", "Breakers", {"Static Legs In Air" , "Leg Breaker"} , 0 , "Breakes your animations."),
        fake_flick  = Menu.Switch("Anti-Aim", script_name.. " - Anti-aims" , "Fake Flick" , false, "Flicks your anti-aim to make enemy miss."),
        extended_dsy = Menu.Switch("Anti-Aim" ,  script_name.. " - Anti-aims" , "Extended Lean" , false),
        dfl = Menu.Switch("Anti-Aim" ,  script_name.. " - Anti-aims" , "Adjust fakelag limit" , false ),
        abrute = Menu.Switch("Anti-Aim", script_name.. " - Anti-aims", "Anti-Bruteforce", false, "Basicly inverts your desync side when someone shoots near at your body, or hit you."),
        abrute_disables = Menu.MultiCombo("Anti-Aim", script_name.. " - Anti-aims" , "Disablers" , {"In-Air" , "Slow motion" , "Crouching"} , 0, "Disables anti-bruteforce in selected conditions."),
        type = Menu.Switch("Anti-Aim", script_name.. " - Anti-aims", "Anti-aim system",  false, "Custom anti-aims per conditions."),
        
        aa_type = Menu.Combo("Anti-Aim" ,  script_name.. " - Anti-aims" , "Anti-aim type" , {"Preset" , "Custom"} , 0),

        aa_presets = Menu.Combo("Anti-Aim" ,  script_name.. " - Anti-aims" , "Preset" , {"Hybrid" , "Alternative" } , 0),
        

        
        cond = Menu.Combo("Anti-Aim", script_name.. " - Anti-aims", "Player state", {"Global", "Standing", "Slow motion", "Moving", "Air", "Crouching", "Legit AA"}, 0),

        manual = Menu.Combo("Anti-Aim" , script_name..  " - Anti-aims" , "Manual Yaw Basе" , { "Disabled", "Forward" , "Backward" , "Right" , "Left" , "At Target" , "Freestanding"} , 0),
    
        enabled = {},
        yaw_base = {},
        yaw_add = {},
        yaw_add2 = {},
        yaw_mod = {},
        yaw_mod_deg = {},
        onshot = {},
        pitch = {},
        fake_opt = {},
        lby = {},
        freestand = {},
        r_limit = {},
        l_limit = {},
        e_fakejit = {},
        phases = {},

    },
    vis = {
        palette = Menu.ComboColor("Visuals", script_name.. " - Visuals UI", "UI Theme", {"Flat","Flat Fade" ,"Fade", "Animated Fade"}, 0,Color.new(1,1,1,1) , "Theme for UI elements."),
        rainbow_speed = Menu.SliderFloat("Visuals", script_name.. " - Visuals UI", "Animation Speed", 5, 0, 10, "Animation speed for fade."),
        ui_elem = Menu.MultiCombo("Visuals", script_name.. " - Visuals UI","UI elements", {"Watermark" , "Keybinds" , "Spectator List" , "Fake Indicator" , "Performance bar", "Menu Header", "Slowdown indicator" }, 0, "Allows you to choose what ui elements will be enabled."),
        blur_bg = Menu.SwitchColor("Visuals", script_name.. " - Visuals UI" , "Blur Background" , false, Color.new(1,1,1,1) , "Allows you to choose whether to blur background or not"),
        watermark_custom = Menu.Switch("Visuals", script_name.. " - Visuals UI", "Custom Name" , false),
        watermark_name = Menu.TextBox("Visuals", script_name.. " - Visuals UI" , "" , 64, globals.username ),
        hitsound = Menu.Switch("Visuals", script_name.. " - Visuals UI" , "Skeet Hitsound" , false , "Enables Skeet Hitsound" , function(v) refs.hitsound:Set(not v) end),
        hitsound_vol = Menu.SliderInt("Visuals", script_name.. " - Visuals UI" , "Hitsound Volume" , 100 , 0, 100 ),
        clantag = Menu.Switch("Visuals", script_name.. " - Visuals UI", "Clantag", false, "Unique exscord clantag."),

        -- do not touch
        kx = Menu.SliderInt("Visuals", script_name.. " - Visuals UI", "kx" , 500 , 0, globals.screen_size.x),
        ky = Menu.SliderInt("Visuals", script_name.. " - Visuals UI", "ky" , 500 , 0 , globals.screen_size.y),
        
        sx = Menu.SliderInt("Visuals", script_name.. " - Visuals UI", "sx" , 700 , 0, globals.screen_size.x),
        sy = Menu.SliderInt("Visuals",  script_name.. " - Visuals UI","sy" , 500 , 0 , globals.screen_size.y),

        vx = Menu.SliderInt("Visuals", script_name.. " - Visuals UI", "vx", globals.screen_size.x / 2, 0, globals.screen_size.x),
        vy = Menu.SliderInt("Visuals", script_name.. " - Visuals UI", "vy", globals.screen_size.y / 2 - 60, 0, globals.screen_size.y),

        --


        custom_scope = Menu.SwitchColor("Visuals", script_name.. " - Indicators", "Custom Scope Lines", false,Color.new(1,1,1,1) ,"Overrides your scope lines to gradient one." , function(v) refs.lines:Set(v==true and 2 or 1) end),
        custom_scope_invert = Menu.Combo("Visuals", script_name.. " - Indicators", "Scope Style" , {"Default" , "Inverted"} , 0),
        custom_scope_size = Menu.SliderInt("Visuals", script_name.. " - Indicators", "Scope Lines Size", 100, 0, 1000, "Size of custom lines."),
        custom_scope_gap = Menu.SliderInt("Visuals", script_name.. " - Indicators", "Scope Lines Gap", 10, 0, 100, "Gap between lines."),
        custom_scope_show = Menu.Switch("Visuals", script_name.. " - Indicators", "Show weapon in scope", false, "Shows weapon model in scope."),
        cross_main = Menu.SwitchColor("Visuals", script_name.. " - Indicators", "Screen indicators", false,Color.new(1,1,1,1) ,"Unique screen indicators."),
        arrows_main = Menu.SwitchColor("Visuals", script_name.. " - Indicators", "Manual Arrows", false,Color.new(1,1,1,1), "Shows arrows."),
        arrows_style = Menu.Combo("Visuals" ,  script_name.. " - Indicators" , "Arrows Type" , {"Default" , "Team Skeet"} , 0),
    },



    adjust_abrute = function (self)
        local n = self.aa.gandon_ui:Get()
        globals.abrute_phase = 0
        globals.abrute_phases = n
    end,

    adjust_vis = function (self)
        
        local m = self.vis
        local scope = m.custom_scope:Get()
        local ind = m.cross_main:Get()
        local arr = m.arrows_main:Get() and ind

        m.arrows_style:SetVisible(arr)
        m.custom_scope_size:SetVisible(scope)
        m.custom_scope_gap:SetVisible(scope)
        m.custom_scope_invert:SetVisible(scope)
        m.arrows_main:SetVisible(ind)
        m.watermark_custom:SetVisible(m.ui_elem:GetBool(1) )
        m.watermark_name:SetVisible(m.watermark_custom:Get() and m.ui_elem:GetBool(1) )

        m.kx:SetVisible(false)
        m.sx:SetVisible(false)
        m.ky:SetVisible(false)
        m.sy:SetVisible(false)
        m.vx:SetVisible(false)
        m.vy:SetVisible(false)

        local m = self.vis
        local shit = m.ui_elem:Get()~=0
        local p = m.palette:Get()

        m.blur_bg:SetVisible(shit)
        m.hitsound_vol:SetVisible(m.hitsound:Get())

        m.rainbow_speed:SetVisible(shit and p==3)
    end,

    adjust_rage = function (self)
        local m = self.rage
        local e = m.master_rage:Get()
        local d = m.d_switch:Get() and e
        local hc = m.hc_main

        local l = m.logs:Get() and e

        m.logs_type:SetVisible(l)
        m.shtu4ka:SetVisible(e)
        m.teleport_wps:SetVisible(e and m.shtu4ka:Get())
        m.hc_main:SetVisible(e)
        m.ahc:SetVisible(hc:GetBool(1) and e)
        m.nhc:SetVisible(hc:GetBool(2) and e)
        m.logs:SetVisible(e)
        m.anti_mishkat:SetVisible(e)
        m.d_switch:SetVisible(e)
        m.d_min_damage:SetVisible(d)
    end,

    adjust_aa = function (self)

        local m = self.aa
        local e = m.aa_main:Get()
        local t = m.type:Get() and m.aa_type:Get()==1
        local c = m.cond:Get()
        local ab = m.abrute:Get()
        m.warmup_disablers:SetVisible(e)
        m.edge:SetVisible(e)
        m.abstab:SetVisible(e)
        m.legit_aa:SetVisible(e)
        m.aa_presets:SetVisible(e and m.type:Get() and m.aa_type:Get()==0)
        m.aa_type:SetVisible(m.type:Get() and e)
        m.fake_flick:SetVisible(e)
        m.abrute:SetVisible(e)
        m.abrute_disables:SetVisible(ab and e)
        m.animfuck:SetVisible(e)
        m.legfuc:SetVisible(e and m.animfuck:Get())
        m.gandon_ui:SetVisible(false)
        m.dfl:SetVisible(  e  )
        m.manual:SetVisible(e and m.type:Get())

        m.extended_dsy:SetVisible(e)


        for i=1 , 7 do
            if i>1 then
                m.enabled[i-1]:SetVisible(t and c+1==i and e)
            end
            local sss = i==1 or m.enabled[i-1]:Get() 
            
            if i~=7 then
                m.pitch[i]:SetVisible(t and c+1==i and e and sss)
                m.yaw_base[i]:SetVisible(t and c+1==i and e and sss)
            end
        
        end

        for i=1,7 do

            if c==0 then
                local b = i==1 and e and t

                m.yaw_add[i] :SetVisible(b )
                m.yaw_add2[i] :SetVisible(b )
                m.yaw_mod[i]:SetVisible(b )
                m.yaw_mod_deg[i]:SetVisible(b and  m.yaw_mod[i]:Get()~=0)
                m.fake_opt[i] :SetVisible(b )
                m.lby[i]:SetVisible(b  )
                m.freestand[i]:SetVisible(b )
                m.l_limit[i]:SetVisible(b )
                m.r_limit[i]:SetVisible(b )
                m.e_fakejit[i]:SetVisible(b )            
                m.onshot[i]:SetVisible(b )

            else
                local b = i==c+1 and e and t
                local b2 = e and t and i==c+1
                if i~=1 and i==c+1 then
                    if m.enabled[i-1]:Get() then
                        
                        m.yaw_add[i] :SetVisible(b )
                        m.yaw_add2[i] :SetVisible(b )
                        m.yaw_mod[i]:SetVisible(b )
                        m.yaw_mod_deg[i]:SetVisible(b and  m.yaw_mod[i]:Get()~=0)
                        m.fake_opt[i] :SetVisible(b )
                        m.lby[i]:SetVisible(b  )
                        m.freestand[i]:SetVisible(b )
                        m.l_limit[i]:SetVisible(b )
                        m.r_limit[i]:SetVisible(b )
                        m.e_fakejit[i]:SetVisible(b )            
                        m.onshot[i]:SetVisible(b )

                        m.pitch[1]:SetVisible(false)
                        m.yaw_base[1] :SetVisible(false )
                        m.yaw_add[1] :SetVisible(false )
                        m.yaw_add2[1] :SetVisible(false )
                        m.yaw_mod[1]:SetVisible(false )
                        m.yaw_mod_deg[1]:SetVisible(false and  m.yaw_mod[1]:Get()~=0)
                        m.fake_opt[1] :SetVisible(false )
                        m.lby[1]:SetVisible(false  )
                        m.freestand[1]:SetVisible(false )
                        m.l_limit[1]:SetVisible(false )
                        m.r_limit[1]:SetVisible(false )
                        m.e_fakejit[1]:SetVisible(false )            
                        m.onshot[1]:SetVisible(false )
                    else
                       

            
                        m.yaw_add[i] :SetVisible(false )
                        m.yaw_add2[i] :SetVisible(false )
                        m.yaw_mod[i]:SetVisible(false )
                        m.yaw_mod_deg[i]:SetVisible(false and  m.yaw_mod[i]:Get()~=0)
                        m.fake_opt[i] :SetVisible(false )
                        m.lby[i]:SetVisible(false  )
                        m.freestand[i]:SetVisible(false )
                        m.l_limit[i]:SetVisible(false )
                        m.r_limit[i]:SetVisible(false )
                        m.e_fakejit[i]:SetVisible(false )            
                        m.onshot[i]:SetVisible(false )

                        m.pitch[1]:SetVisible(b2)
                        m.yaw_base[1] :SetVisible(b2 )
                        m.yaw_add[1] :SetVisible(b2 )
                        m.yaw_add2[1] :SetVisible(b2 )
                        m.yaw_mod[1]:SetVisible(b2 )
                        m.yaw_mod_deg[1]:SetVisible(b2 and  m.yaw_mod[1]:Get()~=0)
                        m.fake_opt[1] :SetVisible(b2 )
                        m.lby[1]:SetVisible(b2  )
                        m.freestand[1]:SetVisible(b2 )
                        m.l_limit[1]:SetVisible(b2 )
                        m.r_limit[1]:SetVisible(b2 )
                        m.e_fakejit[1]:SetVisible(b2 )            
                        m.onshot[1]:SetVisible(b2)


                    end
                    
                else

                    m.yaw_add[i] :SetVisible(false )
                    m.yaw_add2[i] :SetVisible(false )
                    m.yaw_mod[i]:SetVisible(false )
                    m.yaw_mod_deg[i]:SetVisible(false and  m.yaw_mod[i]:Get()~=0)
                    m.fake_opt[i] :SetVisible(false )
                    m.lby[i]:SetVisible(false  )
                    m.freestand[i]:SetVisible(false )
                    m.l_limit[i]:SetVisible(false )
                    m.r_limit[i]:SetVisible(false )
                    m.e_fakejit[i]:SetVisible(false )            
                    m.onshot[i]:SetVisible(false )
                end


            end

        end




        m.add_phase:SetVisible(e and ab )
        m.remove_phase:SetVisible(e and ab )

        m.gandon_ui:Set(globals.abrute_phases)

        --for k, v in pairs( m.phases) do v:SetVisible(e and ab) end

        for i=1 , 10 do 
            m.phases[i]:SetVisible(i <= globals.abrute_phases and e and ab)
        end

        m.cond:SetVisible(t and e)
        m.type:SetVisible(e)
    end,


    adjust_ui = function(self)
        self:adjust_rage()
        self:adjust_aa() 
        self:adjust_vis()
     --   if self.vis.ui_elem:Get() == 0 then refs.wind:Set(1) end
        if self.rage.logs:Get() then refs.logs:Set(0) end

    end,
}

globals.abrute_phases = ui.aa.gandon_ui:Get()




ui.aa.gandon_ui:SetVisible(false)


local state2 = {"Global", "Standing" , "Slow motion" , "Moving" , "Air" , "Crouching" , "Legit AA"}
local state1 = {"Standing" , "Slow motion" , "Moving" , "Air" , "Crouching" , "Legit AA"}
local shortstate = {"G", "S" , "SM" , "M" , "A" , "C" , "L"}

for mishkatpidr = 1, 6 do
    ui.aa.enabled[mishkatpidr] = Menu.Switch("Anti-Aim", script_name.. " - Anti-aims" ,"> Enable "..state1[mishkatpidr].." state", false)
    ui.aa.yaw_base[mishkatpidr] = Menu.Combo("Anti-Aim" , script_name.. " - "..state2[mishkatpidr] ,   "["..shortstate[mishkatpidr].."] ".. "Yaw Base" , {"Forward" , "Backward" , "Right" , "Left" , "At Target" , "Freestanding"} , 1 ) 
    ui.aa.pitch[mishkatpidr] = Menu.Combo("Anti-Aim", script_name.. ' - '..state2[mishkatpidr], "["..shortstate[mishkatpidr].."] ".. 'Pitch', {'Disabled', 'Down', 'Fake Down', "Fake Up"}, 1)
end
for i = 1, 7 do
    ui.aa.yaw_add[i] = Menu.SliderInt("Anti-Aim", script_name.. " - "..state2[i],"["..shortstate[i].."] "..  "Left Yaw Add", 0, -180, 180)
    ui.aa.yaw_add2[i] = Menu.SliderInt("Anti-Aim", script_name.. " - "..state2[i],"["..shortstate[i].."] "..  "Right Yaw Add", 0, -180, 180)
    ui.aa.yaw_mod[i] = Menu.Combo("Anti-Aim", script_name.. " - "..state2[i] , "["..shortstate[i].."] ".."Yaw Modifier" , {"Disabled" , "Center" , "Offset" , "Random" , "Spin"} , 0)
    ui.aa.yaw_mod_deg[i] = Menu.SliderInt("Anti-Aim", script_name.. " - "..state2[i] ,   "["..shortstate[i].."] ".."Modifier Degree" , 0 , -180 , 180)
    ui.aa.fake_opt[i] = Menu.MultiCombo("Anti-Aim", script_name.. ' - '..state2[i],  "["..shortstate[i].."] "..'Fake Options', {'Avoid Overlap', 'Jitter', 'Randomize Jitter'}, 0)
    ui.aa.lby[i] = Menu.Combo("Anti-Aim", script_name.. ' - '..state2[i],  "["..shortstate[i].."] "..'LBY Mode', {'Disabled', 'Opposite', 'Sway'}, 0)
    ui.aa.freestand[i] = Menu.Combo("Anti-Aim", script_name.. ' - '..state2[i], "["..shortstate[i].."] ".. 'Freestanding DS', {'Off', 'Default', 'Reversed'}, 0)
    ui.aa.l_limit[i] = Menu.SliderInt("Anti-Aim", script_name.. " - "..state2[i], "["..shortstate[i].."] ".. "Left Fake Limit", 60, 0, 60)
    ui.aa.r_limit[i] = Menu.SliderInt("Anti-Aim", script_name.. " - "..state2[i], "["..shortstate[i].."] ".. "Right Fake Limit", 60, 0, 60)
    ui.aa.onshot[i] = Menu.Combo("Anti-Aim", script_name.. " - "..state2[i] , "["..shortstate[i].."] ".."Desync On Shot" , {"Disabled" , "Opposite" , "Freestanding" , "Switch"} , 0)
    ui.aa.e_fakejit[i] = Menu.Switch("Anti-Aim", script_name.. " - "..state2[i],"["..shortstate[i].."] "..  "Fake Limit Jitter", false)

end


for i=1, 7 do
    ui.aa.yaw_mod[i]:RegisterCallback(function (val)
        ui.aa.yaw_mod_deg[i]:SetVisible(val~=0)
    end)
end

ui.aa.add_phase = Menu.Button("Anti-Aim", script_name.. " - Anti-Bruteforce" , "> Add New Phase" , "" , function ()
    if globals.abrute_phases < 10 then
        globals.abrute_phases = globals.abrute_phases + 1
    end
end)

ui.aa.remove_phase = Menu.Button("Anti-Aim", script_name.. " - Anti-Bruteforce" , "> Remove Phase" , "" , function ()
    if globals.abrute_phases > 2 then
        globals.abrute_phases = globals.abrute_phases - 1
    end        
end)


for i = 1 , 10 do 
    ui.aa.phases[i] = Menu.SliderInt("Anti-Aim", script_name.. " - Anti-Bruteforce" , "["..i.." Phase] Fake Limit" , 60 , -60 , 60)
end

local vis_cb = {ui.vis.custom_scope , ui.vis.ui_elem , ui.vis.palette , ui.vis.cross_main, ui.vis.arrows_main , ui.vis.hitsound , ui.vis.watermark_custom}
local rage_cb = {  ui.rage.hc_main , ui.rage.logs , ui.rage.d_switch, ui.rage.master_rage , ui.rage.shtu4ka}
local aa_cb = {ui.aa.aa_main , ui.aa.type , ui.aa.cond ,ui.aa.abrute, ui.aa.remove_phase ,ui.aa.add_phase, ui.aa.animfuck , ui.aa.aa_type, ui.aa.extended_dsy,unpack(ui.aa.enabled) }




for _ , v in pairs(vis_cb) do v:RegisterCallback( function () ui:adjust_ui() end) end
for _ , v in pairs(rage_cb) do v:RegisterCallback( function () ui:adjust_ui() end) end
for _ , v in pairs(aa_cb) do v:RegisterCallback( function () ui:adjust_ui() end) end
ui:adjust_ui()


local ui_v = {
    aa ={},
    rage = {},
    vis = {},
}

local function init_ui_memoizing()
    for tab_name , tab in pairs({["rage"] =  ui.rage ,["vis"] =  ui.vis ,["aa"] = ui.aa}) do
        for elem_name , elem_ptr in pairs(tab) do
            if (type(elem_ptr)=="table") then
                ui_v[tab_name][elem_name]  = {}
                for i=1 , #elem_ptr do
                
                    ui_v[tab_name][elem_name] [i] = elem_ptr[i]:Get()
                    elem_ptr[i]:RegisterCallback( function(val)
                        ui_v[tab_name][elem_name] [i] = val
                    end)
                end
            else
                ui_v[tab_name][elem_name] = elem_ptr:Get()
                elem_ptr:RegisterCallback( function(val)
                    ui_v[tab_name][elem_name] = val
                end)
            end
        end
    end
end

local function update_ui_memory()
    for tab_name , tab in pairs({["rage"] =  ui.rage ,["vis"] =  ui.vis ,["aa"] = ui.aa}) do
        for elem_name , elem_ptr in pairs(tab) do
            if (type(elem_ptr)=="table") then
                ui_v[tab_name][elem_name]  = {}
                for i=1 , #elem_ptr do
                    ui_v[tab_name][elem_name] [i] = elem_ptr[i]:Get()
                end
            else
                ui_v[tab_name][elem_name] = elem_ptr:Get()
            end
        end
    end
end


init_ui_memoizing()

local font = Render.InitFont("Verdana", 12 , {'r' })
local add_h = -100

local logs_data = {
    logs = {},
    size = 0,

    adjust = function (self)

        if #self.logs >5 then
            for i=1,#self.logs-5 do 
                local log = self.logs[i]

                if not log then goto c end

                log.h = helpers:lerp(log.h ,-(log.num-1)*50 , 0.115 )
                log.col.a = helpers:lerp(log.col.a , 0 , 0.115)
                if log.col.a < 0.01 then table.remove(self.logs , i) end

                ::c::
            end
        else
            for i,log in pairs(self.logs) do
                if  log.time +4 < GlobalVars.curtime then
                    log.h = helpers:lerp(log.h ,-(log.num-1)*50 , 0.115 )
                    log.col.a = helpers:lerp(log.col.a , 0 , 0.115)

                    if log.col.a < 0.01 then table.remove(self.logs , i) end

                else
                    log.h = helpers:lerp(log.h ,-(log.num)*50 , 0.115 )
                    log.col.a = helpers:lerp(log.col.a , 1 , 0.115)
                    log.prog = 1
                end
            end
        end

        for i = 1, #self.logs do
            self.logs[i].num = i
        end

    end,

    paint = function (self)

        if #self.logs < 1 then
            return
        end
        local sss = EngineClient.GetScreenSize()
        local ss = Vector2.new(sss.x/2 , sss.y-200)
        local mult = 0
       
        for i, log in pairs(self.logs) do 
            if log.bb  then
                local ts = Render.CalcTextSize(log.text , 12 , font)
                mult = mult+1

                Render.Blur(ss + Vector2.new(-ts.x/2-7 , log.h -add_h -16),ss + Vector2.new(ts.x/2+7 , 17+log.h -add_h) , Color.new(0.2 , 0.2 , 0.2 , log.col.a*0.5 ) )
                Render.Box(ss + Vector2.new(-ts.x/2-7 , log.h -add_h -16),ss + Vector2.new(ts.x/2+7 , 17+log.h -add_h) , Color.new(1,0 , 0 , log.col.a*0.8 ) )


                Render.BoxFilled(ss + Vector2.new(-ts.x/2 - 7, log.h -add_h -16),ss + Vector2.new((ts.x/2+7)*log.prog , -13+log.h -add_h) , Color.new(1,0 , 0 , log.col.a )   )
           --     Render.GradientBoxFilled(ss + Vector2.new(0, log.h -add_h -16),ss + Vector2.new((-ts.x/2-7)*log.prog , -12+log.h -add_h) , Color.new(0.4 ,0.5 ,1 , log.col.a ), Color.new(0.4 ,0.5 ,1 , 0 ) ,  Color.new(0.4 ,0.5 ,1 , log.col.a )  ,  Color.new(0.4 ,0.5 ,1 , 0 ))
                Render.Text(log.text , ss + Vector2.new(0 , log.h -add_h+1) , log.col , 12 , font , true , true)
            end
 

        end


    end,

    add = function (self , t , c )

        self.logs[#self.logs+1]  =  {text = t , col = c , prog = 0, h =0 - (#self.logs)*65 , time=GlobalVars.curtime , printed = false , bb = true , num = #self.logs}

    end,

}

handlers:add("draw", function()

    logs_data:adjust()
    logs_data:paint()

end,"logs" )

local cheat_engine = {

    get_class = ffi.typeof("void***"),

    panorama = Panorama.Open(),

    is_valid_ptr = function (self, ptr)
        if not self.nullptr then
            self.nullptr = {void = ffi.new("void*"), unsigned_int = ffi.new("unsigned int")}
        end

        return ptr ~= self.nullptr.void and ptr ~= nil and ffi.cast("unsigned int", ptr) ~= self.nullptr.unsigned_int
    end,

    interfaces = {
        get = function (self, dll, name)
            if not self.interfaces[name] then
                self.interfaces[name] = self.get_class(Utils.CreateInterface(dll, name))
            end
            return self.interfaces[name]
        end,

        cast = function (self, dll, name, cast, index)
            if not self.interfaces[cast .. index] then
                self.interfaces[cast .. index] = function (...)
                    local interface = self.interfaces.get(self, dll, name)
                    local args = {...}
                    local num_args = select(2, cast:gsub(", ", ""))

                    return ffi.cast(cast, interface[0][index])(interface, ...)
                end
            end
            return self.interfaces[cast .. index]
        end
    },

    get_client_entity = function (self, index)
        return self.interfaces.cast(self, "client.dll", "VClientEntityList003", "void*(__thiscall*)(void*, int)", 3)(index)
    end,

    play_sound = function (self, sound, volume, pitch)
        return self.interfaces.cast(self, "engine.dll", "IEngineSoundClient003", "void(__thiscall*)(void*, const char*, float, int, int, float)", 12)(sound, volume, pitch, 0, 0)
    end,

    get_clipboard_text = function (self, unk, buffer, size)
        return self.interfaces.cast(self, "vgui2.dll", "VGUI_System010", "void(__thiscall*)(void*, int, const char*, int)", 11)(unk, buffer, size)
    end,

    get_clipboard_text_count = function (self)
        return self.interfaces.cast(self, "vgui2.dll", "VGUI_System010", "int(__thiscall*)(void*)", 7)()
    end,

    set_clipboard_text = function (self, str)
        return self.interfaces.cast(self, "vgui2.dll", "VGUI_System010", "void(__thiscall*)(void*, const char*, int)", 9)(str, str:len())
    end,

    color_print = function (self, str, color)
        local color_struct = ffi.new("struct { uint8_t r, g, b, a; }")

        color_struct.r = color.r * 255
        color_struct.g = color.g * 255
        color_struct.b = color.b * 255
        color_struct.a = color.a * 255

        return self.interfaces.cast(self, "vstdlib.dll", "VEngineCvar007", "void(__cdecl*)(void*, void*, const char*)", 25)(color_struct, str)
    end
}



local configs = {
    export = function (from, color_exceptions)
        local config = {}
        for tabname , tab in pairs( from ) do
            for name, cheatvar in pairs(tab) do
                local result = {}
                if type(cheatvar) == "table" then
                    local temp = {}
                    for i=1 ,#cheatvar do temp[i] = cheatvar[i]:Get() end
                    result = {array = temp }
                else
                    if cheatvar:Get()==nil  then goto huy2 end

                    result = {value = cheatvar:Get()}
                end
                if (result.array ~= nil) then
                    goto huy 
                end

                if color_exceptions[name] then
                    local color = cheatvar:GetColor()
                    result["color"] = {r = color.r, g = color.g, b = color.b, a = color.a}
                end

                if type(result.value) == "userdata" then
                    result["color"] = {r = result.value.r, g = result.value.g, b = result.value.b, a = result.value.a}
                end
                ::huy:: 
                if not config[tabname] then config[tabname] = {} end

                config[tabname][name] = result

                ::huy2::
            end
        end

        local exported_to_armenia = "mishkatpidr" .. helpers.json.stringify(config)
        cheat_engine:set_clipboard_text("exscord_".. helpers.data_crypt.base64:encode(exported_to_armenia , 3))
    end,
    import = function (array, color_exceptions , siska , aa)
        local clipboard_text_length = cheat_engine:get_clipboard_text_count()
        local clipboard_data = ""
        
        if siska~=nil then 
            clipboard_data = siska 
            goto poshel_naxyu
        end


  
        if clipboard_text_length > 0 then
            buffer = ffi.new("char[?]", clipboard_text_length)
            size = clipboard_text_length * ffi.sizeof("char[?]", clipboard_text_length)
        
            cheat_engine:get_clipboard_text( 0, buffer, size )
        
            clipboard_data = ffi.string( buffer, clipboard_text_length-1 )
        end

        
        ::poshel_naxyu::
       if not clipboard_data then return end

       if not string.find( clipboard_data , "exscord_") then
        Cheat.AddNotify(script_name, "An error occured with config!")
        return
       end

        local notified = false
       local config = helpers.json.parse((helpers.data_crypt.base64:decode( clipboard_data:gsub("exscord_" , "") ,3)):gsub("mishkatpidr", "") )

        if not config then 
            Cheat.AddNotify(script_name, "An error occured with config!")
            return 
        end

        for tabname , tab in pairs(config) do
            if not tab or not tabname then 
                Cheat.AddNotify(script_name, "An error occured with config!")
                return 
            end

            for name, cheatvar in pairs(tab) do

                if not name or not cheatvar or not array[tabname] or not array[tabname][name] then
                    if not notified then     
                        Cheat.AddNotify(script_name, "An error occured with config or config might be outdated!")
                        notified = true
                    end
                    goto mama 
                end


                if cheatvar.color then
                    array[tabname][name]:SetColor(Color.new(tonumber(cheatvar.color.r), tonumber(cheatvar.color.g), tonumber(cheatvar.color.b), tonumber(cheatvar.color.a)))

                end
                if cheatvar.array then
                    for i=1, #array[tabname][name] do
                        if array[tabname][name][i] and cheatvar.array[i] then 
                            array[tabname][name][i]:Set(cheatvar.array[i])
                        end
                    end
                end
                if not cheatvar.array and not (cheatvar.color and not color_exceptions[name]) then
                    if  array[tabname][name] and cheatvar.value then
                        array[tabname][name]:Set(cheatvar.value)
                    end
                end
                 ::mama::
            end
        end
        if not notified and not aa then
            Cheat.AddNotify(script_name, "Config was succesfully loaded!")
        end
        ui:adjust_abrute()
        ui:adjust_ui()  
        update_ui_memory()
     end,

}




--#endregion

--#region visuals

local colors = {ui.vis.palette:GetColor(), ui.vis.palette:GetColor(),
                ui.vis.palette:GetColor(), ui.vis.palette:GetColor()}
local accent_alpha = 0

handlers:add("draw" , (function()
    if  ui_v.vis.ui_elem==0 then return end
    local palette = ui_v.vis.palette
    local menu_color_main = ui.vis.palette:GetColor()
    accent_alpha = menu_color_main.a

    if palette == 0 then
        local menu_color = Color.new(menu_color_main.r, menu_color_main.g, menu_color_main.b, 1)
        local menu_color2 = Color.new(menu_color.r, menu_color.g, menu_color.b , 1)
        
        colors[1] = menu_color2
        colors[2] = menu_color
        colors[3] = menu_color2
        accent_alpha = menu_color_main.a

    elseif palette == 1 then
        local menu_color = Color.new(menu_color_main.r, menu_color_main.g, menu_color_main.b, 1)
        local menu_color2 = Color.new(menu_color.r, menu_color.g, menu_color.b , 0)
        
        colors[1] = menu_color2
        colors[2] = menu_color
        colors[3] = menu_color2
        accent_alpha = menu_color_main.a
    
    elseif palette == 3 then
        local realtime = GlobalVars.realtime * 10
        local suka = helpers.HSVToRGB(realtime * (ui_v.vis.rainbow_speed / 200), 1, 1)
        
        accent_alpha = menu_color_main.a
        colors[1] = Color.new(suka.b, suka.r, suka.g, 1)
        colors[2] = Color.new(suka.r, suka.g, suka.b, 1)
        colors[3] = Color.new(suka.g, suka.b, suka.r, 1)
    elseif palette == 2 then
        local suka = helpers.HSVToRGB(0.5, 1, 1)
        
        colors[1] = Color.new(suka.r, suka.g, suka.b, 1)
        colors[2] = Color.new(suka.b, suka.r, suka.g, 1)
        colors[3] = Color.new(suka.g, suka.b, suka.r, 1)
        accent_alpha = menu_color_main.a
    else
        local menu_color = Color.new(menu_color_main.r, menu_color_main.g, menu_color_main.b, 1)

        colors[1] = menu_color
        colors[2] = menu_color
        colors[3] = menu_color
    end
end) , "manage_colors")


local init = function()
    local window_alpha = 0

    local blur_alpha = 0

    local offset = 0

    local sw = false

    handlers:add("draw" , function()
       
        if  not Cheat.IsMenuVisible() or not get_value(ui_v.vis.ui_elem , 6) then 
          --  if window_alpha == 0 or blur_alpha == 0 then return end
            

            window_alpha = helpers:lerp(window_alpha , 0 , 0.095)
         
        else

            window_alpha = helpers:lerp(window_alpha , 1 , 0.095)
        end

        if window_alpha<0.01 then return end

        local menu_pos = Render.GetMenuPos() + Vector2.new(0, -3)
        local menu_sz = Render.GetMenuSize()
        local colors = {
            Color.new(colors[1].r, colors[1].g, colors[1].b, colors[1].a * (window_alpha )),
            Color.new(colors[2].r, colors[2].g, colors[2].b, colors[2].a * (window_alpha )),
            Color.new(colors[3].r, colors[3].g, colors[3].b, colors[3].a * (window_alpha ))
        }

        offset = helpers:lerp(offset , menu_sz.x , 0.025) > menu_sz.x - 0.5 and menu_sz.x or helpers:lerp(offset , menu_sz.x , 0.025)



        Render.GradientBoxFilled(menu_pos + Vector2.new(1,-26), menu_pos + Vector2.new(offset/2 , -25) , colors[1] , colors[2] , colors[1] , colors[2])
        local blur_col = Color.new(ui.vis.blur_bg:GetColor().r , ui.vis.blur_bg:GetColor().g, ui.vis.blur_bg:GetColor().b, window_alpha * ui.vis.blur_bg:GetColor().a)
        Render.GradientBoxFilled(menu_pos + Vector2.new(offset/2 , -26), menu_pos + Vector2.new(offset-1 , -25) , colors[2] , colors[3] , colors[2] , colors[3])
        Render.Blur(menu_pos, menu_pos + Vector2.new(offset , -25) ,blur_col)
        Render.Texts("Welcome, "..globals.username , menu_pos+ Vector2.new(7 , -15) , Color.new(1,1,1,window_alpha) , 11 , fonts.verdana_10 , false )
        Render.Text("exscord \n   beta" , menu_pos+ Vector2.new(offset/2 , -24) , Color.new(1,1,1,window_alpha) , 11 , fonts.verdana_10 , true  )
        local ts = Render.CalcTextSize("GJ MISHKAT AXAXAX!" , 11 , fonts.verdana_10)

        Render.Texts("GJ MISHKAT AXAXAX!" , menu_pos+ Vector2.new(offset - ts.x-7 , -15) , Color.new(1,1,1,window_alpha) , 11 , fonts.verdana_10 , false )

        



    end,"init")


end

local function scope_lines()
    local l = 0
    local a = 0 
    local g = 0   
    local fov_cs = CVar.FindVar("fov_cs_debug")

    local ss = globals.screen_center

    ui.vis.custom_scope:RegisterCallback( function ()
 
        refs.lines:Set(ui_v.vis.custom_scope==true and 2 or 1)

    end)


    ui.vis.custom_scope_invert:RegisterCallback( function ()
    
        a = 0
        l = 0
        g = 0

    end)

    handlers:add("draw" , function()  
        if ui_v.vis.custom_scope_show and fov_cs:GetInt()~=90 then fov_cs:SetInt(90) end
        if not  ui_v.vis.custom_scope_show and fov_cs:GetInt()~=0 then fov_cs:SetInt(0) end
        local should_work = true    
        if not helpers.cm_check() then 
            a = 0
            l = 0
            g = 0
            return 
        end

        if not ui_v.vis.custom_scope then should_work = false end  

        local lp = EntityList.GetLocalPlayer()

        if not lp:GetProp("m_bIsScoped") then should_work = false end
        local gap = ui_v.vis.custom_scope_gap
   
        if not should_work then
            a = helpers:lerp(a , 0 , 0.095 , 0.05)
            l = helpers:lerp(l , 0, 0.095 , 0.1)
            g = helpers:lerp(g , 0 , 0.095 , 0.01)
        else
            a = helpers:lerp(a , 1 , 0.095 ,0.05)
            l = helpers:lerp(l , ui_v.vis.custom_scope_size , 0.095,0.1 )
            g = helpers:lerp(g , gap , 0.095 , 0.01)
        end

        if a<0.01 and not should_work then  return end
        if refs_v.lines == 1 and should_work then refs.lines:Set(2) end

        local menu_color = ui.vis.custom_scope:GetColor()
        local color1 = Color.new(menu_color.r, menu_color.g, menu_color.b , ui_v.vis.custom_scope_invert==1 and 0 or a)
        local color2 = Color.new(menu_color.r, menu_color.g, menu_color.b , ui_v.vis.custom_scope_invert==1 and a or 0)
     

        Render.GradientBoxFilled(Vector2.new(ss.x, ss.y - g), Vector2.new(ss.x + 1, ss.y - g - l), color1, color1, color2, color2)
        Render.GradientBoxFilled(Vector2.new(ss.x, ss.y + g), Vector2.new(ss.x + 1, ss.y + g + l), color1, color1, color2, color2)
        Render.GradientBoxFilled(Vector2.new(ss.x - g, ss.y), Vector2.new(ss.x - g - l, ss.y + 1), color1, color2, color1, color2)
        Render.GradientBoxFilled(Vector2.new(ss.x + g, ss.y), Vector2.new(ss.x + g + l, ss.y + 1), color1, color2, color1, color2)
    
    end , "scope_lines")


    handlers:add("destroy", function() refs.lines:Set(1) fov_cs:SetInt(0) end, "scope_destroy")

end




local function indicators() 
    local font_cringe = Render.InitFont(game_dir.."nl\\exscord\\smallest_pixel-7.ttf", 10)

    local get_fake_angle = function ()
        local real = AntiAim.GetCurrentRealRotation()
        local fake = AntiAim.GetFakeRotation()

        return math.min(math.abs(real - fake), AntiAim.GetMaxDesyncDelta())
    end
    
    local is_dmg_override = function ()
        local b = Cheat.GetBinds()
        local o = false
        for i = 1, #b do
            local bind = b[i]
            if bind:IsActive() then
                if bind:GetName() == "Minimum Damage" then
                     o= true
                end
            end
        end
            
        return o
    end


    local ind = {
        {
            0,
            0,
            function() return refs_v.dt end,
            function() return {Exploits.GetCharge()>0.9 and Color.new(0.4, 0.8, 0.2,1) or Color.new(0.7, 0, 0,1) ,Exploits.GetCharge()>0.9 and Color.new(0.4, 0.8, 0.2,1) or Color.new(0.7, 0, 0,1) } end,
            {"doubletap" , "DT"}
        },
        {
            0,
            0,
            function() return refs_v.hs and not refs_v.dt end,
            function() return {Exploits.GetCharge()>0.9 and Color.new(0.4, 0.8, 0.2,1) or Color.new(0.7, 0, 0,1) ,Exploits.GetCharge()>0.9 and Color.new(0.4, 0.8, 0.2,1) or Color.new(0.7, 0, 0,1) } end,
            {"on-shot" , "HIDE SHOT"}
        },
         {
            0,
            0,
            is_dmg_override,
            function() return {Color.new(1 , 0.5 , 0.7,1), Color.new(1 , 0.5 , 0.7,1)} end,
            {"dmg" , "DMG"}
        },
        {
            0,
            0,
            function() return refs_v.fd end,
            function() return {Color.new(1 , 0.8 , 1, EntityList.GetLocalPlayer():GetProp("m_flDuckAmount")<0.5 and  EntityList.GetLocalPlayer():GetProp("m_flDuckAmount")*0.5 + 0.75 or 1 ), Color.new(1 , 0.8 , 1, EntityList.GetLocalPlayer():GetProp("m_flDuckAmount") )} end,
            {"duck" , "DUCK"}
        },
        {
            0,
            0,
            function() return ui_v.rage.anti_mishkat end,
            function() return {Color.new(0.5 , 0.9 , 0.2,1), Color.new(0.5 , 0.9 , 0.2,1)} end,
            {"AX" , "AX"}
        },
        {
            0,
            0,
            function() return ui_v.aa.fake_flick and refs_v.dt and Exploits.GetCharge()>0.9 end,
            function() return {globals.flick and Color.new(0.4,0.7,0.2,1) or Color.new(0.8 , 0.8,0.1,1) , globals.flick and Color.new(0.4,0.7,0.2,1) or Color.new(0.8 , 0.8,0.1,1)} end,
            {"FLICK" , "FLICK"}
        },
    }

    local fake = 0
    local active_color = Color.new(1,1,1,1)
    local inactive_color = Color.new(1,1,1,1)
    local global_alpha = 0



    local ss = globals.screen_center

    handlers:add("draw" , function() 
        if not helpers.cm_check() then return end        
    
        local should_work = true
    
        if not ui_v.vis.cross_main then should_work = false end
    
        if should_work then
            global_alpha = helpers:lerp(global_alpha , 1 , 0.045 ,0.05)
        else
            global_alpha = helpers:lerp(global_alpha , 0 , 0.045 , 0.05)
        end

        if global_alpha<0.01  then return end
        
        local st = 0
    
        local y0 = st==0 and 27 or 40
        local add = st==0 and 9 or -12
        local off = -add
        for i=1 , 6 do
            if ind[i][3]() then
                if st==0 then
                    ind[i][2] = ((i==2 and ind[1][1]>0) or (i==1 and ind[2][1]>0)) and 0 or  9
                    ind[i][1] = ( (i==2  and ind[2][2] == 0 and st ==0 ) or (i==1  and ind[1][2]==0  and st ==0) ) and 0 or helpers:lerp(ind[i][1], 1 , st==0 and 0.095 or 0.145 , 0.05)
                else
                    ind[i][1] = ( (i==2  and ind[1][1] ~= 0 ) or (i==1  and ind[2][1]~=0) ) and 0 or helpers:lerp(ind[i][1], 1 , st==0 and 0.095 or 0.145 , 0.05)
                end
            else
                ind[i][1] = helpers:lerp(ind[i][1], 0 ,  0.095   , 0.05)
                if st==0 then
                    ind[i][2] = ind[i][1] ==0 and 0 or 9
                end
            end
            
            if st==0 then
                off = off + ind[i][2] 
            end
            
            
            if ind[i][1]>0 then
                local col = Color.new(ind[i][4]()[st+1].r , ind[i][4]()[st+1].g , ind[i][4]()[st+1].b , ind[i][4]()[st+1].a *  ind[i][1] * global_alpha)
                if i==1 then
                    local mul = Exploits.GetCharge()<1 and Exploits.GetCharge() or 0
                    if st==0 then
                        Render.Text(ind[i][5][st+1] , ss+Vector2.new(-3*mul,y0+ind[i][2]) ,col , 10 , font_cringe , true , true )
                        if Exploits.GetCharge()<1 and refs_v.dt then
                            Render.Circle(ss+Vector2.new(23,27.5+ind[i][2]) , 3.4 , 11 , Color.new(0,0,0,1) ,  1.7 ,-90, 360*Exploits.GetCharge()-90)
                            Render.Circle(ss+Vector2.new(23,27.5+ind[i][2]) , 3.2 , 11 , col ,  1.3 ,-90, 360*Exploits.GetCharge()-90)
                        end
                    else
                        Render.Texts("DT" , globals.screen_center+Vector2.new(-6*mul,40+off) ,col , 12 , nil , true , true )
                        if  Exploits.GetCharge()<1 and refs_v.dt then
                             Render.Circle(globals.screen_center+Vector2.new(8,40.5+off) , 4, 12 , col ,  1.5 ,-90, 360*Exploits.GetCharge()-90)
                         end
                    end
                else
                    if st==1 then
                        Render.Texts(ind[i][5][st+1] , ss+Vector2.new(0,y0 + off) ,col , 12 , nil , true , true )
                    else
                        Render.Text(ind[i][5][st+1] , ss+Vector2.new(0,y0+ind[i][2] + off) ,col , 10 , font_cringe , true , true )
                    end
                end
                if st==1 then

                    if i~=1 and i~=2 then
                        off = off + (ind[i][3]() and 12 or 12*ind[i][1])
                    else
                        if i==1 then
                            off = off +  ((ind[2][1] ~=0 and i==1) and 0 or  12*ind[i][1]) 
                        else
                            off = off +  ((ind[1][1] ~=0 and i==2) and 0 or  12*ind[i][1]) 
                        end
                    end
                end
            end
        end

       

        local fake_col4 = Color.new(ui.vis.cross_main:GetColor().r , ui.vis.cross_main:GetColor().g , ui.vis.cross_main:GetColor().b , global_alpha)
        local fake_col = Color.new(ui.vis.cross_main:GetColor().r , ui.vis.cross_main:GetColor().g , ui.vis.cross_main:GetColor().b , global_alpha)
        local fake_col2 = Color.new(fake_col.r , fake_col.g , fake_col.b , 0)

        active_color = AntiAim.GetInverterState() and helpers:lerp_color(active_color , Color.new(1,1,1,1) , 0.05) or helpers:lerp_color(active_color , ui.vis.cross_main:GetColor() , 0.05)
        inactive_color = not AntiAim.GetInverterState() and helpers:lerp_color(inactive_color , Color.new(1,1,1,1) , 0.05) or helpers:lerp_color(inactive_color , ui.vis.cross_main:GetColor() , 0.05)

        active_color = Color.new(active_color.r, active_color.g , active_color.b, global_alpha)
        inactive_color = Color.new(inactive_color.r, inactive_color.g , inactive_color.b, global_alpha)
        if st==1 then
            local cord_size = Render.CalcTextSize("CORD" , 12 )
            local exs_size = Render.CalcTextSize("EXS" , 12 )
            Render.Texts("EXS" , globals.screen_center + Vector2.new(- cord_size.x/2, 40)  , active_color , 12 , nil, true , true)
            Render.Texts("CORD" , globals.screen_center + Vector2.new( exs_size.x/2, 40)  , inactive_color , 12 ,nil, true , true)
            if not globals.in_antibrute2 then
                Render.Text(math.floor(get_fake_angle()) .. "°" , globals.screen_center + Vector2.new(3 , 23) ,Color.new(0,0,0,0.6*global_alpha),11 , fonts.degree  ,false , true)
                Render.Text(math.floor(get_fake_angle()) .. "°" , globals.screen_center + Vector2.new(2 , 22) ,Color.new(1,1,1,1*global_alpha),11 , fonts.degree  ,false , true)
                fake = helpers:lerp(fake , get_fake_angle()/1.5 , 0.095 , 0.01)
                Render.GradientBoxFilled(globals.screen_center + Vector2.new(-fake , 30) , globals.screen_center + Vector2.new(0,31) , fake_col2 , fake_col , fake_col2 , fake_col)
                Render.GradientBoxFilled(globals.screen_center + Vector2.new(fake , 30) , globals.screen_center + Vector2.new(0,31) , fake_col2 , fake_col , fake_col2 , fake_col)
            else
                fake = 0
                local mul = ( globals.abrute_timer)/3
                local a = globals.abrute_timer < 0.33333 and globals.abrute_timer *3 or 1
                local fake_col3 = Color.new(fake_col4.r , fake_col4.g , fake_col4.b , a*global_alpha)
                Render.Text( "phase "..globals.abrute_phase+1 , globals.screen_center + Vector2.new(0 , 24) ,Color.new(0,0,0,a*0.6*global_alpha),11 , fonts.degree  ,false , true)
                Render.Text("phase "..globals.abrute_phase+1, globals.screen_center + Vector2.new(0 , 23) ,Color.new(1,1,1,a*global_alpha),11 , fonts.degree  ,false , true)
                --Render.BoxFilled(globals.screen_center + Vector2.new(-26 , 30) , globals.screen_center + Vector2.new(26,33) , Color.new(0.1,0.1,0.1,a))
                Render.GradientBoxFilled(globals.screen_center + Vector2.new(-25  , 31) , globals.screen_center + Vector2.new(  (50*mul)-25,32) , fake_col3, fake_col3 , fake_col3 , fake_col3)
            end
        else
            local cord_size = Render.CalcTextSize("cord" , 10 , font_cringe)
            local exs_size = Render.CalcTextSize("exs" , 10 , font_cringe)
            Render.Text("exs" , globals.screen_center + Vector2.new(- cord_size.x/2, 19)  , active_color , 10 , font_cringe , true , true)
            Render.Text("cord" , globals.screen_center + Vector2.new( exs_size.x/2, 19)  , inactive_color , 10 , font_cringe , true , true)
            if not globals.in_antibrute2 then
                fake = helpers:lerp(fake , get_fake_angle()/3 , 0.095 , 0.01)
                Render.GradientBoxFilled(globals.screen_center + Vector2.new(-fake , 27) , globals.screen_center + Vector2.new(0,29) , fake_col2 , fake_col , fake_col2 , fake_col)
                Render.GradientBoxFilled(globals.screen_center + Vector2.new(fake , 27) , globals.screen_center + Vector2.new(0,29) , fake_col2 , fake_col , fake_col2 , fake_col)
            else
                fake = 0
                local mul = ( globals.abrute_timer)/3
                local a = globals.abrute_timer < 0.33333 and globals.abrute_timer *3 or 1
                local fake_col3 = Color.new(fake_col4.r , fake_col4.g , fake_col4.b , a)
                Render.BoxFilled(globals.screen_center + Vector2.new(-26 , 26) , globals.screen_center + Vector2.new(26,30) , Color.new(0.1,0.1,0.1,a))
                Render.GradientBoxFilled(globals.screen_center + Vector2.new(-25  , 27) , globals.screen_center + Vector2.new(  (50*mul)-25,29) , fake_col3, fake_col3 , fake_col3 , fake_col3)
            end
        end


    end , "cross_main")

end

local arrows = function ()
    local add =30
    local a = 0
    local manual_a = 0 local parasha_a = 0
    local col_1 = Color.new(1,1,1,0)
    local col_2 = Color.new(1,1,1,0)
    local col_3 = Color.new(1,1,1,0)
    local col_4 = Color.new(1,1,1,0)

    refs.yaw_b:RegisterCallback( function () a=0 end)
    ui.aa.manual:RegisterCallback(function() a = 0 end)
    local col1 = Color.new(0,0,0,0)

    local function render_manual(yaw_b)
        local uicol =  ui.vis.arrows_main:GetColor()
        
        local screen_size_middle = Vector2.new(globals.screen_size.x / 2 + 9+add, globals.screen_size.y / 2 - 11);
        local screen_size_middle2 = Vector2.new(globals.screen_size.x / 2 - 18-add, globals.screen_size.y / 2 - 11);
        if yaw_b==2 then
            Render.Text(">", screen_size_middle, Color.new(uicol.r , uicol.g , uicol.b , manual_a), 20, true) 
        elseif yaw_b==3 then
            Render.Text("<", screen_size_middle2, Color.new(uicol.r , uicol.g , uicol.b , manual_a), 20, true)
        end
    end


    local function parasha() 
        local idle_color = Color.new(0.13, 0.13, 0.13, 0.6 * parasha_a*a)
        local ss = globals.screen_center
        local yawbase = globals.cur_yaw_base
        col_1 = helpers:lerp_color(col_1 , yawbase==2 and col1 or idle_color , 0.095)
        col_2 = helpers:lerp_color(col_2 , yawbase==3 and col1 or idle_color , 0.095)
        col_3 = helpers:lerp_color(col_3 , AntiAim.GetInverterState() and col1 or idle_color , 0.095)
        col_4 = helpers:lerp_color(col_4 , not AntiAim.GetInverterState() and col1 or idle_color , 0.095)

        Render.PolyFilled(col_1, ss + Vector2.new(55,2), ss+Vector2.new(42, -7), ss+Vector2.new(42, 11) )
        Render.PolyFilled(col_2, ss + Vector2.new(-55,2), ss+Vector2.new(-42, -7), ss+Vector2.new(-42, 11) )
        Render.BoxFilled(ss + Vector2.new(38, -7), ss + Vector2.new(40, 11), col_3 )
        Render.BoxFilled(ss + Vector2.new(-40, -7), ss + Vector2.new(-38, 11), col_4)
    end

    local arrows_arr = {render_manual , parasha}

    handlers:add("draw", function()
        local should_work = true
        local yaw_b =  globals.cur_yaw_base
        local check_for_manual_arrows =  (yaw_b==2 or yaw_b==3)
        if not ui_v.vis.arrows_main or not ui_v.vis.cross_main or not helpers.cm_check()  then 
            should_work = false 
        end
        if ui_v.vis.arrows_style==0 and not check_for_manual_arrows and a<0.01 then
            should_work = false 
        end


        if should_work then
            a = helpers:lerp(a , 1 , 0.095 , 0.05)
        else
            a = helpers:lerp(a , 0 , 0.095 , 0.05)
        end
        col1 =Color.new( ui.vis.arrows_main:GetColor().r , ui.vis.arrows_main:GetColor().g , ui.vis.arrows_main:GetColor().b , parasha_a*a)
        if a<0.01  then  col1 = Color.new(0,0,0,0) return end

        if ui_v.vis.arrows_style == 0 then
            manual_a = helpers:lerp(manual_a , 1 , 0.095)
            parasha_a = helpers:lerp(parasha_a , 0 , 0.095)
        else
            manual_a = helpers:lerp(manual_a , 0 , 0.095)
            parasha_a = helpers:lerp(parasha_a , 1 , 0.095)
        end

        if manual_a > 0.01 then
            arrows_arr[1](yaw_b)
        end

        if parasha_a>0.01 then
            arrows_arr[2]()
        end

    end , "arrows")

end


local function watermark()
    local global_alpha = 0

    local username = globals.username
    local build = globals.build
    ui.vis.watermark_name:RegisterCallback(function(val) if ui_v.vis.watermark_custom then username = val end end)

    local blur_alpha = 0
    local box_alpha = 0
    ui.vis.blur_bg:RegisterCallback( function (val)
        
        blur_alpha =     val and 0 or 1
        box_alpha =    val and 1 or 0
        
    end)

    handlers:add("draw" , function()
        local should_work = true
        if not get_value(ui_v.vis.ui_elem , 1) then should_work = false end

        if should_work then
            global_alpha = helpers:lerp(global_alpha , 1 , 0.095 , 0.05)
        else
            global_alpha = helpers:lerp(global_alpha , 0 , 0.095 , 0.05)
        end

        if not should_work and global_alpha<0.01 then return end

        globals.watermark_h = 25*global_alpha
        blur_alpha =  helpers:lerp( blur_alpha,    ui_v.vis.blur_bg and  global_alpha or 0 , 0.125)
        box_alpha =  helpers:lerp( box_alpha,  not ui_v.vis.blur_bg and  global_alpha or 0 , 0.125)
        local ping = "0"
        local GetNetChannelInfo = EngineClient.GetNetChannelInfo()
        if GetNetChannelInfo then
            ping = helpers.round(GetNetChannelInfo:GetLatency(0) * 1000)
        end

        local colors = {
            Color.new(colors[1].r, colors[1].g , colors[1].b, colors[1].a*global_alpha),
            Color.new(colors[2].r, colors[2].g , colors[2].b, colors[2].a*global_alpha),
            Color.new(colors[3].r, colors[3].g , colors[3].b, colors[3].a*global_alpha),
            Color.new(colors[4].r, colors[4].g , colors[4].b,colors[4].a* global_alpha),
        }

        local time = time:get()
        local text = "exscord [".. build .."] | " .. ( ui_v.vis.watermark_custom and ui_v.vis.watermark_name or globals.username) .. " | delay: " .. ping .. "ms | " .. time
        local text_size = Render.CalcTextSize(text, 11, fonts.verdana_10)
        
        local start = Vector2.new(globals.screen_size.x - text_size.x -16, 10)

        if box_alpha~=0 then
            Render.BoxFilled(start, start + Vector2.new(text_size.x+4, 18), color(17, 17, 17, accent_alpha * 255 * global_alpha*box_alpha))
        end
        if blur_alpha~=0 then
            local blur_col = Color.new(ui.vis.blur_bg:GetColor().r , ui.vis.blur_bg:GetColor().g, ui.vis.blur_bg:GetColor().b, global_alpha*accent_alpha * blur_alpha * ui.vis.blur_bg:GetColor().a)
            Render.Blur(start, start + Vector2.new(text_size.x+4 , 18) ,blur_col)
        end            

        Render.Texts(text, Vector2.new(start.x+2, 13), Color.new(1.0, 1.0, 1.0, global_alpha), 11, fonts.verdana_10)
        local offset = Vector2.new(text_size.x/2 +2 , 2)
        Render.GradientBoxFilled(start, start + offset, colors[1], colors[2], colors[1], colors[2])
        Render.GradientBoxFilled(start + offset, start + offset + Vector2.new(offset.x, -offset.y), colors[2] ,colors[3], colors[2], colors[3])
        
    
    end , "watermark")


end


local  function keybinds_fn ()
    local binds = {}
    local kbinds = draggables:new(1 , Vector2.new(122 , 17) ,  Vector2.new(ui_v.vis.kx , ui_v.vis.ky),ui.vis.kx,ui.vis.ky )
    local g_alpha = 0
    local blur_alpha = 0
    local box_alpha = 0
    ui.vis.blur_bg:RegisterCallback( function (val)
        
        blur_alpha =     val and 0 or 1
        box_alpha =    val and 1 or 0
        
    end)

    handlers:add("draw" , function()

        local mama = Cheat.GetBinds()
        local should_work = false
        local max_size = 122
        for k,v in pairs(mama) do if v:IsActive() then should_work = true end end
        if not get_value(ui_v.vis.ui_elem , 2) then 
            should_work = false
        end



        if not should_work and not (Cheat.IsMenuVisible() and get_value(ui_v.vis.ui_elem , 2)) then
            g_alpha = helpers:lerp(g_alpha, 0 , 0.095 , 0.05)
        else
            g_alpha = helpers:lerp(g_alpha, 1 , 0.095 , 0.05)
        end
        
      
        blur_alpha =  helpers:lerp( blur_alpha,    ui_v.vis.blur_bg and  g_alpha or 0 , 0.125)
        box_alpha =  helpers:lerp( box_alpha,  not ui_v.vis.blur_bg and  g_alpha or 0 , 0.125)

        if g_alpha < 0.01 then return end

        local clamp_alpha = ui.vis.palette:GetColor().a
        local start = kbinds.pos
        local colors = {
            Color.new(colors[1].r, colors[1].g, colors[1].b, colors[1].a * (g_alpha )),
            Color.new(colors[2].r, colors[2].g, colors[2].b, colors[2].a * (g_alpha )),
            Color.new(colors[3].r, colors[3].g, colors[3].b, colors[3].a * (g_alpha ))
        }
        local offset = Vector2.new(kbinds.size.x / 2, 2)


        local y_off = 0
    
        for i = 1 , #mama do
            local bind = mama[i]
            local bind_name = bind:GetName()

            if bind_name == "Yaw Base" and ui_v.aa.type then goto skip end

            if not binds[bind_name] then 
                binds[bind_name] = 0
            end
            local val = (bind:GetValue() == "on" or bind:GetValue()=="off") and (bind:GetMode()==0 and "[toggled]" or  "[hold]") or "["..bind:GetValue().."]" 
            binds[bind_name]  =  helpers:lerp(binds[bind_name] , bind:IsActive() and 1 or 0 , 0.075 , 0.05)
            
            if binds[bind_name] <0.01 then goto skip end

            
            local alpha = binds[bind_name] 

            local text_size = Render.CalcTextSize(val, 11, fonts.verdana_10)
            local text_size2 = Render.CalcTextSize(val .. bind_name, 11, fonts.verdana_10)
            local off = start.y + (y_off ) + 20 
            
            Render.Texts(bind_name, Vector2.new(start.x + 2, off), Color.new(1.0, 1.0, 1.0, alpha*g_alpha ), 11, fonts.verdana_10)
            
            Render.Texts(val, Vector2.new(start.x - 2 + (kbinds.size.x - text_size.x), off), Color.new(1.0, 1.0, 1.0, alpha*g_alpha ), 11, fonts.verdana_10)
            
            if max_size < (text_size2.x)+18 then max_size = (text_size2.x+18 ) end

         
            y_off = bind:IsActive() and  y_off + 17 or y_off + 17*alpha
            ::skip::
        end
    
        kbinds.size.x = helpers:lerp(kbinds.size.x,  max_size, 0.225 , 0.05)

        if  box_alpha ~=0 then
            Render.BoxFilled(start, start +  kbinds.size, color(17, 17, 17, g_alpha * accent_alpha*255*box_alpha))

        end
        if blur_alpha ~=0 then
            local blur_col = Color.new(ui.vis.blur_bg:GetColor().r , ui.vis.blur_bg:GetColor().g, ui.vis.blur_bg:GetColor().b, g_alpha*accent_alpha * blur_alpha * ui.vis.blur_bg:GetColor().a)
            Render.Blur(start, start +  kbinds.size, blur_col)
        end

        Render.GradientBoxFilled(start, start + offset, colors[1], colors[2], colors[1], colors[2])
        Render.GradientBoxFilled(start + offset, start + offset + Vector2.new(offset.x, -offset.y), colors[2], colors[3], colors[2], colors[3])

        Render.Texts("keybinds", Vector2.new(start.x + kbinds.size.x / 2 - 43 / 2, start.y + 3), Color.new(1.0, 1.0, 1.0, g_alpha ), 11, fonts.verdana_10)

    

        kbinds:update()

    end , "keybinds")

end

local  function vbiv_fn ()

    
    local velocity = Render.InitFont('Tahoma', 11, {'b'})
    local function rgb_health_based(percentage)
        local r = 124*2 - 124 * percentage
        local g = 195 * percentage
        local b = 13
        return r, g, b
    end
    
    local function remap(val, newmin, newmax, min, max, clamp)
        min = min or 0
        max = max or 1
    
        local pct = (val-min)/(max-min)
    
        if clamp ~= false then
            pct = math.min(1, math.max(0, pct))
        end
    
        return newmin+(newmax-newmin)*pct
    end
    
    local renderer_rectangle = function(x, y, w, s, r, g, b, a)
        Render.BoxFilled(Vector2.new(x, y), Vector2.new(x + w, y + s), Color.new(r / 255, g / 255, b / 255, a / 255))
    end
    local function rectangle_outline(x, y, w, h, r, g, b, a, s)
        s = s or 1
        renderer_rectangle(x, y, w, s, r, g, b, a) -- top
        renderer_rectangle(x, y+h-s, w, s, r, g, b, a) -- bottom
        renderer_rectangle(x, y+s, s, h-s*2, r, g, b, a) -- left
        renderer_rectangle(x+w-s, y+s, s, h-s*2, r, g, b, a) -- right
    end
    
    local warning_image = Render.LoadImage("\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x40\x00\x00\x00\x40\x08\x06\x00\x00\x00\xAA\x69\x71\xDE\x00\x00\x00\x09\x70\x48\x59\x73\x00\x00\x1E\xC1\x00\x00\x1E\xC1\x01\xC3\x69\x54\x53\x00\x00\x00\x19\x74\x45\x58\x74\x53\x6F\x66\x74\x77\x61\x72\x65\x00\x77\x77\x77\x2E\x69\x6E\x6B\x73\x63\x61\x70\x65\x2E\x6F\x72\x67\x9B\xEE\x3C\x1A\x00\x00\x03\x9A\x49\x44\x41\x54\x78\x9C\xED\x9A\x4D\xA8\x55\x55\x18\x86\x9F\xAF\x9B\x52\x61\x92\x05\x97\xA2\x28\x30\x34\x0C\x43\x83\x22\x0C\x9A\xD8\x40\x9A\xA9\xB3\x9C\x55\xD2\xA4\x81\x4D\xC2\x34\x82\xC0\x81\x18\x08\x39\x2A\x9A\xD5\xB4\xA2\xD9\x1D\x84\x41\x93\x06\x11\x11\x88\x49\x75\xA3\x89\x12\x15\xA5\x61\x65\x65\xEA\xD3\x60\x73\xF2\x5C\xCF\xD9\xFB\xEE\xBF\xB5\x57\xDA\x79\x86\xEB\xEC\xB5\xD6\xFB\x7E\xBC\x67\xB1\xCE\xFE\x0E\xCC\x98\x31\x63\xC6\x8C\x19\x59\x50\xE7\xD4\xD5\xB9\x75\x64\x43\xDD\xAD\x1E\xCE\xAD\x23\x0B\xEA\x2A\xF5\x3B\xF5\x2F\x75\x5D\x6E\x3D\x83\xA3\x1E\xF0\x32\xEF\xE4\xD6\x33\x28\xEA\x9D\xEA\x6F\x2E\xE5\xB1\xDC\xBA\x06\x43\x7D\xCB\x49\x3E\x53\xAF\xCB\xAD\x2D\x39\xEA\x66\xF5\xE2\x94\x02\xA8\xEE\xCA\xAD\x2F\x39\xEA\xD1\x12\xF3\xAA\x27\xD5\x9B\x72\x6B\x4C\x86\xBA\xBD\xC2\xFC\x88\x7D\xB9\x75\x26\x41\x5D\xA1\x7E\x55\xA3\x00\x67\xD5\xDB\x73\xEB\xED\x1D\x75\x4F\x0D\xF3\x23\x5E\xCF\xAD\xB7\x57\xD4\x5B\xD4\x9F\x1A\x14\xE0\x82\xBA\x31\xB7\xEE\xDE\x50\x0F\x37\x30\x3F\x62\x21\xB7\xEE\x5E\x50\xD7\xAA\x7F\xB6\x28\x80\xEA\xB6\xDC\xFA\x3B\xA3\xBE\xDB\xD2\xBC\xEA\x17\xEA\xF5\xB9\x3D\xB4\x46\xDD\xA2\x5E\xEA\x50\x00\xD5\xDD\xB9\x7D\xB4\x42\x0D\xF5\xE3\x8E\xE6\x55\x7F\x30\xE1\x3B\x83\x94\x77\xEF\x27\x81\x47\x7B\x58\x67\x1E\x78\xA1\x87\x75\xA6\x12\x29\x16\x55\x6F\x00\xBE\x04\xEE\x29\x79\xE4\xCD\x92\xF1\x67\x4B\xC6\xCF\x01\xF7\x45\xC4\xA9\xAE\xDA\x06\x41\xDD\x57\x95\xE9\x8A\x79\x55\xBC\x3D\xA4\x87\xD6\xA8\xF3\xEA\x2F\x09\x0A\x70\x49\x7D\x68\x48\x2F\xAD\x50\xDF\x58\xC6\x48\xDB\x02\xA8\x7E\x34\xA0\x95\xE6\xA8\x1B\xD4\xBF\x13\x16\x40\x75\xFB\x90\x9E\x1A\xA1\x2E\xD4\x71\x50\x31\xBF\x0E\xDF\xA8\x2B\x87\xF4\x55\x0B\x75\x6B\x4D\x03\x5D\x0B\xA0\xBA\x67\x48\x6F\xCB\x62\xD1\xE0\x38\x36\x60\x01\x4E\xAB\xB7\xF5\xA1\xBD\xAF\x8B\xD0\xD3\xC0\x03\x3D\xAD\x55\x87\x35\xC0\xFE\x3E\x16\xEA\x7C\x11\x52\x57\x01\x5F\x03\x77\xD4\xDE\x34\x62\xEA\xBE\x55\xE9\x98\xC2\x79\x60\x63\x44\x2C\x36\x98\x33\x41\x1F\x09\xD8\x4B\x03\xF3\x3D\xB2\x12\x38\x98\x61\xDF\xCB\x58\x34\x38\x7E\x6F\xF0\xDD\xED\xEB\x0C\x18\xA7\x53\x43\xA5\x6B\x02\x0E\x02\xB9\x5F\x63\x1F\x31\x47\x43\x45\x7D\xD0\xF2\x06\xC7\x90\x09\xD0\x0E\x0D\x95\xD6\x87\xA0\x7A\x14\x78\xBC\xD5\xA6\xFD\x1C\x82\xE3\x9C\xA2\xF8\xB5\x78\xAE\xE9\xC4\x56\xD1\x51\x77\xD0\xD2\x7C\x22\xEE\x02\x5A\x5D\x8E\x1A\x27\x40\x5D\x01\x1C\x07\xD6\xB7\xD9\x10\x92\x24\x00\xE0\x57\x60\x7D\x44\x7C\xDF\x64\x52\x9B\x04\x3C\x47\x07\xF3\x09\xB9\x19\x78\xA5\xE9\xA4\x46\x09\x50\xD7\x00\x8B\x40\xA7\x6B\x68\xA2\x04\x00\x5C\x04\x36\x47\xC4\xF1\xBA\x13\x9A\x26\xE0\x65\x3A\x9A\x4F\xCC\x1C\xF0\x6A\x93\x09\xB5\x13\xA0\xDE\x0B\x9C\xA0\xB8\x81\x75\xE5\xD6\x92\xF1\xD3\x3D\xAC\x0D\xB0\x2D\x22\x3E\xA8\xF3\x60\x93\x02\xBC\x07\xEC\x6C\x2D\x69\x58\x4E\x00\x9B\x22\xE2\xC2\x72\x0F\xD6\xFA\x0A\xA8\x5B\x80\x1D\x5D\x55\x0D\xC8\xFD\xC0\x53\x75\x1E\x5C\x36\x01\x6A\x00\x9F\x00\x0F\x77\x14\x35\x34\x3F\x02\xEB\x22\xE2\x6C\xD5\x43\x75\x12\xB0\x8B\xAB\xCF\x3C\xD4\x6C\xA8\x54\x26\x40\xBD\x91\xA2\xC1\x71\x77\x4F\xA2\x46\x1C\x2A\x19\xDF\xDB\xF3\x3E\x7F\x50\x5C\x91\x4F\xB6\x9A\xAD\xEE\xEF\xF0\x03\xA5\x94\x8A\xFD\x52\x50\xD9\x50\x29\x4D\x80\x3A\x4F\x71\xE9\xE9\xBD\x31\x99\xF0\x22\x34\x75\x59\xE0\x91\x88\xF8\x74\xDA\x87\x55\x67\xC0\x01\x12\x98\xCF\x40\x00\xAF\x59\x1C\xE6\x53\x3F\x9C\x40\xDD\x00\x1C\x03\x92\xFC\x39\x61\xE0\x04\x8C\xD8\x19\x11\xEF\x4F\x68\x29\x11\xB2\x00\x3C\x91\x50\xCC\xB7\x25\xE3\x6B\x13\xEE\xB9\x48\xF1\x12\xF5\xFC\xF8\xE0\x44\x01\xD4\xAD\xC0\x87\x09\x85\xE4\xE4\xF9\x88\x38\x32\x3E\xB0\xA4\x00\xEA\x1C\xF0\x39\xC3\xBE\xE3\x1F\x92\x33\x14\x97\xA3\x9F\x47\x03\x57\x1E\x82\xCF\x70\xED\x9A\x87\xA2\xA1\xF2\xD2\xF8\xC0\xBF\x09\xB0\x45\x83\xE3\x2A\x65\x49\x43\x65\x3C\x01\x2F\x72\xED\x9B\x87\x2B\x1A\x2A\xE3\x09\x58\x4D\xF1\x42\xE1\x7F\x41\x44\x9C\xC9\xAD\x61\xC6\x8C\xFF\x00\xFF\x00\xC3\xE5\xE3\x5A\xDA\x71\x10\xC7\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82", Vector2.new(64, 64))
    local function reversed_freestanding(color, pos, sz)
        --local poly = {
        --    Vector2.new(pos.x, pos.y),
        --    Vector2.new(pos.x + sz / 2, pos.y - sz / 1.2),
        --    Vector2.new(pos.x + sz, pos.y),
        --    Vector2.new(pos.x, pos.y),
        --}
        --local poly1 = {
        --    Vector2.new(pos.x + 1, pos.y),
        --    Vector2.new(pos.x + sz / 2, pos.y - sz / 1.2),
        --    Vector2.new(pos.x + sz, pos.y),
        --    Vector2.new(pos.x, pos.y),
        --}
        --Render.PolyLine(color, unpack(poly))
        --Render.PolyLine(color, unpack(poly1))
    
        Render.Image(warning_image, pos, sz, color, 0)
    end
    
    local interval = 0
    local function drawBar(modifier, r, g, b, a, text, pos)
        interval = interval + (1-modifier) * 0.7 + 0.3
        local warningAlpha = math.abs(interval*0.01 % 2 - 1)
        
        local text_width = 95
        local sw = globals.screen_size
        local x, y = pos.x, pos.y
        local iw, ih = 35, 35--warning:measure(nil, 35)
    
        -- icon
        reversed_freestanding(Color.new(16/255, 16/255, 16/255, 1*a), Vector2.new(x-3, y-4), Vector2.new(iw+6, ih+6))
        --warning:draw(x-3, y-4, iw+6, ih+6, 16, 16, 16, 255*a)
        if a > 0.7 then
            renderer_rectangle(x+13, y+11, 8, 20, 16, 16, 16, 255*a)
        end
        reversed_freestanding(Color.new(r/255,g/255,b/255, warningAlpha*a), Vector2.new(x, y), Vector2.new(iw, ih))
        --warning:draw(x, y, nil, 35, r,g,b, warningAlpha*a)
    
        -- text
        Render.Text(string.format("%s %d%%", text, modifier*100), Vector2.new(x+iw+9, y+4), Color.new(0.1,0.1,0.1,0.7*a), 11, velocity)
        Render.Text(string.format("%s %d%%", text, modifier*100), Vector2.new(x+iw+8, y+3), Color.new(1,1,1,1*a), 11, velocity)
    
        -- bar
        local rx, ry, rw, rh = x+iw+8, y+3+17, text_width, 12
        rectangle_outline(rx, ry, rw, rh, 0, 0, 0, 255*a, 1)
        renderer_rectangle(rx+1, ry+1, rw-2, rh-2, 16, 16, 16, 180*a)
        renderer_rectangle(rx+1, ry+1, math.floor((rw-2)*modifier), rh-2, r, g, b, 180*a)
    end

    local vbiv = draggables:new(10000000, Vector2.new(globals.screen_size.x / 2 - 95, 50), Vector2.new(ui_v.vis.vx, ui_v.vis.vy),ui.vis.vx,ui.vis.vy )
    local g_alpha = 0

    handlers:add("draw" , function()
        vbiv.size.x = 145

        local should_work = get_value(ui_v.vis.ui_elem, 7)

        local anim_out = not should_work or not Cheat.IsMenuVisible()
        if anim_out then
            g_alpha = helpers:lerp(g_alpha, 0, 0.095, 0.05)
        else
            g_alpha = helpers:lerp(g_alpha, 1, 0.095, 0.05)
        end

        vbiv:update()

        if (g_alpha ~= 1 and g_alpha ~= 0) or Cheat.IsMenuVisible() then 
            local r, g, b = rgb_health_based(0.5)
            drawBar(0.5, r, g, b, g_alpha, "Slowed down", vbiv.pos)
            return
        end

        local lp = EntityList.GetLocalPlayer()
        if not lp or not lp:IsAlive() then
            return
        end
        local modifier = lp:GetProp("m_flVelocityModifier")
        if modifier == 1 then return end
        local r, g, b = rgb_health_based(modifier)
        local a = remap(modifier, 1, 0, 0.85, 1)
        drawBar(modifier, r, g, b, a, "Slowed down", vbiv.pos)

    end , "хохлопанель")

end

local function spectators()
    local global_alpha = 0

    local function get_steam_id_fn(ent_idx)

        local panorama_handle = Panorama.Open()
        local huy = panorama_handle.GameStateAPI.GetPlayerXuidStringFromEntIndex(ent_idx)
        return huy
    
    end

    local get_avatar = function(steamid)
        local huy = nil
        local counter = 4
        local rgba_image = {}
        local huy = nil
        local handle = native_ISteamFriends_GetSmallFriendAvatar( native_ISteamFriends , tonumber(steamid:sub(4, -1)) + 76500000000000000ULL)
    
        local image_bytes = ""
    
        if handle > 0 then
            local width = uintbuffer(1)
            local height = uintbuffer(1)
            if native_ISteamUtils_GetImageSize(native_ISteamUtils, handle, width, height) then
                if width[0] > 0 and height[0] > 0 then
                    local rgba_buffer_size = width[0]*height[0]*4
                    local rgba_buffer = charbuffer(rgba_buffer_size)
                    if native_ISteamUtils_GetImageRGBA(native_ISteamUtils, handle, rgba_buffer, rgba_buffer_size) then
                        local png = begin(width[0] , height[0] , "rgba")
                        for x =0 , width[0]-1 do
                            for y =0, height[0]-1 do
                                local pizda = x*(height[0]*4) + y*4
                                png:write { rgba_buffer[pizda] , rgba_buffer[pizda+1] ,  rgba_buffer[pizda+2] ,  rgba_buffer[pizda+3]}
                            end
                        end
                        huy = png.output
                    end
                end
            end
        elseif handle ~= -1 then
            huy = nil
        end
        function transform(input)
            local output = string.format("%x", input ) -- "7F"
            return ("\\x" .. string.upper(output))
        end

        if not huy then return end

        for i=1 ,#huy do  
            image_bytes=  image_bytes..huy[i]
        end
    
        local image_loaded = Render.LoadImage(image_bytes ,  Vector2.new(12,12))
    
        return image_loaded
    end
    
    
    local avatars = {} -- credits : elleqt(for the whole struct) + LORDCATAFALK$$$$$$$$$ (for other stuff)

    avatars.data = {}

    avatars.default_image = Render.LoadImage("\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x0C\x00\x00\x00\x0C\x08\x03\x00\x00\x00\x61\xAB\xAC\xD5\x00\x00\x00\x04\x67\x41\x4D\x41\x00\x00\xB1\x8F\x0B\xFC\x61\x05\x00\x00\x00\x20\x63\x48\x52\x4D\x00\x00\x7A\x26\x00\x00\x80\x84\x00\x00\xFA\x00\x00\x00\x80\xE8\x00\x00\x75\x30\x00\x00\xEA\x60\x00\x00\x3A\x98\x00\x00\x17\x70\x9C\xBA\x51\x3C\x00\x00\x00\x78\x50\x4C\x54\x45\x23\x1F\x20\x21\x1D\x1E\x28\x25\x26\x28\x24\x25\x27\x23\x24\x75\x73\x73\xAA\xA9\xA9\x71\x6F\x6F\x26\x22\x23\x20\x1C\x1D\x64\x62\x62\xC6\xC5\xC5\x51\x4E\x4F\x57\x54\x55\xCA\xCA\xCA\x5B\x58\x59\x22\x1E\x1F\x4F\x4C\x4D\x20\x1B\x1C\xB7\xB6\xB6\x74\x71\x72\x1F\x1B\x1C\x21\x1C\x1D\x24\x20\x21\x79\x76\x77\xC0\xBF\xBF\x3E\x3A\x3B\x61\x5E\x5F\xC2\xC1\xC1\x49\x45\x46\x88\x86\x86\x7A\x77\x78\x1E\x1A\x1B\x53\x50\x51\x48\x45\x46\x86\x84\x85\x74\x72\x73\x2D\x29\x2A\x2B\x27\x28\xFF\xFF\xFF\x2C\x3A\xBD\x75\x00\x00\x00\x01\x62\x4B\x47\x44\x27\x2D\x0F\xA8\x23\x00\x00\x00\x07\x74\x49\x4D\x45\x07\xE5\x05\x11\x0A\x0B\x10\x59\xCC\xD3\x62\x00\x00\x00\x52\x49\x44\x41\x54\x08\xD7\x63\x60\x40\x07\x8C\x4C\xCC\x8C\x30\x36\x0B\x2B\x1B\x1B\x3B\x07\x84\xCD\xC9\xC5\xCD\xC3\xCB\xC7\xCF\x09\xE6\x08\x08\xF2\x0A\x31\x08\x8B\x88\x42\xB5\x88\x89\x4B\x48\x4A\xC1\x74\x71\x4A\xCB\xC8\xC2\x4D\xE0\x94\x93\x57\x80\x1B\x2D\xA0\xA8\x24\x80\xE0\x28\xAB\x70\x22\x6C\x55\x55\x43\x72\x82\x00\x44\x15\x00\xEA\x7E\x03\x71\xAA\xD2\xFC\x2F\x00\x00\x00\x25\x74\x45\x58\x74\x64\x61\x74\x65\x3A\x63\x72\x65\x61\x74\x65\x00\x32\x30\x32\x31\x2D\x30\x35\x2D\x31\x37\x54\x31\x30\x3A\x31\x31\x3A\x30\x34\x2B\x30\x30\x3A\x30\x30\x18\x6D\xCD\x25\x00\x00\x00\x25\x74\x45\x58\x74\x64\x61\x74\x65\x3A\x6D\x6F\x64\x69\x66\x79\x00\x32\x30\x32\x31\x2D\x30\x35\x2D\x31\x37\x54\x31\x30\x3A\x31\x31\x3A\x30\x34\x2B\x30\x30\x3A\x30\x30\x69\x30\x75\x99\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82", Vector2.new(12, 12))

    avatars.fn_create_item = function(name) 
        avatars.data[name] = {}
        avatars.data[name].url = nil
        avatars.data[name].image = nil
        avatars.data[name].loaded = false
        avatars.data[name].loading = false
    end

    avatars.fn_get_avatar = function(name, entindex)
        if avatars.data[name] and avatars.data[name].loaded then
            return avatars.data[name].image
        end

        if avatars.data[name] == nil then

            avatars.fn_create_item(name)


            local ya_molodec = get_steam_id_fn(entindex)

            if  #ya_molodec<5 then return avatars.default_image end

            avatars.data[name].image = get_avatar(ya_molodec)
            avatars.data[name].loaded = true

        end


        return avatars.default_image
    end



    


    local function get_specs()
        if not EngineClient.IsConnected() or not EngineClient.IsInGame() or not get_value(ui_v.vis.ui_elem , 3) then
            return
        end
        local spectators = {}
        local local_player = EntityList.GetLocalPlayer()
        if not local_player then
            return
        end
        local local_player_ent_index = local_player:EntIndex()
        local local_target = bit.band(local_player:GetProp("m_hObserverTarget"), 0xFFF)
        local is_local_alive = helpers.is_entity_alive(local_player)
        for i = 1, EngineClient.GetMaxClients() do
            local entity = EntityList.GetClientEntity(i)
            if not entity then
                goto continue
            end
            local observer = bit.band(entity:GetProp("m_hObserverTarget"), 0xFFF)
            if not observer then
                goto continue
            end
            if is_local_alive then
                if observer ~= local_player_ent_index then
                    goto continue
                end
                local player = entity:GetPlayer()
                if not player then
                    goto continue
                end
                if player:IsDormant() then
                    goto continue
                end
                local name = player:GetName()
                if not name then
                    goto continue
                end

                spectators[#spectators+1] ={
                    name = name,
                    id = player:EntIndex(),
                }
            else
                if observer ~= local_target then
                    goto continue
                end
                local player = entity:GetPlayer()
                if not player then
                    goto continue
                end
                if player:IsDormant() then
                    goto continue
                end
                local name = player:GetName()
                if not name then
                    goto continue
                end

                spectators[#spectators+1] ={
                    name = name,
                    id = player:EntIndex(),
                }

            end

            ::continue::
        end

        return spectators
    end
    
    local spec_offset = 0
    local g_alpha = 0
    local binds = {}
    local kbinds = draggables:new(2 , Vector2.new(115 , 17) ,  Vector2.new(ui_v.vis.sx , ui_v.vis.sy),ui.vis.sx,ui.vis.sy )
    local blur_alpha = 0
    local box_alpha = 0
    ui.vis.blur_bg:RegisterCallback( function (val)
        
        blur_alpha =     val and 0 or 1
        box_alpha =    val and 1 or 0
        
    end)

    handlers:add("draw" , function()
        local should_work = true
        local mama = get_specs()


        if not mama then should_work = false goto c end

     

        if  mama   then  if #mama==0 then should_work = false end end
        if not get_value(ui_v.vis.ui_elem , 3) then 
            should_work = false
        end

        ::c::

        if  should_work or (Cheat.IsMenuVisible() and get_value(ui_v.vis.ui_elem , 3))   then
            g_alpha = helpers:lerp(g_alpha, 1 , 0.095 , 0.05)
        else
            g_alpha = helpers:lerp(g_alpha, 0 , 0.095 , 0.05)
        end
    
        if g_alpha < 0.01  then return end

        blur_alpha =  helpers:lerp( blur_alpha,    ui_v.vis.blur_bg and  g_alpha or 0 , 0.125)
        box_alpha =  helpers:lerp( box_alpha,  not ui_v.vis.blur_bg and  g_alpha or 0 , 0.125)
        local max_size = 115
        local clamp_alpha = ui.vis.palette:GetColor().a
        local start = kbinds.pos
        local colors = {
            Color.new(colors[1].r, colors[1].g, colors[1].b, colors[1].a * (g_alpha )),
            Color.new(colors[2].r, colors[2].g, colors[2].b, colors[2].a * (g_alpha )),
            Color.new(colors[3].r, colors[3].g, colors[3].b, colors[3].a * (g_alpha ))
        }
        local offset = Vector2.new(kbinds.size.x / 2, 2)

        if kbinds.pos.x +kbinds.size.x/2 < globals.screen_center.x then 
            spec_offset = helpers:lerp(spec_offset, 1 , 0.095)
        else
            spec_offset = helpers:lerp(spec_offset, 0 , 0.095)
        end

        local y_off = 0
        if mama then
            for i = 1 , #mama do
                local bind = mama[i]
                local bind_name = bind.name
                if not binds[bind_name] then 
                    binds[bind_name] = 0
                end
                local val = avatars.fn_get_avatar(bind_name , bind.id)

                if not val then goto skip end

                binds[bind_name]  =  helpers:lerp(binds[bind_name] ,  1  , 0.075 , 0.05)

                if binds[bind_name] <0.01 then goto skip end


                local alpha = binds[bind_name] 

                local text_size = Vector2.new(12,12)
                local text_size2 = Render.CalcTextSize(bind_name, 11, fonts.verdana_10) + Vector2.new(12,12)
                local off = start.y + (y_off ) + 20 

              
                    Render.Texts(bind_name, Vector2.new(start.x + 2 + 17*spec_offset, off), Color.new(1.0, 1.0, 1.0, alpha*g_alpha ), 11, fonts.verdana_10)
                    Render.Image(val , Vector2.new(start.x + (kbinds.size.x - 15)*(1-spec_offset) + 2*spec_offset , off) , Vector2.new(12,12) , Color.new(1,1,1,g_alpha) )
            
   
             


                if max_size < (text_size2.x)+18 then max_size = (text_size2.x+18 ) end

            
                y_off =   y_off + 17 
                ::skip::
            end
        end
        kbinds.size.x = helpers:lerp(kbinds.size.x,  max_size, 0.225 , 0.05)

        if box_alpha~=0 then
            Render.BoxFilled(start, start +  kbinds.size, color(17, 17, 17, g_alpha * accent_alpha*255 * box_alpha))
        end
        if blur_alpha~=0 then
            local blur_col = Color.new(ui.vis.blur_bg:GetColor().r , ui.vis.blur_bg:GetColor().g, ui.vis.blur_bg:GetColor().b, g_alpha*accent_alpha * blur_alpha* ui.vis.blur_bg:GetColor().a)
            Render.Blur(start, start +  kbinds.size, blur_col)
        end

        Render.GradientBoxFilled(start, start + offset, colors[1], colors[2], colors[1], colors[2])
        Render.GradientBoxFilled(start + offset, start + offset + Vector2.new(offset.x, -offset.y), colors[2], colors[3], colors[2], colors[3])

        Render.Texts("spectators", Vector2.new(start.x+ kbinds.size.x/2  , start.y + 8), Color.new(1.0, 1.0, 1.0, g_alpha ), 11, fonts.verdana_10 , true)

        kbinds:update()

    end , "spectators")

    


    handlers:add("events" , function(event)  if event:GetName() == "player_connect_full" or event:GetName() == "cs_game_disconnected" then avatars.data = {} end    end, "destroy_avatars")
   -- handlers:add("draw" , function() if not get_value(ui_v.vis.ui_elem , 3) then return end  if #avatars.data>=32 then avatars.data = {} end  end  , "clear_stuff")

end



local hitsound = function()
    local IEngineSoundClient = ffi.cast("void***" , Utils.CreateInterface("engine.dll", "IEngineSoundClient003")) or error("Failed to find IEngineSoundClient003!")
    local play_sound_fn = ffi.cast("void(__thiscall*)(void*, const char*, float, int, int, float)",IEngineSoundClient[0][12])
    local play_sound = function (name , pitch , bitch)
        return play_sound_fn( IEngineSoundClient, name , pitch , bitch ,0,0)
    end
    
    handlers:add("events", function(event) 
        if not ui_v.vis.hitsound then return end
        if event:GetName()=="player_hurt" then
            if refs_v.hitsound==true then refs.hitsound:Set(false) end

            local attacker = EntityList.GetPlayerForUserID(event:GetInt("attacker", 0))
            local me = EntityList.GetLocalPlayer()
            local userid = event:GetInt("userid", 1)

            local player = EntityList.GetPlayerForUserID(userid)
            if me and attacker == me and player~= me then
               play_sound("buttons\\arena_switch_press_02.wav",  ui_v.vis.hitsound_vol/100 ,100) 
            end

        end
    end , "hitsound")

    handlers:add("destroy" , function()
        
        refs.hitsound:Set(true)
    
    end , "restorce_hs")

end



--ugly but too lazy to recode

ffi.cdef [[
    typedef int(__fastcall* clantag_t)(const char*, const char*);
]]

local fn_change_clantag = Utils.PatternScan("engine.dll", "53 56 57 8B DA 8B F9 FF 15")
local set_clantag = ffi.cast("clantag_t", fn_change_clantag)
local once = false
local animation = {"", "3", "e", "e|", "e|-", "ex", "ex5", "exs", "exs<", "exsc", "exsc*", "exsc0", "exsco", "exsco|",
                   "exsco|-", "exscor", "exscor|", "exscord", "exscord", "exscord", "exscord", "exscord", "exscor|",
                   "exscor", "exsco|-", "exsco|", "exsco", "exsc*", "exsc", "exs<", "exs", "ex5", "ex", "e|-", "e|",
                   "e", "3", "", "", ""}

local old_time = 0
function clantag_cc()
    if not ui_v.vis.clantag then
        if old_time ~= curtime and not once then
            set_clantag(" ", " ")
            once = true
        end
        return
    else
        once = false
        local curtime = math.floor(GlobalVars.curtime * 5.6534)
        if old_time ~= curtime then
            set_clantag(animation[curtime % #animation + 1], animation[curtime % #animation + 1])
        end
        Menu.FindVar("Miscellaneous", "Main", "Spammers", "Clantag"):SetBool(false)
        old_time = curtime
    end

end
handlers:add("draw" , clantag_cc,"clantag")
handlers:add("destroy" , function()
    set_clantag(" ", " ")
end,"clantag")



local function fakelc_indic()
    local get_fake_angle = function ()
        local real = AntiAim.GetCurrentRealRotation()
        local fake = AntiAim.GetFakeRotation()

        return math.min(math.abs(real - fake), AntiAim.GetMaxDesyncDelta())
    end


    local get_avrg = function (table)
        local cnt = 0
        for i =1 , #table do
            cnt = cnt + table[i]
        end
        return cnt/#table
    end


    local records = {}
    local anim_delta = 0
    local dst = 0
    local cur_dst = 0
    local should_work = false
    local choked_max = 0;
    local choked_prev = 0;
    local choked = 0;
    local lerped_color = {0, 0, 0}
    local last_origin = nil
    local g_alpha = 0
    local blur_alpha = 0
    local box_alpha = 0
    ui.vis.blur_bg:RegisterCallback( function (val)
        
        blur_alpha =     val and 0 or 1
        box_alpha =    val and 1 or 0
        
    end)
    handlers:add("createmove" , function(cmd)
        should_work = true

        if not get_value(ui_v.vis.ui_elem , 4) then 
            cur_dst = 0
            dst = 0    
            should_work = false  
            last_origin = nil
        end

        local g_local = EntityList.GetLocalPlayer()

        if not g_local then should_work = false end

        if not should_work then return end

        

        choked_prev = choked;
        choked = ClientState.m_choked_commands
        if choked > choked_max then
            choked_max = choked
        elseif choked == 0 and choked_prev ~= 0 then
            choked_max = choked_prev
        elseif choked == 0 and choked_prev == 0 then
            choked_max = 0
        end

        anim_delta = helpers:lerp(anim_delta ,get_fake_angle() , 0.095 , 0.01) 



        if not FakeLag.Choking() and last_origin    then
            records[#records+1] =  math.abs((last_origin - g_local:GetProp("m_vecOrigin")):Length2D())
            cur_dst = math.abs((last_origin - g_local:GetProp("m_vecOrigin")):Length2D())*g_alpha
            dst = get_avrg(records)*g_alpha
            last_origin = g_local:GetProp("m_vecOrigin")
        end

        if not last_origin  then
            last_origin = g_local:GetProp("m_vecOrigin")
        end


           
     

        if #records > 8 then
            table.remove(records, 1)
        end

    end , "gather_info") 

    local text_size_fake = 0
    local animbox= 0
    local shifting_offset = 0
    local dst_offset = 0
    local lenin_bidlo = 0
    local wtf = 0
    local to_render_dst = 0
    local lc_width = 0
    handlers:add("draw" , function()
        if not helpers.cm_check() then should_work = false end

        if not should_work then
            g_alpha = helpers:lerp(g_alpha, 0, 0.115 , 0.05)
            globals.fake_height = helpers.sine3(globals.fake_height , 0 , 0.095 , 0.01)
        else
            g_alpha = helpers:lerp(g_alpha, 1 , 0.115 , 0.05)
            globals.fake_height = helpers.sine3(globals.fake_height , 22 , 0.095 , 0.01)
        end


        blur_alpha =  helpers:lerp( blur_alpha,    ui_v.vis.blur_bg and  g_alpha or 0 , 0.125)
        box_alpha =  helpers:lerp( box_alpha,  not ui_v.vis.blur_bg and  g_alpha or 0 , 0.125)

        if g_alpha < 0.05  then return end
    
        local safety = math.min(helpers.round(1.8 * math.abs(anim_delta)), 100);
        local delta_string = string.format("%.1f", anim_delta)
    
 

        local text = "FAKE (" .. delta_string .. "°)  "
        text_size_fake = Render.CalcTextSize(text, 11, fonts.verdana_10).x
        animbox = helpers:lerp(animbox, text_size_fake - (delta_string ~= 0 and 0 or 15), 0.095 , 0.05)

        local lc_offset =  lc_width + 4 
        local watermark_offset = -globals.watermark_h
        local start = Vector2.new(globals.screen_size.x - animbox - 19 - lc_offset, 8 - watermark_offset)
        local alphaless = color(17, 17, 17, 25 * g_alpha*box_alpha)
        local alphaness = color(17, 17, 17, accent_alpha * 255 * g_alpha*box_alpha)
        local width = Vector2.new((animbox + 4) / 2, 17)
        
        local start2 = start + Vector2.new(width.x, 0)
        if box_alpha~=0 then
            Render.GradientBoxFilled(start, start + width, alphaless, alphaness, alphaless, alphaness)
            Render.GradientBoxFilled(start2, start2 + width, alphaness, alphaless, alphaness, alphaless)
        end
        if blur_alpha ~=0 then
            local blur_col = Color.new(ui.vis.blur_bg:GetColor().r , ui.vis.blur_bg:GetColor().g, ui.vis.blur_bg:GetColor().b, g_alpha*accent_alpha * blur_alpha* ui.vis.blur_bg:GetColor().a)
            Render.Blur(start, start + width,blur_col)
            Render.Blur(start2, start2 + width, blur_col)
        end
        
        local color_zero = Color.new((255 - safety * 2.5) / 255, (safety * 2.5) / 255, (17) / 255, 0)
        local color_notzero = Color.new((255 - safety * 2.5) / 255, (safety * 2.5) / 255, (17) / 255, g_alpha)
        Render.GradientBoxFilled(start, start + Vector2.new(2, 9), color_zero, color_zero, color_notzero, color_notzero)
    
        local start1 = start + Vector2.new(0, 9)
        Render.GradientBoxFilled(start1, start1 + Vector2.new(2, 9), color_notzero, color_notzero, color_zero, color_zero)
        
    
        Render.Texts(text, Vector2.new(globals.screen_size.x - animbox - 12 - lc_offset - 1, 10 - watermark_offset),  Color.new(1, 1, 1, g_alpha), 11, fonts.verdana_10)
        
        
        if Exploits.GetCharge() == 1 and refs_v.dt and wtf==0 then
            shifting_offset =  helpers:lerp(shifting_offset, 62, 0.095 , 0.5)
            lenin_bidlo =  helpers:lerp(lenin_bidlo, shifting_offset > 50 and 1 or 0, 0.045 , 0.5)
        else
            shifting_offset =  helpers:lerp(shifting_offset, 0, 0.095 , 0.5)
            lenin_bidlo =  helpers:lerp(lenin_bidlo, 0, 0.315 , 0.5)
        end
    
        if dst > 40   and lenin_bidlo==0 and not refs_v.dt then
            dst_offset = helpers:lerp(dst_offset, 57 , 0.095 , 0.5)
            wtf =  helpers:lerp(wtf, dst_offset > 50 and  1 or 0  , 0.095 , 0.5)
        else
            dst_offset = wtf==0 and 0 or 57
            wtf =  helpers:lerp(wtf,  0   , 0.015 , 0.5)
        end
        
        local start = Vector2.new(globals.screen_size.x - 25, 8 - watermark_offset)
        lc_width = 37 + shifting_offset + dst_offset
    
        local off = Vector2.new(-24 - shifting_offset - dst_offset, 0)
        if box_alpha~=0 then
            Render.BoxFilled(start + off, start + off + Vector2.new(lc_width, 16), color(17, 17, 17, accent_alpha * 255 * g_alpha*box_alpha))
        end
        if blur_alpha~=0 then
            local blur_col = Color.new(ui.vis.blur_bg:GetColor().r , ui.vis.blur_bg:GetColor().g, ui.vis.blur_bg:GetColor().b, g_alpha*accent_alpha * blur_alpha* ui.vis.blur_bg:GetColor().a)
            Render.Blur(start + off, start + off + Vector2.new(lc_width, 16), blur_col)
        end
        Render.Texts("FL:", start + Vector2.new(off.x + 5, 1.5), Color.new(1, 1, 1, g_alpha), 11, fonts.verdana_10)
        
        local col = ui.vis.palette:GetColor()

        local colors = {
            Color.new(col.r, col.g, col.b, wtf * g_alpha ),
            Color.new(col.r, col.g, col.b, 0),
        }


        local c_text = tostring(choked_max)
        local bidlan = choked_max < 10 and 10 or 15
    
        Render.Texts(c_text, start + Vector2.new(10 - bidlan - shifting_offset - dst_offset, 1.5), Color.new(1, 1, 1, g_alpha),  11, fonts.verdana_10)
    
        if shifting_offset ~= 0 and dst_offset==0 then
            Render.Texts(" | SHIFTING", start + Vector2.new(10 - bidlan - shifting_offset + 5, 1),   Color.new(1, 1, 1, lenin_bidlo * g_alpha), 11, fonts.verdana_10)
        end


    
        local grad_col = shifting_offset ~= 0 and {255, 130, 0} or {150, 150, 150}
        lerped_color[1] = helpers:lerp(lerped_color[1], grad_col[1], 0.025)
        lerped_color[2] =  helpers:lerp(lerped_color[2], grad_col[2], 0.025)
        lerped_color[3] = helpers:lerp(lerped_color[3], grad_col[3], 0.025)
    
        local grad_offs = Vector2.new(-lc_width / 2 - shifting_offset / 2 -6 - dst_offset/2, 16)
        local alphaness = color(lerped_color[1], lerped_color[2], lerped_color[3], 255 * g_alpha)
        local alphaless = color(lerped_color[1], lerped_color[2], lerped_color[3], 0)
        local width = Vector2.new(lc_width / 2, 1)
        Render.GradientBoxFilled(start + grad_offs, start + grad_offs + width, alphaless, alphaness, alphaless, alphaness)
        Render.GradientBoxFilled(start + grad_offs + Vector2.new(width.x, 0), start + grad_offs + width + Vector2.new(width.x + 1, 0), alphaness, alphaless, alphaness, alphaless)
    
        if dst_offset ~= 0 and shifting_offset == 0  and g_alpha==1 and lenin_bidlo==0 then
            Render.Texts(" | dst:", start + Vector2.new( bidlan-dst_offset +15-20, 1),   Color.new(1, 1, 1, wtf * g_alpha), 11, fonts.verdana_10)
            local st = start + Vector2.new( 48 - dst_offset+bidlan-20, 5)
            to_render_dst = helpers:lerp(to_render_dst, cur_dst , 0.045)
            Render.GradientBoxFilled(st, st + Vector2.new((to_render_dst*wtf)/3, 6) , colors[1] , colors[2] , colors[1] , colors[2]   )
        end


    end , "fake_lc")


end



local function WATAFAK()

    local devmode_ptr = ffi.new("struct _devicemodeA")
    devmode_ptr.dmSize = ffi.sizeof(devmode_ptr)
    ffi.C.EnumDisplaySettingsA(0, -1, devmode_ptr)
    
    local display_frequency = devmode_ptr.dmDisplayFrequency
    local input_lag_raw = 0
    local visual_input_lag = 0
    local screen_size = EngineClient.GetScreenSize()
    local last_unixtime = 0

    local color_for_gradient = Color.new(0, 0, 0, 0)
    local maximum = 0
    local start_position = Vector2.new(screen_size.x - 6, 10 + globals.watermark_h + globals.fake_height)
    local end_position = Vector2.new(screen_size.x - 6, 10 + globals.watermark_h + globals.fake_height)
    local frequency_list = {}
    local blur_alpha = 0
    local box_alpha = 0
    local g_alpha = 0
    ui.vis.blur_bg:RegisterCallback( function (val)
        
        blur_alpha =     val and 0 or 1
        box_alpha =    val and 1 or 0
        
    end)
    handlers:add( "draw" , function ()
        if  get_value(ui_v.vis.ui_elem , 5) then
            g_alpha = helpers:lerp(g_alpha, 1 , 0.095)
        else
            g_alpha = helpers:lerp(g_alpha, 0 , 0.095)
        end

        if g_alpha < 0.01  then return end

        visual_input_lag = helpers:lerp(visual_input_lag, input_lag_raw, 0.15)
        local text_to_render = string.format("%.2fms / %shz", visual_input_lag, display_frequency)
        local text_size = Render.CalcTextSize(text_to_render, 11, fonts.verdana_10)
        local io_text_size = Render.CalcTextSize("IO |", 11, fonts.verdana_10)

        start_position.y =  10 + globals.watermark_h + globals.fake_height
        blur_alpha =  helpers:lerp( blur_alpha,    ui_v.vis.blur_bg and  accent_alpha or 0 , 0.125)
        box_alpha =  helpers:lerp( box_alpha,  not ui_v.vis.blur_bg and  accent_alpha or 0 , 0.125)
        end_position.x = helpers:lerp(end_position.x, screen_size.x - 6 - text_size.x - 20, 0.095)
        end_position.y =  10 + globals.watermark_h + globals.fake_height + text_size.y
        
        if box_alpha~=0 then
            Render.BoxFilled(Vector2.new(start_position.x - 5, start_position.y - 2), Vector2.new(end_position.x + 8, end_position.y + 1), Color.new(0, 0, 0,g_alpha* accent_alpha * box_alpha))
            Render.BoxFilled(Vector2.new(end_position.x, end_position.y + 2), Vector2.new(end_position.x - io_text_size.x - 29 - 1, start_position.y - 2), Color.new(0, 0, 0, g_alpha*accent_alpha * box_alpha))
        end
        if blur_alpha ~=0 then
            local blur_col = Color.new(ui.vis.blur_bg:GetColor().r , ui.vis.blur_bg:GetColor().g, ui.vis.blur_bg:GetColor().b, g_alpha*accent_alpha * blur_alpha *ui.vis.blur_bg:GetColor().a) 
            Render.Blur(Vector2.new(start_position.x - 6, start_position.y - 2), Vector2.new(end_position.x + 8, end_position.y + 1), blur_col)
            Render.Blur(Vector2.new(end_position.x, end_position.y + 2), Vector2.new(end_position.x - io_text_size.x - 29 - 1, start_position.y - 2), blur_col)
        end
        Render.Texts(text_to_render, Vector2.new(start_position.x - text_size.x - 9, start_position.y-1), Color.new(1.0, 1.0, 1.0, g_alpha), 11, fonts.verdana_10)
        Render.Texts("IO |", Vector2.new(end_position.x - io_text_size.x - 27, start_position.y-1), Color.new(1.0, 1.0, 1.0, g_alpha), 11, fonts.verdana_10)
        local local_maximum = 0
        for i = 1, #frequency_list do
            if (frequency_list[i].input_lag > local_maximum) then
                local_maximum = frequency_list[i].input_lag
            end
        end

        maximum = helpers:lerp(maximum, local_maximum, 0.095)

        for i in ipairs(frequency_list) do

            if frequency_list[i].animation_state < 0 then
                table.remove(frequency_list, i)
                break
            end
            if i > 4 then
                frequency_list[i].animation_state = helpers:lerp(frequency_list[i].animation_state, -1, 0.095)
            else
                frequency_list[i].animation_state = helpers:lerp(frequency_list[i].animation_state, 1, 0.095)
            end
            local color_ui = ui.vis.palette:GetColor()
            local color_gradient_first = Color.new(color_ui.r, color_ui.g, color_ui.b, frequency_list[i].animation_state * 1 * g_alpha)
            local color_gradient_second = Color.new(color_ui.r, color_ui.g, color_ui.b, frequency_list[i].animation_state * 0.2 * g_alpha)

            if (frequency_list[i].position_1.x == -1) then
                frequency_list[i].position_1 = Vector2.new(end_position.x - 3 - (5 * (i - 1)) - 5, end_position.y)
                frequency_list[i].position_2 = Vector2.new(end_position.x - 3 - (5 * (i - 1)), end_position.y - math.min(10 * (frequency_list[i].input_lag / maximum), 10))
            else
                frequency_list[i].position_1 = Vector2.new(helpers:lerp(frequency_list[i].position_1.x, end_position.x - 3 - (5 * (i - 1)) - 5, 0.095), end_position.y)
                frequency_list[i].position_2 = Vector2.new(helpers:lerp(frequency_list[i].position_2.x, end_position.x - 3 - (5 * (i - 1)), 0.095), end_position.y - math.min(10, 10 * (frequency_list[i].input_lag / maximum)))
            end

            Render.GradientBoxFilled(frequency_list[i].position_1, frequency_list[i].position_2, color_gradient_first, color_gradient_first, color_gradient_second, color_gradient_second)
        end

        color_for_gradient = Color.new(helpers:lerp(color_for_gradient.r, visual_input_lag / 10, 0.015), helpers:lerp(color_for_gradient.g, 1 - (visual_input_lag / 60) * 2, 0.055), 0, g_alpha)
        local color_gradient_2 = Color.new(color_for_gradient.r, color_for_gradient.g, color_for_gradient.b, 0.25*g_alpha)

        Render.GradientBoxFilled(Vector2.new(start_position.x-5  , end_position.y + 2), Vector2.new(end_position.x -4 + (start_position.x - end_position.x) / 2, end_position.y + 1), color_gradient_2, color_for_gradient, color_gradient_2, color_for_gradient)
        Render.GradientBoxFilled(Vector2.new(start_position.x  - (start_position.x - end_position.x) / 2, end_position.y + 2), Vector2.new(end_position.x + 8, end_position.y + 1), color_for_gradient, color_gradient_2, color_for_gradient, color_gradient_2)

        if (Utils.UnixTime() > last_unixtime) then
            input_lag_raw = GlobalVars.frametime * display_frequency * 10
            table.insert(frequency_list, 0, {
                input_lag = input_lag_raw,
                animation_state = 0.01,
                position_1 = Vector2.new(-1, -1),
                position_2 = Vector2.new(-1, -1)
            })
            last_unixtime = Utils.UnixTime() + 2000
        end

    end , "perf_bar") 

end


local logs = {
    data = {},

    add = function(self, should_render , ... )
        if should_render then
            self.data[#self.data+1] = {text = (...) ,  a= 0 ,t = GlobalVars.curtime}
        else
            local arg = {...}
            for _ , v in pairs(arg) do
                local text , color = unpack(v)
                helpers.color_print(text , color)
            end
            print()
        end
    end,

    render = function(self)
        local adding = 0
        for idx , log_data in ipairs(self.data) do
            if GlobalVars.curtime - log_data.t < 3.5 and not (#self.data>10 and idx < #self.data-10)  then 
                log_data.a = helpers:lerp(log_data.a , 1 , 0.095 , 0.01)
            else 
                log_data.a = helpers:lerp(log_data.a , 0 , 0.095 , 0.01)


            end


            adding = adding + 15*log_data.a

            
            if log_data.a >0.01 and -11+adding > 1 then
                Render.Texts(log_data.text , Vector2.new(4 , -11 + math.abs(adding) ) , Color.new(1,1,1,log_data.a) , 10, fonts.font_log , false ) 
            end



            ::c::

        end
    end
}



handlers:add("draw" , function()
    if not ui_v.rage.logs or not ui_v.rage.master_rage then return end
    logs:render()

end , "draw_logs")



handlers:add("ragebot_shot" , function(shot)

    if not ui_v.rage.logs or not ui_v.rage.master_rage or not get_value(ui_v.rage.logs_type , 1) then return end

    local pEnt = EntityList.GetPlayer(shot.index)

    if not pEnt then return end

    local pName = pEnt:GetName()
    local dmg = shot.damage
    local hbox = globals.hitboxes[shot.hitgroup+1]
    local hc , bt = shot.hitchance , shot.backtrack

    local str = "Fired shot at "..pName.."'s "..hbox .." for "..dmg .. " damage [hc: "..hc.." , bt: "..bt.."]"

    local col = Color.new(1 , 0.7 , 0.4)
    local white = Color.new(1,1,1,1)

   -- logs:add(true ,str )
    logs:add(false , {"[" ,white } , {""..script_name.."" , col}  , {"] " , white} , {"Fired shot at " , white} , {pName.."'s "..hbox , col} , {" for " , white}, {dmg , col} ,  {" damage [hc: "..hc.." , bt: "..bt.."]" , white})



end , "gather_info_rbshot")


handlers:add("registered_shot" , function(shot)

    if not ui_v.rage.logs or not ui_v.rage.master_rage then return end

    local pEnt = EntityList.GetPlayer(shot.target_index)

    if not pEnt then return end

    local reasons_default = {"resolver", "spread", "occlusion", "prediction error"}
    local pName = pEnt:GetName()
    local dmg = shot.damage
    local hbox = globals.hitboxes[shot.hitgroup+1]
    local hc , bt = shot.hitchance , shot.backtrack

   
    local white = Color.new(1,1,1,1)
    local pweap = EntityList.GetLocalPlayer():GetActiveWeapon()
    local prefix = "Hit"
    if not pweap then return end

    if shot.reason==0 and pweap:GetClassID()~=268  then
        if get_value(ui_v.rage.logs_type , 2) then
            local str = "["..script_name.."] Hit "..pName.." in the "..hbox .." for "..dmg .. " damage [hc: "..hc.." , bt: "..bt.."]"
            local col = Color.new(0.65 , 0.85 , 0.15 , 1)

            logs:add(true ,str )
            logs:add(false , {"[" ,white } , {""..script_name.."" , col}  , {"] " , white} , {"Hit " , white} , {pName , col} , {" in the " , white} , {hbox , col} , {" for " , white}, {dmg , col} ,  {" damage [hc: "..hc.." , bt: "..bt.."]" , white})
        end
    else
        if get_value(ui_v.rage.logs_type , 3) and pweap:GetClassID()~=268 then
            local col = Color.new(0.8 , 0.2 , 0.2 , 1)
            local ang = math.floor(shot.spread_degree*100)/100
            local r = reasons_default[shot.reason] and reasons_default[shot.reason]  or "?"
            local str = "["..script_name.."] Missed "..pName.." due to "..r .. " [angle: " .. ang.. "°, hc: "..hc.." , bt: "..bt.."]"
            logs:add(true ,str )
            logs:add(false , {"[" ,white } , {""..script_name.."" , col}  , {"] " , white} , {"Missed " , white} , {pName , col} , {" due to " , white}, {r , col} ,  { " [angle: " .. ang.. "°, hc: "..hc.." , bt: "..bt.."]" , white})
        end
    end

end , "gather_info_regshot")

local wpn_list = {
    ["molotov"] = 1,
    ["inferno"] = 1,
    ["knife"] = 1,
    ["hegrenade"] =1,
    ["taser"] = 1,
    ["smokegrenade"] = 1,
    ["decoy"] = 1,
    ["flashbang"] =1,
}

handlers:add("events" , function(event) 

    if not ui_v.rage.logs or not ui_v.rage.master_rage  then return end

    if event:GetName()~="player_hurt" then return end

    local target_player = EntityList.GetPlayerForUserID(event:GetInt("userid", 0))
    if not target_player then return end

    local attacker_player = EntityList.GetPlayerForUserID(event:GetInt("attacker", 0))
    if not attacker_player then return end
    local wpn = event:GetString("weapon")
    local pName = attacker_player:GetName()
    local pName2 = target_player:GetName()
    local dmg = event:GetInt("dmg_health")
    local hbox = globals.hitboxes[event:GetInt("hitgroup")+1]
    local rem = event:GetInt("health")
    if target_player==EntityList.GetLocalPlayer() and target_player~=attacker_player and get_value(ui_v.rage.logs_type , 4) then
        local str = "["..script_name.."] " ..pName.." harmed you in the "..hbox .." for "..dmg .. " damage ("..rem.." health remaining)"
        local col = Color.new(1 , 0.5 , 0.5 , 1)
        local white = Color.new(1,1,1,1)
        logs:add(true ,str )

        logs:add(false , {"[" ,white } , {""..script_name.."" , col}  , {"] " , white} ,  {pName , col} , {" harmed you in the " , white} , {hbox , col} , {" for " , white}, {dmg , col} ,  {" damage ("..rem.." health remaining)" , white})
    end

    if target_player~=EntityList.GetLocalPlayer() and attacker_player==EntityList.GetLocalPlayer() and get_value(ui_v.rage.logs_type , 2) then
        local prefix = "Hit"

        if wpn=="hegrenade"  then prefix = "Naded" end
        if wpn=="taser" then prefix = "Zeused" end
        if wpn=="inferno" then prefix = "Burned" end
        if wpn=="knife" then prefix = "Knifed" end
        
        if wpn_list[wpn] or target_player:IsDormant() or not refs_v.rb then
            local str = "["..script_name.."] " .. prefix .." "..pName2.." for "..dmg .. " damage (" ..rem .. " health remaining)" 
            local col = Color.new(0.65 , 0.85 , 0.15 , 1)
            local white = Color.new(1,1,1,1)
            logs:add(true ,str )
            logs:add(false , {"[" ,white } , {""..script_name.."" , col}  , {"] " , white} , {prefix.." " , white} , {pName2 , col} , {" for " , white}, {dmg , col} ,  {" damage (" ..rem .. " health remaining)" , white})
        end
    end
    


end , "hur_logs")



--#endregion



--#region rage



local function dormant_aimbot()



    local scan_data = {
        point = nil,
        damage = ui_v.rage.d_min_damage,
        hit_ent = nil,
        name = "",
        tick = 0,
    }

    local get_ent_ptr = function(ent)
        if not ent then return nil end
        return GET_CLIENT_ENTITY_FN(ENTITY_LIST_POINTER , ent:EntIndex()) 
    end
    
    local accepted_weapons = {[261]=1, [242]=1, [233]=1, [267]=1}


    handlers:add("createmove" , function(cmd)
        if not ui_v.rage.master_rage or not ui_v.rage.d_switch then return end
        scan_data = {
            point = nil,
            damage = ui_v.rage.d_min_damage,
            hit_ent = nil,
            name = "",
            tick = 0,
        }
        local lp = EntityList.GetLocalPlayer()
        local shoot_pos = EntityList.GetLocalPlayer():GetEyePosition()
        for _ , player in pairs(EntityList.GetPlayers()) do
            if not player or player:IsTeamMate() or not player:IsAlive() or not player:IsDormant() or player:GetNetworkState() ==-1 or player:GetNetworkState()==4 then goto skip end
           
           
            local pos = player:GetProp("m_vecOrigin")
            local ang = math.rad(helpers.calc_angle(shoot_pos , pos).yaw)
            local check_visible = EngineTrace.TraceRay(shoot_pos , pos + Vector.new(0,0,40) , lp , 0xFFFFFFFF)
            if check_visible.fraction ==1 then 
            --    print_dbg("vis")
                goto skip end
            for k = 25, 45, 5 do -- get points from bbmins , bbmaxs
                for j = -4, 4, 4 do
                    local point = pos + Vector.new(  j*math.sin(ang) ,  -j*math.cos(ang),  k)
                    local fire_data = Cheat.FireBullet(EntityList.GetLocalPlayer() , shoot_pos , point)
                   
                    if fire_data.damage >=  scan_data.damage and not fire_data.trace.hit_entity  then
                        scan_data.point = point
                        scan_data.damage = fire_data.damage
                        scan_data.hit_ent = player
                        scan_data.tick = GlobalVars.tickcount
                        scan_data.name = player:GetName()
                        return
                    end
                end
            end
            ::skip::    
        end


        

    end , "dormant_aimbot_scan")

    local ticks_to_time = function(t) return t*GlobalVars.interval_per_tick  end 
    handlers:add("pre_prediction" , function(cmd)
        
        if not ui_v.rage.master_rage or not ui_v.rage.d_switch then return end
       
        if not scan_data.point or not scan_data.hit_ent or not scan_data.hit_ent:IsDormant() or not scan_data.name or scan_data.tick == 0 then 
    --        print_dbg("smth wrong with ent")
            return end
        local weap = EntityList.GetLocalPlayer():GetActiveWeapon()

        if not weap or weap:IsKnife() then return end

        local lp = EntityList.GetLocalPlayer()
        
        local pacan_time = ticks_to_time(lp:GetProp("m_nTickBase"))

        if pacan_time - lp:GetProp("m_flNextAttack") < 0.05 or pacan_time - weap:GetProp("m_flNextPrimaryAttack") < 0.05 then 
   --         print_dbg("shoot fail ".. scan_data.damage .. " ent: " )
            return end

        if weap:GetInaccuracy(weap) > 0.12 * (1-(refs_v.hc+1)/100) then
          --  print_dbg("hitchance fail ".. scan_data.damage .. " ent: "..weap:GetInaccuracy(weap) )
            return end

        if accepted_weapons[weap:GetClassID()] and not lp:GetProp("m_bIsScoped") then    --autoscope
            cmd.buttons = bit.bor(cmd.buttons , 2048)
        end

    --     local addr = get_ent_ptr(scan_data.hit_ent)

    --     if not addr then 
    --  --       print_dbg("addr fucked up"..addr)
    --         return end
        local shoot_pos = EntityList.GetLocalPlayer():GetEyePosition()

--         ffi.cast("bool*" , addr + 0xED)[0] = 0
--         local check_trace = Cheat.FireBullet( EntityList.GetLocalPlayer(), shoot_pos , scan_data.point)
--         if check_trace.damage < 1 then 
--    --         print_dbg("bro you dumb")
--             ffi.cast("bool*" , addr + 0xED)[0] = 1
--             return end
--         ffi.cast("bool*" , addr + 0xED)[0] = 1


        
        cmd.viewangles = helpers.calc_angle(shoot_pos , scan_data.point) 
        cmd.buttons = bit.bor(cmd.buttons , 1)
        cmd.tick_count = cmd.tick_count - 1
        


        local white = Color.new(1,1,1,1)
        local col = Color.new(0,0.6 , 1 , 1)
        logs:add(true , "["..script_name.."] attempted shot by dormant aimbot [target: " .. scan_data.name.." , tick: "..scan_data.tick.." , dmg: "..math.floor(scan_data.damage) .." ]")
    --    print_dbg("fired shot for " .. scan_data.damage .. " ent: ")
        logs:add(false , {"[" ,white } , {""..script_name.."" , col}  , {"] " , white} , {"attempted shot by dormant aimbot [target: " , white} , {scan_data.name , col} , {" , tick: "..scan_data.tick.." , " , white} , {"dmg: " , white} , {math.floor(scan_data.damage) , col} , {" ]" , white})
    
    end , "dormant_aimbot_fire")


end


local function anti_exploit()
    local cvar = CVar.FindVar("cl_lagcompensation")

    local join_tick = 0
    local function handlechanges(teamnum)
        if teamnum == 1 then return end
        EngineClient.ExecuteClientCmd("teammenu")
        EngineClient.ExecuteClientCmd("jointeam 1")
        join_tick = GlobalVars.realtime + 0.8
    end

    local should_change = -1
    local team_cache = 2
    local is_enabled = false
    ui.rage.anti_mishkat:RegisterCallback(
        function ()
            if not ui_v.rage.master_rage then return end
            if not EngineClient.IsConnected() then
                cvar:SetInt(ui_v.rage.anti_mishkat and 0 or 1)
                return
            end

            should_change =ui_v.rage.anti_mishkat and 0 or 1
            handlechanges(team_cache)
            is_enabled = true
        end
    )

    handlers:add("draw",function ()
        if GlobalVars.tickcount % 100 == 0 then
            ui.rage.anti_mishkat:Set(cvar:GetInt() == 0)
        end

        if not is_enabled then return end

        if not EntityList.GetLocalPlayer() then return end

        local lp = EntityList.GetLocalPlayer()

        if EntityList.GetLocalPlayer():IsAlive() then
            team_cache = lp:GetProp("m_iTeamNum")
        end

        if join_tick < GlobalVars.realtime then
            EngineClient.ExecuteClientCmd("jointeam ".. team_cache .." 1")
            join_tick = 0
            is_enabled = false
        end

        if should_change ~= -1 and lp:GetProp("m_iTeamNum") == 1 then
            cvar:SetInt(should_change)
            should_change = -1
        end
    end, "ax")
end

local custom_hc = function()
    local accepted_weapons = {
        ["261"] = 1,
        ["242"] = 1,
    }
    local accepted_weapons2 = {
        ["267"] = 1,
        ["46"] = 1,
    }


    local get_enemies = function()
        local ret = {}
        local players = EntityList.GetPlayers()
        for _ , player in pairs(players) do        
            if player:IsTeamMate() or not player:IsAlive() or player:IsDormant() then goto s end

            ret[#ret+1] = player:EntIndex()
            ::s::
        end

        return ret
    end

    handlers:add("pre_prediction" , function()
        if not ui_v.rage.master_rage or ui_v.rage.hc_main==0 then return end
    
        local i = get_enemies()
        local air_check = bit.band(EntityList.GetLocalPlayer():GetProp("m_fFlags"), 1) == 0 and ui.rage.hc_main:GetBool(1) and EntityList.GetLocalPlayer():GetActiveWeapon() and accepted_weapons2[""..EntityList.GetLocalPlayer():GetActiveWeapon():GetClassID()]
        local wpn_check = ui.rage.hc_main:GetBool(2) and EntityList.GetLocalPlayer():GetProp("m_bIsScoped")==false and EntityList.GetLocalPlayer():GetActiveWeapon() and accepted_weapons[""..EntityList.GetLocalPlayer():GetActiveWeapon():GetClassID()]


        if (not air_check and not wpn_check)  then return end

    
       
        for k,v in pairs(i) do RageBot.OverrideHitchance(v , (air_check==1 and ui_v.rage.ahc or ui_v.rage.nhc)) end
    end , "hc")

end



local auto_teleport = function ()
    local should_teleport = false
    local get_closet_enemy = function ()
        local g_Local = EntityList.GetLocalPlayer()

        if not g_Local then return nil end

        local dist = math.huge
        local playerr = nil
        for _ , player in pairs(EntityList.GetPlayers()) do
            if not player or player:IsDormant() or player:IsTeamMate() or not  player:IsAlive() then goto cont end 

            if helpers.get_origin(g_Local):DistTo(helpers.get_origin(player)) < dist then 
                dist = helpers.get_origin(g_Local):DistTo(helpers.get_origin(player))
                playerr = player
            end
            ::cont::
        end

        return playerr
    end

    local delay = 0
    
    local weaps = {
        {["233"] = 1},
        {["242"] = 1 , ["261"] = 1},
        {["267"] = 1},
        {["46"] = 1},
        {["245"] = 1, ["258"] = 1 , ["241"] = 1, ["239"] = 1, ["269"] = 1,  ["246"] = 1},
        {["96"] = 1 , ["156"] = 1, ["47"] = 1,["77"] = 1, ["113"] = 1, ["99"] = 1},
        {["268"] = 1},
    }
    local not_other = {}

    for i=1 , 7 do
        for j ,k in pairs( weaps[i]) do
            not_other[""..j..""] =k
        end
    end



    handlers:add("createmove" , function (cmd)
        local g_Local = EntityList.GetLocalPlayer()

        if not g_Local then return end

        if refs_v.hs and not refs_v.dt then return end

        if not ui_v.rage.shtu4ka or  not ui_v.rage.master_rage or bit.band(g_Local:GetProp("m_fFlags") , 1 ) ~=0 then return end

        local weap = g_Local:GetActiveWeapon()

        if not weap then return end

        local weap_id = tostring(weap:GetClassID())
        local work = false
        for i=1 , 8 do
            if work then break end
            if get_value(ui_v.rage.teleport_wps , i) then
                if i==8 then
                    work =  not_other[weap_id] ~=1
                else

                    work = weaps[i][weap_id] ==1
                end
            end
        end
    
        if not work then return end

        local move_raw = g_Local:GetProp("m_vecVelocity")
        local move = Vector.new(move_raw.x , move_raw.y , 0)
        local lp_pos = g_Local:GetHitboxCenter(0)
        globals.predicted_pos = helpers.extrapolate(g_Local , lp_pos , 2 , 0)
        globals.predicted_pos_after_dt = globals.predicted_pos + move*0.1

        if not get_closet_enemy() then return end

        local p = get_closet_enemy()

        local fb = Cheat.FireBullet(p , p:GetEyePosition() , globals.predicted_pos)
        local fb1 = Cheat.FireBullet(p , p:GetEyePosition() , globals.predicted_pos_after_dt)



        if Exploits.GetCharge() < 0.9 and  globals.teleported_last_tick  then
            Exploits.ForceCharge()
        end

        if fb.damage > fb1.damage and (fb.damage > 1 ) then
            should_teleport = true
        else 
            globals.teleported_last_tick = false
        end

        if should_teleport then
            if delay == 2 then
                Exploits.ForceTeleport()
              --  Exploits.AllowCharge(false)
                should_teleport = false
                delay = 0
            globals.teleported_last_tick = true

            else
                delay  = delay + 1
                globals.teleported_last_tick = false
            end
        end

    end , "auto_teleport")
end


--#endregion

--#region aa

local function extended_desync()

    handlers:add("pre_prediction" , function(cmd)
        if not ui_v.aa.aa_main or not ui_v.aa.extended_dsy then return end
        local lp = EntityList.GetLocalPlayer()

        if #lp:GetProp("m_vecVelocity") >10 and not refs_v.sw then return end

        local side = AntiAim.GetInverterState() and 1 or -1
        cmd.viewangles.roll = 45*side

    end , "extended_desync")

end


local cache_warmup = refs_v.aa_main

local function warmup_disablers()
    if not ui_v.aa.warmup_disablers then globals.aa_dis = false return end
    local rules = EntityList.GetGameRules()
    if not rules then return end
    local is_warmup = rules:GetProp("m_bWarmupPeriod")
    globals.aa_dis = is_warmup and ui_v.aa.warmup_disablers

    if is_warmup and refs_v.aa_main then
        cache_warmup = refs_v.aa_main
        refs.aa_main:Set(false)
    else
        refs.aa_main:Set(cache_warmup)
    end

end

ui.aa.warmup_disablers:RegisterCallback(function(val)
    local rules = EntityList.GetGameRules()
    if not rules then return end
    local is_warmup = rules:GetProp("m_bWarmupPeriod")
    if val==true and is_warmup then
        refs.aa_main:Set(false)
    else
        refs.aa_main:Set(cache_warmup)
    end
end)

handlers:add("createmove" , warmup_disablers , "warmup_disablers")

local edge_yaw_on = false
local edgeyaw = function ()
    local data = {
        dist = 1337028,
        i = -181,
        ang = QAngle.new(0, 0, 0)
    }
 
    handlers:add("prediction",function(args)
        if not ui_v.aa.aa_main or not ui_v.aa.edge or globals.legit_aa_on or bit.band(EntityList.GetLocalPlayer():GetProp("m_fFlags") , 1 ) == 0 or globals.in_antibrute then
            edge_yaw_on = false
            return
        end
    
        local yaw_b =  ui_v.aa.type and ui_v.aa.manual-1 or refs_v.yaw_b
        local yaw_add = yaw_b == 0 and 180 or yaw_b == 2 and -90 or yaw_b == 3 and 90 or 0
        local me = EntityList.GetLocalPlayer()
        local lp_head = me:GetRenderOrigin() + Vector.new(0, 0, 64)
        local lp_body = me:GetRenderOrigin() + Vector.new(0, 0, 64)
        local start_angles = helpers.normalize_angles(args.viewangles)
        local trace_ang = QAngle.new(0, start_angles.yaw, 0)
        for i = -180, 180, 10 do
            local traced = EngineTrace.TraceRay(lp_head, (lp_head + Cheat.AngleToForward(trace_ang) * 8192), me, 16395)
            if (traced.fraction * 8192 < data.dist or data.dist == -1) and traced.fraction * 8192 < 25 then
                data.dist = traced.fraction * 8192
                data.i = i + 12
                data.ang = trace_ang
            end
            trace_ang = helpers.normalize_angles(trace_ang + QAngle.new(0, 10, 0))
        end
        if GlobalVars.tickcount % 3 == 0 then
            data.dist = -1
        end
        local check_trace = EngineTrace.TraceRay(lp_body, lp_body + Cheat.AngleToForward(data.ang) * 8192, me, 16395)
        if check_trace.fraction * 8192 >= 25 then
            edge_yaw_on = false
            return
        end
        edge_yaw_on = true
        AntiAim.OverrideYawOffset(data.i + yaw_add)
    end,"edge_yaw" )
end

local desync_on_use = function ()
    local dist = 0
    local hostage_check = function(getplayer)
        local ents = EntityList.GetEntitiesByClassID(97)
        local lp_pos = getplayer:GetRenderOrigin()
        for i = 1, #ents do
            if ents[i] ~= nil then
                local ent = ents[i]
                local origin = ent:GetRenderOrigin()
                local dist = lp_pos:DistTo(origin)
                if dist < 64 then
                    return false
                end
            end

        end
        return true
    end

    local bomb_check = function(me)
        local weap = me:GetActiveWeapon()
        if weap ~= nil then
            if weap:GetClassID() == 34 then
                return false
            else
                return true
            end
        else
            return false
        end
    end

    local defuse_check = function(getplayer)
        local ents = EntityList.GetEntitiesByClassID(129)
        local lp_pos = getplayer:GetRenderOrigin()
        for i = 1, #ents do
            if ents[i] ~= nil then
                local ent = ents[i]
                local origin = ent:GetRenderOrigin()
                local dist = lp_pos:DistTo(origin)
                if dist < 100 then
                    return false
                end
            end

        end
        return true
    end
    
    local tick = GlobalVars.tickcount
    local huy = false

    local cached = false
    local yaw_cache = 0

    local used_once = 0

    handlers:add("pre_prediction" , function(argss)
        if not ui_v.aa.aa_main then
            return
        end
        if ui_v.aa.legit_aa then
            local use = bit.rshift(bit.lshift(argss.buttons, 26), 31)
            local yaw_b =  globals.cur_yaw_base
            local yaw_add = (yaw_b == 0 or yaw_b == 5) and 180 or yaw_b == 2 and -90 or yaw_b == 3 and 90 or 0
            local localplayer = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
            local getplayer = localplayer:GetPlayer()
            local buttonss = argss.buttons
            local view_angles = EngineClient.GetViewAngles()
            
            
            if use ~= 0  then
                if  hostage_check(getplayer) and bomb_check(getplayer) and defuse_check(getplayer) then
                    tick = not huy and GlobalVars.tickcount or tick
                    huy = true
                    globals.legit_aa_on = true
                    used_once = 1
                    if not cached then 
                        yaw_cache = yaw_b
                        cached = true
                    end
                    AntiAim.OverridePitch(view_angles.pitch)
                        
                    if not ui_v.aa.type then
                        AntiAim.OverrideYawOffset(180 + yaw_add)
                    end
                end
            else
                huy = false
                cached = false
                if used_once~=0 then
                  --  refs.yaw_b:Set(yaw_cache)
                    used_once = 0
                end
                globals.legit_aa_on = false
            end
            if tick + 4 <= GlobalVars.tickcount and hostage_check(getplayer) and bomb_check(getplayer) and
                defuse_check(getplayer) then
                argss.buttons = bit.band(argss.buttons, bit.bnot(32))
            end
        end
    end,"desync_on_use")


end

local secret = function()
    local ticks = {17,9}
    local last_tick = 2
    handlers:add("prediction", function ()
        if GlobalVars.tickcount % 39 ~= ticks[last_tick]  or not ui_v.aa.fake_flick or not refs.dt:Get()  or not ui_v.aa.aa_main then 
            globals.flick = false
            return 
        end
        last_tick = last_tick == 1 and 2 or 1
        globals.flick = true
        AntiAim.OverrideYawOffset(AntiAim.GetInverterState() and -90 or 90)        
    end,"flick" )


end
local anti_backstab = function()
    local get_closest_enemy = function()
        local p = nil
        local all_players = EntityList.GetPlayers()
        local lp_origin = EntityList.GetLocalPlayer():GetHitboxCenter(0)
        local dist = math.huge
        for _,player in pairs(all_players) do
            if not player or player:IsDormant() or player:IsTeamMate() or not player:IsAlive() or player:GetHitboxCenter(0):DistTo(lp_origin)>160 or not player:GetActiveWeapon() or not player:GetActiveWeapon():IsKnife() then goto c end

            local traced = EngineTrace.TraceRay(lp_origin ,player:GetHitboxCenter(0) , EntityList.GetLocalPlayer() ,  16395)
         

            if player:GetHitboxCenter(0):DistTo(lp_origin) < dist and traced.fraction > 0.9 then 
                dist = player:GetHitboxCenter(0):DistTo(lp_origin)
                p = player
            end
            ::c::
        end


        return p
    end
    local have_reset = true
    local have_cached = false
    local cache = {yaw_b =  ui_v.aa.type and ui_v.aa.manual-1 or refs_v.yaw_b}
    local cache_stuff = function()
        if not have_reset then
            cache.yaw_b =  ui_v.aa.type and ui_v.aa.manual-1 or refs_v.yaw_b
            have_reset = true
            have_cached = false
        end
    end
    local reset_stuff = function()
        if not have_reset then
            refs.yaw_b:Set(cache.yaw_b)
            have_reset = true
            have_cached = false
        end
    end
    
    handlers:add("prediction" , function(args)
        if not ui_v.aa.aa_main or not ui_v.aa.abstab then 
            reset_stuff()
            return end
        if not get_closest_enemy() then 
            reset_stuff()
            return end
        if not have_cached then
            cache_stuff()
            have_cached = true
        end
        local lp_origin = EntityList.GetLocalPlayer():GetProp("m_vecOrigin")
        local e_origin = get_closest_enemy():GetProp("m_vecOrigin")
        local angle = helpers.normalize_angle(helpers.calc_angle(lp_origin, e_origin).yaw) - args.viewangles.yaw
        AntiAim.OverrideYawOffset(angle - 180)
        refs.yaw_b:Set(1)
        have_reset = false
    end,"abstab")

end



local anti_brute = function ()


    local last_switch_tick = 0

    local check_disablers = function()
        local lp = EntityList.GetLocalPlayer()
        local disablers = ui.aa.abrute_disables
        if disablers:GetBool(2) and refs.sw:Get() then return false end
        if disablers:GetBool(3) and lp:GetProp("m_flDuckAmount")>0.78 and bit.band(lp:GetProp("m_fFlags"), 1) ~= 0 then return false end
        if disablers:GetBool(1) and bit.band(lp:GetProp("m_fFlags"), 1) == 0 then return false end

        return true 

    end

    handlers:add("events", function (event)
        if not ui_v.aa.aa_main then return end

        if event:GetName() == "bullet_impact" then
            if not ui_v.aa.aa_main or ui_v.aa.fake_flick then
                return
            end

    
            local lp = EntityList.GetLocalPlayer()
            if not lp or not lp:IsAlive() then
                return
            end
            if not event:GetInt("userid") then
                return
            end
            local entity = EntityList.GetPlayerForUserID(event:GetInt("userid"))
            if not entity then
                return
            end
    
            if entity == lp then
                return
            end
            local player = entity
            if not player then
                return
            end
            if player:IsTeamMate() then
                return
            end
    
            local bullet_impact = Vector.new(event:GetFloat("x"), event:GetFloat("y"), event:GetFloat("z"))
            local eye_pos = player:GetEyePosition()
            if not eye_pos then
                return
            end
            local local_player = lp
            if not local_player then
                return
            end
            local local_eye_pos = local_player:GetEyePosition()
            if not local_eye_pos then
                return
            end
    
            local distance_between = helpers.closest_point_on_ray(eye_pos, bullet_impact, local_eye_pos):DistTo(local_eye_pos)
            if distance_between < 60 and GlobalVars.tickcount ~= last_switch_tick and check_disablers() then
                globals.in_antibrute2 = true
                globals.abrute_timer = 3
                if not ui_v.aa.abrute then
                    return
                end
                globals.in_antibrute = true
                globals.abrute_phase = globals.abrute_phase > globals.abrute_phases-1 and 0 or globals.abrute_phase + 1 
                last_switch_tick = GlobalVars.tickcount
            end
        end

    end,"abrute_events" )




    handlers:add("prediction" , function ()
        if not globals.in_antibrute2 then return end


        if (not globals.in_antibrute and not  globals.in_antibrute2) or #ui.aa.phases==0 or ui_v.aa.fake_flick then return end
        if not ui_v.aa.aa_main then return end
        
        globals.abrute_timer = globals.abrute_timer - GlobalVars.interval_per_tick

        if globals.abrute_timer < 0 then globals.abrute_timer = 0 end
        if not helpers.cm_check() then globals.in_antibrute = false globals.in_antibrute2 = false globals.abrute_timer = 0  end

       

        if globals.abrute_timer == 0 and (globals.in_antibrute or globals.in_antibrute2)  then globals.in_antibrute = false  globals.in_antibrute2 = false end



        local phases = {}    
        for i = 1 , globals.abrute_phases do
            phases[#phases+1] = ui_v.aa.phases[i]
        end

        --print(globals.abrute_phases , globals.abrute_phase , #ui.aa.phases)
        if phases[globals.abrute_phase +1] and globals.in_antibrute then
            AntiAim.OverrideInverter(phases[globals.abrute_phase +1] < 0)
            AntiAim.OverrideLimit(math.abs(phases[globals.abrute_phase+1]))
        end
    end,"abrute_timer and aa")

    handlers:add("events" , function(e)
    
        if e:GetName()=="round_start" then globals.abrute_timer = 0 globals.in_antibrute = false globals.in_antibrute2 = false end
        
    end,"huy")

end


local function adjust_fl()
    local cache = refs_v.fl_limit

    if refs_v.hs==true then
        cache = refs_v.fl_limit 
        refs.fl_limit:Set(1)
    else
        refs.fl_limit:Set(cache)
    end

    ui.aa.dfl:RegisterCallback(function(val)
        
        if val==true and refs_v.hs and not refs_v.dt then
            cache = refs_v.fl_limit 
            refs.fl_limit:Set(1)
        else
            refs.fl_limit:Set(cache)
        end
    end)

    handlers:add("destroy" , function()

            refs.fl_limit:Set(cache)
    end , "sdfsdf")

    refs.hs:RegisterCallback(function(val)
        if not ui_v.aa.dfl then return end
        if val==true then
            cache = refs_v.fl_limit 
            refs.fl_limit:Set(1)
        else
            refs.fl_limit:Set(cache)
        end
    
    end)

end



local function aa_system()


    local last_cond = 0
    local get_condition = function ()
        local lp = EntityList.GetLocalPlayer()
        if globals.legit_aa_on then return 6 
        elseif lp:GetProp("m_flDuckAmount") > 0.89 and not refs.fd:Get() and  bit.band(lp:GetProp("m_fFlags"), 1) ~= 0 then return 5 
        elseif lp:GetProp("m_vecVelocity"):Length() < 2 then return 1 
        elseif refs.sw:Get() then return 2 
        elseif bit.band(lp:GetProp("m_fFlags"), 1) == 0 then return 4 
        else return 3 end
    end

    local cache = {
        yaw_b = 0,
        yaw_deg = 0,
        yaw_mod = 0,
        yaw_mod_deg = 0,
        fake_opt = 0,
        lby = 0,
        free_dsy = 0,
        l_limit = 0,
        r_limit = 0,
    }

    local cache_aa = {

    }

    local get_cache = function ()
        cache.yaw_mod_deg   =       refs.yaw_mod_deg:Get()
        cache.yaw_mod       =       refs.yaw_mod:Get()
        cache.yaw_b         =       refs.yaw_b:Get()
        cache.yaw_deg       =       refs.yaw_add:Get()
        cache.fake_opt      =       refs.fakeopt:Get()
        cache.lby           =       refs.lbymode:Get()
        cache.free_dsy      =       refs.free_dsy:Get()
        cache.r_limit       =       refs.right_limit:Get()
        cache.l_limit       =       refs.left_limit:Get()
        cache.shot_dsy      =       refs.shot_dsy:Get()
    end
    
    get_cache()

    local reset_stuff = function ()
        refs.yaw_mod:Set(cache.yaw_mod)
        refs.yaw_mod_deg:Set(cache.yaw_mod_deg)
        refs.yaw_b:Set(cache.yaw_b)
        refs.yaw_add:Set(cache.yaw_deg)
        refs.fakeopt:Set(cache.fake_opt)
        refs.lbymode:Set(cache.lby)
        refs.free_dsy:Set(cache.free_dsy)
        refs.right_limit:Set(cache.r_limit)
        refs.left_limit:Set(cache.l_limit)
        refs.shot_dsy:Set(cache.shot_dsy)
    end

    
    local arr = {
        ui.aa.enabled,
        ui.aa.yaw_add,
        ui.aa.yaw_add2, 
        ui.aa.yaw_mod ,
        ui.aa.yaw_mod_deg ,
        ui.aa.onshot ,
        ui.aa.pitch ,
        ui.aa.fake_opt, 
        ui.aa.lby ,
        ui.aa.freestand ,
        ui.aa.r_limit ,
        ui.aa.l_limit ,
        ui.aa.e_fakejit ,
        ui.aa.yaw_base,
    }

  

    handlers:add("destroy" , function ()
        reset_stuff()
    end, "reset_stuff")
    local m = ui_v.aa
    local presets = {
        nil,
        nil,
    }
    local map = {"enabled" , "yaw_add" , "yaw_add2" , "yaw_mod" , "yaw_mod_deg" , "onshot" , "pitch" , "fake_opt" , "lby" , "freestand" , "r_limit" , "l_limit" , "e_fakejit" , "yaw_base"}
    local preset_arr2 = {

    }
    local preset_arr1 = {

    }

    ui.aa.type:RegisterCallback(function ()
        reset_stuff()
        
        if ui_v.aa.aa_type==0 and presets[1] and presets[2] then
            m = ui_v.aa.aa_presets==0 and preset_arr1 or preset_arr2
        else
            m = ui_v.aa
        end
    end)

    ui.aa.aa_type:RegisterCallback(function()
        if ui_v.aa.aa_type==0 and presets[1] and presets[2] then
            m = ui_v.aa.aa_presets==0 and preset_arr1 or preset_arr2
        else
            m = ui_v.aa
        end
    end)
    ui.aa.aa_presets:RegisterCallback(function()
        if ui_v.aa.aa_type==0 and presets[1] and presets[2] then
            m = ui_v.aa.aa_presets==0 and preset_arr1 or preset_arr2
        else
            m = ui_v.aa
        end
    end)

    ui.info.import_cfg:RegisterCallback(function()
        
        refs.yaw_add:Set(0)

        if ui_v.aa.aa_type==0 and presets[1] and presets[2] then
            m = ui_v.aa.aa_presets==0 and preset_arr1 or preset_arr2
        else
            m = ui_v.aa
        end
    end)

    ui.info.def_cfg:RegisterCallback(function()
        
        refs.yaw_add:Set(0)

        if ui_v.aa.aa_type==0 and presets[1] and presets[2] then
            m = ui_v.aa.aa_presets==0 and preset_arr1 or preset_arr2
        else
            m = ui_v.aa
        end
    end)

    local Test = { };
    local got_presets = false
    local got_presets1 = false
    local str1 = "exscord_cSX8jHIW4xafqxkBh1JDgtFDQbhvrnki9S7Nqbhv4xkNqE+Fh1hDgtFD4w3F4SMDgtRn4SdzCGh8h1fBhtqWcxdXh1f+2tdXObPD6Ghvrnki9S7Nqbhv4xkNqE+Fh1MDgtFD4w3F4SMDgtRn4SdzCGhih1fBhtqWcxdXh1f+2tdXOE+Fh1hDgtFDQbhvrnki9S7NqbhvQx+Fh1hDgtFD4w3F4SMDgD+NObPDQnhvrnki9S7NqbhvQx+Fh1TDgtFD4w3F4SMDgD+7QE+Fh1MDgtFD4w3F4SMDgD+nObPD6Dhvrnki9S7NqbhvQt+Fh12DgtFD4w3F4SMDg1azObPDQnhvrnh7h1fBhtqWcxdXh1uPObPDQDhvrnki9S7NqbhvQ/4zCGh8h1fBhtqWcxdXh1uPObPD6Ghvrnki9S7NqbhvQ/qzCGhNh1fBhtqWcxdXh1unObPD6Dhvrnki9S7NqbhvQ/6zCGhUh1fBhtqWcxdXh1uPOE+Fh1TDgtFDQbhvrnki9S7NqbhvQt+Fh1hDgtFD4w3F4SMDg13zCGh8h1fBhtqWcxdXh1unObPD6Ghvrnki9S7NqbhvQE+Fh1MDgtFD4w3F4SMDg13zCGhih1fBhtqWcxdXh1u7ObPD6nhvrnki9S7NqbhvQENzCGhNh1fBh1JDgtFD4w3F4SMDg1dzCGhnh1fBhtqWcxdXh1u8gE+Fh1QDgtFD4w3F4SMDg1dzCGh+h1fBhtqWcxdXh1uNQt+Fh1MDgtFD4w3F4SMDg1JPObPD6Dhvrnki9S7Nqbhv6pazCGhUh1fBhtqWcxdXh1uNOE+Fh19DgtFDQbhvrnki9S7NqbhvQt+Fh1hDgtFD4w3F4SMDg13zCGh8h1fBhtqWcxdXh1u7ObPD6Ghvrnki9S7NqbhvQE+Fh1MDgtFD4w3F4SMDg1kzCGhih1fBhtqWcxdXh1u7ObPD6nhvrnki9S7NqbhvQUNzCGhUh1fBh1JDgtFD4w3F4SMDg13zCGhnh1fBhtqWcxdXh1u7ObPDQnhvrnki9S7NqbhvQE+Fh1TDgtFD4w3F4SMDg13zCGhNh1fBhtqWcxdXh1u7ObPD6Dhvrnki9S7NqbhvQENzCGhLh1fBh1JDgtFD4w3F4SMDg1azCGhnh1fBhtqWcxdXh1unObPDQnhvrnki9S7NqbhvQx+Fh1TDgtFD4w3F4SMDg1kzCGhNh1fBhtqWcxdXh1unObPD6Dhvrnki9S7NqbhvQt+Fh12DgtFD4w3F4SMDg1kzObPDgbhvrnh7h1fBhtqWcxdXh1uPObPDQDhvrnki9S7NqbhvQE+Fh1QDgtFD4w3F4SMDg1azCGh+h1fBhtqWcxdXh1u7ObPD6bhvrnki9S7NqbhvQx+Fh19DgtFD4w3F4SMDg1azCGhUh1fBhtqWcxdXh1uPOE+Fh1JPh1fBh1JDgtFD4w3F4SMDg1azCGhnh1fBhtqWcxdXh1uPObPDQnhvrnki9S7NqbhvQx+Fh1TDgtFD4w3F4SMDg1azCGhNh1fBhtqWcxdXh1uPObPD6Dhvrnki9S7NqbhvQx+Fh12DgtFD4w3F4SMDg1azObPDQ/JDgtFDQbhvrnki9S7Nqbhv61azCGhnh1fBhtqWcxdXh1uiQx+Fh1QDgtFD4w3F4SMDg19PObPD6Ghvrnki9S7Nqbhv61azCGhNh1fBhtqWcxdXh1uPObPD6Dhvrnki9S7Nqbhv61azCGhUh1fBhtqWcxdXh1uiQxNzCGh7QDhvrnh7h1fBhtqWcxdXh1uiQx+Fh1hDgtFD4w3F4SMDg19PObPDQnhvrnki9S7Nqbhv61azCGh+h1fBhtqWcxdXh1uiQx+Fh1MDgtFD4w3F4SMDg1azCGhih1fBhtqWcxdXh1uiQx+Fh12DgtFD4w3F4SMDg19POE+Fh1J8h1fBh1JDgtFD4w3F4SMDgwqWcx6XObPDQDhvrnki9S7Nqbhvqw3F2idzCGh8h1fBhtqWcxdXh1fw9S78qE+Fh1TDgtFD4w3F4SMDgwqWcx6XObPD6bhvrnki9S7Nqbhvqw3F2idzCGhih1fBhtqWcxdXh1fw9S78qE+Fh12DgtFD4w3F4SMDgwqWcx6XOE+Fh1J+h1fBh1JDgtFD4w3F4SMDg1RzCGhnh1fBhtqWcxdXh1u+ObPDQnhvrnki9S7Nqbhv6x+Fh1TDgtFD4w3F4SMDg1RzCGhNh1fBhtqWcxdXh1u+ObPD6Dhvrnki9S7Nqbhv6xNzOT=="

        presets[1] = helpers.json.parse((helpers.data_crypt.base64:decode( str1:gsub("exscord_" , "") ,3)):gsub("mishkatpidr", "") )
            
        for i , j in ipairs(presets[1]) do
            local cnt = 1
            preset_arr1[map[i]] = {}
            for k ,v in pairs(j) do
                
                for p,q in pairs(v) do
                    if not Test[({"Global", "Standing" , "Slow motion" , "Moving" , "Air" , "Crouching" , "Legit AA"})[k]] then
                        Test[({"Global", "Standing" , "Slow motion" , "Moving" , "Air" , "Crouching" , "Legit AA"})[k]] = { };
                    end

                    Test[({"Global", "Standing" , "Slow motion" , "Moving" , "Air" , "Crouching" , "Legit AA"})[k]][map[i]] = q;

                    preset_arr1[map[i]][cnt] = q 
                    cnt = cnt+1

                end
            end
        end
        if ui_v.aa.aa_type==0 and presets[1] and presets[2] then
            m = ui_v.aa.aa_presets==0 and preset_arr1 or preset_arr2
        else
            m = ui_v.aa
        end


        got_presets = true

    

local str2 = "exscord_cSX8jHIW4xafqxkBh1JDgtFDQbhvrnki9S7Nqbhv4xkNqE+Fh1hDgtFD4w3F4SMDgtRn4SdzCGh8h1fBhtqWcxdXh1f+2tdXObPD6Ghvrnki9S7Nqbhv4xkNqE+Fh1MDgtFD4w3F4SMDgtRn4SdzCGhih1fBhtqWcxdXh1fw9S78qENzCGhnh1fBh1JDgtFD4w3F4SMDg1azCGhnh1fBhtqWcxdXh1uI6E+Fh1QDgtFD4w3F4SMDgD+7QE+Fh1TDgtFD4w3F4SMDgD+7QE+Fh1MDgtFD4w3F4SMDgD+nObPD6Dhvrnki9S7NqbhvQt+Fh12DgtFD4w3F4SMDg1azObPDQnhvrnh7h1fBhtqWcxdXh1uPObPDQDhvrnki9S7NqbhvQ/4zCGh8h1fBhtqWcxdXh1u7QE+Fh1TDgtFD4w3F4SMDg1JiObPD6bhvrnki9S7NqbhvQt+Fh19DgtFD4w3F4SMDg1J7ObPD6nhvrnki9S7NqbhvQxNzCGh+h1fBh1JDgtFD4w3F4SMDg13zCGhnh1fBhtqWcxdXh1u7ObPDQnhvrnki9S7NqbhvQE+Fh1TDgtFD4w3F4SMDg13zCGhNh1fBhtqWcxdXh1u7ObPD6Dhvrnki9S7NqbhvQE+Fh12DgtFD4w3F4SMDg1azObPD6bhvrnh7h1fBhtqWcxdXh1uoObPDQDhvrnki9S7Nqbhv6pazCGh8h1fBhtqWcxdXh1uNQx+Fh1TDgtFD4w3F4SMDg1MPObPD6bhvrnki9S7NqbhvQ/azCGhih1fBhtqWcxdXh1uNQx+Fh12DgtFD4w3F4SMDg1azObPD6Dhvrnh7h1fBhtqWcxdXh1uPObPDQDhvrnki9S7NqbhvQE+Fh1QDgtFD4w3F4SMDg13zCGh+h1fBhtqWcxdXh1u7ObPD6bhvrnki9S7NqbhvQt+Fh19DgtFD4w3F4SMDg13zCGhUh1fBhtqWcxdXh1uPOE+Fh12DgtFDQbhvrnki9S7NqbhvQE+Fh1hDgtFD4w3F4SMDg13zCGh8h1fBhtqWcxdXh1u7ObPD6Ghvrnki9S7NqbhvQE+Fh1MDgtFD4w3F4SMDg13zCGhih1fBhtqWcxdXh1u7OE+Fh1YDgtFDQbhvrnki9S7NqbhvQt+Fh1hDgtFD4w3F4SMDg1kzCGh8h1fBhtqWcxdXh1unObPD6Ghvrnki9S7NqbhvQt+Fh1MDgtFD4w3F4SMDg16zCGhih1fBhtqWcxdXh1unObPD6nhvrnki9S7NqbhvQxNzCGhoh1fBh1JDgtFD4w3F4SMDg13zCGhnh1fBhtqWcxdXh1u7ObPDQnhvrnki9S7NqbhvQE+Fh1TDgtFD4w3F4SMDg13zCGhNh1fBhtqWcxdXh1uPObPD6Dhvrnki9S7NqbhvQx+Fh12DgtFD4w3F4SMDg1azObPDQ/ADgtFDQbhvrnki9S7NqbhvQx+Fh1hDgtFD4w3F4SMDg1azCGh8h1fBhtqWcxdXh1uPObPD6Ghvrnki9S7NqbhvQx+Fh1MDgtFD4w3F4SMDg1azCGhih1fBhtqWcxdXh1uPObPD6nhvrnki9S7NqbhvQxNzCGh7Qbhvrnh7h1fBhtqWcxdXh1uiQx+Fh1hDgtFD4w3F4SMDg19PObPDQnhvrnki9S7Nqbhv61azCGh+h1fBhtqWcxdXh1uiQx+Fh1MDgtFD4w3F4SMDg19PObPD6Dhvrnki9S7Nqbhv61azCGhUh1fBhtqWcxdXh1uiQxNzCGh7QDhvrnh7h1fBhtqWcxdXh1uiQx+Fh1hDgtFD4w3F4SMDg19PObPDQnhvrnki9S7Nqbhv61azCGh+h1fBhtqWcxdXh1uiQx+Fh1MDgtFD4w3F4SMDg19PObPD6Dhvrnki9S7Nqbhv61azCGhUh1fBhtqWcxdXh1uiQxNzCGh7Qnhvrnh7h1fBhtqWcxdXh1fw9S78qE+Fh1hDgtFD4w3F4SMDgwqWcx6XObPDQnhvrnki9S7Nqbhvqw3F2idzCGh+h1fBhtqWcxdXh1fw9S78qE+Fh1MDgtFD4w3F4SMDgtRn4SdzCGhih1fBhtqWcxdXh1fw9S78qE+Fh12DgtFD4w3F4SMDgwqWcx6XOE+Fh1J+h1fBh1JDgtFD4w3F4SMDg1RzCGhnh1fBhtqWcxdXh1u+ObPDQnhvrnki9S7Nqbhv6x+Fh1TDgtFD4w3F4SMDg1RzCGhNh1fBhtqWcxdXh1u+ObPD6Dhvrnki9S7Nqbhv6xNzOT=="        
        presets[2] = helpers.json.parse((helpers.data_crypt.base64:decode( str2:gsub("exscord_" , "") ,3)):gsub("mishkatpidr", "") )
        for i , j in ipairs(presets[2]) do
            local cnt = 1
            preset_arr2[map[i]] = {}
            for k ,v in pairs(j) do
                
                for p,q in pairs(v) do 
                    preset_arr2[map[i]][cnt] = q 
                    cnt = cnt+1

                end
            end
        end

        if ui_v.aa.aa_type==0 and presets[1] and presets[2] then
            m = ui_v.aa.aa_presets==0 and preset_arr1 or preset_arr2
        else
            m = ui_v.aa
        end


        got_presets1 = true
    

    local jit =1



    
    local get_fake_angle = function ()
        local real = AntiAim.GetCurrentRealRotation()
        local fake = AntiAim.GetFakeRotation()

        return math.min(math.abs(real - fake), AntiAim.GetMaxDesyncDelta())
    end
    local real = AntiAim.GetCurrentRealRotation()
    local fake = AntiAim.GetFakeRotation()

    handlers:add("pre_prediction" , function()
    
        if FakeLag.SentPackets() ~= 0 then
            jit = jit * -1
        end
        
        real = AntiAim.GetCurrentRealRotation()
        fake = AntiAim.GetFakeRotation()

    end , "update_jit")






    local yaw_b = 0
    local preset_set = ui_v.aa.aa_type == 1
    handlers:add("prediction" , function()
        globals.cur_yaw_base = refs_v.yaw_b
        if ui_v.aa.aa_type==0 and (not got_presets or not got_presets1) then return end
        


        if not ui_v.aa.type or not ui_v.aa.aa_main  or edge_yaw_on then return end
        
        local yaw = 0
        local cond = get_condition()
        local i = m.enabled[cond] and cond+1 or 1

        if not globals.legit_aa_on then 
            refs.yaw_b:Set(ui_v.aa.manual ==0 and m.yaw_base[i] or ui_v.aa.manual-1) 
            yaw_b = ui_v.aa.manual ==0 and m.yaw_base[i] or ui_v.aa.manual-1
            globals.cur_yaw_base = yaw_b
        else
            refs.yaw_b:Set(1)
            yaw  = yaw + 180
        end
        

        if not globals.legit_aa_on then
            Menu.FindVar("Aimbot", "Anti Aim", "Main", "Pitch"):SetInt(m.pitch[i])
        end
        local jit_type = m.yaw_mod[i]
        refs.lbymode:SetInt(m.lby[i])
        refs.free_dsy:SetInt(m.freestand[i])
        refs.shot_dsy:SetInt(m.onshot[i])
        refs.fakeopt:Set(0)
        if not globals.in_antibrute then
            if m.e_fakejit[i] then
                AntiAim.OverrideLimit(jit==1 and 20  or AntiAim.GetInverterState() and m.l_limit[i] or m.r_limit[i])
            else
                AntiAim.OverrideLimit( AntiAim.GetInverterState() and m.l_limit[i] or m.r_limit[i])
            end
        end
    
        local ya = AntiAim.GetInverterState() and m.yaw_add[i] or m.yaw_add2[i]
        yaw = yaw + ya
        if get_value(m.fake_opt[i] , 2) then 
            if get_value(m.fake_opt[i] , 3) then
                AntiAim.OverrideInverter(math.random(0,1)==0)
            else
                AntiAim.OverrideInverter(jit==-1)
            end
        end
        if get_value(m.fake_opt[i] , 1) then
            if get_fake_angle() < 20 and (m.yaw_mod_deg[i] > 20 or m.e_fakejit[i]) then
                AntiAim.OverrideInverter(not AntiAim.GetInverterState())
            end
        end
        if jit_type==1 then --center
            local mul = AntiAim.GetInverterState() and 1 or -1
            yaw  = yaw + (m.yaw_mod_deg[i]/2) * jit   --center
        elseif jit_type == 2 then
            yaw  = yaw + m.yaw_mod_deg[i] * ((jit+1)/2)  --ofset
        elseif jit_type == 3 then
            yaw  = yaw + Utils.RandomInt(-m.yaw_mod_deg[i]  , m.yaw_mod_deg[i]  )
        elseif jit_type == 4 and m.yaw_mod_deg[i]~=0 then
            yaw  = yaw -  (GlobalVars.tickcount*3) % m.yaw_mod_deg[i]
        else
            --
        end
        AntiAim.OverrideYawOffset(yaw)

    
    end , "custom_aa")

--[[
     Menu.Button("Anti-Aim" , "aa exporter" , "Export" , ""):RegisterCallback(function()

         configs.export(arr , {} , nil)
    
     end)
     ]]
end





local hook = {hooks = {}}

handlers:add("events" , function(event)  if event:GetName() == "player_connect_full" or event:GetName() == "cs_game_disconnected" then logs.data = {} logs_data.data = {} end    end, "destroy_avatars")

local ffi_helpers = {
    get_entity_address = function(entity_index)
        local addr = GET_CLIENT_ENTITY_FN(ENTITY_LIST_POINTER, entity_index)
        return addr
    end
}

function hook.new(cast, callback, hook_addr, size, trampoline, org_bytes_tramp)
    local size = size or 5
    local trampoline = trampoline or false
    local new_hook, mt = {}, {}
    local detour_addr = tonumber(ffi.cast('intptr_t', ffi.cast('void*', ffi.cast(cast, callback))))
    local void_addr = ffi.cast('void*', hook_addr)
    local old_prot = ffi.new('unsigned long[1]')
    local org_bytes = ffi.new('uint8_t[?]', size)
    ffi.copy(org_bytes, void_addr, size)
    if trampoline then
        local alloc_addr = ffi.gc(ffi.C.VirtualAlloc(nil, size + 5, 0x1000, 0x40), function(addr) ffi.C.VirtualFree(addr, 0, 0x8000) end)
        local trampoline_bytes = ffi.new('uint8_t[?]', size + 5, 0x90)
        if org_bytes_tramp then
            local bytes = {}
            for byte in org_bytes_tramp:gmatch('(%x%x)') do
                table.insert(bytes, tonumber(byte, 16))
            end
            trampoline_bytes = ffi.new('uint8_t[?]', size + 5, bytes)
        else
            ffi.copy(trampoline_bytes, org_bytes, size)
        end
        trampoline_bytes[size] = 0xE9
        ffi.cast('uint32_t*', trampoline_bytes + size + 1)[0] = hook_addr - tonumber(ffi.cast('intptr_t', ffi.cast('void*', ffi.cast(cast, alloc_addr)))) - size
        ffi.copy(alloc_addr, trampoline_bytes, size + 5)
        new_hook.call = ffi.cast(cast, alloc_addr)
        mt = {__call = function(self, ...)
            return self.call(...)
        end}
    else
        new_hook.call = ffi.cast(cast, hook_addr)
        mt = {__call = function(self, ...)
            self.stop()
            local res = self.call(...)
            self.start()
            return res
        end}
    end
    local hook_bytes = ffi.new('uint8_t[?]', size, 0x90)
    hook_bytes[0] = 0xE9
    ffi.cast('uint32_t*', hook_bytes + 1)[0] = detour_addr - hook_addr - 5
    new_hook.status = false
    local function set_status(bool)
        new_hook.status = bool
        ffi.C.VirtualProtect(void_addr, size, 0x40, old_prot)
        ffi.copy(void_addr, bool and hook_bytes or org_bytes, size)
        ffi.C.VirtualProtect(void_addr, size, old_prot[0], old_prot)
    end
    new_hook.stop = function() set_status(false) end
    new_hook.start = function() set_status(true) end
    new_hook.start()

    table.insert(hook.hooks, new_hook)
    return setmetatable(new_hook, mt)
end
--HOOKS
local updatecsa_address = Utils.PatternScan("client.dll", "8B F1 80 BE ? ? ? ? ? 74 36", -5)
function starthooks()
    updateCSA_fn = hook.new('void(__fastcall*)(void*, void*)', updateCSA_hk, ffi.cast("uintptr_t", updatecsa_address))
end 
--FUNNY 113 42 262!!! 223 192 15 7  10 11

function updateCSA_hk(thisptr, edx)
    local localplayer = EntityList.GetClientEntity(EngineClient.GetLocalPlayer())
    if not localplayer then return updateCSA_fn(thisptr, edx) end
    local lp_ptr = ffi_helpers.get_entity_address(EngineClient.GetLocalPlayer())  
    local ref_slide = Menu.FindVar("Aimbot", "Anti Aim", "Misc", "Leg Movement")


    if not ui_v.aa.aa_main or not ui_v.aa.animfuck  then    updateCSA_fn(thisptr, edx) return end

    if ui.aa.legfuc:GetBool(1) then
        ffi.cast("float*" , lp_ptr+10104)[6] = 1
    end
    if ui.aa.legfuc:GetBool(2) then
        ref_slide:SetInt(1)
        ffi.cast("float*" , lp_ptr+10104)[0] = 0
    end
    updateCSA_fn(thisptr, edx)
    if ui.aa.legfuc:GetBool(1) then
        ffi.cast("float*" , lp_ptr+10104)[6] = 1
    end
end

-- handlers:subscribe("draw" , function()
--     if Cheat.IsMenuVisible() then
--         for i, hook in ipairs(hook.hooks) do
--             if hook.status then
--                 hook.stop()
--             end
--         end
--     end
-- end)

handlers:add("destroy" , function ()
    for i, hook in ipairs(hook.hooks) do
        if hook.status then
            hook.stop()
        end
    end
end,"hks")



--#endregion


--#region configs and other misc stuff

local def_cfg_text = ""

local def_cfg_text_req = Http.GetAsync("https://exscord.xyz/neverlose/cfg.txt" , function(res)
    def_cfg_text = res
end)

ui.info.def_cfg:RegisterCallback(function ()
    if def_cfg_text== "" then
        Cheat.AddNotify(script_name, "An error occured in cloud config!")
        return end 
    
     
    configs.import({vis = ui.vis , rage = ui.rage , aa = ui.aa } , {["palette"] = 1 , ["arrows_main"]=1 , ["cross_main"]=1 ,["custom_scope"]=1 , ["blur_bg"] = 1 }, def_cfg_text)
    draggables:adjust_pos()
end)

ui.info.export_cfg:RegisterCallback(function ()
    configs.export({vis = ui.vis , rage = ui.rage , aa = ui.aa } , {["palette"] = 1 , ["arrows_main"]=1 , ["cross_main"]=1 ,["custom_scope"]=1 , ["blur_bg"] = 1})
    Cheat.AddNotify(script_name, "Config was succesfully exported!")
end)

ui.info.import_cfg:RegisterCallback(function ()
   
    configs.import({vis = ui.vis , rage = ui.rage , aa = ui.aa } , {["palette"] = 1 , ["arrows_main"]=1 , ["cross_main"]=1 ,["custom_scope"]=1, ["blur_bg"] = 1 },  nil)
    draggables:adjust_pos()
end)




ui.info.discord:RegisterCallback(function()
    
end)



--#endregion

refs.yaw_add:Set(0)

--#region calls

extended_desync()
init()
aa_system()
adjust_fl()
anti_brute()
auto_teleport()
secret()
anti_backstab()
edgeyaw()
desync_on_use()
custom_hc()
anti_exploit()
dormant_aimbot()
WATAFAK()
fakelc_indic()
hitsound()
spectators()
keybinds_fn()
vbiv_fn()
watermark()
arrows()
scope_lines()
indicators()

--#endregion


handlers:add("destroy", function()handlers:log() end , "log")
handlers:update()
starthooks()
Cheat.AddNotify(script_name, "Welcome to exscord source for neverlose.cc axaxaxaxax PWND!")
