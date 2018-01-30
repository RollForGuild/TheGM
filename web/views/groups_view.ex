defmodule Thegm.GroupsView do
  use Thegm.Web, :view

  def render("memberof.json", %{group: group}) do
    %{data: full_json(group)}
  end

  def render("notmember.json", %{group: group}) do
    %{data: non_member_json(group)}
  end

  def render("search.json", %{groups: groups, meta: meta}) do
    %{meta: search_meta(meta), data: Enum.map(groups, &non_member_json/1)}
  end

  def full_json(group) do
    %{type: "group", id: group.id, attributes: %{name: group.name, description: group.description, address: group.address, geo: Thegm.GeoView.geo(group.geom), games: group.games}, relationships: relationships(group.id)}
  end

  def relationships(group_id) do
    base = Application.get_env(:thegm, :api_url)
    %{members: %{links: %{related: base <> "/groups/" <> group_id <> "/members"}}}
  end

  def non_member_json(group) do
    %{type: "group", id: group.id, attributes: non_member_attributes(group)}
  end

  def non_member_attributes(group) do
    %{name: group.name, description: group.description, games: group.games, members: length(group.group_members)}
  end

  def search_meta(meta) do
    %{total: meta.total, count: meta.count, limit: meta.limit, offset: meta.offset}
  end
end
