# KV v2: чтение secret/test. Для API путь secret/data/test.
path "secret/data/test" {
  capabilities = ["read"]
}