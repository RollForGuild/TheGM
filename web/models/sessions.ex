defmodule Thegm.Sessions do
  use Thegm.Web, :model

  @primary_key {:token, :string, autogenerate: false}
  @derive {Phoenix.Param, key: :token}
  @foreign_key_type :binary_id
  schema "sessions" do
    belongs_to :users, Thegm.Users

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, [:token, :users_id])
    |> validate_required([:users_id])
  end

  def create_changeset(model, params \\ :empty) do
    model
    |> changeset(params)
    |> put_change(:token, SecureRandom.urlsafe_base64())
  end
end
# credo:disable-for-this-file
