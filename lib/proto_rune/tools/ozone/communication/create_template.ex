# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Tools.Ozone.Communication.CreateTemplate do
  @moduledoc """
  Generated procedure module for main

  **Description**: Administrative action to create a new, re-usable communication (email for now) template.
  """

  @type output :: ProtoRune.Tools.Ozone.Communication.Defs.TemplateView.t()
  @type input :: %{
          content_markdown: String.t(),
          created_by: String.t(),
          lang: String.t(),
          name: String.t(),
          subject: String.t()
        }
  @type error ::
          ProtoRune.Tools.Ozone.Communication.CreateTemplate.MainErrorDuplicateTemplateName.t()
end
