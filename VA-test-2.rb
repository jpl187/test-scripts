#!/usr/bin/env ruby

require 'async'
require 'vaas/client_credentials_grant_authenticator'
require 'vaas/vaas_main'

authenticator = VAAS::ClientCredentialsGrantAuthenticator.new(
  CLIENT_ID,
  CLIENT_SECRET,
  TOKEN_URL,
  SSL_VERIFICATION
)
vaas = VAAS::VaasMain.new
token = authenticator.get_token

Async do
  vaas.connect(token)
  path = "/path/to/file"
  verdict = vaas.for_file(path) 
  puts verdict.wait.verdict 
  vaas.close
end
