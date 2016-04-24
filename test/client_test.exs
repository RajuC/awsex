defmodule ClientTest do
  use ExUnit.Case
  alias Awsex.Client

  test "load_credentials!" do
    #####################################
    ### with a valid credentials file ###
    #####################################

    test_loc = "./test_credentials"
    test_creds = """
    [default]
    aws_access_key_id = 1234
    aws_secret_access_key = 5678
    region = us-east-1
    """

    File.write!(test_loc, test_creds)

    creds = Client.load_credentials!("./test_credentials")

    File.rm!(test_loc)

    assert creds == %Awsex.Client{
      access_key_id: "1234",
      secret_access_key: "5678",
      region: "us-east-1"
    }

    #######################################################
    ### with valid env, and an invalid credentials file ###
    #######################################################

    System.put_env("AWS_ACCESS_KEY_ID", "different_creds")
    System.put_env("AWS_SECRET_ACCESS_KEY", "also_different")
    System.put_env("AWS_REGION", "us-east-1")

    creds = Client.load_credentials!("~/.aws/not_a_real_credentials_file")

    assert creds == %Awsex.Client{
      access_key_id: "different_creds",
      secret_access_key: "also_different",
      region: "us-east-1"
    }

    ####################################################
    ### with no env, and an invalid credentials file ###
    ####################################################

    System.delete_env("AWS_ACCESS_KEY_ID")
    System.delete_env("AWS_SECRET_ACCESS_KEY")
    System.delete_env("AWS_REGION")

    assert_raise(
      Awsex.Client.CredentialsError,
      fn ->
        Client.load_credentials!("~/.aws/not_a_real_credentials_file")
      end
    )
  end

  test "load_from_file!" do
    test_loc = "./test_credentials"
    test_creds = """
    [default]
    aws_access_key_id = foobar
    aws_secret_access_key = bazquux
    region = us-east-1
    """

    File.write!(test_loc, test_creds)

    creds = Client.load_from_file!(test_loc)

    File.rm!(test_loc)

    assert creds == %Awsex.Client{
      access_key_id: "foobar",
      secret_access_key: "bazquux",
      region: "us-east-1"
    }
  end

  test "load_from_env!" do
    System.put_env("AWS_ACCESS_KEY_ID", "foobar")
    System.put_env("AWS_SECRET_ACCESS_KEY", "bazquux")
    System.put_env("AWS_REGION", "us-east-1")

    creds = Client.load_from_env!

    assert creds == %Awsex.Client{
      access_key_id: "foobar",
      secret_access_key: "bazquux",
      region: "us-east-1"
    }
  end
end
