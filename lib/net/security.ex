defmodule Net.Security do
  def decrypt(iv, ciphertext, tag) do
    key = Application.get_env(:prism, :key)
    if byte_size(key) != 32 do
      {:error, :invalid_key_size, byte_size(key)}
    else
      try do
        case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, <<>>, tag, false) do
          :error ->
            {:error, :decryption_failed}
          dec ->
            {:ok, dec}
        end
      catch
        :error, _ ->
          {:error, :decryption_failed}
      end
    end
  end

  def encrypt(data) do
    key = Application.get_env(:prism, :key)
    iv = :crypto.strong_rand_bytes(12)
    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, data, <<>>, true)
    {iv, ciphertext, tag}
  end
end
