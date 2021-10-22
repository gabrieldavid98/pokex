defmodule PokexWeb.RoomLive do
  use PokexWeb, :live_view
  require Logger

  alias PokexWeb.Presence

  @impl true
  def mount(params, session, socket) do
    room_id = params["id"]

    if Map.has_key?(session, "user") do
      user = Map.get(session, "user")

      if Map.has_key?(user.rooms, room_id) do
        current_room = Map.get(user.rooms, room_id) |> Map.put(:id, room_id)
        user = Map.put(user, :is_current_room_owner?, current_room.owner)
        assigns = %{
          user: user,
          current_room: current_room,
          users: normalize_presence(Presence.list(room_id)),
          fib: [1, 2, 3, 5, 8, 13, 21, 34, 55, 89],
          vote: nil,
          votes: %{},
          users_who_voted: %{},
        }

        if connected?(socket) do
          Phoenix.PubSub.subscribe(Pokex.PubSub, room_id, metadata: :room)
          Phoenix.PubSub.subscribe(Pokex.PubSub, user.id, metadata: :user)
          Presence.track(self(), room_id, user.id, %{name: user.name})

          Phoenix.PubSub.broadcast(Pokex.PubSub, current_room.id, {:get_users_who_voted, user.id})
        end

        {:ok, assign(socket, assigns)}
      else
        {:ok, redirect(socket, to: "/rooms")}
      end
    else
      {:ok, redirect(socket, to: "/join/room/#{room_id}")}
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

  defp normalize_presence(data) do
    data
    |> Enum.map(fn {k, %{metas: [meta | _]}} ->
      {k, meta |> Map.take([:name])}
    end)
    |> Map.new()
  end
end
