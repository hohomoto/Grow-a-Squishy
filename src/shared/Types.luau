--!strict
-- Shapes of saved player data and of the state the server sends to clients.

-- A squishy growing on a plot tile. Times are Unix seconds (os.time()).
export type Plant = {
	id: string,
	startedAt: number,
	readyAt: number,
	-- Mutation ids (Config/Mutations). Nil when there are none.
	mutations: { string }?,
}

-- A harvested squishy waiting to be sold.
export type Harvest = {
	id: string,
	size: number,
	mutations: { string }?,
}

export type PlayerData = {
	version: number,
	coins: number,
	seeds: { [string]: number },
	backpack: { Harvest },
	-- Keyed by tile index as a string; DataStores need string keys for sparse tables.
	plants: { [string]: Plant },
	shop: {
		window: number,
		bought: { [string]: number },
	},
	stats: {
		harvested: number,
		earned: number,
	},
	-- Session lock written by DataService; see DataService for details.
	lock: { jobId: string, time: number }?,
}

-- What the client sees. Sent whole on every change; it is small.
export type ClientState = {
	coins: number,
	seeds: { [string]: number },
	backpack: { Harvest },
	backpackCapacity: number,
	shop: {
		restockAt: number,
		-- Units this player can still buy this window, per squishy id in stock.
		remaining: { [string]: number },
	},
}

return {}
