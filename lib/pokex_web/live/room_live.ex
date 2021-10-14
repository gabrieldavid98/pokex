defmodule PokexWeb.RoomLive do
  use PokexWeb, :live_view
  require Logger

  @impl true
  def mount(params, session, socket) do
    room_id = params["id"]

    if Map.has_key?(session, "user") do
      user = Map.get(session, "user")
      current_room = Map.get(user.rooms, room_id)
      user = Map.put(user, :is_current_room_owner?, current_room.owner)

      {:ok, assign(socket, %{user: user, current_room: current_room})}
    else
      {:ok, redirect(socket, to: "/join/room/#{room_id}")}
    end
  end
end
