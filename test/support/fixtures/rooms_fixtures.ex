defmodule Pokex.RoomsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Pokex.Rooms` context.
  """

  @doc """
  Generate a room.
  """
  def room_fixture(attrs \\ %{}) do
    {:ok, room} =
      attrs
      |> Enum.into(%{
        active_at: ~U[2021-11-25 15:49:00Z],
        name: "some name"
      })
      |> Pokex.Rooms.create_room()

    room
  end
end
