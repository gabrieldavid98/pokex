defmodule PokexWeb.RoomLive do
  use PokexWeb, :live_view
  require Logger

  alias PokexWeb.Presence
  alias Pokex.Rooms

  @impl true
  def mount(params, session, socket) do
    room_id = params["id"]

    with {:ok, user} <- get_current_user(session),
         {:ok, room} <- get_current_room(user, room_id)
    do
      room_name = room.name
      current_room =
        Map.get(user.rooms, room_id)
        |> Map.put(:id, room_id)
        |> Map.put(:name, room_name)

      if current_room.owner do
        Rooms.update_room(room, %{active_at: DateTime.utc_now()})
      end

      user = Map.put(user, :is_current_room_owner?, current_room.owner)
      assigns = %{
        user: user,
        current_room: current_room,
        users: normalize_presence(Presence.list(room_id)),
        fib: [1, 2, 3, 5, 8, 13, 21, 34, 55, 89],
        vote: nil,
        votes: %{},
        users_who_voted: %{},
        active?: true,
      }

      if connected?(socket) do
        Phoenix.PubSub.subscribe(Pokex.PubSub, room_id, metadata: :room)
        Phoenix.PubSub.subscribe(Pokex.PubSub, user.id, metadata: :user)
        Presence.track(self(), room_id, user.id, %{name: user.name})

        Phoenix.PubSub.broadcast(Pokex.PubSub, current_room.id, {:get_users_who_voted, user.id})
      end

      {:ok, assign(socket, assigns)}
    else
      {:error, :no_such_user} -> {:ok, redirect(socket, to: "/join/room/#{room_id}")}
      {:error, :no_such_room} -> {:ok, redirect(socket, to: "/join/room/#{room_id}")}
      {:error, :room_not_found} -> {:ok, redirect(socket, to: "/rooms?not-found")}
    end
  end

  @impl true
  def handle_event("submit-vote", %{"vote" => vote}, socket) do
    vote = String.to_integer(vote)
    Phoenix.PubSub.broadcast(
      Pokex.PubSub,
      socket.assigns.current_room.id,
      {:user_voted, socket.assigns.user.id}
    )

    {:noreply, update(socket, :vote, fn _vote -> vote end)}
  end

  @impl true
  def handle_event("show-results", _params, socket) do
    Phoenix.PubSub.broadcast(
      Pokex.PubSub,
      socket.assigns.current_room.id,
      {:show_results}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset", _params, socket) do
    Logger.info("Haldle event: reset")
    Phoenix.PubSub.broadcast(
      Pokex.PubSub,
      socket.assigns.current_room.id,
      {:reset}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_voted, user_id}, socket) do
    socket = update(
      socket,
      :users_who_voted,
      &Map.update(&1, user_id, true, fn _vote -> true end)
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info(
    %Phoenix.Socket.Broadcast{
      event: "presence_diff",
      payload: %{joins: joins, leaves: leaves}
    },
    socket
  ) do
    socket =
      socket
      |> update(:users, &(Map.merge(&1, normalize_presence(joins))))
      |> update(:users, &(Map.drop(&1, Map.keys(leaves))))
      |> update(:users_who_voted, &(Map.drop(&1, Map.keys(leaves))))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:get_users_who_voted, caller_id}, socket) do
    if socket.assigns.vote do
      Phoenix.PubSub.broadcast(Pokex.PubSub, caller_id, {:user_voted, socket.assigns.user.id})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:show_results}, socket) do
    Phoenix.PubSub.broadcast(
      Pokex.PubSub,
      socket.assigns.current_room.id,
      {:vote, socket.assigns.user.id, socket.assigns.vote}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:vote, user_id, vote}, socket) do
    socket = update(socket, :votes, &Map.put(&1, user_id, vote))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:reset}, socket) do
    Logger.info("Haldle info: :reset")
    socket =
      socket
      |> update(:vote, fn _ -> nil end)
      |> update(:votes, fn _ -> %{} end)
      |> update(:users_who_voted, fn _ -> %{} end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:room_deleted}, socket) do
    Logger.info("Handle info: :room_deleted")
    socket =
      socket
      |> put_flash(:error, "This room is no longer available")
      |> update(:active?, fn _ -> false end)

    {:noreply, socket}
  end

  defp normalize_presence(data) do
    data
    |> Enum.map(fn {k, %{metas: [meta | _]}} ->
      {k, meta |> Map.take([:name])}
    end)
    |> Map.new()
  end

  defp get_current_user(%{"user" => user}), do: {:ok, user}
  defp get_current_user(_session), do: {:error, :no_such_user}

  defp get_current_room(user, room_id) do
    if Map.has_key?(user.rooms, room_id) do
      try do
        {:ok, Rooms.get_room!(room_id)}
      rescue
        Ecto.NoResultsError -> {:error, :room_not_found}
      end
    else
      {:error, :no_such_room}
    end
  end
end
