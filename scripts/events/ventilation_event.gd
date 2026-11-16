extends WarehouseEvent
## Ventilation Inspection: industrial fans run throughout the building. Air currents
## push you (and light items) along; two big updrafts in the open middle of the
## second floor can lift you up there if you stand in them.


func _start() -> void:
	# [centre of the air column, wind, size]. Horizontal wind is extra walking speed
	# in m/s; vertical wind is an upward acceleration (gravity is 9.8).
	var fans: Array = [
		[Vector3(18.5, 1.5, -7.4), Vector3(6, 0, 0), Vector3(13.0, 3.0, 2.5)],     # east along a corridor of the Z room
		[Vector3(41.5, 1.5, -3.8), Vector3(-6, 0, 0), Vector3(13.0, 3.0, 2.5)],    # west along a corridor of the X room
		[Vector3(31.0, 1.5, -14.6), Vector3(-6, 0, 0), Vector3(25.0, 3.0, 1.2)],   # along the south side of the Y room
		[Vector3(29.2, 2.3, -18.7), Vector3(0, 13, 0), Vector3(1.6, 4.6, 1.6)],    # updrafts in the open middle of the 2nd floor
		[Vector3(32.8, 2.3, -18.7), Vector3(0, 13, 0), Vector3(1.6, 4.6, 1.6)],
		[Vector3(22.0, 1.5, 6.4), Vector3(7, 0, 0), Vector3(10.0, 3.0, 2.5)],      # across the work floor (the corridor)
	]
	for fan in fans:
		var zone := FanZone.new()
		zone.wind = fan[1]
		zone.size = fan[2]
		zone.position = fan[0]
		zone.build()
		add_to_interior(zone)
