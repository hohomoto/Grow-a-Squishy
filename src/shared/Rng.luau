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

-- 32-bit multiply (mod 2^32) without losing precision in doubles.
local function mul32(a: number, b: number): number
	local high = a // 65536
	local low = a % 65536
	return ((high * b) % 65536 * 65536 + low * b) % 4294967296
end

-- MurmurHash3's finalizer. Scrambles nearby seeds (window 1, 2, 3, ...) into
-- unrelated states; xorshift alone is linear and keeps them correlated.
local function mix(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85EBCA6B)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xC2B2AE35)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h
end

function Rng.new(seed: number): Rng
	local low = seed % 4294967296
	local high = (seed // 4294967296) % 4294967296
	local state = mix(bit32.bxor(mix(low), high, 0x9E3779B9))
	-- xorshift must never hold a zero state.
	if state == 0 then
		state = 0x6D2B79F5
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
