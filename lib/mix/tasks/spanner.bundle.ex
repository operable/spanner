defmodule Mix.Tasks.Spanner.Bundle do
  use Mix.Task
  alias Spanner.Bundle.Manifest

  @shortdoc "Generate a Spanner command bundle from this project"
  @moduledoc """
  #{@shortdoc}

  A bundle is a ZIP file with the extension `#{Spanner.bundle_extension()}`
  that contains the compiled Elixir BEAM files for the commands and
  services, as well as metadata files describing the bundle.

  """

  @work_dir_name "bundle_working_directory"
  def run(_args) do

    # Ensure there are BEAM files to collect!
    Mix.Task.run("compile")

    project = Keyword.fetch!(Mix.Project.config, :app) |> Atom.to_string
    project_root = Path.join([Mix.Project.build_path, "lib", project])

    # Target the BEAM files we need to bundle up
    ebin_dir = Path.join(project_root, "ebin")

    # Create a working directory in which to assemble the bundle prior
    # to zipping it up
    work_dir = create_working_directory(project)

    # Copy the BEAM files to the working directory
    dest_ebin_dir = Path.join(work_dir, "ebin")

    copy_beams(ebin_dir, dest_ebin_dir)
    for dep <- deps_to_package do
      dep_ebins = Path.join([Mix.Project.build_path, "lib", Atom.to_string(dep), "ebin"])
      copy_beams(dep_ebins, dest_ebin_dir)
    end
    templates_dir = Path.join(["lib", project, "templates"])

    if File.exists?(templates_dir) do
      # Copy templates to the working directory
      dest_templates_dir = Path.join(work_dir, "templates")
      File.cp_r!(templates_dir, dest_templates_dir)
    end

    # Create a configuration file
    generate_config(project, work_dir)

    # Once all files are in the working directory, generate a manifest
    Manifest.write_manifest(work_dir)

    # Generate the compressed bundle
    zip_cwd = Path.expand(Path.join(work_dir, ".."))
    {:ok, filename} = :zip.create(bundle_name(project),
                                  [String.to_char_list(project)],
                                  [{:cwd, zip_cwd},
                                   :verbose])
    IO.puts "Generated bundle #{filename}"
  end

  defp bundle_name(project),
    do: "#{project}#{Spanner.bundle_extension()}"

  # Generate the directory structure for the bundle, rooted in the
  # system's temporary directory. We remove any previously-existing
  # working directory to ensure a "clean slate".
  #
  # Returns the path to the working directory.
  defp create_working_directory(project) do
    work_dir = Path.join([System.tmp_dir!, @work_dir_name, project])

    File.rm_rf!(work_dir)
    File.mkdir_p!(work_dir)
    File.mkdir_p!(Path.join(work_dir, "ebin"))

    work_dir
  end

  defp copy_beams(src_ebin_dir, dest_ebin_dir) do
    beams = Path.wildcard("#{Path.absname(src_ebin_dir)}/*.beam")
    for beam <- beams do
      dest = Path.join(dest_ebin_dir, Path.basename(beam))
      :ok = File.cp(beam, dest)
    end
  end

  defp generate_config(name, work_dir) do
    if File.exists?("config.json") do
      # Until we can automatically annotate services, we'll just rely
      # on a file existing; you'll need to manage it yourself
      #
      # You can make a bundle, let it create a config.json for you,
      # and then hand-edit that.
      File.cp!("config.json", Path.join(work_dir, "config.json"))
    else
      modules = beams_to_modules(work_dir)

      json = Spanner.Bundle.Config.gen_config(name, modules, work_dir)
      |> Poison.encode_to_iodata!

      path = Path.join(work_dir, "config.json")
      File.write!(path, json)
    end
  end

  # Grab the module names from all the beam files in a working
  # directory.
  defp beams_to_modules(work_dir) do
    Path.wildcard("#{work_dir}/ebin/*.beam")
    |> Enum.map(&String.to_char_list/1)
    |> Enum.map(&Keyword.fetch!(:beam_lib.info(&1), :module))
  end

  @doc """

  Return a list of atoms naming all the dependencies that need to be
  packaged up in this bundle.

  We currently do not include the `spanner` dependency (or anything that
  is an exclusive dependency of it), as that code will already be on
  the Spanner server the bundle gets installed on.

  """
  def deps_to_package do
    all_deps = Mix.Dep.loaded(env: Mix.env)

    all_deps
    |> Enum.filter(&top_level?/1)
    |> Enum.reject(dep_named(:spanner))
    |> find_keepers(all_deps)
    |> Enum.map(&dep_name/1)
  end

  @doc """
  Return a boolean indicating whether the given dependency is a
  top-level dependency (i.e., direct dependency of the project, and
  not a dependency-of-a-dependency) or not.
  """
  def top_level?(%Mix.Dep{top_level: top_level}),
    do: top_level

  @doc """
  Returns a function that can be used to indicate whether a dependency
  is for a specific named application. Useful for filtering
  collections.
  """
  def dep_named(app),
    do: fn(dep) -> dep_name(dep) == app end

  def dep_name(%Mix.Dep{app: name}),
    do: name

  @doc """
  Given a list of target dependencies (i.e., dependencies we'd like to
  keep), compile a list of those dependencies as well as any of their
  dependencies (and _their_ dependencies, etc.)

  We must pass in a global list of all dependencies for a project
  because of how Mix represents dependencies. Though each `Mix.Dep`
  struct has a `deps` key, dependencies of these dependencies will not
  be present; however, that dependency's entry in the global
  dependency list _will_ contain its dependencies.  Thus, for each
  dependency we encounter, we first look it up in the global
  dependency list to ensure we capture all the dependencies in our
  final list of "keepers".
  """
  def find_keepers(target_deps, all_deps),
    do: find_keepers(target_deps, all_deps, [])

  def find_keepers([], _all_deps, keep),
    do: keep
  def find_keepers([current_dep|rest], all_deps, keep) do
    # Find the complete dependency information in the global list
    %Mix.Dep{deps: deps} = complete_dep = resolve_complete_dep_info(current_dep, all_deps)
    case Enum.member?(keep, complete_dep) do
      true ->
        # We've already encountered this dependency before (e.g., two
        # dependencies share a common dependency); move along
        find_keepers(rest, all_deps, keep)
      false ->
        # We've never seen this dependency before; let's process it!
        case deps do
          [] ->
            # There are no dependencies; add the complete current
            # dependency to the list of keepers and continue.
            find_keepers(rest, all_deps, [complete_dep | keep])
          _ ->
            # The current dependency has dependencies of its own. Recur on
            # each of those, accumulating more dependencies to keep.
            updated_keep = find_keepers(deps, all_deps, keep)
            # Add the complete current dependency to the updated list of
            # keepers and continue.
            find_keepers(rest, all_deps, [complete_dep | updated_keep])
        end
    end
  end

  @doc """
  Resolve complete dependency information from global dependency list.
  """
  def resolve_complete_dep_info(%Mix.Dep{app: name}, all_deps),
    do: Enum.find(all_deps, dep_named(name))

end
