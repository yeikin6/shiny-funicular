--!strict
-- Formateo de números grandes: 1.23K, 4.5M ... y notación e cuando se acaban los sufijos.

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local Format = {}

function Format.number(value: number): string
	if value ~= value then
		return "0"
	end
	if value == math.huge then
		return "∞"
	end
	local sign = if value < 0 then "-" else ""
	local abs = math.abs(value)
	if abs < 1000 then
		return sign .. tostring(math.floor(abs))
	end

	local exponent = math.floor(math.log10(abs))
	local tier = exponent // 3
	if tier < #SUFFIXES then
		local scaled = abs / 10 ^ (tier * 3)
		local text = if scaled >= 100
			then string.format("%d", math.floor(scaled))
			elseif scaled >= 10 then string.format("%.1f", math.floor(scaled * 10) / 10)
			else string.format("%.2f", math.floor(scaled * 100) / 100)
		return sign .. text .. SUFFIXES[tier + 1]
	end

	local mantissa = abs / 10 ^ exponent
	return string.format("%s%.2fe%d", sign, math.floor(mantissa * 100) / 100, exponent)
end

function Format.seconds(value: number): string
	local s = math.max(0, math.ceil(value))
	if s < 60 then
		return `{s}s`
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

return Format
