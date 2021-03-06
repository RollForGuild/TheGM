defmodule Thegm.PasswordResets do
  use Thegm.Web, :model

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Phoenix.Param, key: :id}
  @foreign_key_type :binary_id

  schema "password_resets" do
    field :used, :boolean
    belongs_to :users, Thegm.Users

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `users_id`.
  """

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, [:used, :users_id])
  end
end
# credo:disable-for-this-file
