extends RefCounted
# Short rumble on a gamepad and a buzz on phones for the moments the screen already shows:
# hits, landings, boosts, mud and scraping a rail. Reduced motion turns it off. A stronger
# pulse may cut a weaker one short; weak ones never interrupt a strong one.
var enabled := true
var phone_buzz := false
var busy_until := 0
var busy_priority := 0
var pulses := 0

# strong / weak are the large and small rumble motors (0-1); priority 0 is a background effect.
func pulse(strong: float, weak: float, seconds: float, priority: int = 1) -> bool:
	if not enabled: return false
	var now := Time.get_ticks_msec()
	if now < busy_until and priority < busy_priority: return false
	busy_until = now+int(seconds*1000)
	busy_priority = priority
	pulses += 1
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device,clampf(weak,0,1),clampf(strong,0,1),seconds)
	if phone_buzz and OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.vibrate && navigator.vibrate(%d)" % clampi(int(seconds*1000),10,400))
	return true

func stop() -> void:
	busy_until = 0
	busy_priority = 0
	for device in Input.get_connected_joypads(): Input.stop_joy_vibration(device)
