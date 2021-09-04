defmodule Realtime.Walrus.Subscriptions do
  def add_topic_subscriber!(user_id, "realtime:" <> sub_topic) do
    query_params(user_id, sub_topic)
    |> case do
      [_ | _] = params ->
        Postgrex.query!(
          Postgrex,
          "insert into cdc.subscription(user_id, entity, filters)
          values ($1::text::uuid, $2::text::regclass, $3::cdc.user_defined_filter[])
          on conflict (user_id, entity, filters) do nothing;",
          params
        )

      _ ->
        nil
    end
  end

  def remove_topic_subscriber!(user_id, "realtime:" <> sub_topic) do
    query_params(user_id, sub_topic)
    |> case do
      [_ | _] = params ->
        Postgrex.query!(
          Postgrex,
          "delete from cdc.subscription
            where user_id = $1::text::uuid
            and entity = $2::text::regclass
            and filters = $3::cdc.user_defined_filter[];",
          params
        )

      _ ->
        nil
    end
  end

  def remove_subscriber!(user_id) do
    Postgrex.query!(
      Postgrex,
      "delete from cdc.subscription
        where user_id = $1::text::uuid;",
      [user_id]
    )
  end

  defp query_params(user_id, topic) do
    case String.split(topic, ":") do
      [schema, table, filter] ->
        [
          user_id,
          schema <> "." <> table,
          [List.to_tuple(String.split(filter, ~r/(\=|\.)/))]
        ]

      [schema, table] ->
        [
          user_id,
          schema <> "." <> table,
          []
        ]

      _ ->
        []
    end
  end
end
