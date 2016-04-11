# Awsex

This is an experiment to generate an Elixir AWS SDK using macros
and the AWS API spec from [botocore](https://github.com/boto/botocore).

## So far

Incomplete. Somewhat working Poc, where you can do:

```
$ AWS_ACCESS_KEY_ID="foo" AWS_SECRET_ACCESS_KEY="bar" iex -S mix
iex(1)> Awsex.DataPipeline.list_pipelines(nil, %{})
```

and it works for some requests

## Todo

- [x] Authentication
- [x] Prove out compile-time API function generation
- [ ] Complete function generation for all param types
- [ ] Parameterization of Auth and Ops for all APIs
- [ ] Tests (in progress)
- [ ] Actual use
