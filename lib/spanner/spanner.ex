defmodule Spanner do
  @bundle_extension ".cog"
  @skinny_bundle_extension ".yaml"

  @doc "Getter for the bundle extension"
  def bundle_extension(),
    do: @bundle_extension

  @doc """
  Getter for the skinny bundle extension. Technically skinny bundles can use any
  extension in #{Spanner.Config.config_extensions}, but internally it will always
  be converted to this extension.
  """
  def skinny_bundle_extension(),
    do: @skinny_bundle_extension

  @doc "Getter for skinny bundle extensions"
  def skinny_bundle_extensions(),
    do: Spanner.Config.config_extensions()

  @doc """
  Returns the type of bundle ':simple' or ':standard' based on the extension
  """
  def bundle_type(bundle_path) do
    if String.ends_with?(bundle_path, skinny_bundle_extensions) do
      :simple
    else
      :standard
    end
  end

  @doc "Whether or not the path refers to a skinny bundle"
  def skinny_bundle?(path) do
    case bundle_type(path) do
      :simple -> true
      :standard -> false
    end
  end

  @doc "Whether or not the path refers to a standard bundle"
  def standard_bundle?(path),
    do: String.ends_with?(path, @bundle_extension)

end
