////////////////////////
//Turret Control Panel//
////////////////////////

/area
	// Turrets use this list to see if individual power/lethal settings are allowed
	var/list/turret_controls = list()

/obj/machinery/turretid
	name = "turret control panel"
	desc = "Used to control a room's automated defenses."
	icon = 'icons/obj/machines/turret_control.dmi'
	icon_state = "control_standby"
	anchored = 1
	density = 0
	var/enabled = 0
	var/lethal = 0
	var/locked = 1
	var/area/control_area //can be area name, path or nothing.

	var/check_arrest = 1	//checks if the perp is set to arrest
	var/check_records = 1	//checks if a security record exists at all
	var/check_weapons = 0	//checks if it can shoot people that have a weapon they aren't authorized to have
	var/check_access = 1	//if this is active, the turret shoots everything that does not meet the access requirements
	var/check_anomalies = 1	//checks if it can shoot at unidentified lifeforms (ie xenos)
	var/check_synth = 0 	//if active, will shoot at anything not an AI or cyborg
	var/ailock = 0 	//Silicons cannot use this

	req_access = list(access_ai_upload)

/obj/machinery/turretid/stun
	enabled = 1
	icon_state = "control_stun"

/obj/machinery/turretid/lethal
	enabled = 1
	lethal = 1
	icon_state = "control_kill"

/obj/machinery/turretid/Del()
	if(control_area)
		var/area/A = control_area
		if(A && istype(A))
			A.turret_controls -= src
	..()

/obj/machinery/turretid/initialize()
	if(!control_area)
		var/area/CA = get_area(src)
		control_area = CA.master
	else if(istext(control_area))
		for(var/area/A in world)
			if(A.name && A.name==control_area)
				control_area = A.master
				break

	if(control_area)
		var/area/A = control_area
		if(istype(A))
			A.turret_controls += src
		else
			control_area = null

	power_change() //Checks power and initial settings
	return

/obj/machinery/turretid/proc/isLocked(mob/user)
	if(ailock && (isrobot(user) || isAI(user)))
		user << "<span class='notice'>There seems to be a firewall preventing you from accessing this device.</span>"
		return 1

	if(locked && !(isrobot(user) || isAI(user)))
		user << "<span class='notice'>Access denied.</span>"
		return 1

	return 0

/obj/machinery/turretid/attackby(obj/item/weapon/W, mob/user)
	if(stat & BROKEN)
		return

	if(istype(W, /obj/item/weapon/card/id)||istype(W, /obj/item/device/pda))
		if(src.allowed(usr))
			if(emagged)
				user << "<span class='notice'>The turret control is unresponsive.</span>"
			else
				locked = !locked
				user << "<span class='notice'>You [ locked ? "lock" : "unlock"] the panel.</span>"
		return
	return ..()
	
/obj/machinery/turretid/emag_act(user as mob)
	if(!emagged)
		user << "<span class='danger'>You short out the turret controls' access analysis module.</span>"
		emagged = 1
		locked = 0
		ailock = 0
		return

/obj/machinery/turretid/attack_ai(mob/user as mob)
	if(isLocked(user))
		return

	ui_interact(user)

/obj/machinery/turretid/attack_hand(mob/user as mob)
	if(isLocked(user))
		return

	ui_interact(user)

/obj/machinery/turretid/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1)
	var/data[0]
	data["access"] = !isLocked(user)
	data["locked"] = locked
	data["enabled"] = enabled
	data["is_lethal"] = 1
	data["lethal"] = lethal

	if(data["access"])
		var/settings[0]
		settings[++settings.len] = list("category" = "Neutralize All Non-Synthetics", "setting" = "check_synth", "value" = check_synth)
		settings[++settings.len] = list("category" = "Check Weapon Authorization", "setting" = "check_weapons", "value" = check_weapons)
		settings[++settings.len] = list("category" = "Check Security Records", "setting" = "check_records", "value" = check_records)
		settings[++settings.len] = list("category" = "Check Arrest Status", "setting" = "check_arrest", "value" = check_arrest)
		settings[++settings.len] = list("category" = "Check Access Authorization", "setting" = "check_access", "value" = check_access)
		settings[++settings.len] = list("category" = "Check Misc. Lifeforms", "setting" = "check_anomalies", "value" = check_anomalies)
		data["settings"] = settings

	ui = nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "turret_control.tmpl", "Turret Controls", 500, 300)
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(1)

/obj/machinery/turretid/Topic(href, href_list, var/nowindow = 0)
	if(..())
		return 1
		
	if(isLocked(usr))
		return 1

	if(href_list["command"] && href_list["value"])
		var/value = text2num(href_list["value"])
		if(href_list["command"] == "enable")
			enabled = value
		else if(href_list["command"] == "lethal")
			lethal = value
		else if(href_list["command"] == "check_synth")
			check_synth = value
		else if(href_list["command"] == "check_weapons")
			check_weapons = value
		else if(href_list["command"] == "check_records")
			check_records = value
		else if(href_list["command"] == "check_arrest")
			check_arrest = value
		else if(href_list["command"] == "check_access")
			check_access = value
		else if(href_list["command"] == "check_anomalies")
			check_anomalies = value

		updateTurrets()
		return 1

/obj/machinery/turretid/proc/updateTurrets()
	var/datum/turret_checks/TC = new
	TC.enabled = enabled
	TC.lethal = lethal
	TC.check_synth = check_synth
	TC.check_access = check_access
	TC.check_records = check_records
	TC.check_arrest = check_arrest
	TC.check_weapons = check_weapons
	TC.check_anomalies = check_anomalies
	TC.ailock = ailock

	if(istype(control_area))
		for(var/area/sub_area in control_area.related)
			for (var/obj/machinery/porta_turret/aTurret in sub_area)
				aTurret.setState(TC)

	update_icon()

/obj/machinery/turretid/power_change()
	..()
	updateTurrets()
	update_icon()

/obj/machinery/turretid/update_icon()
	..()
	if(stat & NOPOWER)
		icon_state = "control_off"
	else if (enabled)
		if (lethal)
			icon_state = "control_kill"
		else
			icon_state = "control_stun"
	else
		icon_state = "control_standby"

/obj/machinery/turretid/emp_act(severity)
	if(enabled)
		//if the turret is on, the EMP no matter how severe disables the turret for a while
		//and scrambles its settings, with a slight chance of having an emag effect

		check_arrest = pick(0, 1)
		check_records = pick(0, 1)
		check_weapons = pick(0, 1)
		check_access = pick(0, 0, 0, 0, 1)	// check_access is a pretty big deal, so it's least likely to get turned on
		check_anomalies = pick(0, 1)

		enabled=0
		updateTurrets()

		sleep(rand(60,600))
		if(!enabled)
			enabled=1
			updateTurrets()

	..()