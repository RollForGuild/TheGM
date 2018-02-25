defmodule Thegm.AWS do
  @moduledoc "Modulefor handling Amazon AWS operations"

  @s3_options Application.get_env(:ex_aws, :s3)
  @bucket_name System.get_env("RFG_API_AWS_BUCKET")
  @aws_region System.get_env("RFG_API_AWS_REGION")
  @avatar_location "avatars"

  alias Thegm.Users
  alias ExAws.S3

  def upload_avatar(image_path, avatar_identifier) do
    image =
      image_path
      |> S3.Upload.stream_file
      |> S3.upload(@bucket_name, "#{@avatar_location}/#{avatar_identifier}.jpg")
      |> ExAws.request!
  end

  def remove_avatar(avatar_identifier) do
    S3.delete_object(@bucket_name, "#{@avatar_location}/#{avatar_identifier}.jpg")
    |> ExAws.request!
  end

  def get_avatar_location(avatar_identifier) do
    "https://s3.#{@aws_region}.amazonaws.com/#{@bucket_name}/#{@avatar_location}/#{avatar_identifier}.jpg"
  end
end
