# Awsex

This is an experiment to generate an Elixir AWS SDK using macros
and the AWS API spec from [botocore](https://github.com/boto/botocore).

## So far

Incomplete. Somewhat working Poc, where you can do:

```
[~/code/personal/awsex](master✱)
clark$> iex -S mix
Erlang/OTP 18 [erts-7.3] [source] [64-bit] [smp:4:4] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.2.4) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> c = Awsex.Client.load_credentials!
%Awsex.Client{access_key_id: "$SCRUBBED_ACCESS_KEY_ID", endpoint: nil, port: "443",
 proto: "https", region: "us-east-1",
 secret_access_key: "$SCRUBBED_SECRET_ACCESS_KEY", service: nil}
iex(2)> res = Awsex.DataPipeline.list_pipelines(c, %{})
iex(3)> res.status_code
200
iex(4)> res.headers
[{"x-amzn-RequestId", "be9faa0b-0a68-11e6-$SCRUBBED"},
 {"Content-Type", "application/x-amz-json-1.1"}, {"Content-Length", "1827"},
 {"Date", "Sun, 24 Apr 2016 22:06:06 GMT"}]
iex(5)> Enum.drop(res.body, 2) |> hd() |> elem(1) |> Enum.take(1)
[%{"id" => "df-$SCRUBBED",
   "name" => "webhook_service_$SCRUBBED"}]
```

and it works for some requests.

So far this has only been tested with the DataPipeline API.

## Todo

- [x] Authentication
- [x] Prove out compile-time API function generation
- [x] Credentials from `credentials` file or environment
- [x] Description-level documentation generation
- [ ] Param-level documentation generation
- [x] Complete function generation for all param types
- [ ] Parameterization of Auth and Ops for all APIs
- [ ] Tests (in progress)
- [ ] Actual use
