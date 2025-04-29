defmodule Lexicon.Com.Atproto.Moderation.Defs do
  @moduledoc """
  Definitions for moderation-related data structures.

  NSID: com.atproto.moderation.defs
  """

  # Reason types
  @reason_spam "com.atproto.moderation.defs#reasonSpam"
  @reason_violation "com.atproto.moderation.defs#reasonViolation"
  @reason_misleading "com.atproto.moderation.defs#reasonMisleading"
  @reason_sexual "com.atproto.moderation.defs#reasonSexual"
  @reason_rude "com.atproto.moderation.defs#reasonRude"
  @reason_other "com.atproto.moderation.defs#reasonOther"
  @reason_appeal "com.atproto.moderation.defs#reasonAppeal"

  # Subject types
  @subject_type_account "account"
  @subject_type_record "record"
  @subject_type_chat "chat"

  # Export reason type constants
  def reason_spam, do: @reason_spam
  def reason_violation, do: @reason_violation
  def reason_misleading, do: @reason_misleading
  def reason_sexual, do: @reason_sexual
  def reason_rude, do: @reason_rude
  def reason_other, do: @reason_other
  def reason_appeal, do: @reason_appeal

  @doc """
  Checks if a reason type is valid.
  """
  def valid_reason_type?(val) do
    val in [
      @reason_spam,
      @reason_violation,
      @reason_misleading,
      @reason_sexual,
      @reason_rude,
      @reason_other,
      @reason_appeal
    ]
  end

  # Export subject type constants
  def subject_type_account, do: @subject_type_account
  def subject_type_record, do: @subject_type_record
  def subject_type_chat, do: @subject_type_chat

  @doc """
  Checks if a subject type is valid.
  """
  def valid_subject_type?(val) do
    val in [@subject_type_account, @subject_type_record, @subject_type_chat]
  end
end
