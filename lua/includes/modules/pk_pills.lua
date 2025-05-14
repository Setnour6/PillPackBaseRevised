AddCSLuaFile()
-- Module starts here...
module("pk_pills", package.seeall)
-- Load files
file.CreateDir("pill_config")
local locked_perma = {}
local locked_game = {}

for k, v in pairs(util.KeyValuesToTable(file.Read("pill_config/permalocked.txt") or "")) do
    locked_perma[string.upper(k)] = v
end

-- Pack Registration
local packString = ""
local packs = {}
local currentPack

function packStart(name, id, icon)
    currentPack = {}
    currentPack.name = name
    currentPack.icon = icon or "icon16/pill.png"
    currentPack.headers = {}
    currentPack.items = {}
    table.insert(packs, currentPack)
    id = id:gsub("%W", "-"):lower()
    packString = packString .. id .. " "
end

function packRequireGame(name, id)
    --Assume server owners are not stupid.
    if CLIENT then
        if (id == -1) then
            table.insert(currentPack.headers, {
                type = "pill-info",
                heading = "Hello, World!",
                color = "#FF88FF",
                text = [[
				This pack requires content from the game ]] .. name .. [[, which does not appear to exist.
				You can try pretending that the game exists to fix this issue.
			]]
            })

            return
        end

        for _, v in pairs(engine.GetGames()) do
            if (v.depot == id) then
                if not v.mounted then
                    if v.installed then
                        table.insert(currentPack.headers, {
                            type = "pill-info",
                            heading = "Warning!",
                            color = "#C9B995",
                            text = [[
							This pack requires content from the game ]] .. name .. [[, which appears to be installed but not mounted.
							You can mount the game using the gamepad icon in the bottom right corner of the main menu.
							You may need to restart the map or rejoin the server for this to work.
						]]
                        })
                    elseif v.owned then
                        table.insert(currentPack.headers, {
                            type = "pill-info",
                            heading = "Warning!",
                            color = "#C9B395",
                            text = [[
							This pack requires content from the game ]] .. name .. [[, which you appear to own but is not installed.
							If you have issues with missing models or textures, install the game through Steam, then mount it through Gmod's main menu.
						]]
                        })
                    else
                        table.insert(currentPack.headers, {
                            type = "pill-info",
                            heading = "Warning!",
                            color = "#C99595",
                            text = [[
							This pack requires content from the game ]] .. name .. [[, which you do not appear to own.
							You can buy it on Steam. If you <i>obtained</i> the content through other means, you can close this message.
						]]
                        })
                    end
                end
            end
        end
    end
end

function hasPack(name)
    return table.HasValue(string.Explode(" ", packString), name)
end

function getPacks()
    return packString
end

-- Pill Registration
local forms = {}

function register(name, t)
    t.name = name

    if t.printName then
        table.insert(currentPack.items, {
            type = "pill",
            name = name,
            printName = t.printName
        })
    end

    if (t.sounds) then
        for _, s in pairs(t.sounds) do
            if (isstring(s)) then
                util.PrecacheSound(s)
            elseif (istable(s)) then
                for k, s2 in pairs(s) do
                    if s2 == false then
                        s[k] = nil
                    else
                        util.PrecacheSound(s2)
                    end
                end
            end
        end
    end

    forms[name] = t
end

local function fixParent(name)
    local t = forms[name]
     if t.parent == name then
        print("Tried to self-inherit '" .. name .. "' pill! Please verify the parent value in this pill.")
        return
    end
    local t_parent = forms[t.parent]

    if t_parent and t_parent.parent then
        fixParent(t.parent)
    end

    t_parent = forms[t.parent]

    if t_parent then
        t_parent = table.Copy(t_parent)
        forms[name] = table.Merge(t_parent, t)
        t.parent = nil
    else
        print("Tried to inherit pill from non-existant '" .. t.parent .. "'. Make sure you register the parent first.")
    end
end

function getPillTable(typ)
    return forms[typ]
end

function getFormCount()
    return table.Count(forms)
end

function getRandomForm()
    local v, k = table.Random(forms)

    return k
end

hook.Add("Initialize", "pk_pill_finalize", function()
    for n, t in pairs(forms) do
        if t.parent then
            fixParent(n)
        end
    end
end)

-- Player to Pill Entity Mapping
function mapEnt(ply, ent)
    ply.pk_pill_ent = ent
end

function unmapEnt(ply, ent)
    if ply.pk_pill_ent == ent then
        ply.pk_pill_ent = nil
    elseif IsValid(ply.pk_pill_ent) then
        return ply.pk_pill_ent.formTable.type
    end
end

function getMappedEnt(ply)
    return ply.pk_pill_ent
end

--[[Darkrp shit

	local function init_darkrp()
		if !DarkRP.createJob then error("No DarkRP job creation function!") end
		local TEAM_PILL = DarkRP.createJob("Pill Merchant", {
			color = Color(80, 40, 120, 255),
			model = "models/player/soldier_stripped.mdl",
			description = "This guy sells pills.",
			weapons = {},
			command = "pillmerchant",
			max = 2,
			salary = GAMEMODE.Config.normalsalary,
			admin = 0,
			vote = false
		})

		for name,tbl in pairs(forms) do
			if !tbl.printName or darkrp_costs[name]==-1 then continue end

			local mdl=tbl.model
			if !mdl then
				local opts = tbl.options&&tbl.options()
				if opts then
					mdl=opts[1].model
				end
			end
			if !mdl then mdl = "models/props_junk/watermelon01.mdl" end

			DarkRP.createEntity(tbl.printName.." Pill", {
				ent = "pill_worldent",
				model = mdl,
				price = darkrp_costs[name] or 1000,
				max = 10,
				cmd = "buypill_"..name,
				pill = name,
				allowed = {TEAM_PILL}
			})
		end
	end

	if SERVER then
		hook.Add("Initialize","pk_pill_init_darkrp",function()
			if DarkRP then
				if !file.Exists("pill_config/darkrp_costs.txt","DATA") then
					darkrp_costs={}
					for n,t in pairs(forms) do
						if t.userSpawn or !t.printName then continue end
						darkrp_costs[n]=t.default_rp_cost||-1
					end
					file.Write("pill_config/darkrp_costs.txt",util.TableToKeyValues(darkrp_costs))
				else
					local readfile = file.Read("pill_config/darkrp_costs.txt")
					if readfile=="DISABLE" then return end

					darkrp_costs = util.KeyValuesToTable(file.Read("pill_config/darkrp_costs.txt"))
				end

				init_darkrp(darkrp_costs)
			end
		end)
	else
		net.Receive("pk_pill_init_darkrp", function( len, pl )
			darkrp_costs = net.ReadTable()
			init_darkrp(darkrp_costs)
		end)
	end
]]
-- Concommands, Convars, etc.
if SERVER then
    concommand.Add("pk_pill_apply", function(ply, cmd, args, str)
        apply(ply, args[1], "user", tonumber(args[2]))
    end)

    concommand.Add("pk_pill_restore", function(ply, cmd, args, str)
        restore(ply)
    end)

    concommand.Add("pk_pill_restore_force", function(ply, cmd, args, str)
        if not ply:IsAdmin() then return end
        restore(ply, true)
    end)

    concommand.Add("pk_pill_spawnent", function(ply, cmd, args, str)
        if not ply:IsAdmin() then return end
        local tr = ply:GetEyeTrace()
        local e = ents.Create("pill_worldent")
        e:SetPos(tr.HitPos + tr.HitNormal * 5)
        e:SetPillForm(args[1])
        e:Spawn()
    end)

    concommand.Add("pk_pill_morphgun_select", function(ply, cmd, args, str)
        if not ply:IsAdmin() then return end
        local pill = args[1]
        local wep = ply:GetWeapon("pill_wep_morphgun")

        if not IsValid(wep) then
            wep = ply:Give("pill_wep_morphgun")
        end

        if not IsValid(wep) then return end
        ply:SelectWeapon("pill_wep_morphgun")
        wep:SetForm(pill)
    end)
end

-- Spawnmenu
if CLIENT then
    local icon_restricted = Material("icon16/lock.png")

    spawnmenu.AddContentType("pill", function(container, obj)
        if (not obj.name) then return end
        if (not obj.printName) then return end
        local icon = vgui.Create("ContentIcon", container)
        icon:SetContentType("pill")
        icon:SetName(obj.printName)
        icon:SetMaterial("pills/" .. obj.name .. ".png")

        icon.DoClick = function()
            RunConsoleCommand("pk_pill_apply", obj.name)
            surface.PlaySound("ui/buttonclickrelease.wav")
        end

        icon.OpenMenu = function(icon)
            local menu = DermaMenu()
            local formTable = getPillTable(obj.name)

            menu:AddOption("Copy Type to Clipboard", function()
                SetClipboardText(obj.name)
            end):SetImage("icon16/page_copy.png")

            if (formTable.options) then
                menu:AddOption("Use with Skin...", function()
                    local pickerWindow = vgui.Create("DFrame")
                    pickerWindow:SetSize(606, 400)
                    pickerWindow:Center()
                    pickerWindow:SetTitle("Pill Skin Picker")
                    pickerWindow:SetVisible(true)
                    pickerWindow:SetDraggable(true)
                    pickerWindow:ShowCloseButton(true)
                    pickerWindow:MakePopup()
                    local picker = vgui.Create("DPanelSelect", pickerWindow)
                    picker:SetPos(0, 24)
                    picker:SetSize(606, 376)

                    for n, opt in pairs(formTable.options()) do
                        local mdl = opt.icon or opt.model or formTable.model
                        local skin = opt.skin or formTable.skin or 0
                        local icon = vgui.Create("SpawnIcon")
                        icon:SetModel(mdl, skin)
                        icon:SetSize(64, 64)
                        icon:SetTooltip(mdl)

                        function icon:OnMousePressed(code)
                            if code == MOUSE_LEFT then
                                RunConsoleCommand("pk_pill_apply", obj.name, n)
                                pickerWindow:Close()
                            end
                        end

                        picker:AddPanel(icon)
                    end
                end):SetImage("icon16/palette.png")
            end

            if LocalPlayer():IsAdmin() then
                menu:AddSpacer()

                if not formTable.userSpawn then
                    menu:AddOption("Spawn to World", function()
                        RunConsoleCommand("pk_pill_spawnent", obj.name)
                    end):SetImage("icon16/pill_go.png")

                    menu:AddOption("Use with Morphgun", function()
                        RunConsoleCommand("pk_pill_morphgun_select", obj.name)
                    end):SetImage("icon16/lightning_go.png")
                end

                if LocalPlayer():IsSuperAdmin() then
                    if pk_pills._restricted[obj.name] then
                        menu:AddOption("Remove Restriction", function()
                            RunConsoleCommand("pk_pill_restrict", obj.name, "off")
                        end):SetImage("icon16/lock_delete.png")
                    else
                        menu:AddOption("Restrict to Admins", function()
                            RunConsoleCommand("pk_pill_restrict", obj.name, "on")
                        end):SetImage("icon16/lock_add.png")
                    end
                end
            end

            menu:Open()
        end

        icon.PaintOver = function(self, w, h)
            if pk_pills._restricted[obj.name] then
                surface.SetMaterial(icon_restricted)
                surface.DrawTexturedRect(self.Border + 8, self.Border + 8, 16, 16)
            end
        end

        if (IsValid(container)) then
            container:Add(icon)
        end

        return icon
    end)

    spawnmenu.AddContentType("pill-info", function(container, obj)
        if (not obj.text) then return end
        local html = vgui.Create("DHTML", container)
        html:SetSize(256, 256)
        html:SetAllowLua(true)
        html:SetHTML("<style>body {background-color: " .. (obj.color or "gray") .. "; font-family: ariel; border: 6px double black; margin: 0; padding: 6px;} b {font-size: 20px; margin: 0;}</style><b>" .. (obj.heading or "") .. "</b> " .. obj.text .. "<hr><button onclick=\"console.log('RUNLUA:SELF:Remove()')\">Close</button>")

        if (IsValid(container)) then
            container:Add(html)
        end

        return html
    end)

    spawnmenu.AddCreationTab("Pills", function()
        local ctrl = vgui.Create("SpawnmenuContentPanel")
        local searchContainer = vgui.Create("DPanel", ctrl)
        searchContainer:Dock(TOP)
        searchContainer:SetTall(23)
        searchContainer:DockMargin(0, 0, 0, 0)
        searchContainer:SetPaintBackground(false)
        searchContainer.Think = function(self)
            self:SetWide(ctrl.ContentNavBar:GetWide())
        end

        local searchEntryContainer = vgui.Create("DPanel", searchContainer)
        searchEntryContainer:Dock(FILL)
        searchEntryContainer:SetPaintBackground(false)

        local searchEntry = vgui.Create("DTextEntry", searchEntryContainer)
        searchEntry:Dock(FILL)
        searchEntry:SetWide(searchEntryContainer:GetWide())
        searchEntry:SetTall(20)
        searchEntry:SetPlaceholderText("Search...")
        searchEntry:SetTooltip("Press Enter to search")
        searchEntry:DockMargin(0, 0, 0, 3)
        searchEntry:SetUpdateOnType(false)

        local oldSwitchPanel = ctrl.SwitchPanel
        local lastRealPanel = nil

        local searchResultsContainer = vgui.Create("ContentContainer", ctrl)
        searchResultsContainer:SetVisible(false)
        searchResultsContainer:SetTriggerSpawnlistChange(false)

        local lastSearchText = nil
        local lastSearchResults = {}
        local searchHeader = nil

        -- local searchHeader = vgui.Create("ContentHeader", searchResultsContainer)
        -- searchHeader:SetText("Press Enter to search")
        -- searchResultsContainer:Add(searchHeader)

        local function SearchForPills(searchText)
            local allPills = {}
            for _, pack in pairs(packs) do
                for _, item in pairs(pack.items) do
                    if item.type == "pill" and string.find(
                        string.lower(item.printName),
                        string.lower(searchText),
                        1,
                        true
                    ) then
                        table.insert(allPills, item)
                    end
                end
            end
            return allPills
        end

        local function UpdateSearchDisplay(searchText, results)
            searchResultsContainer:Clear()
            if IsValid(searchHeader) then
                searchHeader:Remove()
            end

            searchHeader = vgui.Create("ContentHeader", searchResultsContainer)
            searchHeader:DockMargin(0, -4, 0, 0)
            searchHeader:SetTall(0)
            searchResultsContainer:Add(searchHeader)

            if searchText == "" then
                searchHeader:SetText("Press Enter to search")
            else
                searchHeader:SetText(#results .. " Results for \""..searchText.."\"")
                for _, item in SortedPairsByMemberValue(results, "printName") do
                    spawnmenu.CreateContentIcon(item.type, searchResultsContainer, item)
                end
            end

            if not searchResultsContainer:IsVisible() then
                lastRealPanel = ctrl.currentPanel
                oldSwitchPanel(ctrl, searchResultsContainer)
                searchResultsContainer:SetVisible(true)
            end
        end

        local function PerformSearch()
            local searchText = searchEntry:GetText() or ""
            lastSearchText = searchText
            lastSearchResults = SearchForPills(searchText)
            UpdateSearchDisplay(searchText, lastSearchResults)
            searchEntry:RequestFocus()
        end

        searchEntry.OnFocusChanged = function(self, gainedFocus)
            if gainedFocus then
                local currentText = self:GetText() or ""

                if currentText ~= lastSearchText then
                    if currentText == "" then
                        UpdateSearchDisplay("", {})
                    else
                        UpdateSearchDisplay(currentText, {})
                    end
                else
                    if not searchResultsContainer:IsVisible() then
                        lastRealPanel = ctrl.currentPanel
                        oldSwitchPanel(ctrl, searchResultsContainer)
                        searchResultsContainer:SetVisible(true)
                    end
                end
            end
        end

        local searchIcon = vgui.Create("DImageButton", searchEntry)
        searchIcon:Dock(RIGHT)
        searchIcon:SetText("")
        searchIcon:SetImage("icon16/magnifier.png")
        searchIcon:SetSize(16, 16)
        searchIcon:DockMargin(4, 2, 4, 2)
        searchIcon:SetTooltip("Press to search")
        searchIcon.DoClick = PerformSearch

        searchEntryContainer.PerformLayout = function(self, w, h)
            searchEntry:SetWide(w)
        end
        searchEntry.OnEnter = PerformSearch

        function ctrl:SwitchPanel(panel)
            if panel ~= searchResultsContainer then
                lastRealPanel = panel
            end
            oldSwitchPanel(self, panel)
        end

        local function makeHTMLnode(node, url)
            local html

            node.DoPopulate = function(self)
                -- If we've already populated it - forget it.
                if (self.SpawnPanel) then return end
                -- Create the container panel
                self.SpawnPanel = vgui.Create("DHTML", ctrl)
                self.SpawnPanel:SetVisible(false)
                self.SpawnPanel:OpenURL(url)
                self.SpawnPanel:SetAllowLua(true)
            end

            node.DoClick = function(self)
                self:DoPopulate()
                ctrl:SwitchPanel(self.SpawnPanel)
                self.SpawnPanel:Dock(NODOCK)
            end
        end

        local function makeWorkshopNode(node, wsid)
            node.DoClick = function()
                steamworks.ViewFile(tostring(wsid))
            end
        end

        local function makeBrowserNode(node, url)
            node.DoClick = function()
                gui.OpenURL(url)
            end
        end

        local tree = ctrl.ContentNavBar.Tree
        local node_morphs = tree:AddNode("Categories", "icon16/folder.png")
        local node_base = node_morphs:AddNode("Base", "icon16/folder.png")
        local node_installed = node_morphs:AddNode("Installed", "icon16/package.png")
        local node_settings = tree:AddNode("Settings", "icon16/cog.png")

        node_settings.DoPopulate = function(self)
            -- If we've already populated it - forget it.
            if (self.SpawnPanel) then return end
            -- Create the container panel
            self.SpawnPanel = vgui.Create("DPanel", ctrl)
            self.SpawnPanel:SetVisible(false)

            local checkbox_thirdperson = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_thirdperson:SetPos(20, 20)
            checkbox_thirdperson:SetText("Thirdperson")
            checkbox_thirdperson:SetDark(true)
            checkbox_thirdperson:SetConVar("pk_pill_cl_thirdperson")
            checkbox_thirdperson:SizeToContents()

            local checkbox_hidehud = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_hidehud:SetPos(20, 40)
            checkbox_hidehud:SetText("Hide HUD")
            checkbox_hidehud:SetDark(true)
            checkbox_hidehud:SetConVar("pk_pill_cl_hidehud")
            checkbox_hidehud:SizeToContents()

            local button_exit = vgui.Create("DButton", self.SpawnPanel)
            button_exit:SetText("Exit Pill")
            button_exit:SizeToContents()
            button_exit:SetPos(20, 60)

            button_exit.DoClick = function()
                RunConsoleCommand("pk_pill_restore")
            end

            local heading_admin = vgui.Create("DLabel", self.SpawnPanel)
            heading_admin:SetPos(20, 100)
            heading_admin:SetText("Admin Settings")
            heading_admin:SetFont("DermaLarge")
            heading_admin:SetColor(Color(255, 0, 0))
            heading_admin:SizeToContents()

            local function AdminClick(self)
                if not LocalPlayer():IsSuperAdmin() then
                    surface.PlaySound("buttons/button10.wav")

                    return
                end

                self:Toggle()
            end

            local function AdminSetValue(self)
                if not LocalPlayer():IsSuperAdmin() then
                    surface.PlaySound("buttons/button10.wav")

                    return
                end

                self:SetValue()
            end

            local function AdminConVarChanged(self, val)
                if (not self.m_strConVar) then return end
                RunConsoleCommand("pk_pill_admin_set", string.sub(self.m_strConVar, 15), val)
            end

            local checkbox_admin_restrict = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_restrict:SetPos(20, 140)
            checkbox_admin_restrict:SetText("Restrict Pills to Admins")
            checkbox_admin_restrict:SetDark(true)
            checkbox_admin_restrict:SetConVar("pk_pill_admin_restrict")
            checkbox_admin_restrict:SizeToContents()
            checkbox_admin_restrict.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_restrict.Button.DoClick = AdminClick

            local checkbox_admin_anyweapons = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_anyweapons:SetPos(20, 160)
            checkbox_admin_anyweapons:SetText("Allow Use of Any Weapon with Pills")
            checkbox_admin_anyweapons:SetDark(true)
            checkbox_admin_anyweapons:SetConVar("pk_pill_admin_anyweapons")
            checkbox_admin_anyweapons:SizeToContents()
            checkbox_admin_anyweapons.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_anyweapons.Button.DoClick = AdminClick

            local checkbox_admin_allownoclip = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_allownoclip:SetPos(20, 180)
            checkbox_admin_allownoclip:SetText("Allow the noclip button to be used to exit pills")
            checkbox_admin_allownoclip:SetDark(true)
            checkbox_admin_allownoclip:SetConVar("pk_pill_admin_allownoclip")
            checkbox_admin_allownoclip:SizeToContents()
            checkbox_admin_allownoclip.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_allownoclip.Button.DoClick = AdminClick

            local checkbox_admin_delayattack = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_delayattack:SetPos(20, 200)
            checkbox_admin_delayattack:SetText("Disallow attacks on pill entry for some time")
            checkbox_admin_delayattack:SetTooltip("Helps prevent accidentally killing your friends right away")
            checkbox_admin_delayattack:SetDark(true)
            checkbox_admin_delayattack:SetConVar("pk_pill_admin_delayattack")
            checkbox_admin_delayattack:SizeToContents()
            checkbox_admin_delayattack.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_delayattack.Button.DoClick = AdminClick

            local checkbox_admin_drivemoderolljump = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_drivemoderolljump:SetPos(20, 220)
            checkbox_admin_drivemoderolljump:SetText("Allow entity physics object to have a force center jump under the 'roll' drive mode")
            checkbox_admin_drivemoderolljump:SetDark(true)
            checkbox_admin_drivemoderolljump:SetConVar("pk_pill_admin_drivemoderolljump")
            checkbox_admin_drivemoderolljump:SizeToContents()
            checkbox_admin_drivemoderolljump.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_drivemoderolljump.Button.DoClick = AdminClick

            local checkbox_admin_globalspeed = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_globalspeed:SetPos(20, 240)
            checkbox_admin_globalspeed:SetText("Set all pill walk/run speeds to the same value")
            checkbox_admin_globalspeed:SetTooltip("Usually takes effect in 6 seconds to compensate for initialization")
            checkbox_admin_globalspeed:SetDark(true)
            checkbox_admin_globalspeed:SetConVar("pk_pill_admin_globalspeed")
            checkbox_admin_globalspeed:SizeToContents()
            checkbox_admin_globalspeed.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_globalspeed.Button.DoClick = AdminClick

            local numberwang_admin_globalspeedamount = vgui.Create("DNumberWang", self.SpawnPanel)
            numberwang_admin_globalspeedamount:SetPos(40, 260)
            numberwang_admin_globalspeedamount:SetValue(560)
            numberwang_admin_globalspeedamount:SetTooltip("Amount of walk/run speed for all pills. Usually takes effect in 6 seconds to compensate for initialization")
            numberwang_admin_globalspeedamount:SetMin(1)
            numberwang_admin_globalspeedamount:SetMax(2000)
            numberwang_admin_globalspeedamount:SetConVar("pk_pill_admin_globalspeedamount")
            numberwang_admin_globalspeedamount:SizeToContents()
            numberwang_admin_globalspeedamount:ConVarChanged(AdminConVarChanged)
            numberwang_admin_globalspeedamount.OnValueChanged = AdminSetValue

            local label_admin_globalspeedamount = vgui.Create("DLabel", self.SpawnPanel)
            label_admin_globalspeedamount:SetPos(105, 263)
            label_admin_globalspeedamount:SetText("Amount of walk/run speed for all pills")
            label_admin_globalspeedamount:SetDark(true)
            label_admin_globalspeedamount:SizeToContents()

            local checkbox_admin_globalcrouchwalkspeed = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_globalcrouchwalkspeed:SetPos(20, 280)
            checkbox_admin_globalcrouchwalkspeed:SetText("Set all pill crouch walk speeds to the same value")
            checkbox_admin_globalcrouchwalkspeed:SetDark(true)
            checkbox_admin_globalcrouchwalkspeed:SetConVar("pk_pill_admin_globalcrouchwalkspeed")
            checkbox_admin_globalcrouchwalkspeed:SizeToContents()
            checkbox_admin_globalcrouchwalkspeed.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_globalcrouchwalkspeed.Button.DoClick = AdminClick

            local numberwang_admin_globalcrouchwalkspeedamount = vgui.Create("DNumberWang", self.SpawnPanel)
            numberwang_admin_globalcrouchwalkspeedamount:SetPos(40, 300)
            numberwang_admin_globalcrouchwalkspeedamount:SetValue(560)
            numberwang_admin_globalcrouchwalkspeedamount:SetTooltip("Amount of crouch walk speed for all pills")
            numberwang_admin_globalcrouchwalkspeedamount:SetMin(1)
            numberwang_admin_globalcrouchwalkspeedamount:SetMax(2000)
            numberwang_admin_globalcrouchwalkspeedamount:SetConVar("pk_pill_admin_globalcrouchwalkspeedamount")
            numberwang_admin_globalcrouchwalkspeedamount:SizeToContents()
            numberwang_admin_globalcrouchwalkspeedamount:ConVarChanged(AdminConVarChanged)
            numberwang_admin_globalcrouchwalkspeedamount.OnValueChanged = AdminSetValue

            local label_admin_globalcrouchwalkspeedamount = vgui.Create("DLabel", self.SpawnPanel)
            label_admin_globalcrouchwalkspeedamount:SetPos(105, 303)
            label_admin_globalcrouchwalkspeedamount:SetText("Amount of crouch walk speed for all pills")
            label_admin_globalcrouchwalkspeedamount:SetDark(true)
            label_admin_globalcrouchwalkspeedamount:SizeToContents()

            local checkbox_admin_globaljumppower = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_globaljumppower:SetPos(20, 320)
            checkbox_admin_globaljumppower:SetText("Set all pill jump powers to the same value")
            checkbox_admin_globaljumppower:SetDark(true)
            checkbox_admin_globaljumppower:SetConVar("pk_pill_admin_globaljumppower")
            checkbox_admin_globaljumppower:SizeToContents()
            checkbox_admin_globaljumppower.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_globaljumppower.Button.DoClick = AdminClick

            local numberwang_admin_globaljumppoweramount = vgui.Create("DNumberWang", self.SpawnPanel)
            numberwang_admin_globaljumppoweramount:SetPos(40, 340)
            numberwang_admin_globaljumppoweramount:SetValue(4)
            numberwang_admin_globaljumppoweramount:SetTooltip("Amount of jump power for all pills")
            numberwang_admin_globaljumppoweramount:SetMin(1)
            numberwang_admin_globaljumppoweramount:SetMax(100)
            numberwang_admin_globaljumppoweramount:SetConVar("pk_pill_admin_globaljumppoweramount")
            numberwang_admin_globaljumppoweramount:SizeToContents()
            numberwang_admin_globaljumppoweramount:ConVarChanged(AdminConVarChanged)
            numberwang_admin_globaljumppoweramount.OnValueChanged = AdminSetValue

            local label_admin_globaljumppoweramount = vgui.Create("DLabel", self.SpawnPanel)
            label_admin_globaljumppoweramount:SetPos(100, 343)
            label_admin_globaljumppoweramount:SetText("Amount of jump power for all pills")
            label_admin_globaljumppoweramount:SetDark(true)
            label_admin_globaljumppoweramount:SizeToContents()

            local checkbox_admin_attackschangespeed = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_attackschangespeed:SetPos(20, 360)
            checkbox_admin_attackschangespeed:SetText("Make attacks change pill speed")
            checkbox_admin_attackschangespeed:SetDark(true)
            checkbox_admin_attackschangespeed:SetConVar("pk_pill_admin_attackschangespeed")
            checkbox_admin_attackschangespeed:SizeToContents()
            checkbox_admin_attackschangespeed.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_attackschangespeed.Button.DoClick = AdminClick

            local checkbox_admin_wallclimb = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_wallclimb:SetPos(20, 380)
            checkbox_admin_wallclimb:SetText("Allow pills to climb walls")
            checkbox_admin_wallclimb:SetDark(true)
            checkbox_admin_wallclimb:SetConVar("pk_pill_admin_wallclimb")
            checkbox_admin_wallclimb:SizeToContents()
            checkbox_admin_wallclimb.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_wallclimb.Button.DoClick = AdminClick

            local checkbox_admin_fastcloak = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_fastcloak:SetPos(20, 400)
            checkbox_admin_fastcloak:SetText("Faster cloaking")
            checkbox_admin_fastcloak:SetDark(true)
            checkbox_admin_fastcloak:SetConVar("pk_pill_admin_fastcloak")
            checkbox_admin_fastcloak:SizeToContents()
            checkbox_admin_fastcloak.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_fastcloak.Button.DoClick = AdminClick

            local numberwang_admin_fastcloakamount = vgui.Create("DNumberWang", self.SpawnPanel)
            numberwang_admin_fastcloakamount:SetPos(40, 420)
            numberwang_admin_fastcloakamount:SetValue(15)
            numberwang_admin_fastcloakamount:SetTooltip("How fast in ticks do pills with cloaking abilities cloak for")
            numberwang_admin_fastcloakamount:SetMin(1)
            numberwang_admin_fastcloakamount:SetMax(255)
            numberwang_admin_fastcloakamount:SetConVar("pk_pill_admin_fastcloakamount")
            numberwang_admin_fastcloakamount:SizeToContents()
            numberwang_admin_fastcloakamount:ConVarChanged(AdminConVarChanged)
            numberwang_admin_fastcloakamount.OnValueChanged = AdminSetValue

            local label_admin_fastcloakamount = vgui.Create("DLabel", self.SpawnPanel)
            label_admin_fastcloakamount:SetPos(100, 423)
            label_admin_fastcloakamount:SetText("How fast in ticks do pills with cloaking abilities cloak for")
            label_admin_fastcloakamount:SetDark(true)
            label_admin_fastcloakamount:SizeToContents()

            local button_exit_2 = vgui.Create("DButton", self.SpawnPanel)
            button_exit_2:SetText("Force Exit Pill")
            button_exit_2:SizeToContents()
            button_exit_2:SetPos(20, 450)
            button_exit_2.DoClick = function()
                RunConsoleCommand("pk_pill_restore_force")
            end

            local heading_debug = vgui.Create("DLabel", self.SpawnPanel)
            heading_debug:SetPos(20, 640)
            heading_debug:SetText("Debug Settings")
            heading_debug:SetFont("DermaLarge")
            heading_debug:SetColor(Color(153, 0, 0))
            heading_debug:SizeToContents()

            local checkbox_admin_debug_animfreezespeed = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_debug_animfreezespeed:SetPos(20, 680)
            checkbox_admin_debug_animfreezespeed:SetText("[DEBUG] Set speed after animFreeze or plyFrozen")
            checkbox_admin_debug_animfreezespeed:SetDark(true)
            checkbox_admin_debug_animfreezespeed:SetConVar("pk_pill_admin_debug_animfreezespeed")
            checkbox_admin_debug_animfreezespeed:SizeToContents()
            checkbox_admin_debug_animfreezespeed.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_debug_animfreezespeed.Button.DoClick = AdminClick

            local checkbox_admin_debug_formtablethinkfunc = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_debug_formtablethinkfunc:SetPos(20, 700)
            checkbox_admin_debug_formtablethinkfunc:SetText("[DEBUG] Extra formTable.think.func")
            checkbox_admin_debug_formtablethinkfunc:SetDark(true)
            checkbox_admin_debug_formtablethinkfunc:SetConVar("pk_pill_admin_debug_formtablethinkfunc")
            checkbox_admin_debug_formtablethinkfunc:SizeToContents()
            checkbox_admin_debug_formtablethinkfunc.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_debug_formtablethinkfunc.Button.DoClick = AdminClick

            local checkbox_admin_debug_oldwaterdamage = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_debug_oldwaterdamage:SetPos(20, 720)
            checkbox_admin_debug_oldwaterdamage:SetText("[DEBUG] Old damageFromWater logic")
            checkbox_admin_debug_oldwaterdamage:SetDark(true)
            checkbox_admin_debug_oldwaterdamage:SetConVar("pk_pill_admin_debug_oldwaterdamage")
            checkbox_admin_debug_oldwaterdamage:SizeToContents()
            checkbox_admin_debug_oldwaterdamage.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_debug_oldwaterdamage.Button.DoClick = AdminClick

            local checkbox_admin_debug_oldcharge = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_debug_oldcharge:SetPos(20, 740)
            checkbox_admin_debug_oldcharge:SetText("[DEBUG] Use the old charge logic")
            checkbox_admin_debug_oldcharge:SetTooltip("Best used with the pill loop stop debug option")
            checkbox_admin_debug_oldcharge:SetDark(true)
            checkbox_admin_debug_oldcharge:SetConVar("pk_pill_admin_debug_oldcharge")
            checkbox_admin_debug_oldcharge:SizeToContents()
            checkbox_admin_debug_oldcharge.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_debug_oldcharge.Button.DoClick = AdminClick

            local checkbox_admin_debug_oldbulksound = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_debug_oldbulksound:SetPos(20, 760)
            checkbox_admin_debug_oldbulksound:SetText("[DEBUG] Use the old bulk sound logic")
            checkbox_admin_debug_oldbulksound:SetDark(true)
            checkbox_admin_debug_oldbulksound:SetConVar("pk_pill_admin_debug_oldbulksound")
            checkbox_admin_debug_oldbulksound:SizeToContents()
            checkbox_admin_debug_oldbulksound.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_debug_oldbulksound.Button.DoClick = AdminClick

            local checkbox_admin_debug_pillloopstop = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_debug_pillloopstop:SetPos(20, 780)
            checkbox_admin_debug_pillloopstop:SetText("[DEBUG] Additional functionality to make pill loop sounds stop")
            checkbox_admin_debug_pillloopstop:SetTooltip("Best used when the old charge logic is enabled")
            checkbox_admin_debug_pillloopstop:SetDark(true)
            checkbox_admin_debug_pillloopstop:SetConVar("pk_pill_admin_debug_pillloopstop")
            checkbox_admin_debug_pillloopstop:SizeToContents()
            checkbox_admin_debug_pillloopstop.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_debug_pillloopstop.Button.DoClick = AdminClick

            -- checkbox_admin_debug_oldcharge.Button.DoClick = function(selfBtn)
            --     local newVal = not selfBtn:GetChecked()
            --     selfBtn:SetChecked(newVal)
            --     RunConsoleCommand("pk_pill_admin_debug_oldcharge", newVal and "1" or "0")

            --     checkbox_admin_debug_pillloopstop.Button:SetChecked(newVal)
            --     RunConsoleCommand("pk_pill_admin_debug_pillloopstop", newVal and "1" or "0")

            --     if AdminClick then AdminClick(selfBtn) end
            -- end

            -- checkbox_admin_debug_oldcharge.Button.ConVarChanged = function(selfBtn, val)
            --     local boolVal = val == "1"
            --     checkbox_admin_debug_pillloopstop.Button:SetChecked(boolVal)
            --     RunConsoleCommand("pk_pill_admin_debug_pillloopstop", boolVal and "1" or "0")

            --     if AdminConVarChanged then AdminConVarChanged(selfBtn, val) end
            -- end

            local checkbox_admin_debug_attack2tracedata = vgui.Create("DCheckBoxLabel", self.SpawnPanel)
            checkbox_admin_debug_attack2tracedata:SetPos(20, 800)
            checkbox_admin_debug_attack2tracedata:SetText("[DEBUG] Entity physics tracedata when using attack2")
            checkbox_admin_debug_attack2tracedata:SetDark(true)
            checkbox_admin_debug_attack2tracedata:SetConVar("pk_pill_admin_debug_attack2tracedata")
            checkbox_admin_debug_attack2tracedata:SizeToContents()
            checkbox_admin_debug_attack2tracedata.Button.ConVarChanged = AdminConVarChanged
            checkbox_admin_debug_attack2tracedata.Button.DoClick = AdminClick
        end

        node_settings.DoClick = function(self)
            self:DoPopulate()
            ctrl:SwitchPanel(self.SpawnPanel)
        end

        local node_docs = tree:AddNode("Documentation", "icon16/note.png")
        makeBrowserNode(node_docs, "https://steamcommunity.com/workshop/filedetails/discussion/950845673/1836811737987032534/")
        local node_bug = tree:AddNode("Bugs, Fixes, and Compatibility", "icon16/bug.png")
        makeBrowserNode(node_bug, "https://steamcommunity.com/workshop/filedetails/discussion/950845673/1836811737987005083/")
        local node_drednot = tree:AddNode("Play Drednot.io", "icon16/joystick.png")
        makeBrowserNode(node_drednot, "https://drednot.io")
        local node_github = tree:AddNode("Github Repository", "icon16/world_link.png")
        makeBrowserNode(node_github, "https://github.com/Setnour6/PillPackBaseRevised/")

        for _, pack in pairs(packs) do
            local parentNode = node_installed
            if pack.name == "Half-Life 2" or pack.name == "Fun" or pack.name == "Jake" then
                parentNode = node_base
            end
            local node = parentNode:AddNode(isstring(pack.name) and pack.name, isstring(pack.icon) and pack.icon)

            --[[if (istable(pack.name) || istable(pack.icon)) then
				-- wew shitcode!
				timer.Create("pk_discosheep_"..math.random(9999), .1, 0, function()
					if istable(pack.name) then
						node:SetText( pack.name[ math.random( #pack.name ) ] )
					end

					if istable(pack.icon) then
						node.Icon:SetImage( pack.icon[ math.random( #pack.icon ) ] )
					end
				end)
			end]]
            node.DoPopulate = function(self)
                -- If we've already populated it - forget it.
                if (self.SpawnPanel) then return end
                -- Create the container panel
                self.SpawnPanel = vgui.Create("ContentContainer", ctrl)
                self.SpawnPanel:SetVisible(false)
                self.SpawnPanel:SetTriggerSpawnlistChange(false)

                -- warnings
                for _, item in pairs(pack.headers) do
                    spawnmenu.CreateContentIcon(item.type, self.SpawnPanel, item)
                end

                -- icons
                for _, item in SortedPairsByMemberValue(pack.items, "printName") do
                    spawnmenu.CreateContentIcon(item.type, self.SpawnPanel, item)
                end
            end

            -- If we click on the node populate it and switch to it.
            node.DoClick = function(self)
                self:DoPopulate()
                ctrl:SwitchPanel(self.SpawnPanel)
            end
        end

        node_morphs:SetExpanded(true)
        node_base:SetExpanded(true)
        node_installed:SetExpanded(true)

        return ctrl
    end, "icon16/pill_go.png", 60)
end

-- NW Strings
if SERVER then
    util.AddNetworkString("pk_pill_filtercam")
    util.AddNetworkString("pk_pill_morphsound")
    --util.AddNetworkString("pk_pill_init_darkrp")
else
    net.Receive("pk_pill_filtercam", function(len, pl)
        local pill = net.ReadEntity()
        local filtered = net.ReadEntity()

        if IsValid(pill) and IsValid(filtered) then
            table.insert(pill.camTraceFilter, filtered)
        end
    end)

    local snd_pillSet = Sound("Friends/friend_online.wav")
    local snd_pillFail = Sound("buttons/button2.wav")

    net.Receive("pk_pill_morphsound", function(len, pl)
        local success = net.ReadBit()

        if success == 1 then
            surface.PlaySound(snd_pillSet)
        else
            surface.PlaySound(snd_pillFail)
        end
    end)
end

-- Apply/Restore
if SERVER then
    --[[
		Modes:
		DEFAULT - Force, but don't change locking settings
		user - Obey restrictions
		force - force, change locking settings
		lock-life - force until death
		lock-map - force until map restart
		lock-perma - force forever
	]]
    function apply(ply, name, mode, option)
        if CLIENT then return end
        t = forms[name]

        if not t then
            print("Player '" .. ply:Name() .. "' attempted to use nonexistent pill '" .. name .. "'.")
            ply:PrintMessage(HUD_PRINTCONSOLE, "Attempted to use nonexistent pill '" .. name .. "'.")

            return
        end

        local old = getMappedEnt(ply)

        if not ply:Alive() and not IsValid(old) then
            ply:ChatPrint("You are DEAD! Dead people can't use pill!")

            return
        end

        local locked
        local overridePos
        local overrideAng

        --restriction logic
        if mode == "user" then
            local success = true

            if not t.printName then
                ply:ChatPrint("You cannot use this pill directly.")
                success = false
            end

            if pk_pills.convars.admin_restrict:GetBool() and not ply:IsAdmin() then
                ply:ChatPrint("Pills are restricted to Admins.")
                success = false
            end

            if success and pk_pills._restricted[name] and not ply:IsAdmin() then
                ply:ChatPrint("You must be an Admin to use this pill.")
                success = false
            end

            if IsValid(old) and old.locked then
                if locked_perma[ply:SteamID()] then
                    ply:ChatPrint("You are locked in your current pill -- FOREVER!")
                elseif locked_game[ply:SteamID()] then
                    ply:ChatPrint("You are locked in your current pill until the map changes.")
                else
                    ply:ChatPrint("You are locked in your current pill until you die.")
                end

                success = false
            end

            if t.type == "phys" and t.userSpawn then
                local tr

                if IsValid(old) and old.formTable.type == "phys" then
                    tr = util.QuickTrace(old:GetPos(), ply:EyeAngles():Forward() * 99999, old)
                else
                    tr = ply:GetEyeTrace()
                end

                if t.userSpawn.type == "ceiling" then
                    if tr.HitNormal.z < -.8 and not tr.HitSky then
                        overridePos = tr.HitPos + tr.HitNormal * (t.userSpawn.offset or 0)
                    else
                        success = false
                        ply:ChatPrint("You need to be looking at a ceiling to use this pill.")
                    end
                elseif t.userSpawn.type == "wall" then
                    if not tr.HitSky then
                        overridePos = tr.HitPos + tr.HitNormal * (t.userSpawn.offset or 0)
                        overrideAng = tr.HitNormal:Angle()

                        if t.userSpawn.ang then
                            overrideAng = overrideAng + t.userSpawn.ang
                        end
                    else
                        success = false
                        ply:ChatPrint("You need to be looking at a wall to use this pill.")
                    end
                end
            end

            net.Start("pk_pill_morphsound")
            net.WriteBit(success)
            net.Send(ply)
            if not success then return end
        elseif mode ~= nil then
            --anything that can change locks
            if mode == "lock-map" then
                locked_game[ply:SteamID()] = name
            else
                locked_game[ply:SteamID()] = nil
            end

            if mode == "lock-perma" then
                locked_perma[ply:SteamID()] = name
            else
                locked_perma[ply:SteamID()] = nil
            end

            file.Write("pill_config/permalocked.txt", util.TableToKeyValues(locked_perma, "permalocked"))

            if mode ~= "force" then
                locked = true
            end
        end

        local e

        if t.type == "phys" then
            e = ents.Create("pill_ent_phys")

            if overridePos then
                e:SetPos(overridePos)
                --elseif old&&old.formTable&&old.formTable.type=="phys" then
                --	e:SetPos(old:LocalToWorld(t.spawnOffset or Vector(0,0,60)))
            else
                e:SetPos(ply:LocalToWorld(t.spawnOffset or Vector(0, 0, 60)))
            end

            if overrideAng then
                e:SetAngles(overrideAng)
            else
                local angs = ply:EyeAngles()
                angs.p = 0
                e:SetAngles(angs)
            end
        elseif t.type == "ply" then
            e = ents.Create("pill_ent_costume")

            if old and old.formTable.type == "phys" then
                local angs = ply:EyeAngles()
                ply:Spawn()
                ply:SetEyeAngles(angs)
                ply:SetPos(old:GetPos())
            end
        else
            ply:ChatPrint("WARNING: Attempted to use invalid pill type.")

            return
        end

        local oldvel

        if IsValid(old) and old.formTable.type == "phys" then
            local phys = old:GetPhysicsObject()
            oldvel = IsValid(phys) and phys:GetVelocity() or Vector(0, 0, 0)
        else
            oldvel = ply:GetVelocity()
        end

        --Remove old AFTER we had a chance to set the new
        if IsValid(old) then
            old:Remove()
        end

        e:SetPillForm(name)
        e:SetPillUser(ply)
        e.locked = locked
        e.option = option
        e:Spawn()
        e:Activate()

        --if mode=="user" then
        if t.type == "phys" then
            --ply:SetLocalVelocity(oldvel)
            --else
            local phys = e:GetPhysicsObject()

            if IsValid(phys) then
                phys:SetVelocity(oldvel)
            end
        end

        --end
        if t.type ~= "ply" then
            ply:SetLocalVelocity(Vector(0, 0, 0))
        end

        return e
    end

    local driveModes = {}

    function getDrive(typ)
        return driveModes[typ]
    end

    function registerDrive(name, t)
        driveModes[name] = t
    end
end

--set breakout to true to break out of any locks
--returns true if the player was using a pill
--shared because it goes in the noclip function, I guess
function restore(ply, breakout)
    local ent = getMappedEnt(ply)

    if IsValid(ent) then
        if SERVER then
            if ent.locked and not breakout then
                if locked_perma[ply:SteamID()] then
                    ply:ChatPrint("You are locked in your current pill -- FOREVER!")
                elseif locked_game[ply:SteamID()] then
                    ply:ChatPrint("You are locked in your current pill until the map changes.")
                else
                    ply:ChatPrint("You are locked in your current pill until you die.")
                end
            else
                ent.notDead = true
                ent:Remove()
            end

            if not breakout then
                net.Start("pk_pill_morphsound")
                net.WriteBit(ent.notDead)
                net.Send(ply)
            else
                locked_game[ply:SteamID()] = nil
                locked_perma[ply:SteamID()] = nil
                file.Write("pill_config/permalocked.txt", util.TableToKeyValues(locked_perma, "permalocked"))
            end
        end

        if pk_pills.convars.preserve:GetBool() then
            if math.random() < .8 then
                local e = ents.Create("pill_worldent")
                e:SetPos(ply:EyePos() + ply:EyeAngles():Forward() * 80)
                e:SetPillForm(ent:GetPillForm())
                e:Spawn()
                local phys = e:GetPhysicsObject()

                if IsValid(phys) then
                    phys:SetVelocity(ply:GetVelocity() + ply:EyeAngles():Forward() * 500)
                end

                ent:EmitSound("weapons/crossbow/fire1.wav")
            else
                ent:EmitSound("npc/scanner/scanner_explode_crash2.wav")
            end
        end

        return true
    end
end

-- This crap is entirely for MorphDM.
if SERVER then
    function pk_pills.handeDeathCommon(ent)
        if pk_pills.convars.preserve:GetBool() then
            if math.random() < .8 then
                local e = ents.Create("pill_worldent")
                e:SetPos(ent:GetPos())
                e:SetPillForm(ent:GetPillForm())
                e:Spawn()
                local phys = e:GetPhysicsObject()

                if IsValid(phys) then
                    phys:SetVelocity(VectorRand() * 500)
                end

                ent:EmitSound("weapons/crossbow/fire1.wav")
            else
                ent:EmitSound("npc/scanner/scanner_explode_crash2.wav")
            end
        end
    end
end

-- THEM HOOKS
if SERVER then
    hook.Add("KeyPress", "pk_pill_keypress", function(ply, key)
        local ent = getMappedEnt(ply)

        if IsValid(ent) then
            ent:DoKeyPress(ply, key)
        end
    end)

    hook.Add("PlayerSwitchFlashlight", "pk_pill_flashlight", function(ply, on)
        local ent = getMappedEnt(ply)

        if IsValid(ent) and on then
            if ent.formTable.flashlight and not ent.animFreeze then
                ent.formTable.flashlight(ply, ent)
            end

            return false
        end
    end)

    hook.Add("SetupPlayerVisibility", "pk_pill_pvs", function(ply)
        if IsValid(getMappedEnt(ply)) and getMappedEnt(ply).formTable.type == "phys" then
            AddOriginToPVS(getMappedEnt(ply):GetPos())
        end
    end)

    hook.Add("PlayerDeathThink", "pk_pill_nospawn", function(ply)
        if getMappedEnt(ply) then return false end
    end)

    hook.Add("DoAnimationEvent", "pk_pill_triggerAnims", function(ply, event, data)
        if IsValid(getMappedEnt(ply)) and getMappedEnt(ply).formTable.type == "ply" then
            if event == PLAYERANIMEVENT_JUMP then
                getMappedEnt(ply):PillAnim("jump")
                getMappedEnt(ply):DoJump()
            end

            if event == PLAYERANIMEVENT_ATTACK_PRIMARY then
                getMappedEnt(ply):PillGesture("attack")
            end

            if event == PLAYERANIMEVENT_ATTACK_SECONDARY then
                getMappedEnt(ply):PillGesture("attack2")
            end

            if event == PLAYERANIMEVENT_RELOAD then
                getMappedEnt(ply):PillGesture("reload")
            end
        end
    end)

    hook.Add("OnPlayerHitGround", "pk_pill_hitground", function(ply)
        local ent = getMappedEnt(ply)

        if IsValid(ent) then
            if ent.formTable.land then
                ent.formTable.land(ply, ent)
                ent:PillSound("land")
            end

            if ent.formTable.noFallDamage or ent.formTable.type == "phys" then return true end
        end
    end)

    hook.Add("DoPlayerDeath", "pk_pill_death", function(ply)
        if IsValid(getMappedEnt(ply)) then
            if SERVER then
                getMappedEnt(ply):PillDie()
            end

            return false
        end
    end)
	
    hook.Add("PlayerCanPickupWeapon", "pk_pill_pickupWeapon", function(ply, wep)
        if IsValid(getMappedEnt(ply)) then
            if getMappedEnt(ply).formTable.type == "ply" then
                if pk_pills.convars.admin_anyweapons:GetBool() or (getMappedEnt(ply).formTable.validHoldTypes and table.HasValue(getMappedEnt(ply).formTable.validHoldTypes, wep:GetHoldType())) then return true end

                return false
            else
                return false
            end
        end
    end)

    hook.Add("PlayerFootstep", "pk_pill_step", function(ply, pos, foot, snd, vol, filter)
        local ent = getMappedEnt(ply)

        if IsValid(ent) then
            if ent.formTable.type == "phys" or ent.formTable.muteSteps or ent.animFreeze then
                return true
            else
                return ent:PillSound("step", pos)
            end
        end
    end)

    hook.Add("PlayerSpawn", "pk_pill_force_on_spawn", function(ply)
        local forcedType = locked_perma[ply:SteamID()] or locked_game[ply:SteamID()]

        if forcedType then
            local e = apply(ply, forcedType)

            if IsValid(e) then
                e.locked = true
            end

            return
        end
    end)
    --For compatibility with player resizer and God knows what else
	hook.Add("SetPlayerSpeed", "pk_pill_speed_enforcer", function(ply,walk,run)
		if IsValid(getMappedEnt(ply)) then
			return false
		end
	end)

--	hook.Add("PlayerStepSoundTime", "pk_pill_step_time", function(ply,type,walking)
--		local ent = playerMap[ply]
--		if IsValid(ent) then
--			//if ent.formTable.stepSize then
--				
--			//end
--			return 100
--		end
--	end)
else -- CLIENT HOOKS
    hook.Add("HUDPaint", "pk_pill_hud", function()
        if pk_pills.convars.cl_hidehud:GetBool() then return end
        local ent = getMappedEnt(LocalPlayer())

        if IsValid(ent) then
            if (ent.formTable.health) then
                local hpMax = ent.formTable.health
                local hpCurrent = ent:GetPillHealth()
                surface.SetDrawColor(Color(0, 0, 0))
                surface.DrawRect(40, ScrH() - 80, 300, 40)

                if not ent.formTable.onlyTakesExplosiveDamage then
                    surface.SetDrawColor(Color(255, 60, 40))
                    surface.DrawRect(42, ScrH() - 78, 296 * math.min(hpCurrent / hpMax, 1), 36)
                    draw.SimpleText("Health: " .. math.Round(hpCurrent) .. "/" .. hpMax, "ChatFont", 190, ScrH() - 52, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                else
                    surface.SetDrawColor(Color(255, 100, 40))
                    surface.DrawRect(42, ScrH() - 78, 296 * math.min(hpCurrent / hpMax, 1), 36)
                    draw.SimpleText("Hits Left: " .. math.Round(hpCurrent) .. "/" .. hpMax, "ChatFont", 190, ScrH() - 52, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                end
            end

            if ent.formTable.cloak and ent.formTable.cloak.max ~= -1 then
                surface.SetDrawColor(Color(0, 0, 0))
                surface.DrawRect(ScrW() - 370, ScrH() - 110, 300, 30)
                surface.SetDrawColor(Color(130, 130, 255))
                surface.DrawRect(ScrW() - 368, ScrH() - 108, 296 * math.min(ent:GetCloakLeft() / ent.formTable.cloak.max, 1), 26)
                draw.SimpleText("Cloak: " .. string.format("%.3f", ent:GetCloakLeft()) .. " Seconds", "ChatFont", ScrW() - 200, ScrH() - 86, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
            end

            if ent.formTable.aim and (not ent.formTable.aim.usesSecondaryEnt or IsValid(ent:GetPillAimEnt())) and not ent.formTable.aim.nocrosshair then
                local aimEnt = (ent.GetPillAimEnt and IsValid(ent:GetPillAimEnt()) and ent:GetPillAimEnt()) or ent
                local attachment

                if ent.formTable.aim.attachment then
                    attachment = aimEnt:GetAttachment(aimEnt:LookupAttachment(ent.formTable.aim.attachment))
                end

                local dir

                if ent.formTable.aim.simple or not attachment then
                    dir = LocalPlayer():EyeAngles():Forward()
                else
                    dir = attachment.Ang:Forward()
                end

                local start = ent.formTable.aim.overrideStart and ent:LocalToWorld(ent.formTable.aim.overrideStart) or (attachment and attachment.Pos) or (ent.formTable.type == "ply" and LocalPlayer():GetShootPos() or ent:GetPos())
                local tr = util.QuickTrace(start, dir * 99999, {aimEnt, LocalPlayer()})
                local screenPos = tr.HitPos:ToScreen()
                local chColor = Color(160, 220, 50)

                if IsValid(tr.Entity) and (tr.Entity:IsPlayer() or tr.Entity:IsNPC() or tr.Entity:GetClass() == "pill_ent_phys") then
                    chColor = Color(255, 0, 0)
                end

                if screenPos.visible then
                    draw.TexturedQuad({
                        texture = surface.GetTextureID("sprites/hud/v_crosshair1"),
                        color = chColor,
                        x = screenPos.x - 20,
                        y = screenPos.y - 20,
                        w = 40,
                        h = 40
                    })
                end
            end
        end

        -- nametags
        if IsValid(LocalPlayer()) then
            local trent = LocalPlayer():GetEyeTraceNoCursor().Entity

            if (IsValid(trent) and trent:GetClass() == "pill_ent_phys") then
                local pillowner = trent:GetPillUser()

                if IsValid(pillowner) and pillowner ~= LocalPlayer() then
                    draw.SimpleText(pillowner:GetName(), "ChatFont", ScrW() / 2, ScrH() / 2, team.GetColor(pillowner:Team()), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                    if trent:GetPillHealth() > 0 then
                        draw.SimpleText(trent:GetPillHealth() .. " HP", "ChatFont", ScrW() / 2, ScrH() / 2 + 20, team.GetColor(pillowner:Team()), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end
            end
        end
    end)

    -- IGNORE THIS NONSENSE: Just use the default HUD from now on
    hook.Add("HUDShouldDraw", "pk_pill_hideHud", function(name)
        if (getMappedEnt(LocalPlayer()) and name == "CHudHealth") then return false end
    end)
    --[[
	--Causes issues with other players being drawn over their puppets
	hook.Add("ShouldDrawLocalPlayer","pk_pill_thirdperson",function() //only really used for viewmodel... betr ways?
		if getMappedEnt(LocalPlayer()) then
			return true
		end
	end)
	hook.Add("CalcViewModelView","pk_pill_thirdperson",function(wep,mdl,oldpos,oldang,pos,ang)
		if playerMap[LocalPlayer()] && var_thirdperson:GetBool() then
			return pos-Vector(0,0,100),ang
		end
	end)]]
end

-- Shared hooks
hook.Add("PhysgunPickup", "pk_pill_nograb", function(ply, ent)
    if ent:GetClass() == "pill_ent_phys" then
        if ply:IsAdmin() then
            return true
        else
            return false
        end
    end
end)

hook.Add("SetupMove", "pk_pill_movemod", function(ply, mv, cmd)
    local ent = getMappedEnt(ply)

    if IsValid(ent) then
        if ent.formTable.moveMod then
            ent.formTable.moveMod(ply, ent, mv, cmd)
        end

        if ent.GetChargeTime and ent:GetChargeTime() ~= 0 then
            local charge = ent.formTable.charge
            --check if we should continue
            local vel = mv:GetVelocity()

            if ent:GetChargeTime() + .1 < CurTime() and vel:Length() < charge.vel * .8 then
                print("uncharge")
                ent:SetChargeTime(0)
                ent:PillLoopStopAll()
                -- ent:PillLoopStop("charge")
            else
                local angs = ent:GetChargeAngs()
                ply:SetEyeAngles(angs)
                mv:SetVelocity(angs:Forward() * charge.vel)
            end
        end
    end
end)

-- Includes
if SERVER then
    include("ppp_includes/sv_ai.lua")
end

include("ppp_includes/vox.lua")
include("ppp_includes/util.lua")
include("ppp_includes/nocompat.lua")
include("ppp_includes/tf2lib.lua")
include("ppp_includes/console.lua")
include("ppp_includes/join_prompt.lua")
include("ppp_includes/restricted.lua")

include("ppp_includes/locomotion.lua")
-- DONE!
print("PILL CORE LOADED")
