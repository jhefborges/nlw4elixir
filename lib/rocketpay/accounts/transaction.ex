defmodule Rocketpay.Accounts.Transaction do

  alias Ecto.Multi

  alias Rocketpay.{Account, Repo, User}
  alias Rocketpay.Accounts.Operation
  alias Rocketpay.Accounts.Transaction.Response, as: TransactionResponse

  def call(%{"from" => from_id, "to" => to_id, "value" => value}) do
    withdraw_params = build_params(from_id, value)
    deposit_params  = build_params(to_id, value)

    Multi.new()
    |> Multi.merge(fn _changes -> Operation.call(withdraw_params, :withdraw) end)
    |> Multi.merge(fn _changes -> Operation.call(deposit_params, :deposit) end)
    |> run_transaction(value)
  end

  defp build_params(id, value), do: %{"id" => id, "value" => value}

  defp run_transaction(multi, value) do
    case Repo.transaction(multi) do
      {:error, _operation, reason, _changes} -> {:error, reason}
      {:ok, %{deposit: to_account, withdraw: from_account}} ->
        Task.start(fn -> print_proof(from_account, to_account, value) end)
        {:ok, TransactionResponse.build(from_account, to_account)}
    end
  end

  defp print_proof(from_account, to_account, value) do
    nick_from = get_nickname(from_account)
    nick_to = get_nickname(to_account)
    prof_text = "Transaction from #{nick_from} to #{nick_to} value #{value}"
    File.write!("./.proof/prof.txt", prof_text)
  end


  defp get_nickname(account) do
    user = Repo.preload(account, :user).user
    user.nickname
  end

end
