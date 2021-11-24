defmodule Realtime.RLS.Repo.Migrations.AddRealtimeSchema do
  use Ecto.Migration

  def change do
    execute("CREATE SCHEMA IF NOT EXISTS realtime;")
    execute("GRANT USAGE ON SCHEMA realtime TO postgres;")
    execute("GRANT ALL ON ALL TABLES IN SCHEMA realtime TO postgres, dashboard_user;")
    execute("GRANT ALL ON ALL SEQUENCES IN SCHEMA realtime TO postgres, dashboard_user;")
    execute("GRANT ALL ON ALL ROUTINES IN SCHEMA realtime TO postgres, dashboard_user;")
  end
end
