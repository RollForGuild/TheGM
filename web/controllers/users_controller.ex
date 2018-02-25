defmodule Thegm.UsersController do
  @moduledoc "Controller responsible for handling users"

  use Thegm.Web, :controller

  alias Thegm.Users

  def index(conn, _params) do
    users = Repo.all(Users)
    render conn, "index.json", users: users
  end

  def create(conn, %{"data" => %{"attributes" => params, "type" => type}}) do
    case {type, params} do
      {"users", params} ->
        changeset = Users.create_changeset(%Users{}, params)

        case Repo.insert(changeset) do
          {:ok, resp} ->
            Thegm.ConfirmationCodesController.new(resp.id, resp.email)
            Thegm.Mailchimp.subscribe_new_user(resp.email)
            send_resp(conn, :created, "")
          {:error, resp} ->
            error_list = Enum.map(resp.errors, fn {k, v} -> Atom.to_string(k) <> ": " <> elem(v, 0) end)
            conn
            |> put_status(:bad_request)
            |> render(Thegm.ErrorView, "error.json", errors: error_list)
        end
      _ ->
        conn
        |> put_status(:bad_request)
        |> render(Thegm.ErrorView, "error.json", errors: ["Posted a non `user` data type"])
    end
  end

  def update(conn, %{"id" => user_id, "data" => %{"attributes" => params, "type" => type}}) do
    current_user_id = conn.assigns[:current_user].id

    if type == "users" do
      case Repo.get(Users, user_id) |> Repo.preload([{:group_members, :groups}]) do
        nil ->
          conn
          |> put_status(:not_found)
          |> render(Thegm.ErrorView, "error.json", errors: ["A user with the specified `username` was not found"])
        user ->
          if current_user_id == user_id do
            user = Users.unrestricted_changeset(user, params)
            case Repo.update(user) do
              {:ok, result} ->
                conn
                |> put_status(:ok)
                |> render("private.json", user: result)
              {:error, changeset} ->
                conn
                |> put_status(:unprocessable_entity)
                |> render(Thegm.ErrorView, "error.json", errors: Enum.map(changeset.errors, fn {k, v} -> Atom.to_string(k) <> ": " <> elem(v, 0) end))
            end
          else
            conn
            |> put_status(:forbidden)
            |> render(Thegm.ErrorView, "error.json", errors: ["You do not have privileges to edit this account"])
          end
      end
    else
      conn
      |> put_status(:bad_request)
      |> render(Thegm.ErrorView, "error.json", errors: ["Posted a non `user` data type"])
    end
  end

  def show(conn, %{"id" => user_id}) do
    current_user_id = conn.assigns[:current_user].id

    case Repo.get(Users, user_id) |> Repo.preload([{:group_members, :groups}]) do
      nil ->
        conn
        |> put_status(:not_found)
        |> render(Thegm.ErrorView, "error.json", errors: ["A user with the specified `username` was not found"])
      user ->
        if current_user_id == user_id do
          render conn, "private.json", user: user
        else
          render conn, "public.json", user: user
      end
    end
  end
end
