# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Tools.Ozone.Server.GetConfig do
  @moduledoc """
  Generated query module for main

  **Description**: Get details about ozone's server configuration.
  """

  @type output :: %{
          appview: ProtoRune.Tools.Ozone.Server.GetConfig.ServiceConfig.t(),
          blob_divert: ProtoRune.Tools.Ozone.Server.GetConfig.ServiceConfig.t(),
          chat: ProtoRune.Tools.Ozone.Server.GetConfig.ServiceConfig.t(),
          pds: ProtoRune.Tools.Ozone.Server.GetConfig.ServiceConfig.t(),
          viewer: ProtoRune.Tools.Ozone.Server.GetConfig.ViewerConfig.t()
        }
end
