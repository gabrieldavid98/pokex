defmodule Pokex.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :active_at, :utc_datetime

      timestamps()
    end
  end
end
