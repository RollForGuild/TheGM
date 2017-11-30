defmodule Thegm.Router do
  use Thegm.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Thegm do
    pipe_through :api

    post "/beta-sub", BetasubController, :create
    get "/rolldice", RollDiceController, :index 
  end
end
