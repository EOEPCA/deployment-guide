#!/usr/bin/env python3

from eoepca_scim import EOEPCA_Scim, ENDPOINT_AUTH_CLIENT_POST
import sys
import os
import requests
from urllib3.exceptions import InsecureRequestWarning

def main():
  # Mandatory command-line args
  if len(sys.argv) >= 3:
    auth_server = sys.argv[1]
    client_name = sys.argv[2]
    redirectURIs = [""]
    logoutURI = ""
  else:
    print("ERROR: not enough args", file=sys.stderr)
    usage()
    exit(1)

  # Optional command-line args
  if len(sys.argv) >= 4:
    redirectURIs = [ sys.argv[3] ]
  if len(sys.argv) >= 5:
    logoutURI = sys.argv[4]

  # Ignore TLS validation errors
  requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

  # Use SCIM to register the client
  scim_client = EOEPCA_Scim(f"https://{auth_server}")
  client = scim_client.registerClient(
    client_name,
    grantTypes = ["client_credentials", "password", "urn:ietf:params:oauth:grant-type:uma-ticket"],
    redirectURIs = redirectURIs,
    logoutURI = logoutURI,
    responseTypes = ["code","token","id_token"],
    subject_type = "public",
    scopes = ['openid',  'email', 'user_name ','uma_protection', 'permission', 'is_operator'],
    token_endpoint_auth_method = ENDPOINT_AUTH_CLIENT_POST)

  print('''Client successfully registered.
Make a note of the credentials...'''.format(client["client_id"], client["client_secret"]), file=sys.stderr)

  print('''client-id: {}
client-secret: {}'''.format(client["client_id"], client["client_secret"]))

def usage():
  print('''
Usage:
  {} <authorization-server-hostname> <client-name> [<redirect-uri> [<logout-uri>]]
'''.format(os.path.basename(sys.argv[0])), file=sys.stderr)

if __name__ == "__main__":
  main()
