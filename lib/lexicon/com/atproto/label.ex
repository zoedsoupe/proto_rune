defmodule Lexicon.Com.Atproto.Label do
  @moduledoc """
  Definitions for label-related data structures.

  NSID: com.atproto.label
  """

  # Label values
  @label_value_hide "!hide"
  @label_value_no_promote "!no-promote"
  @label_value_warn "!warn"
  @label_value_no_unauthenticated "!no-unauthenticated"
  @label_value_dmca_violation "dmca-violation"
  @label_value_doxxing "doxxing"
  @label_value_porn "porn"
  @label_value_sexual "sexual"
  @label_value_nudity "nudity"
  @label_value_nsfl "nsfl"
  @label_value_gore "gore"

  # Severity values
  @severity_inform "inform"
  @severity_alert "alert"
  @severity_none "none"

  # Blur values
  @blur_content "content"
  @blur_media "media"
  @blur_none "none"

  # Default setting values
  @default_setting_ignore "ignore"
  @default_setting_warn "warn"
  @default_setting_hide "hide"

  # Export label value constants
  def label_value_hide, do: @label_value_hide
  def label_value_no_promote, do: @label_value_no_promote
  def label_value_warn, do: @label_value_warn
  def label_value_no_unauthenticated, do: @label_value_no_unauthenticated
  def label_value_dmca_violation, do: @label_value_dmca_violation
  def label_value_doxxing, do: @label_value_doxxing
  def label_value_porn, do: @label_value_porn
  def label_value_sexual, do: @label_value_sexual
  def label_value_nudity, do: @label_value_nudity
  def label_value_nsfl, do: @label_value_nsfl
  def label_value_gore, do: @label_value_gore

  @doc """
  Checks if a label value is valid.
  """
  def valid_label_value?(val) do
    val in [
      @label_value_hide,
      @label_value_no_promote,
      @label_value_warn,
      @label_value_no_unauthenticated,
      @label_value_dmca_violation,
      @label_value_doxxing,
      @label_value_porn,
      @label_value_sexual,
      @label_value_nudity,
      @label_value_nsfl,
      @label_value_gore
    ]
  end

  # Export severity constants
  def severity_inform, do: @severity_inform
  def severity_alert, do: @severity_alert
  def severity_none, do: @severity_none

  @doc """
  Checks if a severity value is valid.
  """
  def valid_severity?(val) do
    val in [@severity_inform, @severity_alert, @severity_none]
  end

  # Export blur constants
  def blur_content, do: @blur_content
  def blur_media, do: @blur_media
  def blur_none, do: @blur_none

  @doc """
  Checks if a blur value is valid.
  """
  def valid_blur?(val) do
    val in [@blur_content, @blur_media, @blur_none]
  end

  # Export default setting constants
  def default_setting_ignore, do: @default_setting_ignore
  def default_setting_warn, do: @default_setting_warn
  def default_setting_hide, do: @default_setting_hide

  @doc """
  Checks if a default setting value is valid.
  """
  def valid_default_setting?(val) do
    val in [@default_setting_ignore, @default_setting_warn, @default_setting_hide]
  end
end
