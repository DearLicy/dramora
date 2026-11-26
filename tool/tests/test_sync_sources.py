import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("sync_sources", Path(__file__).parents[1] / "sync_sources.py")
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)


class SourceSyncTests(unittest.TestCase):
    def test_publisher_arrays_are_resolved_without_eval(self):
        js = """var subdomains=['thu', // comment
        'pku']; var urls=['new-example.cc/'];
        newestUrls.push('https://' + getRandomSubdomain(availableSubdomains) + '.' + urls[0]);"""
        self.assertIn("https://thu.new-example.cc", sync.extract_sources(js))
        self.assertIn("https://pku.new-example.cc", sync.extract_sources(js))
        self.assertEqual(sync.extract_sources(js), sync.extract_sources(js))

    def test_json_and_escaped_links(self):
        self.assertIn("https://a.example.cc", sync.extract_sources(r'{"url":"https:\/\/a.example.cc\/"}'))

    def test_publication_ads_and_private_urls_never_enter_without_probe(self):
        for value in ['http://a.example.cc', 'https://127.0.0.1', 'https://10.0.0.1', 'https://user:pass@example.cc', 'https://huang-guo.pages.dev', 'https://a.local']:
            self.assertIsNone(sync.normalize(value), value)
        with patch.object(sync, 'fetch', return_value='{"status":1,"data":{"url":"https://ad.example"}}'):
            self.assertFalse(sync.probe('https://ad.example'))
        with patch.object(sync, 'fetch', return_value='<html>OK</html>'):
            self.assertFalse(sync.probe('https://a.example'))
        with patch.object(sync, 'fetch', return_value='{"status":1,"data":{"banners":[],"latest":[]}}'):
            self.assertTrue(sync.probe('https://a.example'))

    def test_probe_uses_the_current_direct_content_route(self):
        requested = []

        def fake_fetch(url, **_kwargs):
            requested.append(url)
            return '{"status":1,"data":{"banners":[],"latest":[]}}'

        with patch.object(sync, 'fetch', side_effect=fake_fetch):
            self.assertTrue(sync.probe('https://current.example.cc'))

        self.assertEqual(requested, ['https://current.example.cc/api/home'])

    def test_no_change_and_failures_preserve_bytes_and_version(self):
        old = {'version': 2, 'sources': ['https://a.example.cc']}
        self.assertIs(sync.merge_manifest(old, [], 'today'), old)
        self.assertIs(sync.merge_manifest(old, old['sources'], 'tomorrow'), old)

    def test_new_verified_source_preserves_old_sources(self):
        old = {'version': 2, 'sources': ['https://a.example.cc']}
        updated = sync.merge_manifest(old, ['https://b.example.cc'], 'today')
        self.assertEqual(updated['sources'], ['https://b.example.cc', 'https://a.example.cc'])
        self.assertEqual(updated['version'], 3)
        self.assertEqual(updated['updated_at'], 'today')


if __name__ == '__main__':
    unittest.main()
