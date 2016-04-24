defmodule Awsex.Client do
  alias Awsex.Try
  @moduledoc """
  Access and connections details needed when making requests to AWS services.
  """

  defmodule CredentialsError do
    defexception [:message]
  end

  defstruct access_key_id: nil,
            secret_access_key: nil,
            region: nil,
            endpoint: nil,
            service: nil,
            proto: "https",
            port: "443"

  def load_credentials!(creds_file \\ "~/.aws/credentials") do
    case Try.first!(
      [
        {__MODULE__, :load_from_file!, [Path.expand(creds_file)]},
        {__MODULE__, :load_from_env!, []}
      ]
    ) do
      {:ok, res} -> res
      {:error, errs} ->
        raise(CredentialsError,
          message: "Could not load credentials from any source:\n#{Enum.map_join(errs, "\n", fn(err) -> Exception.message(err) end)}")
    end
  end

  def load_from_file!(creds_file) do
    kvs =
      creds_file
      |> File.read!
      |> String.split("\n")
      |> Enum.drop(1)
      |> Enum.map(fn(str) -> String.split(str, ~r/ *= */, trim: true) |> List.to_tuple end)
      |> Enum.filter(fn(tuple) -> tuple != {} end)
      |> Enum.into(%{})

    %Awsex.Client{
      access_key_id: Map.fetch!(kvs, "aws_access_key_id"),
      secret_access_key: Map.fetch!(kvs, "aws_secret_access_key"),
      region: Map.fetch!(kvs, "region")
    }
  end

  def load_from_env! do
    access_key_id = System.get_env("AWS_ACCESS_KEY_ID")
    secret_access_key = System.get_env("AWS_SECRET_ACCESS_KEY")
    region = System.get_env("AWS_REGION")

    any_nils? = Enum.any?(
      [access_key_id, secret_access_key, region],
      fn(x) -> is_nil(x) end
    )
    if any_nils? do
      raise RuntimeError, message: "Could not load credentials from environment"
    end

    %Awsex.Client{
      access_key_id: access_key_id,
      secret_access_key: secret_access_key,
      region: region
    }
  end
end
