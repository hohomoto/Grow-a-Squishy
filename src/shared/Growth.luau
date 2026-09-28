--!strict
-- Pure growth and value math shared by server (authoritative) and client (visuals).

local Economy = require(script.Parent.Config.Economy)

local Growth = {}

-- Fraction grown in [0, 1].
function Growth.progress(startedAt: number, readyAt: number, now: number): number
	local total = readyAt - startedAt
	if total <= 0 then
		return 1
	end
	return math.clamp((now - startedAt) / total, 0, 1)
end

function Growth.isReady(readyAt: number, now: number): boolean
	return now >= readyAt
end

-- Maps a uniform roll u in [0, 1) to a harvest size multiplier, rounded to 0.01.
function Growth.sizeFromRoll(u: number): number
	local size = Economy.MinSize + (Economy.MaxSize - Economy.MinSize) * u ^ Economy.SizeSkew
	return math.floor(size * 100 + 0.5) / 100
end

-- Sell value of one harvested squishy.
function Growth.value(baseValue: number, size: number): number
	return math.max(1, math.floor(baseValue * size * size + 0.5))
end

return Growth
