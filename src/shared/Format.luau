--!strict
-- Display formatting helpers.

local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }

-- 950 -> "950", 1234 -> "1.23K", 15300000 -> "15.3M"
function Format.short(n: number): string
	if math.abs(n) < 1000 then
		return tostring(math.floor(n))
	end
	local tier = 0
	-- 999.5 rather than 1000 so 999,999 reads "1M", not "1000K".
	while math.abs(n) >= 999.5 and tier < #SUFFIXES do
		n /= 1000
		tier += 1
	end
	local digits = if math.abs(n) >= 100 then 0 elseif math.abs(n) >= 10 then 1 else 2
	local text = string.format("%." .. digits .. "f", n)
	-- Trim trailing zeros: "1.50K" -> "1.5K", "2.00K" -> "2K"
	if digits > 0 then
		text = string.gsub(text, "%.?0+$", "")
	end
	return text .. SUFFIXES[tier]
end

-- 1234567 -> "1,234,567"
function Format.commas(n: number): string
	local s = tostring(math.floor(n))
	local sign, digits = string.match(s, "^(-?)(%d+)$")
	if not digits then
		return s
	end
	local out = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	out = string.gsub(out, "^,", "")
	return (sign or "") .. out
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function Format.duration(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

return Format
