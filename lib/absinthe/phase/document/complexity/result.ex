defmodule Absinthe.Phase.Document.Complexity.Result do
  @moduledoc false

  # Collects complexity errors into the result.

  alias Absinthe.{Blueprint, Phase}

  use Absinthe.Phase

  @doc """
  Run the validation.
  """
  @spec run(Blueprint.t, Keyword.t) :: Phase.result_t
  def run(input, options \\ []) do
    max = Keyword.get(options, :max_complexity, :infinity)
    operation = Blueprint.current_operation(input)
    fun = &handle_node(&1, max, &2)
    {operation, errors} = Blueprint.prewalk(operation, [], fun)
    result = Blueprint.update_current(input, fn(_) -> operation end)
    result = put_in(result.resolution.validation, errors)
    case {errors, Map.new(options)} do
      {[_|_], %{jump_phases: true, result_phase: abort_phase}} ->
        {:jump, result, abort_phase}
      _ ->
        {:ok, result}
    end
  end

  defp handle_node(%{complexity: complexity} = node, max, errors)
       when is_integer(complexity) and complexity > max do
    error = error(node, complexity, max)
    node =
      node
      |> flag_invalid(:too_complex)
      |> put_error(error)
    {node, [error | errors]}
  end
  defp handle_node(%{complexity: _} = node, _, errors) do
    {:halt, node, errors}
  end
  defp handle_node(node, _, errors) do
    {node, errors}
  end

  defp error(%{source_location: location} = node, complexity, max) do
    Phase.Error.new(
      __MODULE__,
      error_message(node, complexity, max),
      location: location
    )
  end

  def error_message(node, complexity, max) do
    "#{describe_node(node)} is too complex: complexity is #{complexity} and maximum is #{max}"
  end

  defp describe_node(%Blueprint.Document.Operation{name: nil}) do
    "Operation"
  end
  defp describe_node(%Blueprint.Document.Operation{name: name}) do
    "Operation #{name}"
  end
  defp describe_node(%Blueprint.Document.Field{name: name}) do
    "Field #{name}"
  end
end
