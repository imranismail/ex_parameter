# Parameters

[![Build Status](https://travis-ci.com/imranismail/parameters.ex.svg?branch=master)](https://travis-ci.com/imranismail/parameters.ex)

Expressive parameter validation riding on the shoulder of a giant

## Installation

```elixir
def deps do
  [
    {:parameters, "~> 2.0"}
  ]
end
```

## Goals

- [X] Expressive and declarative but with the ability to extend via custom validation function
- [ ] Support to express Ecto's built-in validators
- [ ] Auto-generated documentation in the form of `@doc` and [Open API Specification](https://swagger.io/specification/)

## Usage

Parameters behaves like the `@doc` attribute and basically annotates the function with information about the parameters.

At the moment there are 4 macros for defining parameters. These are backed by Ecto's `field/3`, `embeds_one/3` and `embeds_many/3`.

You can nest however deep you want and Parameters will take care of defining the Ecto schemas

```elixir
params do
  optional :name, :string # => equivalent of `field :name, :string` and `cast`
  
  requires :username, :string # => equivalent of `field :username, :string` and `validate_required`

  optional :book, :map do # => equivalent of `embeds_one` and `cast_embed`
    requires :isbn, :string
  end

  requires :books, :array do # => equivalent of `embeds_many` and `cast_embed(required: true)`
    requires :isbn, :string
  end
end
```

Once the schema is declared, you can use `Parameters.params_for(conn | changeset)` or `Parameters.params_for(module_defined_in, function_defined_at, params)` to validate any raw parameters.

```elixir
{:ok, sanitized_params} | {:error, changeset} = Parameters.params_for(conn)
```

Or if you'd like to extend the changeset with additional validations Parameters also exposes a function `Parameters.changeset_for(conn)` and `Parameters.changeset_for(module_defined_in, function_defined_at, params)` which allows you to do so like this:

```elixir
{:ok, params} | {:error, changeset} =
  conn
  |> Parameters.changeset_for() # => %Ecto.Changeset{}
  |> Changeset.validate_change(&custom_validator_fn/2) # => %Ecto.Changeset{} 
  |> Parameters.params_for(params) # => Validate and return sanitized params
```

### Full Example

```elixir
defmodule MyApp.PostController do
  use MyApp, :web
  use Parameters

  params do
    # Schema fields + Changeset.validate_required
    optional :limit, :integer, default: 10
    optional :page, :integer, default: 1
    requires :query, :string

    # Schema embeds_many
    requires :profiles, :array do
      requires :access_key, :string
      requires :secret_key, :string
    end

    # Schema embeds_one
    requires :profile, :map do
      requires :access_key, :string
      requires :secret_key, :string
    end
  end

  def index(conn, _params) do
    with {:ok, params} <- Parameters.params_for(conn) do
      json(conn, params)
    else
      {:error, %Ecto.Changeset{}} ->
        # handle error
    end
  end
end
```

### Using A Sanitizer Plug

```elixir
defmodule Parameters.Sanitizer do
  use Plug.Builder

  alias Ecto.Changeset

  plug :sanitize

  defp sanitize(conn, _opts) do
    case Parameters.params_for(conn) do
      {:ok, params} ->
        Map.put(conn, :params, params)
      {:error, changeset} ->
        errors = errors_from_changeset(changeset)

        conn
        |> put_resp_content_type("application/json")
        |> resp(:bad_request, Jason.encode!(errors))
        |> send_resp()
        |> halt()
    end
  end

  defp errors_from_changeset(changeset) do
    Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

defmodule MyApp.PostController do
  use MyApp, :web
  use Parameters
  
  plug Parameters.Sanitizer

  params do
    # Schema fields + Changeset.validate_required
    optional :limit, :integer, default: 10
    optional :page, :integer, default: 1
    requires :query, :string

    # Schema embeds_many
    requires :profiles, :array do
      requires :access_key, :string
      requires :secret_key, :string
    end

    # Schema embeds_one
    requires :profile, :map do
      requires :access_key, :string
      requires :secret_key, :string
    end
  end

  def index(conn, _params) do
    # params are sanitized by plug
    # errors are reported to user automatically
    json(conn, params)
  end
end
```

