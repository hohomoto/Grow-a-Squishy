-- Unit tests for the pure shared modules (math, stock rolls, formatting,
-- catalog sanity). Run from the repo root with:  lune run tests/run.luau
--
-- Roblox modules use `require(script.Parent.X)`. This runner emulates that
-- with a fake `script` object that maps instance paths onto src/shared files.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local SHARED_ROOT = "src/shared"

local cache: { [string]: any } = {}
local makeNode: (path: string) -> any
local requireNode: (node: any) -> any

local function parentPath(path: string): string
	return string.match(path, "^(.*)/[^/]+$") or ""
end

function makeNode(path: string): any
	return setmetatable({ __path = path }, {
		__index = function(self, key)
			if key == "Parent" then
				return makeNode(parentPath(self.__path))
			end
			return makeNode(self.__path .. "/" .. key)
		end,
	})
end

function requireNode(node: any): any
	local path = rawget(node, "__path")
	if cache[path] ~= nil then
		return cache[path]
	end
	local file = path .. ".luau"
	if not fs.isFile(file) then
		file = path .. "/init.luau"
	end
	assert(fs.isFile(file), "module not found: " .. path)
	local chunk = luau.load(fs.readFile(file), {
		debugName = file,
		environment = {
			script = makeNode(path),
			require = function(target: any)
				if type(target) == "string" then
					return require(target)
				end
				return requireNode(target)
			end,
		},
	})
	local result = chunk()
	cache[path] = result
	return result
end

local function load(name: string): any
	return requireNode(makeNode(SHARED_ROOT .. "/" .. name))
end

-- Tiny test framework ------------------------------------------------------

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print(`FAIL  {name}\n      {err}`)
	end
end

local function eq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function near(actual: number, expected: number, tolerance: number, label: string?)
	if math.abs(actual - expected) > tolerance then
		error(`{label or "value"}: expected {expected} ± {tolerance}, got {actual}`, 2)
	end
end

-- Modules under test ------------------------------------------------------

local Economy = load("Config/Economy")
local Format = load("Format")
local Growth = load("Growth")
local Rarities = load("Config/Rarities")
local Rng = load("Rng")
local ShopStock = load("ShopStock")
local Squishies = load("Config/Squishies")

-- Rng ---------------------------------------------------------------------

test("Rng is deterministic per seed", function()
	local a, b = Rng.new(12345), Rng.new(12345)
	for _ = 1, 100 do
		eq(a:next(), b:next())
	end
end)

test("Rng differs across consecutive seeds", function()
	local same = 0
	for seed = 1, 200 do
		if Rng.new(seed):next() == Rng.new(seed + 1):next() then
			same += 1
		end
	end
	eq(same, 0, "identical first rolls")
end)

test("Rng.next stays in [0, 1) and is roughly uniform", function()
	local rng = Rng.new(7)
	local buckets = table.create(10, 0)
	local n = 100000
	for _ = 1, n do
		local x = rng:next()
		assert(x >= 0 and x < 1, "out of range: " .. x)
		local i = math.floor(x * 10) + 1
		buckets[i] += 1
	end
	for i, count in buckets do
		near(count / n, 0.1, 0.01, "bucket " .. i)
	end
end)

test("Rng.range covers both ends inclusively", function()
	local rng = Rng.new(99)
	local seen = {}
	for _ = 1, 2000 do
		local v = rng:range(3, 6)
		assert(v >= 3 and v <= 6 and v == math.floor(v), "bad value " .. v)
		seen[v] = true
	end
	for v = 3, 6 do
		assert(seen[v], "never rolled " .. v)
	end
end)

test("Rng handles seed 0 and huge seeds", function()
	local x = Rng.new(0):next()
	assert(x >= 0 and x < 1)
	local y = Rng.new(2 ^ 40 + 17):next()
	assert(y >= 0 and y < 1)
end)

-- ShopStock ---------------------------------------------------------------

test("ShopStock windows line up with the restock interval", function()
	local interval = Economy.RestockInterval
	eq(ShopStock.windowAt(0), 0)
	eq(ShopStock.windowAt(interval - 1), 0)
	eq(ShopStock.windowAt(interval), 1)
	eq(ShopStock.nextRestockAt(0), interval)
	local window = ShopStock.windowAt(1_790_000_123)
	assert(ShopStock.nextRestockAt(window) > 1_790_000_123)
	assert(ShopStock.nextRestockAt(window) - interval <= 1_790_000_123)
end)

test("ShopStock is identical for the same window", function()
	local a, b = ShopStock.roll(5_966_000), ShopStock.roll(5_966_000)
	for id, amount in a do
		eq(b[id], amount, id)
	end
	for id in b do
		assert(a[id] ~= nil, id)
	end
end)

test("ShopStock amounts respect each item's range; guaranteed items always appear", function()
	for window = 5_966_000, 5_966_500 do
		local stock = ShopStock.roll(window)
		for _, def in Squishies.List do
			local amount = stock[def.id]
			if def.stockChance >= 1 then
				assert(amount ~= nil, def.id .. " missing in window " .. window)
			end
			if amount then
				assert(amount >= def.stock[1] and amount <= def.stock[2], def.id .. " amount " .. amount)
			end
		end
	end
end)

test("ShopStock appearance rates match stockChance", function()
	local counts = {}
	local n = 20000
	for window = 1, n do
		for id in ShopStock.roll(window) do
			counts[id] = (counts[id] or 0) + 1
		end
	end
	for _, def in Squishies.List do
		local rate = (counts[def.id] or 0) / n
		-- 4 standard deviations of a binomial proportion, plus a small floor.
		local tolerance = 4 * math.sqrt(def.stockChance * (1 - def.stockChance) / n) + 0.002
		near(rate, def.stockChance, tolerance, def.id .. " appearance rate")
	end
end)

-- Growth ------------------------------------------------------------------

test("Growth.progress clamps and interpolates", function()
	eq(Growth.progress(100, 200, 50), 0)
	eq(Growth.progress(100, 200, 150), 0.5)
	eq(Growth.progress(100, 200, 500), 1)
	eq(Growth.progress(100, 100, 100), 1, "zero-length growth")
end)

test("Growth.isReady flips exactly at readyAt", function()
	eq(Growth.isReady(200, 199), false)
	eq(Growth.isReady(200, 200), true)
end)

test("Growth.sizeFromRoll spans MinSize..MaxSize and skews small", function()
	eq(Growth.sizeFromRoll(0), Economy.MinSize)
	near(Growth.sizeFromRoll(0.9999), Economy.MaxSize, 0.01)
	local big = 0
	local n = 10000
	for i = 0, n - 1 do
		local size = Growth.sizeFromRoll(i / n)
		assert(size >= Economy.MinSize and size <= Economy.MaxSize, "size " .. size)
		if size >= 1.5 then
			big += 1
		end
	end
	-- (1.5-0.8)/1.2 = 0.583..., so P(size >= 1.5) = 1 - 0.583^(1/3) ≈ 16.5%
	near(big / n, 0.165, 0.01, "share of big harvests")
end)

test("Growth.value scales with size squared and never pays zero", function()
	eq(Growth.value(100, 1), 100)
	eq(Growth.value(100, 2), 400)
	eq(Growth.value(18, 0.8), 12)
	eq(Growth.value(1, 0.8), 1)
end)

-- Format ------------------------------------------------------------------

test("Format.short", function()
	eq(Format.short(0), "0")
	eq(Format.short(950), "950")
	eq(Format.short(1000), "1K")
	eq(Format.short(1234), "1.23K")
	eq(Format.short(1500), "1.5K")
	eq(Format.short(15300000), "15.3M")
	eq(Format.short(300000), "300K")
	eq(Format.short(2.5e9), "2.5B")
	eq(Format.short(999999), "1M", "rounds up into the next suffix")
end)

test("Format.commas", function()
	eq(Format.commas(0), "0")
	eq(Format.commas(999), "999")
	eq(Format.commas(1000), "1,000")
	eq(Format.commas(1234567), "1,234,567")
	eq(Format.commas(-45000), "-45,000")
end)

test("Format.duration", function()
	eq(Format.duration(0), "0:00")
	eq(Format.duration(5), "0:05")
	eq(Format.duration(75), "1:15")
	eq(Format.duration(59.2), "1:00", "rounds up partial seconds")
	eq(Format.duration(3725), "1:02:05")
	eq(Format.duration(-3), "0:00")
end)

-- Catalog sanity ----------------------------------------------------------

local VALID_SHAPES = { Ball = true, Block = true, Cylinder = true }
local VALID_MATERIALS = { SmoothPlastic = true, Glass = true, Neon = true, Plastic = true, ForceField = true }

test("Every squishy is well-formed", function()
	for _, def in Squishies.List do
		assert(string.match(def.id, "^[a-z_]+$"), "id must be lowercase snake_case: " .. def.id)
		assert(Rarities.Info[def.rarity], def.id .. " has unknown rarity " .. def.rarity)
		assert(def.seedPrice > 0 and def.growTime > 0 and def.baseValue > 0, def.id .. " has non-positive numbers")
		assert(def.stockChance > 0 and def.stockChance <= 1, def.id .. " stockChance out of range")
		assert(def.stock[1] >= 1 and def.stock[1] <= def.stock[2], def.id .. " bad stock range")
		assert(VALID_SHAPES[def.shape], def.id .. " bad shape")
		assert(VALID_MATERIALS[def.material], def.id .. " material not in the tested list")
		assert(#def.color == 3, def.id .. " color needs 3 channels")
		eq(Squishies.ById[def.id], def, "ById lookup")
	end
	for id, amount in Economy.StartingSeeds do
		assert(Squishies.ById[id], "starting seed is not in the catalog: " .. id)
		assert(amount > 0)
	end
end)

test("Catalog is ordered by rarity and price", function()
	local previous = nil
	for _, def in Squishies.List do
		if previous then
			assert(
				Rarities.Info[def.rarity].rank >= Rarities.Info[previous.rarity].rank,
				def.id .. " is listed before a lower rarity"
			)
			assert(def.seedPrice > previous.seedPrice, def.id .. " should cost more than " .. previous.id)
		end
		previous = def
	end
end)

test("Every squishy turns a profit at average size", function()
	-- Expected value multiplier E[size^2] under the skewed roll.
	local n, total = 20000, 0
	for i = 0, n - 1 do
		local size = Growth.sizeFromRoll((i + 0.5) / n)
		total += size * size
	end
	local meanSquare = total / n
	for _, def in Squishies.List do
		local perHarvest = def.baseValue * meanSquare
		-- Single-harvest items must profit in one harvest; regrowing ones
		-- must pay back within 30 harvests.
		local harvestsToPayBack = def.seedPrice / perHarvest
		if def.regrowTime then
			assert(harvestsToPayBack <= 30, `{def.id} needs {harvestsToPayBack} harvests to pay back`)
		else
			assert(harvestsToPayBack < 1, `{def.id} loses money per harvest`)
		end
	end
end)

test("A new player can afford their first shop purchase after one harvest", function()
	local startDef = Squishies.ById.mochi
	local worstFirstSale = Growth.value(startDef.baseValue, Economy.MinSize)
	assert(Economy.StartingCoins + worstFirstSale >= startDef.seedPrice)
end)

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
