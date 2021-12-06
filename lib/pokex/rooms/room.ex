defmodule Pokex.Rooms.Room do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "rooms" do
    field :active_at, :utc_datetime
    field :name, :string
    field :owner_count, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :active_at, :owner_count])
    |> validate_required([:name, :active_at, :owner_count])
  end
end
