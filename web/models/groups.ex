defmodule Thegm.Groups do
  use Thegm.Web, :model
  @uuid_namespace UUID.uuid5(:url, "https://rollforguild.com/groups/")

  @primary_key {:id, :binary_id, autogenerate: false}
  @derive {Phoenix.Param, key: :id}
  @foreign_key_type :binary_id

  schema "groups" do
    field :name, :string
    field :slug, :string, null: false
    field :description, :string
    field :address, :string, null: false
    field :games, {:array, :string}
    field :distance, :float, virtual: true
    field :geom, Geo.Geometry
    field :discoverable, :boolean
    field :member_status, :string, virtual: true
    has_many :group_members, Thegm.GroupMembers
    has_many :join_requests, Thegm.GroupJoinRequests
    has_many :blocked_users, Thegm.GroupBlockedUsers


    timestamps()
  end

  def generate_uuid(resource) do
    UUID.uuid5(@uuid_namespace, resource)
  end

  def set_member_status(model, status) do
    model
    |> cast(%{member_status: status}, [:member_status])
  end

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, [:name, :description, :address, :games, :discoverable])
    |> validate_required([:name, :slug, :address, :discoverable], message: "Are required")
    |> validate_length(:address, min: 1, message: "Group address can not be empty")
    |> unique_constraint(:slug, message: "Group slug must be unique")
    |> validate_length(:description, max: 1000, message: "Group description can be no more than 1000 characters.")
    |> validate_format(:name, ~r/^[a-zA-Z0-9\s'_-]+$/, message: "Group name must be alpha numeric (and may include  -, ')")
    |> validate_length(:name, min: 1, max: 200)
  end

  def create_changeset(model, params \\ :empty) do
    model
    |> changeset(params)
    |> lat_lng
    |> cast(%{id: generate_uuid(params["slug"])}, [:id])
    |> cast(params, [:slug])
    |> validate_format(:slug, ~r/^[a-zA-Z0-9\s'-]+$/, message: "Group slug must be alpha numeric (and may include  -)")
  end

  def lat_lng(model) do
    case GoogleMaps.geocode(model.changes.address) do
      {:ok, result} ->
        lat = List.first(result["results"])["geometry"]["location"]["lat"]
        lng = List.first(result["results"])["geometry"]["location"]["lng"]
        model
        |> put_change(:geom, %Geo.Point{coordinates: {lng, lat}, srid: 4326})
    end
  end
end
