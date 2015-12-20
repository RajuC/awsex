defmodule Awsex.Auth do
  alias Timex.Date
  alias Timex.DateFormat

  @moduledoc """
  Sign requests
  """

  @typep headers() :: [{String.t, String.t}]

  @hash_algorithm "AWS4-HMAC-SHA256"

  @spec main(map(), String.t, String.t) :: map()
  def main(body_params, region, service) do
    access_key_id     = keys["access_key_id"]
    secret_access_key = keys["secret_access_key"]

    today_datestamp = create_today_datestamp
    today_timestamp = create_today_timestamp

    headers = [
      {"host", "#{service}.#{region}.amazonaws.com"},
      {"content-type", "application/x-www-form-urlencoded; charset=utf-8"},
      {"x-amz-date", today_timestamp}
    ]

    body = create_url_params(body_params)

    canonical_request = canonical_request(
      "POST",
      "https://#{service}.#{region}.amazonaws.com/",
      body,
      headers
    )

    hashed_canonical_request = hash(canonical_request)

    string_to_sign = create_string_to_sign(
      hashed_canonical_request,
      today_datestamp,
      today_timestamp,
      region,
      service
    )

    signing_key = create_signing_key(
      secret_access_key,
      today_datestamp,
      region,
      service
    )

    signed_request = sign_request(signing_key, string_to_sign)

    auth_header = auth_header(
      signed_request,
      access_key_id,
      today_datestamp,
      headers,
      region,
      service
    )

    %{
      "host"              => "https://#{service}.#{region}.amazonaws.com/",
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
  def canonical_request(request_method, uri, body, headers) do
    combined_headers  = headers
    canonical_headers = canonical_headers(combined_headers)
    sign_headers      = sign_headers(combined_headers)
    hashed_payload    = hash_body(body)

    request =
      [
        request_method,
        "/" <> "\n",
        canonical_headers,
        sign_headers,
        hashed_payload,
      ] |> Enum.join("\n")
  end

  @spec hash_canonical_request(String.t) :: String.t
  def hash_canonical_request(canonical_request) do
    hash(canonical_request)
  end

  @spec hash_body(String.t) :: String.t
  def hash_body(body) do
    hash(body)
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
    |> Enum.map(
      fn({hname, hvalue}) -> "#{hname}:#{strip_multiple_spaces(hvalue)}\n" end)
    |> Enum.join
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

  @doc """
  Get AWS credentials

  Set at AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables
  """
  @spec keys() :: map()
  def keys do
    access_key_id = System.get_env("AWS_ACCESS_KEY_ID")
    secret_access_key = System.get_env("AWS_SECRET_ACCESS_KEY")

    %{
      "access_key_id"     => access_key_id,
      "secret_access_key" => secret_access_key
    }
  end

  defp auth_header(signature, access_key_id, datestamp, headers, region, service) do
    authorization  = @hash_algorithm
    signed_headers = sign_headers(headers)
    credential     = credential(access_key_id, datestamp, region, service)

    {"Authorization", "#{authorization} Credential=#{credential}, SignedHeaders=#{signed_headers}, Signature=#{signature}"}
  end

  defp create_url_params(body) do
    Enum.map_join(body, "&", fn({k, v}) -> "#{k}=#{v}" end)
  end

  defp strip_multiple_spaces(str) do
    unless Regex.match?(~r/".*?"/, str) do
      Regex.replace(~r/ {2,}/, str, " ") |> String.strip
    else
      str
    end
  end

  defp create_today_datestamp do
    Date.universal
    |> DateFormat.format!("%Y%m%d", :strftime)
  end

  defp create_today_timestamp do
    Date.universal
    |> DateFormat.format!("%Y%m%dT%H%M%SZ", :strftime)
  end

  defp hash(value) do
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
