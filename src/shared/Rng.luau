--!strict
-- Small deterministic PRNG (xorshift32). Used where every server must roll the
-- same result from the same seed, e.g. the global shop stock. Pure bit32 math,
-- so results are exact and identical in Studio, live servers, and tests.

export type Rng = {
	next: (self: Rng) -> number,
	range: (self: Rng, min: number, max: number) -> number,
	_state: number,
}

local Rng = {}
Rng.__index = Rng

local function step(x: number): number
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	return x
end

function Rng.new(seed: number): Rng
	-- Fold the seed into 32 bits; xorshift must never hold a zero state.
	local state = bit32.bxor(seed % 4294967296, 0x9E3779B9)
	if state == 0 then
		state = 0x6D2B79F5
	end
	-- Warm up so consecutive seeds do not produce correlated first values.
	for _ = 1, 16 do
		state = step(state)
	end
	return setmetatable({ _state = state }, Rng) :: any
end

-- Uniform float in [0, 1).
function Rng.next(self: Rng): number
	self._state = step(self._state)
	return self._state / 4294967296
end

-- Uniform integer in [min, max].
function Rng.range(self: Rng, min: number, max: number): number
	return min + math.floor(self:next() * (max - min + 1))
end

return Rng
