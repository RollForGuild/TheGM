defmodule Thegm.GroupEventGamesController do
  use Thegm.Web, :controller
  alias Thegm.GroupEventGames

  def index(conn, params = %{"groups_id" => _, "group_events_id" => events_id}) do
    case Thegm.Reader.read_pagination_params(params) do
      {:ok, settings} ->
        total = Repo.one(
          from geg in GroupEventGames,
          where: geg.group_events_id == ^events_id,
          select: count(geg.id)
        )

        # Do the search
        games = Repo.all(
          from geg in GroupEventGames,
          where: geg.group_events_id == ^events_id,
          limit: ^settings.limit,
          offset: ^settings.offset,
          preload: [:games, :game_suggestions]
        )

        meta = %{total: total, limit: settings.limit, offset: settings.offset, count: length(games)}

        conn
        |> put_status(:ok)
        |> render("index.json", event_games: games, meta: meta)

      {:error, errors} ->
        conn
        |> put_status(:bad_request)
        |> render(Thegm.ErrorView, "error.json", errors: Enum.map(errors, fn{k, v} -> Atom.to_string(k) <> ": " <> elem(v, 0) end))
    end
  end
end
