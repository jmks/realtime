defmodule Realtime.RLS.Replications do
  import Realtime.RLS.Repo

  alias Ecto.Multi

  def prepare_replication(slot_name, temporary_slot) do
    Multi.new()
    |> Multi.run(:create_slot, fn _, _ ->
      query(
        "select 1 from pg_create_logical_replication_slot($1, 'wal2json', $2);",
        [slot_name, temporary_slot]
      )
      |> case do
        {:ok, %Postgrex.Result{rows: [[1]]}} ->
          {:ok, slot_name}

        {:error,
         %Postgrex.Error{
           postgres: %{
             code: :duplicate_object,
             routine: "ReplicationSlotCreate"
           }
         }} ->
          {:ok, slot_name}

        {_, error} ->
          {:error, error}
      end
    end)
    |> Multi.run(:search_path, fn _, _ ->
      # Enable schema-qualified table names for public schema
      # when casting prrelid to regclass in poll query
      case query("set search_path = ''", []) do
        {:ok, %Postgrex.Result{command: command}} -> {:ok, command}
        {_, error} -> {:error, error}
      end
    end)
    |> transaction()
    |> case do
      {:ok, multi_map} -> {:ok, multi_map}
      {:error, error} -> {:error, error}
      {:error, _, error, _} -> {:error, error}
    end
  end

  def list_changes(slot_name, publication) do
    query(
      "with pub as (
        select
          pp.pubname pub_name,
          bool_or(puballtables) pub_all_tables,
          (
            select string_agg(act.name_, ',') actions
            from
              unnest(array[
                case when bool_or(pubinsert) then 'insert' else null end,
                case when bool_or(pubupdate) then 'update' else null end,
                case when bool_or(pubdelete) then 'delete' else null end
              ]) act(name_)
          ) w2j_actions,
          string_agg(cdc.quote_wal2json(prrelid::regclass), ',') w2j_add_tables
        from
          pg_publication pp
          left join pg_publication_rel ppr
            on pp.oid = ppr.prpubid
        where
          pp.pubname = $1
        group by
          pp.pubname
        limit 1
      )
      select
        xyz.wal,
        xyz.is_rls_enabled,
        xyz.users,
        xyz.errors
      from
        pub,
        lateral (
          select
            *
          from
            pg_logical_slot_get_changes(
              $2, null, null,
              'include-pk', '1',
              'include-transaction', 'false',
              'include-timestamp', 'true',
              'write-in-chunks', 'true',
              'format-version', '2',
              'actions', coalesce(pub.w2j_actions, ''),
              'add-tables', coalesce(pub.w2j_add_tables, '')
            )
          ) w2j,
          lateral (
            select
              x.wal,
              x.is_rls_enabled,
              x.users,
              x.errors
            from
              cdc.apply_rls(w2j.data::jsonb) x(wal, is_rls_enabled, users, errors)
          ) xyz
      where pub.pub_all_tables or
        (pub.pub_all_tables is false and w2j_add_tables is not null)",
      [publication, slot_name]
    )
  end
end
