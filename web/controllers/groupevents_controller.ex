defmodule Thegm.GroupEventsController do
  use Thegm.Web, :controller

  alias Thegm.GroupEvents

  def create(conn, %{"groups_id" => groups_id, "data" => %{"attributes" => params, "type" => "events"}}) do
    users_id = conn.assigns[:current_user].id

    # Ensure user is a member and admin of the group
    case Thegm.GroupMembersController.is_member_and_admin?(users_id, groups_id) do
      {:error, error} ->
        conn
        |> put_status(:bad_request)
        |> render(Thegm.ErrorView, "error.json", errors: error)
        |> halt()
      {:ok, _} ->
        nil
    end

    games = case params["games"] do
      nil ->
        []
      list ->
        list
    end

    game_suggestions = case params["game_suggestions"] do
      nil ->
        []
      list ->
        list
    end

    # NOTE: Once we have guilds, this should only be triggered if a group is not a guild.
    if length(games) + length(game_suggestions) > 1 do
      conn
      |> put_status(:bad_request)
      |> render(Thegm.ErrorView, "error.json", errors: ["Events can only have one game associated with them"])
    end

    # Read start/end time params
    params = case read_start_and_end_times(params) do
      {:ok, settings} ->
        params
        |> Map.put("start_time", settings.start_time)
        |> Map.put("end_time", settings.end_time)
        |> Map.put("groups_id", groups_id)
      {:error, errors} ->
        conn
        |> put_status(:bad_request)
        |> render(Thegm.ErrorView, "error.json", errors: Enum.map(errors, fn {k, v} -> Atom.to_string(k) <> ": " <> elem(v, 0) end))
        |> halt()
    end

    # Create event changeset
    event_changeset = GroupEvents.create_changeset(%GroupEvents{}, params)

    multi =
      Multi.new
      |> Multi.insert(:group_events, event_changeset)
      |> Multi.run(:group_event_games, fn %{group_events: group_event} ->

        event_games = compile_game_changesets(games, group_event.id) ++ compile_game_suggestion_changesets(game_suggestions, group_event.id)

        Repo.insert_all(Thegm.GroupEventGames, event_games)
      end)

    case Repo.transaction(multi) do
      {:ok, event} ->
        conn
        |> put_status(:created)
        |> render("show.json", event: event, is_member: true)

      {:error, :group_events, changeset, %{}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Thegm.ErrorView, "error.json", errors: Enum.map(changeset.errors, fn {k, v} -> Atom.to_string(k) <> ": " <> elem(v, 0) end))
        |> halt()

      {:error, :group_event_games, changeset, %{}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Thegm.ErrorView, "error.json", errors: Enum.map(changeset.errors, fn {k, v} -> Atom.to_string(k) <> ": " <> elem(v, 0) end))
        |> halt()
    end
  end

  def update(conn, %{"groups_id" => groups_id, "id" => events_id, "data" => %{"attributes" => params, "type" => "events"}}) do
    users_id = conn.assigns[:current_user].id

    # Ensure user is a member and admin of the group
    case Thegm.GroupMembersController.is_member_and_admin?(users_id, groups_id) do
      {:error, error} ->
        conn
        |> put_status(:bad_request)
        |> render(Thegm.ErrorView, "error.json", errors: error)
        |> halt()
      {:ok, _} ->
        nil
    end

    # # Ensure received data type is `events`
    # unless type == "events" do
    #   conn
    #   |> put_status(:bad_request)
    #   |> render(Thegm.ErrorView, "error.json", errors: ["Posted a non `events` data type"])
    #   |> halt()
    # end

    # Get the event specified
    event = case Repo.get(Thegm.GroupEvents, events_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> render(Thegm.ErrorView, "error.json", errors: ["No event with that id found"])
        |> halt()
      event ->
        event
    end

    # Read the start and end times
    params = case read_start_and_end_times(params) do
      {:ok, settings} ->
        params
        |> Map.put("start_time", settings.start_time)
        |> Map.put("end_time", settings.end_time)
        |> Map.put("groups_id", groups_id)
      {:error, errors} ->
        conn
        |> put_status(:bad_request)
        |> render(Thegm.ErrorView, "error.json", errors: Enum.map(errors, fn {k, v} -> Atom.to_string(k) <> ": " <> elem(v, 0) end))
        |> halt()
    end

    # Update the event
    event_changeset = GroupEvents.update_changeset(event, params)

    # Attempt to update the event in the database
    case Repo.update(event_changeset) do
      {:ok, event} ->
        event = event |> Repo.preload([:groups, :games])
        conn
        |> put_status(:created)
        |> render("show.json", event: event, is_member: true)
      {:error, resp} ->
        error_list = Enum.map(resp.errors, fn {k, v} -> Atom.to_string(k) <> ": " <> elem(v, 0) end)
        conn
        |> put_status(:bad_request)
        |> render(Thegm.ErrorView, "error.json", errors: error_list)
        |> halt()
    end
  end

  def show(conn, %{"groups_id" => groups_id, "id" => events_id}) do
    users_id = case conn.assigns[:current_user] do
      nil ->
        nil
      found ->
        found.id
    end

    case Repo.one(from ge in GroupEvents, where: ge.groups_id == ^groups_id and ge.id == ^events_id) |> Repo.preload([:groups, :games]) do
      nil ->
        conn
        |> put_status(:not_found)
        |> render(Thegm.ErrorView, "error.json", errors: ["Could not find specified event for group"])
      event ->
        if event.deleted do
          conn
          |> put_status(:gone)
          |> render(Thegm.ErrorView, "error.json", errors: ["That event no longer exists."])
        else
          is_member = Thegm.GroupMembersController.is_member(groups_id: groups_id, users_id: users_id)
          conn
          |> put_status(:ok)
          |> render("show.json", event: event, is_member: is_member)
        end
    end
  end

  def index(conn, params) do
    users_id = case conn.assigns[:current_user] do
      nil ->
        nil
      found ->
        found.id
    end

    groups_id = params["groups_id"]
    if groups_id == nil do
      conn
      |> put_status(:bad_request)
      |> render(Thegm.ErrorView, "error.json", errors: ["groups_id: Must be supplied!"])
      |> halt()
    end

    settings = case Thegm.ReadPagination.read_pagination_params(params) do
      {:ok, settings} ->
        settings
      {:error, errors} ->
        conn
        |> put_status(:bad_request)
        |> render(Thegm.ErrorView, "error.json", errors: Enum.map(errors, fn {k, v} -> Atom.to_string(k) <> ": " <> elem(v, 0) end))
        |> halt()
    end

    {meta, events} = query_events_with_meta(groups_id, settings)

    # Is the user a member?
    is_member = Thegm.GroupMembersController.is_member(groups_id: groups_id, users_id: users_id)

    conn
    |> put_status(:ok)
    |> render("index.json", events: events, meta: meta, is_member: is_member)
  end

  def delete(conn, %{"groups_id" => groups_id, "id" => events_id}) do
    users_id = conn.assigns[:current_user].id

    # Ensure user is a member and admin of the group
    case Thegm.GroupMembersController.is_member_and_admin?(users_id, groups_id) do
      {:error, error} ->
        conn
        |> put_status(:bad_request)
        |> render(Thegm.ErrorView, "error.json", errors: error)
        |> halt()
      {:ok, _} ->
        nil
    end

    # Get the specified event
    event = case Repo.get(Thegm.GroupEvents, events_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> render(Thegm.ErrorView, "error.json", errors: ["No event with that id found"])
        |> halt()
      event ->
        event
    end

    # Mark event as deleted
    event_changeset = GroupEvents.delete_changeset(event)

    # Update event to be known as deleted
    case Repo.update(event_changeset) do
      {:ok, _} ->
        send_resp(conn, :no_content, "")
      {:error, resp} ->
        error_list = Enum.map(resp.errors, fn {k, v} -> Atom.to_string(k) <> ": " <> elem(v, 0) end)
        conn
        |> put_status(:bad_request)
        |> render(Thegm.ErrorView, "error.json", errors: error_list)
        |> halt()
    end
  end

  def read_start_and_end_times(params) do
    errors = []

    {start_time, errors} = read_start_time(params, errors)
    {end_time, errors} = read_end_time(params, errors)

    if length(errors) > 0 do
        {:error, errors}
    else
        {:ok, %{start_time: start_time, end_time: end_time}}
    end
  end

  defp read_start_time(params, errors) do
    case params["start_time"] do
      nil ->
        errors = errors ++ [start_time: "Must provide a startime in iso8601 format"]
        {nil, errors}
      start ->
        case DateTime.from_iso8601(start) do
          {:ok, datetime, _} ->
            {datetime, errors}
          {:error, error} ->
            errors = errors ++ [start_time: Atom.to_string(error)]
            {nil, errors}
        end
    end
  end

  defp read_end_time(params, errors) do
    case params["end_time"] do
      nil ->
        errors = errors ++ [end_time: "Must provide a startime in iso8601 format"]
        {nil, errors}
      ending ->
        case DateTime.from_iso8601(ending) do
          {:ok, datetime, _} ->
            {datetime, errors}
          {:error, error} ->
            errors = errors ++ [end_time: Atom.to_string(error)]
            {nil, errors}
        end
    end
  end

  defp query_events_with_meta(groups_id, settings) do
    now = NaiveDateTime.utc_now()

    # Get total in search
    total = Repo.one(from ge in GroupEvents, where: ge.groups_id == ^groups_id and ge.end_time >= ^now and ge.deleted == false, select: count(ge.id))

    events =  Repo.all(from ge in GroupEvents,
      where: ge.groups_id == ^groups_id and ge.end_time >= ^now and ge.deleted == false,
      order_by: [asc: ge.start_time],
      limit: ^settings.limit,
      offset: ^settings.offset
    ) |> Repo.preload([:groups, :games])

    meta = %{total: total, limit: settings.limit, offset: settings.offset, count: length(events)}

    {meta, events}
  end

  def compile_game_changesets([], _) do
    []
  end

  def compile_game_changesets([head | tail], group_events_id) do
    changeset = Thegm.GroupEvents.create_changeset(%Thegm.GroupEvents{}, %{"group_events_id" => group_events_id, "games_id" => head})
    [changeset] ++ compile_game_changesets(tail, group_events_id)
  end

  def compile_game_suggestion_changesets([], _) do
    []
  end

  def compile_game_suggestion_changesets([head | tail], group_events_id) do
    changeset = Thegm.GroupEvents.create_changeset(%Thegm.GroupEvents{}, %{"group_events_id" => group_events_id, "game_suggestions_id" => head})
    [changeset] ++ compile_game_changesets(tail, group_events_id)
  end
end
