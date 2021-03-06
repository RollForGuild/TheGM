defmodule Thegm.PreferencesView do
  use Thegm.Web, :view

  def render("show.json", %{preferences: preferences}) do
    %{
      data: %{
        type: "preferences",
        id: preferences.id,
        attributes: preferences_show(preferences),
        relationships: %{
          users: user_relationship_data(preferences)
        }
      }
    }
  end

  def preferences_show(preferences) do
    %{
      units: preferences.units,
      date: preferences.date,
      time: preferences.time,
      timezone: preferences.timezone,
      updated_at: preferences.updated_at
    }
  end

  def user_relationship_data(preferences) do
    %{
      id: preferences.users_id,
      type: "users"
    }
  end

  def relationship_data(preferences) do
    %{
      id: preferences.id,
      type: "preferences"
    }
  end

  def users_preferences(preferences) do
    preferences_show(preferences)
  end
end
