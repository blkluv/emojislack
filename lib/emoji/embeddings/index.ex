defmodule Emoji.Embeddings.Index do
  @moduledoc """
  Index for embedding search.
  """
  use GenServer
  require Logger
  @me __MODULE__

  def start_link(_opts) do
    GenServer.start_link(@me, [], name: @me)
  end

  def init(_args) do
    {:ok, full_index} = HNSWLib.Index.new(:l2, 1024, 100_000)
    {:ok, image_index} = HNSWLib.Index.new(:l2, 1024, 100_000)

    Emoji.Predictions.list_predictions_with_text_embeddings()
    |> Enum.each(fn prediction ->
      HNSWLib.Index.add_items(full_index, Nx.from_binary(prediction.embedding, :f32),
        ids: Nx.tensor([prediction.id])
      )
    end)

    Emoji.Predictions.list_predictions_with_image_embeddings()
    |> Enum.each(fn prediction ->
      HNSWLib.Index.add_items(image_index, Nx.from_binary(prediction.image_embedding, :f32),
        ids: Nx.tensor([prediction.id])
      )
    end)

    Logger.info("Index successfully created")
    {:ok, %{full_index: full_index, image_index: image_index}}
  end

  def search(embedding, k) do
    Logger.info("Searching text")
    GenServer.call(@me, {:search, embedding, k}, 15_000)
  end

  def search_images(embedding, k) do
    Logger.info("Searching images")
    GenServer.call(@me, {:search_images, embedding, k}, 15_000)
  end

  def handle_call({:search, embedding, k}, _from, %{full_index: index} = index_dict) do
    {:ok, labels, dists} = HNSWLib.Index.knn_query(index, embedding, k: k)
    {:reply, %{labels: labels, distances: dists}, index_dict}
  end

  def handle_call({:search_images, embedding, k}, _from, %{image_index: index} = index_dict) do
    {:ok, labels, dists} = HNSWLib.Index.knn_query(index, embedding, k: k)
    {:reply, %{labels: labels, distances: dists}, index_dict}
  end

  def terminate(reason, _state) do
    Logger.error("#{__MODULE__} terminated due to #{inspect(reason)}")
  end
end
