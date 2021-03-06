defmodule PokexWeb.Router do
  use PokexWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {PokexWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :basicauth do
    plug :basic_auth, username: "admin", password: "l1v3d4shb04rd"
  end

  scope "/", PokexWeb do
    pipe_through :browser

    get "/", RoomController, :index
    get "/rooms", RoomController, :show
    post "/", RoomController, :create
    get "/logout", RoomController, :log_out
    get "/join/room/:id", RoomController, :join_room
    post "/join/room/:id", RoomController, :join_room_create
    delete "/rooms/:id", RoomController, :delete
    get "/kick-out/:id", RoomController, :kick_out

    live "/room/live/:id", RoomLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", PokexWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test, :prod] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through [:browser, :basicauth]
      live_dashboard "/dashboard", metrics: PokexWeb.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
