defmodule Awsex.Auth do
  require Timex

  @moduledoc """
  Sign requests
  """

  @typep headers() :: [{String.t, String.t}]

  @hash_algorithm "AWS4-HMAC-SHA256"

  @spec main(%Awsex.Client{}, map(), map()) :: map()
  def main(creds, body_params, metadata) do
    access_key_id     = creds.access_key_id
    secret_access_key = creds.secret_access_key
    region            = creds.region

    endpoint_prefix = Map.fetch!(metadata, "endpointPrefix")
    target_prefix   = Map.fetch!(metadata, "targetPrefix")


    today_datestamp = create_today_datestamp
    today_timestamp = create_today_timestamp

    action = Map.fetch!(body_params, "action")
    body = Map.delete(body_params, "action") |> Poison.encode!

    headers = [
      {"host", "#{endpoint_prefix}.#{region}.amazonaws.com"},
      {"content-type", "application/x-amz-json-1.1"},
      {"x-amz-date", today_timestamp},
      {"x-amz-target", "#{target_prefix}.#{action}"}
    ]

    canonical_request = canonical_request(
      "POST", # TODO parameterize
      "https://#{endpoint_prefix}.#{region}.amazonaws.com/",
      body,
      headers
    )

    hashed_canonical_request = hash(canonical_request)

    string_to_sign = create_string_to_sign(
      hashed_canonical_request,
      today_datestamp,
      today_timestamp,
      region,
      endpoint_prefix
    )

    signing_key = create_signing_key(
      secret_access_key,
      today_datestamp,
      region,
      endpoint_prefix
    )

    signed_request = sign_request(signing_key, string_to_sign)

    auth_header = auth_header(
      signed_request,
      access_key_id,
      today_datestamp,
      headers,
      region,
      endpoint_prefix
    )

    %{
      "host"              => "https://#{endpoint_prefix}.#{region}.amazonaws.com/",
      "body"              =>  body,
      "headers"           => [auth_header | headers],
      "string_to_sign"    => string_to_sign,
      "canonical_request" => canonical_request
    }
  end

  @spec sign_request(String.t, String.t) :: String.t
  def sign_request(signing_key, string_to_sign) do
    hash(signing_key, string_to_sign)
  end

  @doc """
  https://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html

  CanonicalRequest =
  HTTPRequestMethod + '\n' +
  CanonicalURI + '\n' +
  CanonicalQueryString + '\n' +
  CanonicalHeaders + '\n' +
  SignedHeaders + '\n' +
  HexEncode(Hash(RequestPayload))
  """
  @spec canonical_request(String.t, String.t, String.t, headers()) :: String.t
  def canonical_request(request_method, _uri, body, headers) do
    combined_headers  = headers
    canonical_headers = canonical_headers(combined_headers)
    sign_headers      = sign_headers(combined_headers)
    hashed_payload    = hash(body)

      [
        request_method,
        "/" <> "\n", # TODO parameterize
        canonical_headers,
        sign_headers,
        hashed_payload,
      ] |> Enum.join("\n")
  end

  @doc """
  https://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html

  CanonicalHeaders =
    CanonicalHeadersEntry0 + CanonicalHeadersEntry1 + ... + CanonicalHeadersEntryN
  CanonicalHeadersEntry =
    Lowercase(HeaderName) + ':' + Trimall(HeaderValue) + '\n'
  """
  @spec canonical_headers(headers()) :: String.t
  def canonical_headers(headers) do
    downcase_and_sort(headers)
    |> Enum.map_join(
      fn({hname, hvalue}) ->
        "#{hname}:#{strip_multiple_spaces(hvalue)}\n"
      end)
  end

  @doc """
  https://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html

  SignedHeaders =
    Lowercase(HeaderName0) + ';' + Lowercase(HeaderName1) + ";" + ... + Lowercase(HeaderNameN)
  """
  @spec sign_headers(headers()) :: String.t
  def sign_headers(headers) do
    downcase_and_sort(headers)
    |> Enum.map_join(";", fn({header_name, _}) -> header_name end)
  end

  @doc """
  Algorithm + '\n' +
  RequestDate + '\n' +
  CredentialScope + '\n' +
  HashedCanonicalRequest
  """
  @spec create_string_to_sign(String.t, String.t, String.t, String.t, String.t) :: String.t
  def create_string_to_sign(hashed_canonical_request, datestamp, timestamp, region, service) do
    [
      @hash_algorithm,
      timestamp,
      credential_scope(datestamp, region, service),
      hashed_canonical_request
    ] |> Enum.join("\n")
  end

  @spec credential(String.t, String.t, String.t, String.t) :: String.t
  def credential(aws_key_id, datestamp, region, service) do
    aws_key_id <> "/" <> credential_scope(datestamp, region, service)
  end

  @spec credential_scope(String.t, String.t, String.t) :: String.t
  def credential_scope(datestamp, region, service) do
    "#{datestamp}/#{region}/#{service}/aws4_request"
  end

  @doc """
  From https://docs.aws.amazon.com/general/latest/gr/sigv4-calculate-signature.html

  "Use the digest for the key derivation. Most languages have functions to compute either a binary format hash, commonly called a digest, or a hex-encoded hash, called a hexdigest. The key derivation requires you use a digest.
  """
  @spec create_signing_key(String.t, String.t, String.t, String.t) :: String.t
  def create_signing_key(secret_key, date_stamp, region_name, service_name) do
    hmac256("AWS4" <> secret_key, date_stamp)
    |> hmac256(region_name)
    |> hmac256(service_name)
    |> hmac256("aws4_request")
  end


  defp auth_header(signature, access_key_id, datestamp, headers, region, service) do
    authorization  = @hash_algorithm
    signed_headers = sign_headers(headers)
    credential     = credential(access_key_id, datestamp, region, service)

    {"Authorization", "#{authorization} Credential=#{credential}, SignedHeaders=#{signed_headers}, Signature=#{signature}"}
  end

  defp strip_multiple_spaces(str) do
    unless Regex.match?(~r/".*?"/, str) do
      Regex.replace(~r/ {2,}/, str, " ") |> String.strip
    else
      str
    end
  end

  defp create_today_datestamp do
    Timex.DateTime.universal
    |> Timex.format!("%Y%m%d", :strftime)
  end

  defp create_today_timestamp do
    Timex.DateTime.universal
    |> Timex.format!("%Y%m%dT%H%M%SZ", :strftime)
  end

  def hash(value) do
    :crypto.hash(:sha256, value) |> Base.encode16 |> String.downcase
  end

  defp hash(key, value) do
    hmac256(key, value) |> Base.encode16 |> String.downcase
  end

  defp hmac256(key, value) do
    :crypto.hmac(:sha256, key, value)
  end

  defp downcase_and_sort(headers) do
    headers
    |> Enum.map(fn({hname, hvalue}) -> {String.downcase(hname), hvalue} end)
    |> Enum.sort(fn({hname1, _}, {hname2, _}) -> hname1 < hname2 end)
  end
end
