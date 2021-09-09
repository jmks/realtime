# This file draws heavily from https://github.com/cainophile/cainophile
# License: https://github.com/cainophile/cainophile/blob/master/LICENSE

defmodule Realtime.Replication do
  use GenServer

  require Logger

  alias Realtime.Walrus.Replications

  alias Realtime.Adapters.Changes.{
    NewRecord,
    UpdatedRecord,
    DeletedRecord
  }

  alias Realtime.SubscribersNotification

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    send(self(), :poll)
    {:ok, nil}
  end

  @impl true
  def handle_info(:poll, state) do
    %{num_rows: num_rows, rows: rows, columns: columns} = Replications.fetch_changes!()

    if num_rows > 0 do
      rows
      |> Enum.reduce([], fn row, acc -> [Map.new(Enum.zip(columns, row)) | acc] end)
      |> Enum.reduce([], fn record, acc ->
        record
        |> cast_user_ids()
        |> transform_record()
        |> case do
          nil -> acc
          rec -> [rec | acc]
        end
      end)
      |> SubscribersNotification.notify()
    end

    Process.send_after(
      self(),
      :poll,
      Application.fetch_env!(:realtime, :replication_poll_interval)
    )

    {:noreply, state}
  end

  defp cast_user_ids(%{"users" => users} = record) do
    Map.put(record, "users", Enum.map(users, &Ecto.UUID.load!(&1)))
  end

  defp transform_record(%{
         "errors" => errors,
         "is_rls_enabled" => is_rls_enabled,
         "users" => users,
         "wal" => %{
           "action" => "I",
           "columns" => columns,
           "schema" => schema,
           "table" => table
         }
       }) do
    record = %NewRecord{
      type: "INSERT",
      schema: schema,
      table: table,
      users: users,
      is_rls_enabled: is_rls_enabled,
      errors: errors,
      columns: [],
      record: %{}
    }

    columns
    |> Enum.reduce(record, fn %{"name" => name, "type" => type, "value" => value}, acc ->
      acc
      |> Map.put(:columns, [%{type: type, name: name} | acc.columns])
      |> Map.put(:record, Map.put(acc.record, name, value))
    end)
    |> Map.update!(:columns, &Enum.reverse(&1))
    |> Map.update!(:errors, fn errors ->
      case List.first(errors) do
        nil -> nil
        _ -> errors
      end
    end)
  end

  defp transform_record(%{
         "errors" => errors,
         "is_rls_enabled" => is_rls_enabled,
         "users" => users,
         "wal" => %{
           "action" => "U",
           "columns" => columns,
           "schema" => schema,
           "table" => table,
           "identity" => identity
         }
       }) do
    record = %UpdatedRecord{
      type: "UPDATE",
      schema: schema,
      table: table,
      users: users,
      is_rls_enabled: is_rls_enabled,
      errors: errors,
      columns: [],
      record: %{},
      old_record: %{}
    }

    record =
      Enum.reduce(columns, record, fn %{"name" => name, "type" => type, "value" => value}, acc ->
        acc
        |> Map.put(:columns, [%{type: type, name: name} | acc.columns])
        |> Map.put(:record, Map.put(acc.record, name, value))
      end)
      |> Map.update!(:columns, &Enum.reverse(&1))
      |> Map.update!(:errors, fn errors ->
        case List.first(errors) do
          nil -> nil
          _ -> errors
        end
      end)

    Enum.reduce(identity, record, fn %{"name" => name, "value" => value}, acc ->
      Map.put(acc, :old_record, Map.put(acc.old_record, name, value))
    end)
  end

  defp transform_record(%{
         "errors" => errors,
         "is_rls_enabled" => is_rls_enabled,
         "users" => users,
         "wal" => %{
           "action" => "D",
           "schema" => schema,
           "table" => table,
           "identity" => identity
         }
       }) do
    record = %DeletedRecord{
      type: "DELETE",
      schema: schema,
      table: table,
      users: users,
      is_rls_enabled: is_rls_enabled,
      errors: errors,
      columns: [],
      old_record: %{}
    }

    Enum.reduce(identity, record, fn %{"name" => name, "type" => type, "value" => value}, acc ->
      acc
      |> Map.put(:columns, [%{type: type, name: name} | acc.columns])
      |> Map.put(:old_record, Map.put(acc.old_record, name, value))
    end)
    |> Map.update!(:columns, &Enum.reverse(&1))
    |> Map.update!(:errors, fn errors ->
      case List.first(errors) do
        nil -> nil
        _ -> errors
      end
    end)
  end

  defp transform_record(_), do: nil
end
