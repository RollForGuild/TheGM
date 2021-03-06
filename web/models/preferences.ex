defmodule Thegm.Preferences do
  @moduledoc """
    Database model for user preferences
  """
  use Thegm.Web, :model

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Phoenix.Param, key: :id}
  @foreign_key_type :binary_id

  schema "preferences" do
    field :units, :string, null: true
    field :date, :string, null: true
    field :time, :string, null: true
    field :timezone, :integer, null: true
    belongs_to :users, Thegm.Users

    timestamps()
  end

  def create_changeset(model, params \\ :empty) do
    model
    |> cast(params, [:users_id])
    |> changeset(params)
  end

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, [:units])
    |> cast(params, [:time, :timezone, :date, :units])
  end
end
