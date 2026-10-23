import hashlib
import json
import unittest
from unittest.mock import Mock
from urllib.error import HTTPError

from mirror_catalogue import mirror, validate_catalogue


class MirrorTests(unittest.TestCase):
    def setUp(self):
        self.data = json.dumps({"navigation": [{"id": "module-a", "units": []}]}).encode()
        self.asset = {
            "name": "catalog.json", "size": len(self.data),
            "digest": "sha256:" + hashlib.sha256(self.data).hexdigest(),
            "browser_download_url": "https://github.com/owner/repo/releases/download/content-v1.0.0/catalog.json",
        }
        self.release = {"id": 1, "tag_name": "content-v1.0.0", "draft": False,
                        "prerelease": False, "assets": [self.asset]}
        self.sha = hashlib.sha1(b"blob " + str(len(self.data)).encode() + b"\0" + self.data).hexdigest()

    def test_valid_generated_catalogue(self):
        self.assertEqual(validate_catalogue(self.release, self.asset, self.data)["navigation"][0]["id"], "module-a")

    def test_prerelease_draft_and_corruption_rejected(self):
        for field in ["draft", "prerelease"]:
            with self.assertRaises(ValueError):
                validate_catalogue({**self.release, field: True}, self.asset, self.data)
        for data in [self.data + b" ", self.data.replace(b"module-a", b"module-b")]:
            with self.assertRaises(ValueError):
                validate_catalogue(self.release, self.asset, data)

    def test_source_catalogue_rejected(self):
        data = b'{"modules": []}'
        asset = {"size": len(data), "digest": "sha256:" + hashlib.sha256(data).hexdigest()}
        with self.assertRaises(ValueError):
            validate_catalogue(self.release, asset, data)

    def test_creates_orphan_pointer_after_verification(self):
        api = Mock(side_effect=[self.release, HTTPError("", 404, "missing", {}, None),
                               {"sha": self.sha}, {"sha": "tree"}, {"sha": "commit"}, self.release, {}])
        mirror(api, lambda _: self.data, "owner/repo")
        self.assertEqual(api.call_args.args, ("/git/refs", "POST", {"ref": "refs/heads/web-catalogue", "sha": "commit"}))
        self.assertEqual(api.call_args_list[4].args[2]["parents"], [])

    def test_updates_without_force_and_is_idempotent(self):
        prefix = [self.release, {"object": {"sha": "parent"}}, {"tree": {"sha": "oldtree"}}]
        api = Mock(side_effect=prefix + [{"tree": [{"path": "catalog.json", "sha": self.sha}]}])
        self.assertIn("already current", mirror(api, lambda _: self.data, "owner/repo"))
        self.assertTrue(all(len(c.args) == 1 for c in api.call_args_list))
        api = Mock(side_effect=prefix + [{"tree": [{"path": "catalog.json", "sha": "old"}]},
                   {"sha": self.sha}, {"sha": "tree"}, {"sha": "commit"}, self.release, {}])
        mirror(api, lambda _: self.data, "owner/repo")
        self.assertEqual(api.call_args.args[2], {"sha": "commit", "force": False})

    def test_release_race_leaves_public_pointer_unchanged(self):
        api = Mock(side_effect=[self.release, HTTPError("", 404, "missing", {}, None),
                               {"sha": self.sha}, {"sha": "tree"}, {"sha": "commit"}, {**self.release, "id": 2}])
        with self.assertRaisesRegex(ValueError, "changed"):
            mirror(api, lambda _: self.data, "owner/repo")
        self.assertFalse(any(c.args[0].startswith("/git/refs") for c in api.call_args_list))

    def test_unexpected_branch_files_preserved(self):
        api = Mock(side_effect=[self.release, {"object": {"sha": "parent"}}, {"tree": {"sha": "tree"}},
                               {"tree": [{"path": "README.md", "sha": "x"}]}])
        with self.assertRaisesRegex(ValueError, "unexpected files"):
            mirror(api, lambda _: self.data, "owner/repo")


if __name__ == "__main__":
    unittest.main()
