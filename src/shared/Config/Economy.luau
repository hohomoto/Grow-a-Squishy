--!strict
-- Global tuning knobs that are not tied to a single squishy.

return {
	StartingCoins = 20,
	StartingSeeds = { mochi_bao = 3 } :: { [string]: number },

	-- Max harvested squishies a player can carry before they must sell.
	BackpackCapacity = 150,

	-- Shop restocks every N seconds. Stock is identical on every server for a
	-- given window, so "the Celestial is in stock!" is a shared moment.
	RestockInterval = 300,

	-- Harvest size roll: size = MinSize + (MaxSize - MinSize) * u^SizeSkew.
	-- A higher skew makes big harvests rarer. Value scales with size^2.
	MinSize = 0.8,
	MaxSize = 2.0,
	SizeSkew = 3,

	-- World layout. Set the place's Max Players to PlotCount in Game Settings.
	-- Each plot has two garden beds of PlotColumns x PlotBedRows tiles with a
	-- walkway between them; tiles are numbered row by row across both beds.
	PlotCount = 6,
	PlotColumns = 8,
	PlotBedRows = 4,
	PlotRows = 8,
}
