defmodule Thegm.GroupMembers do
  @moduledoc false
  use Thegm.Web, :model
  alias Thegm.Repo
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Phoenix.Param, key: :id}
  @foreign_key_type :binary_id

  @member_roles ["owner", "admin", "member"]
  @admin_roles ["owner", "admin"]

  schema "group_members" do
    field :role, :string
    field :active, :boolean
    belongs_to :users, Thegm.Users
    belongs_to :groups, Thegm.Groups

    timestamps()
  end

  def create_changeset(model, params \\ :empty) do
    model
    |> cast(params, [:groups_id, :users_id, :role])
    |> validate_required([:groups_id, :users_id, :role], message: "Are required")
    |> unique_constraint(:groups_id, name: :group_members_groups_id_users_id_index)
    |> foreign_key_constraint(:groups_id, name: :group_members_groups_id_fk)
  end

  def role_changeset(model, params \\ :empty) do
    model
    |> cast(params, [:role])
    |> validate_required([:role], message: "Are required")
    |> validate_inclusion(:role, @member_roles)
  end

  def tombstone_changeset(model) do
    model
    |> put_change(:active, nil)
  end

  def get_group_member_ids(groups_id, exclude_users \\ []) do
    members = Repo.all(from m in Thegm.GroupMembers, select: m.users_id, where: m.groups_id == ^groups_id and not m.users_id in ^exclude_users)
    {:ok, members}
  end

  def get_admin_ids(groups_id) do
    admin_ids = Repo.all(from m in Thegm.GroupMembers, select: m.users_id, where: m.groups_id == ^groups_id and m.role in ^@admin_roles)
    {:ok, admin_ids}
  end

  def get_group_ids_where_user_is_member(users_id) do
    if is_nil(users_id) do
      {:ok, []}
    else
      memberships = Repo.all(from m in Thegm.GroupMembers, where: m.users_id == ^users_id, select: m.groups_id)
      {:ok, memberships}
    end
  end

  def isOwner(model) do
    model.role == "owner"
  end

  def isAdmin(model) do
    Enum.any?(@admin_roles, fn role -> model.role == role end)
  end

  def isMember(model) do
    Enum.any?(@member_roles, fn role -> model.role == role end)
  end

  def is_member_and_admin?(users_id, groups_id) do
    # Ensure user is a member of group
    case Repo.one(from gm in Thegm.GroupMembers, where: gm.groups_id == ^groups_id and gm.users_id == ^users_id and gm.active == true) do
      nil ->
        {:error, ["Not a member of specified group"]}
      member ->
        # Ensure user is an admin of the group
        if isAdmin(member) do
          {:ok, member}
        else
          {:error, ["Not an admin of specified group"]}
        end
    end
  end

  def create_new_group_member_notifications(groups_id, admins_id, new_users_id) do
    with {:ok, group} <- Thegm.Groups.get_group_by_id!(groups_id),
        {:ok, user} <- Thegm.Users.get_user_by_id(new_users_id),
        {:ok, recipients} <- Thegm.GroupMembers.get_group_member_ids(groups_id, [admins_id, new_users_id]) do
          type = "group::new-member"
          body = "#{user.name} just joined your group \"#{group.name}\""
          resources = [%{resources_type: "groups", resources_id: groups_id}, %{resources_type: "users", resources_id: new_users_id}]
          Thegm.Notifications.create_notifications(body, type, recipients, resources)
    end
  end

  def create_notifications_that_user_left(groups_id, users_id) do
    with {:ok, group} <- Thegm.Groups.get_group_by_id!(groups_id),
        {:ok, user} <- Thegm.Users.get_user_by_id(users_id),
        {:ok, recipients} <- Thegm.GroupMembers.get_group_member_ids(groups_id, [users_id]) do
          type = "group::member-left"
          body = "#{user.name} left your group \"#{group.name}\""
          resources = [%{resources_type: "groups", resources_id: groups_id}, %{resources_type: "users", resources_id: users_id}]
          Thegm.Notifications.create_notifications(body, type, recipients, resources)
    end
  end
end
