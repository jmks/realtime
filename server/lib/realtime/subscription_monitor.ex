# This file draws from https://github.com/pushex-project/pushex
# License: https://github.com/pushex-project/pushex/blob/master/LICENSE

defmodule Realtime.SubscriptionMonitor do
  use GenServer

  alias Realtime.Walrus.Subscriptions

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, %{}}
  end

  def track_topic_subscriber(socket = %Phoenix.Socket{}) do
    GenServer.cast(__MODULE__, {:track_topic_subscriber, socket})
  end

  ## Callbacks

  def handle_cast(
        {:track_topic_subscriber,
         %Phoenix.Socket{assigns: %{user_id: user_id}, channel_pid: channel_pid, topic: topic}},
        state
      ) do
    Process.monitor(channel_pid)

    new_state =
      Map.put(state, channel_pid, %{
        user_id: user_id,
        topic: topic
      })

    {:noreply, new_state}
  end

  def handle_info(
        {:DOWN, _ref, :process, pid, _reason},
        state
      ) do
    case Map.fetch(state, pid) do
      {:ok, %{user_id: user_id, topic: topic}} ->
        Subscriptions.remove_topic_subscriber!(user_id, topic)

      _ ->
        nil
    end

    {:noreply, Map.delete(state, pid)}
  end
end
