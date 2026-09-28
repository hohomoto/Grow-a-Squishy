--!strict
-- Per-player token bucket. Guards remotes against spam and autoclickers.

local Players = game:GetService("Players")

export type RateLimit = {
	allow: (self: RateLimit, player: Player) -> boolean,
	_rate: number,
	_burst: number,
	_buckets: { [Player]: { tokens: number, at: number } },
}

local RateLimit = {}
RateLimit.__index = RateLimit

-- `rate` actions per second on average, bursts of up to `burst`.
function RateLimit.new(rate: number, burst: number): RateLimit
	local self = setmetatable({ _rate = rate, _burst = burst, _buckets = {} }, RateLimit) :: any
	Players.PlayerRemoving:Connect(function(player)
		self._buckets[player] = nil
	end)
	return self
end

function RateLimit.allow(self: RateLimit, player: Player): boolean
	local now = os.clock()
	local bucket = self._buckets[player]
	if not bucket then
		bucket = { tokens = self._burst, at = now }
		self._buckets[player] = bucket
	end
	bucket.tokens = math.min(self._burst, bucket.tokens + (now - bucket.at) * self._rate)
	bucket.at = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

return RateLimit
