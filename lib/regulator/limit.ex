defprotocol Regulator.Limit do
  def update(rtt, inflight, was_dropped)
end
