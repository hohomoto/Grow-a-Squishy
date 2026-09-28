--!strict
-- Minimal signal for module-to-module events.

export type Connection = { Disconnect: (self: Connection) -> () }

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	_handlers: { (T...) -> () },
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	return setmetatable({ _handlers = {} }, Signal) :: any
end

function Signal.Connect<T...>(self: Signal<T...>, fn: (T...) -> ()): Connection
	table.insert(self._handlers, fn)
	local handlers = self._handlers
	return {
		Disconnect = function()
			local index = table.find(handlers, fn)
			if index then
				table.remove(handlers, index)
			end
		end,
	} :: any
end

-- Handlers run in connection order. Each runs in its own thread so one
-- erroring or yielding handler cannot block the rest.
function Signal.Fire<T...>(self: Signal<T...>, ...: T...)
	for _, fn in table.clone(self._handlers) do
		task.spawn(fn, ...)
	end
end

return Signal
