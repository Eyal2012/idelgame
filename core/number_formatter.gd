class_name NumberFormatter
extends RefCounted

## Shared presentation formatter. Keep the 32-bit chapter target explicit.
## The final five percent is intentionally shown exactly: the player should be
## able to see the remaining signed-integer headroom rather than a rounded 2.1B.
const INT32_EXACT_DISPLAY_THRESHOLD: float = 2040109464.0
const INT32_MAX_DISPLAY_VALUE: float = 2147483647.0

static func format(value: float, decimal_places: int = 0) -> String:
	if is_nan(value) or is_inf(value):
		return "0"
	var absolute := absf(value)
	if absolute >= INT32_EXACT_DISPLAY_THRESHOLD and absolute <= INT32_MAX_DISPLAY_VALUE:
		return _comma_integer(int(round(value)))
	if absolute >= 1_000_000_000.0:
		return _abbreviate(value / 1_000_000_000.0, "B", decimal_places)
	if absolute >= 1_000_000.0:
		return _abbreviate(value / 1_000_000.0, "M", decimal_places)
	if decimal_places > 0 and not is_equal_approx(value, round(value)):
		return _trimmed_decimal(value, decimal_places)
	return _comma_integer(int(round(value)))


static func _abbreviate(value: float, suffix: String, decimal_places: int) -> String:
	return _trimmed_decimal(value, max(1, decimal_places)) + suffix


static func _trimmed_decimal(value: float, decimal_places: int) -> String:
	var text := "%.*f" % [decimal_places, value]
	text = text.trim_suffix("0").trim_suffix(".")
	return text


static func _comma_integer(value: int) -> String:
	var source := str(value)
	var negative := source.begins_with("-")
	if negative:
		source = source.trim_prefix("-")
	var result := ""
	var count := 0
	for index in range(source.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = source[index] + result
		count += 1
	return "-" + result if negative else result
