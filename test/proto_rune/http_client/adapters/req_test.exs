defmodule ProtoRune.HTTPClient.Adapters.ReqTest do
  use ExUnit.Case, async: true

  alias ProtoRune.HTTPClient.Adapters.Req, as: ReqAdapter

  test "timeout: bounds both the connect and the receive phases" do
    test_pid = self()

    # The deprecated `:finch_request` hook is the only way to observe the
    # merged request options without making a network request: Req 0.7
    # rejects step options passed through `Req.request/2`. The hook receives
    # the fully built Req.Request and the Finch options; we halt with a
    # canned response.
    finch_request = fn request, _finch_request, _finch_name, _finch_options ->
      send(test_pid, {:request_options, request.options})
      {request, %Req.Response{status: 200, headers: [], body: ""}}
    end

    assert {:ok, %{status: 200}} =
             ReqAdapter.request(:get, "https://example.com", timeout: 10_000, finch_request: finch_request)

    assert_received {:request_options, options}
    assert options[:connect_options] == [timeout: 10_000]
    assert options[:receive_timeout] == 10_000
  end
end
