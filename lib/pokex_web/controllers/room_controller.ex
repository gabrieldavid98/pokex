defmodule PokexWeb.RoomController do
  use PokexWeb, :controller
  require Logger

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, "index.html", user: get_session(conn, "user"))
  end

  @spec create(Plug.Conn.t(), any) :: Plug.Conn.t()
  def create(conn, %{"room" => %{"name" => name}}) do
    room_id = UUID.uuid4()
    user = %{
      id: UUID.uuid4(),
      name: name,
      rooms: %{room_id => %{
        owner: true,
        share_link: Routes.room_url(conn, :join_room, room_id)
      }},
    }

    conn
    |> put_session("user", user)
    |> redirect(to: "/room/live/#{room_id}")
  end

  def create(conn, _params) do
    room_id = UUID.uuid4()
    user = add_room_to_user(conn, room_id, true)

    conn
    |> put_session("user", user)
    |> redirect(to: "/room/live/#{room_id}")
  end

  @spec log_out(Plug.Conn.t(), any) :: Plug.Conn.t()
  def log_out(conn, _params) do
    conn
    |> delete_session("user")
    |> redirect(to: Routes.room_path(conn, :index))
  end

  @spec join_room(Plug.Conn.t(), any) :: Plug.Conn.t()
  def join_room(conn, %{"id" => room_id}) do
    if get_session(conn, "user") do
      user = add_room_to_user(conn, room_id, false)

      conn
      |> put_session("user", user)
      |> redirect(to: "/room/live/#{room_id}")
    else
      render(conn, "join.html", room_id: room_id, user: nil)
    end
  end

  @spec join_room_create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def join_room_create(conn, %{"id" => room_id, "room" => %{"name" => name}}) do
    user = %{
      id: UUID.uuid4(),
      name: name,
      rooms: %{room_id => %{
        owner: false,
        share_link: Routes.room_url(conn, :join_room, room_id)
      }},
    }

    conn
    |> put_session("user", user)
    |> redirect(to: "/room/live/#{room_id}")
  end

  defp add_room_to_user(conn, room_id, owner) do
    get_session(conn, "user")
    |> Map.update!(
        :rooms,
        &Map.put(&1, room_id, %{
          owner: owner,
          share_link: Routes.room_url(conn, :join_room, room_id)
        })
      )
  end
end
