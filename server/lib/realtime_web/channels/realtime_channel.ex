defmodule RealtimeWeb.RealtimeChannel do
  use RealtimeWeb, :channel
  require Logger, warn: false

  alias RealtimeWeb.ChannelsAuthorization
  alias Realtime.Walrus.Subscriptions

  intercept ["INSERT", "UPDATE", "DELETE"]

  def join("realtime:" <> _ = topic, %{"user_token" => token}, socket) when is_binary(token) do
    socket =
      case ChannelsAuthorization.authorize(token) do
        {:ok, %{"sub" => user_id}} when is_binary(user_id) ->
          Subscriptions.add_topic_subscriber!(user_id, topic)
          user_socket = assign(socket, :user_id, user_id)
          Realtime.SubscriptionMonitor.track_topic_subscriber(user_socket)
          user_socket

        _ ->
          socket
      end

    {:ok, socket}
  end

  def join("realtime:" <> _, _, socket) do
    {:ok, socket}
  end

  def handle_out(event, %{is_rls_enabled: is_rls_enabled, users: users} = msg, socket) do
    user_id = socket.assigns[:user_id]

    if not is_rls_enabled or (is_binary(user_id) and user_id in users) do
      push(socket, event, msg)
    end

    {:noreply, socket}
  end

  @doc """
  Handles a full, decoded transation.
  """
  def handle_realtime_transaction(topic, txn) do
    RealtimeWeb.Endpoint.broadcast_from!(self(), topic, txn.type, txn)
  end
end
