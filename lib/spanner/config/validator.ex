defmodule Spanner.Config.Validator do

  @moduledoc """
  Validates bundle configs based on a built in schema.
  """

  @doc """
  Accepts a config map and validates.
  """
  def validate(config) do
    # Note: The call to resolve can be expensive. Reading the documentation
    # suggests using a genserver and keeping the resolved schema in state.
    # Since we are just resolving once during install I think it will be ok
    # for now. But we may want to revisit.
    ExJsonSchema.Schema.resolve(bundle_config_schema)
    |> ExJsonSchema.Validator.validate(config)
  end

  # Note: This is the schema for bundle configs. For right now it's just
  # hardcoded, but we could load it from a file or the db in the future.
  # It might be useful to load from an external source if/when the validator
  # becomes more generalized.
  defp bundle_config_schema() do
    %{"$schema" => "http://json-schema.org/draft-04/schema#",
      "title" => "Bundle Config",
      "description" => "A config object for a bundle to be installed",
      "type" => "object",
      "required" => ["bundle", "commands"],
      "properties" => %{
        "bundle" => %{
          "type" => "object",
          "required" => ["name"],
          "properties" => %{
            "name" => %{
              "type" => "string",
              "description" => "The name of the bundle"
            },
            "install" => %{
              "type" => "string",
              "description" => "The path to the script to install the bundle"
            },
            "uninstall" => %{
              "type" => "string",
              "description" => "The path to the script to uninstall the bundle"
            }
          }
        },
        "templates" => %{
          "type" => "array",
          "items" => %{
            "$ref" => "#/definitions/template"
          }
        },
        "permissions" => %{
          "type" => "array",
          "items" => %{
            "type" => "string"
          }
        },
        "rules" => %{
          "type" => "array",
          "items" => %{
            "type" => "string"
          }
        },
        "commands" => %{
          "type" => "array",
          "items" => %{
            "$ref" => "#/definitions/command"
          },
          "minItems" => 1,
          "uniqueItems" => true
        }
      },
      "definitions" => %{
        "command" => %{
          "type" => "object",
          "required" => ["name", "executable", "version", "enforcing"],
          "properties" => %{
            "name" => %{"type" => "string"},
            "version" => %{"type" => "string"},
            "executable" => %{"type" => "string"},
            "enforcing" => %{"type" => "boolean"},
            "calling_convention" => %{
              "enum" => ["bound", "all"]
            },
            "env_vars" => %{"type" => "object"},
            "documentation" => %{"type" => "string"},
            "options" => %{
              "type" => "array",
              "items" => %{
                "type" => "object",
                "properties" => %{
                  "type" => %{
                    "enum" => ["string", "int", "bool"]
                  },
                  "required" => %{"type" => "boolean"},
                  "name" => %{"type" => "string"}
                }
              }
            }
          }
        },
        "template" => %{
          "type" => "object",
          "required" => ["name", "adapter", "path"],
          "properties" => %{
            "name" => %{"type" => "string"},
            "adapter" => %{
              "enum" => ["slack", "hipchat"]
            },
            "path" => %{"type" => "string"}
          }
        }
      }
     }
  end
end
