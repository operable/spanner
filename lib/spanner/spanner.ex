defmodule Spanner do
  @bundle_extension ".cog"
  @foreign_bundle_extension ".json"

  def bundle_extension(),
    do: @bundle_extension

  def foreign_bundle_extension(),
    do: @foreign_bundle_extension
end
