defmodule Pokex.Repo.Migrations.AddOwnerCountFieldToRoomsTable do
  use Ecto.Migration

  def change do
    alter table("rooms") do
      add :owner_count, :integer, default: 0
    end
  end
end
