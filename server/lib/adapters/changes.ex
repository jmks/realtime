# This file draws heavily from https://github.com/cainophile/cainophile
# License: https://github.com/cainophile/cainophile/blob/master/LICENSE

require Protocol

defmodule Realtime.Adapters.Changes do
  defmodule(Transaction, do: defstruct([:changes, :commit_timestamp]))

  defmodule NewRecord do
    @derive Jason.Encoder
    defstruct [:type, :record, :schema, :table, :columns, :users, :is_rls_enabled, :errors]
  end

  defmodule UpdatedRecord do
    @derive Jason.Encoder
    defstruct [
      :type,
      :old_record,
      :record,
      :schema,
      :table,
      :columns,
      :users,
      :is_rls_enabled,
      :errors
    ]
  end

  defmodule DeletedRecord do
    @derive Jason.Encoder
    defstruct [:type, :old_record, :schema, :table, :columns, :users, :is_rls_enabled, :errors]
  end

  defmodule(TruncatedRelation, do: defstruct([:type, :schema, :table, :commit_timestamp]))
end

Protocol.derive(Jason.Encoder, Realtime.Adapters.Changes.Transaction)
Protocol.derive(Jason.Encoder, Realtime.Adapters.Changes.TruncatedRelation)
Protocol.derive(Jason.Encoder, Realtime.Adapters.Postgres.Decoder.Messages.Relation.Column)
