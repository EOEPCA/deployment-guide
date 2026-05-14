import logging

import pytest
from cql2 import Expr

import eoepca_filters
from eoepca_filters import CollectionsFilter, ItemsFilter, is_write_request

# Reusable request context fragments
_READ_REQ = {"method": "GET", "path": "/collections"}
_WRITE_REQ = {"method": "POST", "path": "/collections"}

# Default-config token carrying the stac_editor role on the eoapi client.
# `azp` matches the configured editor client — required by _token_has_stac_editor.
_EDITOR_TOKEN = {
    "azp": "eoapi",
    "resource_access": {"eoapi": {"roles": ["stac_editor"]}},
}


def cql2_matches(cql2_json: dict, item: dict) -> bool:
    """Parse a CQL2-JSON expression and test it against an item dict."""
    expr = Expr(cql2_json)
    expr.validate()
    return expr.matches(item)


class TestIsWriteRequest:
    """is_write_request classifies HTTP requests as read or write."""

    @pytest.mark.parametrize(
        "method",
        [
            pytest.param("GET", id="GET"),
            pytest.param("HEAD", id="HEAD"),
            pytest.param("OPTIONS", id="OPTIONS"),
        ],
    )
    def test_safe_methods_are_reads(self, method):
        """GET, HEAD, and OPTIONS are always read operations."""
        assert not is_write_request({"method": method, "path": "/collections"})

    @pytest.mark.parametrize(
        "path",
        [
            pytest.param("/search", id="search"),
            pytest.param("/search/", id="search-trailing-slash"),
        ],
    )
    def test_post_to_search_is_read(self, path):
        """POST to /search (with or without trailing slash) is a read."""
        assert not is_write_request({"method": "POST", "path": path})

    @pytest.mark.parametrize(
        "method",
        [
            pytest.param("POST", id="POST"),
            pytest.param("PUT", id="PUT"),
            pytest.param("PATCH", id="PATCH"),
            pytest.param("DELETE", id="DELETE"),
        ],
    )
    def test_mutating_methods_are_writes(self, method):
        """POST (non-search), PUT, PATCH, and DELETE are write operations."""
        assert is_write_request({"method": method, "path": "/collections"})

    def test_post_to_items_endpoint_is_write(self):
        """POST to an items endpoint (creating an item) is a write."""
        assert is_write_request({"method": "POST", "path": "/collections/my-col/items"})

    def test_case_insensitive_method(self):
        """HTTP methods are matched case-insensitively."""
        assert not is_write_request({"method": "get", "path": "/collections"})
        assert is_write_request({"method": "post", "path": "/collections"})


class TestCollectionsFilter:
    """CollectionsFilter generates CQL2 filters matching on the 'id' property."""

    # --- Unauthenticated access ---

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "collection_id,expected",
        [
            pytest.param("sentinel-2", True, id="public-allowed"),
            pytest.param("alice.my-data", False, id="prefixed-denied"),
            pytest.param("org.dept.data", False, id="deep-prefix-denied"),
        ],
    )
    async def test_unauthenticated_read_access(self, collection_id, expected):
        """Unauthenticated reads allow public collections but deny prefixed ones."""
        filt = await CollectionsFilter()({"payload": None, "req": _READ_REQ})
        assert cql2_matches(filt, {"id": collection_id}) == expected

    @pytest.mark.asyncio
    async def test_unauthenticated_write_denies_all(self):
        """Unauthenticated users cannot write to any collection."""
        filt = await CollectionsFilter()({"payload": None, "req": _WRITE_REQ})
        assert not cql2_matches(
            filt, {"id": "public"}
        ), "unauthenticated write should deny public collections"
        assert not cql2_matches(
            filt, {"id": "alice.data"}
        ), "unauthenticated write should deny prefixed collections"

    @pytest.mark.asyncio
    async def test_missing_payload_treated_as_unauthenticated(self):
        """A context dict without a 'payload' key is treated as unauthenticated."""
        filt = await CollectionsFilter()({"req": _READ_REQ})
        assert cql2_matches(
            filt, {"id": "public"}
        ), "public collection should be visible when payload key is missing"
        assert not cql2_matches(
            filt, {"id": "alice.data"}
        ), "prefixed collection should not be visible when payload key is missing"

    # --- Authenticated user access (own prefix, other users, public) ---

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "req",
        [
            pytest.param(_READ_REQ, id="read"),
            pytest.param(_WRITE_REQ, id="write"),
        ],
    )
    async def test_authenticated_user_accesses_own_prefix(self, req):
        """Users can access their own prefixed collections for both read and write."""
        token = {"preferred_username": "alice"}
        filt = await CollectionsFilter()({"payload": token, "req": req})
        assert cql2_matches(
            filt, {"id": "alice.my-data"}
        ), "user 'alice' should access her own prefixed collection"

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "req",
        [
            pytest.param(_READ_REQ, id="read"),
            pytest.param(_WRITE_REQ, id="write"),
        ],
    )
    async def test_authenticated_user_denied_other_users_prefix(self, req):
        """A user cannot access collections prefixed with another user's name."""
        token = {"preferred_username": "alice"}
        filt = await CollectionsFilter()({"payload": token, "req": req})
        assert not cql2_matches(
            filt, {"id": "bob.my-data"}
        ), "user 'alice' should not access 'bob.my-data'"

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "req,expected",
        [
            pytest.param(_READ_REQ, True, id="read-allows-public"),
            pytest.param(_WRITE_REQ, False, id="write-denies-public"),
        ],
    )
    async def test_authenticated_public_collection_access(self, req, expected):
        """Authenticated reads see public collections; writes do not."""
        token = {"preferred_username": "alice"}
        filt = await CollectionsFilter()({"payload": token, "req": req})
        assert cql2_matches(filt, {"id": "sentinel-2"}) == expected

    # --- Token without username ---

    @pytest.mark.asyncio
    async def test_token_without_username_only_gets_public_access(self):
        """If preferred_username is missing, only public collections are visible on read."""
        token: dict = {}
        filt = await CollectionsFilter()({"payload": token, "req": _READ_REQ})
        assert cql2_matches(
            filt, {"id": "public"}
        ), "public collection should be visible even without preferred_username"
        assert not cql2_matches(
            filt, {"id": "alice.data"}
        ), "prefixed collection should not be visible without preferred_username"

    @pytest.mark.asyncio
    async def test_write_token_without_username_gets_no_access(self):
        """A token without preferred_username gets no write access at all."""
        token: dict = {}
        filt = await CollectionsFilter()({"payload": token, "req": _WRITE_REQ})
        assert not cql2_matches(
            filt, {"id": "public"}
        ), "write without username should deny public collections"
        assert not cql2_matches(
            filt, {"id": "alice.data"}
        ), "write without username should deny prefixed collections"

    # --- Group-based access ---

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "req",
        [
            pytest.param(_READ_REQ, id="read"),
            pytest.param(_WRITE_REQ, id="write"),
        ],
    )
    async def test_rw_group_grants_access(self, req):
        """A /dss/{prefix} group grants both read and write access."""
        token = {"preferred_username": "alice", "groups": ["/dss/org-dss-team"]}
        filt = await CollectionsFilter()({"payload": token, "req": req})
        assert cql2_matches(
            filt, {"id": "org-dss-team.dataset"}
        ), "rw group should grant access to 'org-dss-team.dataset'"

    @pytest.mark.asyncio
    async def test_rw_group_does_not_grant_access_to_other_prefixes(self):
        """A group only grants access to its own prefix, not unrelated prefixes."""
        token = {"preferred_username": "alice", "groups": ["/dss/org-dss-team"]}
        filt = await CollectionsFilter()({"payload": token, "req": _READ_REQ})
        assert not cql2_matches(
            filt, {"id": "other-dss-org.dataset"}
        ), "group '/dss/org-dss-team' should not grant access to 'other-dss-org.dataset'"

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "req,expected",
        [
            pytest.param(_READ_REQ, True, id="read-grants"),
            pytest.param(_WRITE_REQ, False, id="write-denies"),
        ],
    )
    async def test_ro_group_access_depends_on_mode(self, req, expected):
        """A -ro group grants read access but not write access."""
        token = {"preferred_username": "alice", "groups": ["/dss/org-dss-shared-ro"]}
        filt = await CollectionsFilter()({"payload": token, "req": req})
        assert cql2_matches(filt, {"id": "org-dss-shared.dataset"}) == expected

    @pytest.mark.asyncio
    async def test_ro_group_public_still_visible(self):
        """Public collections remain visible alongside read-only group access."""
        token = {"preferred_username": "alice", "groups": ["/dss/org-dss-shared-ro"]}
        filt = await CollectionsFilter()({"payload": token, "req": _READ_REQ})
        assert cql2_matches(
            filt, {"id": "public-data"}
        ), "public collection 'public-data' should remain visible with ro group membership"

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "req,rw_expected,ro_expected",
        [
            pytest.param(_READ_REQ, True, True, id="read-both-grant"),
            pytest.param(_WRITE_REQ, True, False, id="write-only-rw"),
        ],
    )
    async def test_mixed_rw_and_ro_groups(self, req, rw_expected, ro_expected):
        """Both group types contribute on read; only rw contributes on write."""
        token = {
            "preferred_username": "alice",
            "groups": ["/dss/proj-dss-alpha", "/dss/proj-dss-beta-ro"],
        }
        filt = await CollectionsFilter()({"payload": token, "req": req})
        assert cql2_matches(filt, {"id": "proj-dss-alpha.data"}) == rw_expected
        assert cql2_matches(filt, {"id": "proj-dss-beta.data"}) == ro_expected

    @pytest.mark.asyncio
    async def test_write_user_retains_own_prefix_with_ro_group(self):
        """User can still write to own prefix even when only holding -ro groups."""
        token = {
            "preferred_username": "alice",
            "groups": ["/dss/org-dss-shared-ro"],
        }
        filt = await CollectionsFilter()({"payload": token, "req": _WRITE_REQ})
        assert cql2_matches(
            filt, {"id": "alice.data"}
        ), "user should retain write access to own prefix despite only having ro groups"
        assert not cql2_matches(
            filt, {"id": "org-dss-shared.dataset"}
        ), "ro group should not grant write access"

    # --- Invalid / malformed group handling ---

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "group",
        [
            pytest.param("/other/org-dss-team", id="wrong-prefix"),
            pytest.param("/dss/org-team", id="missing-dss-infix"),
            pytest.param("/dss/org-dss-team-mgr", id="manager-group"),
            pytest.param("org-dss-team", id="no-leading-slash"),
        ],
    )
    async def test_invalid_group_format_grants_no_extra_access(self, group):
        """Groups that don't match '/dss/{name-with-dss-infix}' are silently ignored."""
        token = {"preferred_username": "alice", "groups": [group]}
        filt = await CollectionsFilter()({"payload": token, "req": _READ_REQ})
        assert not cql2_matches(
            filt, {"id": "org-dss-team.data"}
        ), f"invalid group '{group}' should not grant access to 'org-dss-team.data'"
        assert cql2_matches(
            filt, {"id": "alice.data"}
        ), "username-based access should still work despite invalid group"
        assert cql2_matches(
            filt, {"id": "public"}
        ), "public access should still work despite invalid group"

    @pytest.mark.asyncio
    async def test_groups_claim_not_a_list_is_ignored(self):
        """If the 'groups' claim is a string instead of a list, it is ignored gracefully."""
        token = {"preferred_username": "alice", "groups": "not-a-list"}
        filt = await CollectionsFilter()({"payload": token, "req": _READ_REQ})
        assert cql2_matches(
            filt, {"id": "public"}
        ), "public access should work when groups claim is malformed"
        assert cql2_matches(
            filt, {"id": "alice.data"}
        ), "username-based access should work when groups claim is malformed"
        assert not cql2_matches(
            filt, {"id": "not-a-list.data"}
        ), "malformed groups string should not be treated as a collection prefix"

    @pytest.mark.asyncio
    async def test_no_groups_claim_still_allows_username_access(self):
        """A token without a 'groups' claim still grants username-based access."""
        token = {"preferred_username": "bob"}
        filt = await CollectionsFilter()({"payload": token, "req": _READ_REQ})
        assert cql2_matches(
            filt, {"id": "bob.data"}
        ), "user 'bob' should access 'bob.data' even without any groups claim"
        assert cql2_matches(
            filt, {"id": "public"}
        ), "public access should work without groups claim"

    @pytest.mark.asyncio
    async def test_empty_groups_list_grants_no_group_access(self):
        """An empty groups list contributes no extra collection prefixes."""
        token = {"preferred_username": "alice", "groups": []}
        filt = await CollectionsFilter()({"payload": token, "req": _READ_REQ})
        assert cql2_matches(
            filt, {"id": "public"}
        ), "public access should work with empty groups list"
        assert cql2_matches(
            filt, {"id": "alice.data"}
        ), "username-based access should work with empty groups list"
        assert not cql2_matches(
            filt, {"id": "org-dss-team.data"}
        ), "empty groups list should not grant access to any group-prefixed collection"

    # --- Input sanitization ---

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "username",
        [
            pytest.param("' OR 1=1 --", id="sql-injection-style"),
            pytest.param("alice'bob", id="embedded-single-quote"),
            pytest.param("alice.bob", id="dot-in-username"),
            pytest.param("alice bob", id="space-in-username"),
        ],
    )
    async def test_unsafe_username_is_rejected(self, username):
        """Usernames with unsafe characters must not be interpolated into CQL2."""
        token = {"preferred_username": username}
        filt = await CollectionsFilter()({"payload": token, "req": _READ_REQ})
        print("Generated filter:", filt)
        assert cql2_matches(
            filt, {"id": "public"}
        ), "public access should still work with unsafe username"
        assert not cql2_matches(
            filt, {"id": f"{username}.data"}
        ), f"unsafe username {username!r} should not produce a filter granting access"

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "group,derived_prefix",
        [
            pytest.param("/dss/org-dss-t'eam", "org-dss-t'eam", id="single-quote"),
            pytest.param("/dss/org-dss-t eam", "org-dss-t eam", id="space"),
            pytest.param(
                "/dss/' OR 1=1-dss- --",
                "' OR 1=1-dss- --",
                id="cql2-injection",
            ),
        ],
    )
    async def test_unsafe_group_prefix_is_rejected(self, group, derived_prefix):
        """Group names that yield unsafe prefixes must not be interpolated into CQL2."""
        token = {"preferred_username": "alice", "groups": [group]}
        filt = await CollectionsFilter()({"payload": token, "req": _READ_REQ})
        assert not cql2_matches(
            filt, {"id": f"{derived_prefix}.data"}
        ), f"unsafe group {group!r} should not produce a filter granting access"
        assert cql2_matches(
            filt, {"id": "alice.data"}
        ), "username-based access should still work despite unsafe group"


class TestItemsFilter:
    """ItemsFilter generates CQL2 filters matching on the 'collection' property."""

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "collection_id,expected",
        [
            pytest.param("sentinel-2", True, id="public-allowed"),
            pytest.param("alice.my-data", False, id="prefixed-denied"),
        ],
    )
    async def test_unauthenticated_read_access(self, collection_id, expected):
        """Unauthenticated reads allow items in public collections but deny prefixed."""
        filt = await ItemsFilter()({"payload": None, "req": _READ_REQ})
        assert cql2_matches(filt, {"collection": collection_id}) == expected

    @pytest.mark.asyncio
    async def test_unauthenticated_write_denies_all(self):
        """Unauthenticated users cannot write items to any collection."""
        filt = await ItemsFilter()({"payload": None, "req": _WRITE_REQ})
        assert not cql2_matches(
            filt, {"collection": "public"}
        ), "unauthenticated write should deny items in public collections"
        assert not cql2_matches(
            filt, {"collection": "alice.data"}
        ), "unauthenticated write should deny items in prefixed collections"

    @pytest.mark.asyncio
    async def test_authenticated_read_access(self):
        """Authenticated users can read items in own, group, and public collections."""
        token = {
            "preferred_username": "alice",
            "groups": ["/dss/org-dss-shared"],
        }
        filt = await ItemsFilter()({"payload": token, "req": _READ_REQ})
        assert cql2_matches(
            filt, {"collection": "alice.data"}
        ), "user 'alice' should access items in her own collection 'alice.data'"
        assert cql2_matches(
            filt, {"collection": "org-dss-shared.data"}
        ), "group membership should grant access to items in 'org-dss-shared.data'"
        assert cql2_matches(
            filt, {"collection": "public"}
        ), "authenticated user should still access items in public collections"
        assert not cql2_matches(
            filt, {"collection": "bob.data"}
        ), "user 'alice' should not access items in 'bob.data'"

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "collection_id,expected",
        [
            pytest.param("alice.data", True, id="own-prefix-allowed"),
            pytest.param("public", False, id="public-denied"),
        ],
    )
    async def test_authenticated_write_basic_access(self, collection_id, expected):
        """Write allows own prefix but denies public collections."""
        token = {"preferred_username": "alice"}
        filt = await ItemsFilter()({"payload": token, "req": _WRITE_REQ})
        assert cql2_matches(filt, {"collection": collection_id}) == expected

    @pytest.mark.asyncio
    async def test_write_ro_group_denied(self):
        """A -ro group does NOT grant write access to items."""
        token = {
            "preferred_username": "alice",
            "groups": ["/dss/org-dss-shared-ro"],
        }
        filt = await ItemsFilter()({"payload": token, "req": _WRITE_REQ})
        assert not cql2_matches(
            filt, {"collection": "org-dss-shared.data"}
        ), "ro group should not grant write access to items"

    @pytest.mark.asyncio
    async def test_write_rw_group_grants_access(self):
        """A rw group grants write access to items in that group's collections."""
        token = {
            "preferred_username": "alice",
            "groups": ["/dss/org-dss-shared"],
        }
        filt = await ItemsFilter()({"payload": token, "req": _WRITE_REQ})
        assert cql2_matches(
            filt, {"collection": "org-dss-shared.data"}
        ), "rw group should grant write access to items in 'org-dss-shared.data'"
        assert not cql2_matches(
            filt, {"collection": "bob.data"}
        ), "rw group should not grant write access to unrelated collections"


class TestStacEditorRole:
    """The stac_editor role grants unrestricted write access catalog-wide."""

    # --- Unrestricted write access when role is present ---

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "collection_id",
        [
            pytest.param("public", id="public"),
            pytest.param("alice.data", id="other-user-prefix"),
            pytest.param("org-dss-team.data", id="group-prefix"),
            pytest.param("anything.goes.here", id="arbitrary-prefix"),
        ],
    )
    async def test_editor_can_write_any_collection(self, collection_id):
        """A token with stac_editor on the eoapi client can write any collection."""
        filt = await CollectionsFilter()({"payload": _EDITOR_TOKEN, "req": _WRITE_REQ})
        assert cql2_matches(
            filt, {"id": collection_id}
        ), f"stac_editor should grant write access to {collection_id!r}"

    @pytest.mark.asyncio
    async def test_editor_can_write_items_in_any_collection(self):
        """The same bypass applies to items, not just collections."""
        filt = await ItemsFilter()({"payload": _EDITOR_TOKEN, "req": _WRITE_REQ})
        assert cql2_matches(
            filt, {"collection": "anything.goes"}
        ), "stac_editor should grant item-write access regardless of collection prefix"

    @pytest.mark.asyncio
    async def test_editor_alongside_username_still_unrestricted(self):
        """An end-user token that also carries stac_editor gets the same unrestricted writes."""
        token = {**_EDITOR_TOKEN, "preferred_username": "alice"}
        filt = await CollectionsFilter()({"payload": token, "req": _WRITE_REQ})
        assert cql2_matches(
            filt, {"id": "bob.private"}
        ), "stac_editor should override the per-user prefix restriction"

    @pytest.mark.asyncio
    async def test_editor_role_among_other_roles(self):
        """The role is detected even when the roles list contains other entries."""
        token = {
            "azp": "eoapi",
            "resource_access": {
                "eoapi": {"roles": ["uma_protection", "stac_editor", "viewer"]}
            },
        }
        filt = await CollectionsFilter()({"payload": token, "req": _WRITE_REQ})
        assert cql2_matches(
            filt, {"id": "any.collection"}
        ), "stac_editor should be detected even when surrounded by other roles"

    # --- Bypass is write-only ---

    @pytest.mark.asyncio
    async def test_editor_does_not_apply_to_reads(self):
        """The unrestricted bypass is write-only; reads still follow normal rules."""
        filt = await CollectionsFilter()({"payload": _EDITOR_TOKEN, "req": _READ_REQ})
        assert cql2_matches(
            filt, {"id": "public"}
        ), "public collections remain readable"
        assert not cql2_matches(
            filt, {"id": "alice.data"}
        ), "stac_editor must not grant read access to arbitrary prefixes"

    # --- Bypass does not fire for the wrong role/client/shape ---

    @pytest.mark.asyncio
    async def test_role_on_non_configured_client_is_ignored(self):
        """The role only counts on configured client IDs (default: eoapi)."""
        token = {"resource_access": {"some-other-client": {"roles": ["stac_editor"]}}}
        filt = await CollectionsFilter()({"payload": token, "req": _WRITE_REQ})
        assert not cql2_matches(
            filt, {"id": "any.collection"}
        ), "stac_editor on a non-configured client must not grant writes"

    @pytest.mark.asyncio
    async def test_token_issued_for_other_client_does_not_grant_bypass(self):
        """A token whose azp is not a configured editor client must not get the bypass.

        Defends against Keycloak scope-mapper misconfigurations where a token
        issued for an unrelated client (e.g., a public portal) transitively
        includes resource_access.eoapi.roles for a user who happens to hold
        stac_editor on the eoapi client. The role assignment is meant to apply
        only when the token was actually issued for the editor client.
        """
        token = {
            "azp": "public-portal",
            "resource_access": {"eoapi": {"roles": ["stac_editor"]}},
        }
        filt = await CollectionsFilter()({"payload": token, "req": _WRITE_REQ})
        assert not cql2_matches(
            filt, {"id": "any.collection"}
        ), "transitively-included stac_editor role must not grant the bypass"

    @pytest.mark.asyncio
    async def test_token_without_azp_does_not_grant_bypass(self):
        """A token lacking the azp claim cannot prove issuance authority."""
        token = {"resource_access": {"eoapi": {"roles": ["stac_editor"]}}}
        filt = await CollectionsFilter()({"payload": token, "req": _WRITE_REQ})
        assert not cql2_matches(
            filt, {"id": "any.collection"}
        ), "missing azp claim must not grant the bypass"

    @pytest.mark.asyncio
    async def test_bypass_logs_token_identifiers_at_info(self, caplog):
        """When the bypass fires, audit-log azp/sub/jti at INFO so a responder
        can trace which token granted catalog-wide writes (e.g., to revoke a
        leaked client-credentials secret)."""
        token = {
            "azp": "eoapi",
            "sub": "service-account-eoapi",
            "jti": "token-uuid-abc-123",
            "resource_access": {"eoapi": {"roles": ["stac_editor"]}},
        }
        with caplog.at_level(logging.INFO, logger="eoepca_filters"):
            await CollectionsFilter()({"payload": token, "req": _WRITE_REQ})
        info_logs = [r for r in caplog.records if r.levelname == "INFO"]
        assert any(
            "eoapi" in r.getMessage()
            and "service-account-eoapi" in r.getMessage()
            and "token-uuid-abc-123" in r.getMessage()
            for r in info_logs
        ), f"expected INFO log naming azp, sub, jti; got {[r.getMessage() for r in info_logs]}"

    @pytest.mark.asyncio
    async def test_role_under_untrusted_azp_is_not_honored(self):
        """A token issued by an untrusted client cannot grant the bypass even
        when that same client carries the editor role.

        Without anchoring on _STAC_EDITOR_CLIENT_IDS, a user registered in a
        public/scratch client where stac_editor was granted by mistake could
        present a self-consistent token (azp == role-bearing client) and
        trigger the bypass.
        """
        token = {
            "azp": "untrusted-client",
            "resource_access": {"untrusted-client": {"roles": ["stac_editor"]}},
        }
        filt = await CollectionsFilter()({"payload": token, "req": _WRITE_REQ})
        assert not cql2_matches(
            filt, {"id": "any.collection"}
        ), "bypass must require azp to name a configured editor client"

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "resource_access",
        [
            pytest.param("not-a-dict", id="string"),
            pytest.param(["list", "of", "things"], id="list"),
            pytest.param(42, id="int"),
            pytest.param(None, id="none"),
        ],
    )
    async def test_malformed_resource_access_is_ignored(self, resource_access):
        """A malformed resource_access claim must not crash or grant writes."""
        token = {"resource_access": resource_access}
        filt = await CollectionsFilter()({"payload": token, "req": _WRITE_REQ})
        assert not cql2_matches(
            filt, {"id": "any.collection"}
        ), f"resource_access={resource_access!r} must not grant writes"

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "client_entry",
        [
            pytest.param("not-a-dict", id="string"),
            pytest.param(["list"], id="list"),
            pytest.param(None, id="none"),
        ],
    )
    async def test_malformed_client_entry_is_ignored(self, client_entry):
        """A malformed entry under resource_access.<clientId> must not crash."""
        token = {"resource_access": {"eoapi": client_entry}}
        filt = await CollectionsFilter()({"payload": token, "req": _WRITE_REQ})
        assert not cql2_matches(
            filt, {"id": "any.collection"}
        ), f"client entry {client_entry!r} must not grant writes"

    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "client_value",
        [
            pytest.param({}, id="empty-dict"),
            pytest.param({"roles": None}, id="roles-none"),
            pytest.param({"roles": "stac_editor"}, id="roles-string-not-list"),
            pytest.param({"roles": []}, id="roles-empty-list"),
            pytest.param({"roles": ["other_role"]}, id="roles-without-editor"),
        ],
    )
    async def test_malformed_or_missing_roles_is_ignored(self, client_value):
        """Roles must be a list containing the editor role; anything else is ignored."""
        token = {"resource_access": {"eoapi": client_value}}
        filt = await CollectionsFilter()({"payload": token, "req": _WRITE_REQ})
        assert not cql2_matches(
            filt, {"id": "any.collection"}
        ), f"client value {client_value!r} must not grant writes"

    # --- Env-var customization (module constants are read at import time) ---

    @pytest.mark.asyncio
    async def test_custom_role_name_via_env(self, monkeypatch):
        """STAC_EDITOR_ROLE customizes which role name triggers the bypass."""
        monkeypatch.setattr(eoepca_filters, "_STAC_EDITOR_ROLE", "custom_admin")

        custom_token = {
            "azp": "eoapi",
            "resource_access": {"eoapi": {"roles": ["custom_admin"]}},
        }
        filt = await CollectionsFilter()({"payload": custom_token, "req": _WRITE_REQ})
        assert cql2_matches(
            filt, {"id": "any.collection"}
        ), "custom role from env should grant writes"

        filt = await CollectionsFilter()({"payload": _EDITOR_TOKEN, "req": _WRITE_REQ})
        assert not cql2_matches(
            filt, {"id": "any.collection"}
        ), "default role must be ignored when a custom role is configured"

    @pytest.mark.asyncio
    async def test_multiple_client_ids_via_env(self, monkeypatch):
        """STAC_EDITOR_CLIENT_IDS supports multiple comma-separated client IDs."""
        monkeypatch.setattr(
            eoepca_filters,
            "_STAC_EDITOR_CLIENT_IDS",
            frozenset(["eoapi", "other-client"]),
        )
        token = {
            "azp": "other-client",
            "resource_access": {"other-client": {"roles": ["stac_editor"]}},
        }
        filt = await CollectionsFilter()({"payload": token, "req": _WRITE_REQ})
        assert cql2_matches(
            filt, {"id": "any.collection"}
        ), "stac_editor on any configured client should grant writes"

    @pytest.mark.asyncio
    async def test_empty_role_disables_bypass(self, monkeypatch):
        """An empty STAC_EDITOR_ROLE disables the bypass entirely."""
        monkeypatch.setattr(eoepca_filters, "_STAC_EDITOR_ROLE", "")
        filt = await CollectionsFilter()({"payload": _EDITOR_TOKEN, "req": _WRITE_REQ})
        assert not cql2_matches(
            filt, {"id": "any.collection"}
        ), "empty STAC_EDITOR_ROLE must disable the bypass"

    @pytest.mark.asyncio
    async def test_empty_client_ids_disables_bypass(self, monkeypatch):
        """An empty STAC_EDITOR_CLIENT_IDS frozenset disables the bypass entirely."""
        monkeypatch.setattr(eoepca_filters, "_STAC_EDITOR_CLIENT_IDS", frozenset())
        filt = await CollectionsFilter()({"payload": _EDITOR_TOKEN, "req": _WRITE_REQ})
        assert not cql2_matches(
            filt, {"id": "any.collection"}
        ), "empty STAC_EDITOR_CLIENT_IDS must disable the bypass"


class TestEditorConfigValidation:
    """Startup logs surface the editor bypass config and flag misconfigurations."""

    def test_warns_when_editor_client_not_in_audiences(self, caplog):
        """An editor client absent from ALLOWED_JWT_AUDIENCES indicates dead config:
        tokens from that client are rejected by the proxy before reaching this filter."""
        with caplog.at_level(logging.WARNING, logger="eoepca_filters"):
            eoepca_filters._validate_editor_config(
                role="stac_editor",
                editor_client_ids=frozenset(["eoapi", "scratch-client"]),
                audiences=frozenset(["eoapi"]),
            )
        warnings = [r for r in caplog.records if r.levelname == "WARNING"]
        assert any(
            "scratch-client" in r.getMessage() and "ALLOWED_JWT_AUDIENCES" in r.getMessage()
            for r in warnings
        ), f"expected warning naming 'scratch-client' and ALLOWED_JWT_AUDIENCES; got {[r.getMessage() for r in warnings]}"

    def test_no_warning_when_editor_clients_subset_of_audiences(self, caplog):
        """Editor clients fully covered by audiences → no dead-config warning."""
        with caplog.at_level(logging.WARNING, logger="eoepca_filters"):
            eoepca_filters._validate_editor_config(
                role="stac_editor",
                editor_client_ids=frozenset(["eoapi"]),
                audiences=frozenset(["eoapi", "other-app"]),
            )
        warnings = [r for r in caplog.records if r.levelname == "WARNING"]
        assert not warnings, f"unexpected warnings: {[r.getMessage() for r in warnings]}"

    def test_skips_subset_check_when_audiences_unknown(self, caplog):
        """If ALLOWED_JWT_AUDIENCES is unset (empty), skip the subset check."""
        with caplog.at_level(logging.WARNING, logger="eoepca_filters"):
            eoepca_filters._validate_editor_config(
                role="stac_editor",
                editor_client_ids=frozenset(["eoapi", "scratch-client"]),
                audiences=frozenset(),
            )
        warnings = [r for r in caplog.records if r.levelname == "WARNING"]
        assert not warnings, "should not warn when audiences config is unavailable"

    def test_disabled_bypass_emits_no_warning(self, caplog):
        """When the bypass is disabled (empty role), no warning is emitted."""
        with caplog.at_level(logging.WARNING, logger="eoepca_filters"):
            eoepca_filters._validate_editor_config(
                role="",
                editor_client_ids=frozenset(["scratch-client"]),
                audiences=frozenset(["eoapi"]),
            )
        warnings = [r for r in caplog.records if r.levelname == "WARNING"]
        assert not warnings, "disabled bypass should not warn about anything"
