import base64
import contextlib
import hashlib
import os
import re
import secrets
import subprocess
from urllib.parse import parse_qs, unquote, urlparse

import requests

test_results = {}

def load_eoepca_state():
    # Source the eoepca state and capture the exported variables
    proc = subprocess.Popen(
        "source $HOME/.eoepca/state && env",
        stdout=subprocess.PIPE,
        shell=True,
        executable="/bin/bash",
    )
    output, _ = proc.communicate()
    # Parse the variables and update the environment
    for line in output.decode("utf-8").splitlines():
        key, _, value = line.partition("=")
        os.environ[key] = value


def get_access_token(username, password, client_id, client_secret=None):
    url = f"{os.environ['HTTP_SCHEME']}://{os.environ['KEYCLOAK_HOST']}/realms/eoepca/protocol/openid-connect/token"
    payload = {
        "username": username,
        "password": password,
        "grant_type": "password",
        "client_id": client_id,
        "scope": "openid profile email offline_access",
    }
    if client_secret:
        payload["client_secret"] = client_secret

    headers = {
        "Content-Type": "application/x-www-form-urlencoded",
    }
    response = requests.post(url, data=payload, headers=headers)
    response.raise_for_status()
    access_token = response.json()["access_token"]
    return access_token


def authenticate_public_client(keycloak_host, realm, client_id, redirect_uri, username, password, http_scheme="https"):
    # Authorization Code + PKCE, with the login form submitted directly - for PUBLIC
    # clients that have directAccessGrantsEnabled=false (no password grant available),
    # so get_access_token() doesn't apply, but interactive device-code login isn't
    # scriptable either. Only works against Keycloak's own default login form.
    verifier = base64.urlsafe_b64encode(secrets.token_bytes(32)).rstrip(b"=").decode()
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(16)

    session = requests.Session()
    auth_response = session.get(
        f"{http_scheme}://{keycloak_host}/realms/{realm}/protocol/openid-connect/auth",
        params={
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": "openid",
            "state": state,
            "code_challenge": challenge,
            "code_challenge_method": "S256",
        },
    )
    auth_response.raise_for_status()
    form_action = re.search(r'action="([^"]+)"', auth_response.text)
    if not form_action:
        raise RuntimeError("Could not find Keycloak login form on the authorization page")
    login_response = session.post(
        unquote(form_action.group(1)).replace("&amp;", "&"),
        data={"username": username, "password": password},
        allow_redirects=False,
    )
    location = login_response.headers.get("Location", "")
    code = parse_qs(urlparse(location).query).get("code")
    if not code:
        raise RuntimeError(f"Keycloak login did not return an authorization code (redirected to: {location})")

    token_response = requests.post(
        f"{http_scheme}://{keycloak_host}/realms/{realm}/protocol/openid-connect/token",
        data={
            "grant_type": "authorization_code",
            "code": code[0],
            "redirect_uri": redirect_uri,
            "client_id": client_id,
            "code_verifier": verifier,
        },
    )
    token_response.raise_for_status()
    return token_response.json()["access_token"]


def oidc_session_login(base_url, login_path, username, password):
    # Scripted browser-style OIDC login for Django apps using mozilla_django_oidc:
    # follows the app's own login-initiation redirect to Keycloak, submits the
    # login form, and returns the requests.Session holding the resulting
    # session/CSRF cookies - for apps whose API auth is session-based (DRF
    # SessionAuthentication) rather than accepting the Keycloak-issued token
    # as a Bearer token directly.
    session = requests.Session()
    response = session.get(f"{base_url}{login_path}")
    response.raise_for_status()
    form_action = re.search(r'action="([^"]+)"', response.text)
    if not form_action:
        raise RuntimeError("Could not find Keycloak login form on the authorization page")
    login_response = session.post(
        unquote(form_action.group(1)).replace("&amp;", "&"),
        data={"username": username, "password": password},
    )
    login_response.raise_for_status()
    if "sessionid" not in session.cookies:
        raise RuntimeError("OIDC login did not establish an authenticated session")
    return session


@contextlib.contextmanager
def test_cell(name):
    try:
        yield
        test_results[name] = {'status': 'PASS', 'message': ''}
    except AssertionError as e:
        test_results[name] = {'status': 'FAIL', 'message': f"Assertion failed: {e}"}
        print(f"[{name}] Assertion failed: {e}")
    except Exception as e:
        test_results[name] = {'status': 'FAIL', 'message': str(e)}
        print(f"[{name}] Exception: {e}")