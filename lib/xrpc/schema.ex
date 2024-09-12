defprotocol XRPC.Schema do
  def parse(source, response)
end

# defimpl XRPC.Schema, for: XRPC.Query do
#   def parse(%XRPC.Query{schema: schema}, response) do
#     schema.parse(response)
#   end
# end
