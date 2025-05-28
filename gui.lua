-- Twój własny key system GUI

local LocalPlayer = game.Players.LocalPlayer

-- PODMIEN TUTAJ LINK DO SWOJEGO PLIKU Z KLUCZEM (key.txt) NA GITHUBIE:
local keyUrl = "https://raw.githubusercontent.com/GuyformscriptROBLOX/abced/refs/heads/main/key.txt" -- <-- TUTAJ WKLEJ SWÓJ LINK DO KEY

-- Ukryte dekodowanie klucza
local _a = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local _b = "abcdefghijklmnopqrstuvwxyz"
local _c = "0123456789+/"
local _abc = _a.._b.._c

local function _d(d)
    d = string.gsub(d, '[^'.._abc..'=]', '')
    return (d:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(_abc:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

-- Pobierz i zdekoduj klucz
local encodedKey = game:HttpGet(keyUrl)
local keyRequired = _d(encodedKey):gsub("%s+", "") -- usuwa białe znaki


local unlockGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
unlockGui.Name = "UnlockGui"

local frame = Instance.new("Frame", unlockGui)
frame.Size = UDim2.new(0, 300, 0, 150)
frame.Position = UDim2.new(0.5, -150, 0.5, -75)
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)

local label = Instance.new("TextLabel", frame)
label.Size = UDim2.new(1, 0, 0, 40)
label.Position = UDim2.new(0, 0, 0, 10)
label.BackgroundTransparency = 1
label.TextColor3 = Color3.new(1,1,1)
label.Text = "Podaj klucz, aby odblokować skrypt:"

local textbox = Instance.new("TextBox", frame)
textbox.Size = UDim2.new(0.8, 0, 0, 30)
textbox.Position = UDim2.new(0.1, 0, 0, 60)
textbox.PlaceholderText = "Wpisz klucz..."
textbox.Text = ""
textbox.TextColor3 = Color3.new(1,1,1)
textbox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

local button = Instance.new("TextButton", frame)
button.Size = UDim2.new(0.8, 0, 0, 30)
button.Position = UDim2.new(0.1, 0, 0, 100)
button.Text = "Odblokuj"
button.TextColor3 = Color3.new(1,1,1)
button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)

local wrongLabel = Instance.new("TextLabel", frame)
wrongLabel.Size = UDim2.new(1, 0, 0, 20)
wrongLabel.Position = UDim2.new(0, 0, 1, -20)
wrongLabel.BackgroundTransparency = 1
wrongLabel.TextColor3 = Color3.new(1,0,0)
wrongLabel.Text = ""
wrongLabel.TextScaled = true

button.MouseButton1Click:Connect(function()
    if textbox.Text == keyRequired then
        unlockGui:Destroy()
        print("Klucz poprawny!")

        -- Ukryte dekodowanie skryptu
        local _a = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        local _b = "abcdefghijklmnopqrstuvwxyz"
        local _c = "0123456789+/"
        local _abc = _a.._b.._c
        local function _d(d)
            d = string.gsub(d, '[^'.._abc..'=]', '')
            return (d:gsub('.', function(x)
                if (x == '=') then return '' end
                local r,f='',(_abc:find(x)-1)
                for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
                return r;
            end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
                if (#x ~= 8) then return '' end
                local c=0
                for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
                return string.char(c)
            end))
        end

        local encoded = game:HttpGet("https://raw.githubusercontent.com/GuyformscriptROBLOX/abced/refs/heads/main/script")
        local decoded = _d(encoded)
        loadstring(decoded)()
    else
        wrongLabel.Text = "Zły klucz!"
        wait(1)
        wrongLabel.Text = ""
    end
end)
