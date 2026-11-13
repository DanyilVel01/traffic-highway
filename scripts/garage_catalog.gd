extends RefCounted

const NAMES: Array[String] = ["AQUA SPRINT", "SUNSET GT", "VIOLET SPORT", "CRIMSON APEX"]
const CLASSES: Array[String] = ["Street", "Grand tourer", "Supercar", "Hypercar"]
const PRICES: Array[int] = [0, 30, 75, 160]
const PAINTS: Array[Color] = [Color("#1ee5d4"), Color("#ff9953"), Color("#ac83ff"), Color("#fa465e")]
const SPEED_KMH: Array[int] = [250, 265, 280, 300]
const ACCELERATION: Array[float] = [12.0, 13.5, 15.0, 17.0]
const NITRO_SECONDS: Array[float] = [0.0, 0.0, 3.0, 5.0]
const NITRO_BONUS_KMH := 45.0
const NITRO_RECHARGE := 12.0
