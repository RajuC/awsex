defmodule Awsex.HttpMacros do
  require HTTPoison
  require Poison

  @api_spec File.read!("service-2.json") |> Poison.decode!

  defmacro __using__(_) do
    endpoint_prefix = get_endpoint_prefix(@api_spec)
    aws_host = "https://#{endpoint_prefix}.us-east-1.amazonaws.com"

    for operation_name <- operation_names(@api_spec) do
      request_uri =
        operations(@api_spec)
        |> get_request_uri(operation_name)

      def_name =
        operation_name
        |> camel_to_snake
        |> String.to_atom

      quote do
        def unquote(def_name)(values) do
          headers = [
            {"X-Amz-Target", "DataPipeline.ActivatePipeline"}#,
            # {Authorization: AuthParams}
          ]

          HTTPoison.post(
            unquote(aws_host <> "/" <> request_uri),
            {:form, values},
            %{"Content-type" => "application/x-www-form-urlencoded"},
            headers
          )
        end
      end
    end
  end

  defp operation_names(api_spec) do
    operations(api_spec) |> Map.keys
  end

  defp get_endpoint_prefix(api_spec) do
    deep_fetch!(api_spec, ["metadata", "endpointPrefix"])
  end

  defp get_request_uri(operations, operation_name) do
    deep_fetch!(operations, [operation_name, "http", "requestUri"])
  end

  defp operations(api_spec) do
    Map.fetch!(api_spec, "operations")
  end

  # PEW
  def deep_fetch!(result, []), do: result
  def deep_fetch!(map, [key|remaining_keys]) do
    Map.fetch!(map, key) |> deep_fetch!(remaining_keys)
  end

  # pew pew
  def camel_to_snake(str) do
    str
    |> String.replace(~r/([a-z])([A-Z])/, "\\g{1}_\\g{2}")
    |> String.downcase
  end
end
