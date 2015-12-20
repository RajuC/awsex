defmodule AuthTest do
  use ExUnit.Case
  alias Awsex.Auth

  test "it gets auth information from the environment" do
    System.put_env("AWS_ACCESS_KEY_ID", "FOO")
    System.put_env("AWS_SECRET_ACCESS_KEY", "BAR")

    keys = Auth.keys

    assert Map.fetch!(keys, "access_key_id") == "FOO"
    assert Map.fetch!(keys, "secret_access_key") == "BAR"
  end

  test "create_signing_key" do
    # from: http://docs.aws.amazon.com/general/latest/gr/signature-v4-examples.html

    key          = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY"
    date_stamp   = "20120215"
    region_name  = "us-east-1"
    service_name = "iam"

    expected_signing_key = <<244, 120, 14, 45, 159, 101, 250, 137, 95, 156, 103, 179, 44, 225, 186, 240, 176, 216, 164, 53, 5, 160, 0, 161, 169, 224, 144, 212, 20, 219, 64, 77>>

    generated_signing_key = Auth.create_signing_key(
      key,
      date_stamp,
      region_name,
      service_name
    )

    assert expected_signing_key == generated_signing_key
  end

  test "canonical_request" do
    request_method = "POST"
    uri = "https://iam.amazonaws.com/"
    query_string = "Action=ListUsers&Version=2010-05-08"
    headers = [
      {"content-type", "application/x-www-form-urlencoded; charset=utf-8"},
      {"x-amz-date", "20110909T233600Z"}
    ]
    hashed_payload = Auth.hash_body(query_string)


    expected_req = "POST\n/\n\ncontent-type:application/x-www-form-urlencoded; charset=utf-8\nx-amz-date:20110909T233600Z\n\ncontent-type;x-amz-date\n#{hashed_payload}"

    assert Auth.canonical_request(request_method, uri, query_string, headers) == expected_req
  end

  test "canonical_headers" do
    #https://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html

    headers = [
      {"Host", "iam.amazonaws.com"},
      {"Content-Type", "application/x-www-form-urlencoded; charset=utf-8"},
      {"My-header1", "a   b   c "},
      {"X-Amz-Date", "20150830T123600Z"},
      {"My-header2", "\"a   b   c\""},
    ]

    expected = """
    content-type:application/x-www-form-urlencoded; charset=utf-8
    host:iam.amazonaws.com
    my-header1:a b c
    my-header2:"a   b   c"
    x-amz-date:20150830T123600Z
    """

    assert Auth.canonical_headers(headers) == expected
  end

  test "signed_headers" do
    # https://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html
    headers = [
      {"Host", "iam.amazonaws.com"},
      {"Content-Type", "application/x-www-form-urlencoded; charset=utf-8"},
      {"My-header1", "a   b   c "},
      {"X-Amz-Date", "20150830T123600Z"},
      {"My-header2", "\"a   b   c\""}
    ]

    expected = "content-type;host;my-header1;my-header2;x-amz-date"

    assert Auth.sign_headers(headers) == expected
  end

  test "create_string_to_sign" do
    request_method = "POST"
    uri = "https://iam.amazonaws.com/"
    query_string = "Action=ListUsers&Version=2010-05-08"

    today_timestamp = "20110909T233600Z"
    today_datestamp = "20110909"
    headers = [
      {"content-type", "application/x-www-form-urlencoded; charset=utf-8"},
      {"x-amz-date", today_timestamp}
    ]
    region = "us-east-1"
    service = "datapipeline"
    credential_scope = Auth.credential_scope(today_datestamp, region, service)
    canonical_request = Auth.canonical_request(request_method, uri, query_string, headers)
    hashed_canonical_request = Auth.hash_canonical_request(canonical_request)

    expected = [
      "AWS4-HMAC-SHA256",
      today_timestamp,
      credential_scope,
      hashed_canonical_request
    ] |> Enum.join("\n")

    assert Auth.create_string_to_sign(hashed_canonical_request, today_datestamp, today_timestamp, region, service) == expected
  end
end
