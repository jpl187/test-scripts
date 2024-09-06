#!/usr/bin/env ruby

require 'vaas/client_credentials_grant_authenticator'
require 'vaas/resource_owner_password_grant_authenticator'
require 'vaas/vaas_main'
require 'async'


def main
    client_id = ENV.fetch("VAAS_CLIENT_ID")
    client_secret = ENV.fetch("CLIENT_SECRET")
    user_name = ENV.fetch("VAAS_USER_NAME")
    password = ENV.fetch("VAAS_PASSWORD")
    token_url = ENV.fetch("TOKEN_URL") || "https://account.gdata.de/realms/vaas-production/protocol/openid-connect/token"
    vaas_url = ENV.fetch("VAAS_URL") || "wss://gateway.production.vaas.gdatasecurity.de"
    test_url = "https://gdata.de"

    #If you got a username and password from us, you can use the ResourceOwnerPasswordAuthenticator like this
    authenticator = VAAS::ResourceOwnerPasswordGrantAuthenticator.new(
      client_id,
      user_name,
      password,
      token_url
    )
vaas = VAAS::VaasMain.new
token = authenticator.get_token

Async do
  vaas.connect(token)
  path = "/var/spool/postfix/incoming/*"
  verdict = vaas.for_file(path) 
  puts verdict.wait.verdict 
  vaas.close
end
