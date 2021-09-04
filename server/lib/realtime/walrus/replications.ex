defmodule Realtime.Walrus.Replications do
  def fetch_changes! do
    Postgrex.query!(
      Postgrex,
      "select
        xyz.wal,
        xyz.is_rls_enabled,
        xyz.users,
        xyz.errors
      from
        pg_logical_slot_get_changes(
            'realtime',
            -- Required Config
            null, null,
            'include-pk', '1',
            'include-transaction', 'false',
            'format-version', '2',
            'filter-tables', 'cdc.*',
            -- Optional Config
            'actions', 'insert,update,delete'
        ),
      lateral (
        select
          x.wal,
          x.is_rls_enabled,
          x.users,
          x.errors
        from
          cdc.apply_rls(data::jsonb) x(wal, is_rls_enabled, users, errors)
      ) xyz;",
      []
    )
  end
end
