AddCSLuaFile()
-- Convars
pk_pills.convars = {}
-- Admin vars
pk_pills.convars.admin_restrict = CreateConVar("pk_pill_admin_restrict", game.IsDedicated() and 1 or 0, FCVAR_REPLICATED + FCVAR_NOTIFY, "Restrict morphing to admins.")
pk_pills.convars.admin_anyweapons = CreateConVar("pk_pill_admin_anyweapons", 0, FCVAR_REPLICATED, "Allow use of any weapon when morphed.")
pk_pills.convars.preserve = CreateConVar("pk_pill_preserve", 0, FCVAR_REPLICATED, "Makes player spit out pills when they unmorph or die.")
pk_pills.convars.admin_delayattack = CreateConVar("pk_pill_admin_delayattack", 0, FCVAR_REPLICATED, "Allows attacking upon first entering a pill for some time.")
pk_pills.convars.admin_drivemoderolljump = CreateConVar("pk_pill_admin_drivemoderolljump", 0, FCVAR_REPLICATED, "Whether the entity physics object can have a force center jump under the 'roll' drive mode.")
pk_pills.convars.admin_globalspeed = CreateConVar("pk_pill_admin_globalspeed", 0, FCVAR_REPLICATED, "Whether all pills from any pill pack have the same walk and run speed.")
pk_pills.convars.admin_globalcrouchwalkspeed = CreateConVar("pk_pill_admin_globalcrouchwalkspeed", 0, FCVAR_REPLICATED, "Whether all pills from any pill pack have the same crouch walk and run speed.")
pk_pills.convars.admin_globaljumppower = CreateConVar("pk_pill_admin_globaljumppower", 0, FCVAR_REPLICATED, "Whether all pills from any pill pack have the same jump power.")
pk_pills.convars.admin_attackschangespeed = CreateConVar("pk_pill_admin_attackschangespeed", 0, FCVAR_REPLICATED, "Whether pills get a bit slower for a moment after attacking.")
pk_pills.convars.admin_wallclimb = CreateConVar("pk_pill_admin_wallclimb", 1, FCVAR_REPLICATED, "Allows all pills to climb walls.")
pk_pills.convars.admin_fastcloak = CreateConVar("pk_pill_admin_fastcloak", 1, FCVAR_REPLICATED, "Pills that can cloak will cloak faster.")

-- Debug vars
pk_pills.convars.admin_debug_animfreezespeed = CreateConVar("pk_pill_admin_debug_animfreezespeed", 0, FCVAR_REPLICATED, "[DEBUG] Set speeds after animFreeze or plyFrozen.")
pk_pills.convars.admin_debug_formtablethinkfunc = CreateConVar("pk_pill_admin_debug_formtablethinkfunc", 1, FCVAR_REPLICATED, "[DEBUG] Do extra formTable.think function.")
pk_pills.convars.admin_debug_oldwaterdamage = CreateConVar("pk_pill_admin_debug_oldwaterdamage", 1, FCVAR_REPLICATED, "[DEBUG] Use old damageFromWater logic.")
pk_pills.convars.admin_debug_oldcharge = CreateConVar("pk_pill_admin_debug_oldcharge", 0, FCVAR_REPLICATED, "[DEBUG] Use the old charge logic.")
pk_pills.convars.admin_debug_oldbulksound = CreateConVar("pk_pill_admin_debug_oldbulksound", 0, FCVAR_REPLICATED, "[DEBUG] Use the old bulk sound logic.")
pk_pills.convars.admin_debug_pillloopstop = CreateConVar("pk_pill_admin_debug_pillloopstop", 0, FCVAR_REPLICATED, "[DEBUG] Additional functionality to make pill loop sounds stop.")
pk_pills.convars.admin_debug_attack2tracedata = CreateConVar("pk_pill_admin_debug_attack2tracedata", 1, FCVAR_REPLICATED, "[DEBUG] Entity physics tracedata when using attack2.")

-- Client vars
if CLIENT then
    pk_pills.convars.cl_thirdperson = CreateClientConVar("pk_pill_cl_thirdperson", 1)
    pk_pills.convars.cl_hidehud = CreateClientConVar("pk_pill_cl_hidehud", 0)
end

-- Admin var setter command.
if SERVER then
    local function admin_set(ply, cmd, args)
        if not ply then
            print("If you are using the server console, you should set the variables directly!")

            return
        end

        if not ply:IsSuperAdmin() then
            ply:PrintMessage(HUD_PRINTCONSOLE, "You must be a super admin to use this command.")

            return
        end

        local var = args[1]
        local value = args[2]

        if not var then
            if ply then
                ply:PrintMessage(HUD_PRINTCONSOLE, "Please supply a valid convar name. Do not include 'pk_pill_admin_'.")
            end

            return
        elseif not ConVarExists("pk_pill_admin_" .. var) then
            ply:PrintMessage(HUD_PRINTCONSOLE, "Convar 'pk_pill_admin_" .. var .. "' does not exist. Please supply a valid convar name. Do not include 'pk_pill_admin_'.")

            return
        end

        if not value then
            ply:PrintMessage(HUD_PRINTCONSOLE, "Please supply a value to set the convar to.")

            return
        end

        RunConsoleCommand("pk_pill_admin_" .. var, value)
    end

    concommand.Add("pk_pill_admin_set", admin_set, nil, "Helper command for setting Morph Mod admin convars. Available to super admins.")
end
