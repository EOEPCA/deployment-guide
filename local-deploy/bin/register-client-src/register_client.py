#!/usr/bin/env python3

from eoepca_scim import EOEPCA_Scim, ENDPOINT_AUTH_CLIENT_POST
import sys
import os
import requests
from urllib3.exceptions import InsecureRequestWarning

def main():
  if len(sys.argv) < 3:
    print("ERROR: not enough args", file=sys.stderr)
    usage()
    exit(1)

  requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

  auth_server = sys.argv[1]
  client_name = sys.argv[2]
  scim_client = EOEPCA_Scim(f"https://{auth_server}")
  client = scim_client.registerClient(
    client_name,
    grantTypes = ["client_credentials", "password", "urn:ietf:params:oauth:grant-type:uma-ticket"],
    redirectURIs = [""],
    logoutURI = "",
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
  {} <authorization-server-hostname> <client-name>
'''.format(os.path.basename(sys.argv[0])), file=sys.stderr)

if __name__ == "__main__":
  main()
