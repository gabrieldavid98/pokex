defmodule PokexWeb.RoomController do
  use PokexWeb, :controller
  require Logger

  alias Pokex.Rooms

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, "index.html", user: get_session(conn, "user"))
  end

  @spec show(Plug.Conn.t(), any) :: Plug.Conn.t()
  def show(conn, params) do
    if get_session(conn, "user") do
      user = get_session(conn, "user")
      room_ids = user.rooms |> Map.keys()
      rooms_with_names =
        Rooms.list_rooms_by_ids(room_ids)
        |> Enum.group_by(fn room -> room.id end, fn room -> room.name end)
        |> Stream.map(fn {k, v} -> {k, List.first(v)} end)
        |> Stream.filter(fn {key, _} -> Map.has_key?(user.rooms, key) end)
        |> Stream.map(fn {k, v} -> {k, Map.put(user.rooms[k], :name, v)} end)
        |> Enum.into(%{})

      user = Map.update(user, :rooms, %{}, fn _ -> rooms_with_names end)

      conn
      |> then(fn conn ->
        if Map.has_key?(params, "not-found") do
          put_flash(conn, :error, "Room not found")
        else
          conn
        end
      end)
      |> put_session("user", user)
      |> render("rooms.html", user: user)
    else
      redirect(conn, to: Routes.room_path(conn, :index))
    end
  end

  @spec create(Plug.Conn.t(), any) :: Plug.Conn.t()
  def create(conn, %{"room" => %{"name" => name, "room_name" => room_name}}) do
    with :ok <- validate_name(name),
         :ok <- validate_room_name(room_name),
         {:ok, room} <- Rooms.create_room(new_room_map(room_name))
    do
      user = %{
        id: UUID.uuid4(),
        name: name,
        rooms: %{room.id => %{
          owner: true,
          share_link: Routes.room_path(conn, :join_room, room.id)
        }},
      }

      conn
      |> put_session("user", user)
      |> redirect(to: "/room/live/#{room.id}")
    else
      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Room cannot be created")
        |> render("index.html", user: get_session(conn, "user"))
      {:error, msg} ->
        conn
        |> put_flash(:error, msg)
        |> render("index.html", user: get_session(conn, "user"))
    end
  end

  def create(conn, %{"room" => %{"room_name" => room_name}}) do
    case Rooms.create_room(new_room_map(room_name)) do
      {:ok, room} ->
        user = add_room_to_user(conn, room.id, true)

        conn
        |> put_session("user", user)
        |> redirect(to: "/room/live/#{room.id}")
      {:error, _} ->
        conn
        |> put_flash(:error, "Room cannot be created")
        |> render("index.html", user: get_session(conn, "user"))
    end
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
    with :ok <- validate_name(name) do
      user = %{
        id: UUID.uuid4(),
        name: name,
        rooms: %{room_id => %{
          owner: false,
          share_link: Routes.room_path(conn, :join_room, room_id)
        }},
      }

      conn
      |> put_session("user", user)
      |> redirect(to: "/room/live/#{room_id}")
    else
      {:error, msg} ->
        conn
        |> put_flash(:error, msg)
        |> render("join.html", room_id: room_id, user: nil)
    end
  end

  def delete(conn, %{"id" => room_id}) do
    room =
      get_session(conn, "user")
      |> Map.get(:rooms)
      |> Map.get(room_id)

    if room.owner do
      current_room = Rooms.get_room!(room_id)

      if current_room.owner_count == 1 do
        Rooms.delete_room(current_room)
        Phoenix.PubSub.broadcast(Pokex.PubSub, room_id, {:room_deleted})
      else
        Rooms.update_room(current_room, %{owner_count: current_room.owner_count - 1})
      end
    end

    new_user =
      get_session(conn, "user")
      |> Map.update!(:rooms, &Map.delete(&1, room_id))

    conn
    |> put_session("user", new_user)
    |> redirect(to: Routes.room_path(conn, :show))
  end

  defp add_room_to_user(conn, room_id, owner) do
    get_session(conn, "user")
    |> Map.update!(
        :rooms,
        &Map.put(&1, room_id, %{
          owner: owner,
          share_link: Routes.room_path(conn, :join_room, room_id)
        })
      )
  end

  defp validate_name(name) do
    case name |> String.trim() |> String.length() do
      0 -> {:error, "Name cannot be empty"}
      x when x < 3 -> {:error, "Name cannot have less than 3 characters"}
      _ -> :ok
    end
  end

  defp validate_room_name(room_name) do
    case room_name |> String.trim() |> String.length() do
      0 -> {:error, "Room Name cannot be empty"}
      x when x < 5 -> {:error, "Room Name cannot have less than 5 characters"}
      _ -> :ok
    end
  end

  defp new_room_map(room_name) do
    %{
      name: room_name,
      active_at: DateTime.utc_now(),
      owner_count: 1
    }
  end
end
