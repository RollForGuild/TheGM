defmodule Thegm.Users do
  @uuid_namespace UUID.uuid5(:url, "https://rollforguild.com/users/")

  use Thegm.Web, :model

  @primary_key {:id, :binary_id, autogenerate: false}
  @derive {Phoenix.Param, key: :id}

  schema "users" do
    field :username, :string
    field :email, :string
    field :password_hash, :string
    field :password, :string, virtual: true
    field :active, :boolean
    has_many :group_members, Thegm.GroupMembers

    timestamps()
  end

  def generate_uuid(resource_identifier) do
    UUID.uuid5(@uuid_namespace, resource_identifier)
  end

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, [:username, :email, :password, :active])
  end

  def create_changeset(model, params \\ :empty) do
    model
    |> changeset(params)
    |> unique_constraint(:username, message: "Username is already taken")
    |> cast(%{id: generate_uuid(params["username"])}, [:id])
    |> validate_required([:username, :password, :email], message: "Are required")
    |> unique_constraint(:email, message: "Email is already taken")
    |> validate_format(:email, ~r/@/, message: "Invalid email address")
    |> validate_length(:email, min: 4, max: 255)
    |> validate_format(:username, ~r/^[a-zA-Z0-9\s'_-]+$/, message: "Username must be alpha numeric")
    |> validate_length(:username, min: 1, max: 200)
    |> validate_length(:password, min: 4)
    |> put_password_hash

  end

  defp put_password_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :password_hash, Comeonin.Argon2.hashpwsalt(password))
      _ ->
        changeset
    end
  end
end
