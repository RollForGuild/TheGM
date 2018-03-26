defmodule Thegm.Repo.Migrations.AlterGroupThreads do
  use Ecto.Migration

  def change do
    alter table(:group_threads) do
      add :deleted, :boolean, null: false, default: false
    end
  end
end
