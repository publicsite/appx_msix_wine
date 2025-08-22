#!/usr/bin/env python3
"""
Compute Windows Store PublisherId from a Publisher string in an APPX manifest.

This corresponds to the "PublisherId" shown in Visual Studio's Packaging tab
(used in Package Family Name). It converts the Publisher string (e.g.,
'CN=B408A06D-44F7-4860-A12E-644DD44FA743') to UTF-16LE bytes, hashes it with
SHA256, takes the first 8 bytes, and encodes them using Crockford Base32 to
produce a 13-character lowercase string.
"""

import hashlib
import sys
import unittest

CROCKFORD_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

def get_publisher_id_from_publisher(publisher: str) -> str:
    """Compute PublisherId for a given Publisher string using direct bit manipulation."""
    digest8 = hashlib.sha256(publisher.encode('utf-16le')).digest()[:8]
    val = int.from_bytes(digest8, 'big') << 1  # 65 bits total

    # Extract 13 groups of 5 bits (MSB to LSB) and map via Crockford Base32
    chars = [CROCKFORD_ALPHABET[(val >> s) & 0x1F] for s in range(60, -1, -5)]
    return ''.join(chars).lower()


class TestPublisherId(unittest.TestCase):
    TEST_DATA = {
        "8wekyb3d8bbwe": "CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US",
        "amge560j0aq9g": "CN=C357A519-CEE3-4675-9EF4-44DE1D99A5D6",
        "a2xxwqz7shah6": "CN=07AACB4D-E1D7-4606-AF0F-77713A7C52F6",
        "cw5n1h2txyewy": "CN=Microsoft Windows, O=Microsoft Corporation, L=Redmond, S=Washington, C=US",
        "54ggd3ev8bvz6": "CN=2180B9A4-DDFD-4BFD-8D7E-EADC9C394EF5",
        "azstdzfk4mfqj": "CN=246910D1-A42D-4A04-8CF1-0C2A5CD42D4D",
        "rxzpp8adhbvh8": "CN=7882B094-0135-443F-8362-164AA239F2A0",
        "pwh22gvzcj20c": "CN=9C2E3884-8027-4E71-97C7-BB7731A649A4",
        "q4d96b2w5wcc2": "CN=DCD4AC3C-C7E0-46FF-8387-51FDC8CBC467",
        "r6rtpscs7gwyg": "CN=54157592-46DE-47CD-AF04-3B89DE46E29B",
        "8xx8rvfyw5nnt": "CN=6E08453F-9BA7-4311-999C-D22FBA2FB1B8",
        "kzf8qxf38zg5c": "CN=Skype Software Sarl, O=Microsoft Corporation, L=Luxembourg, S=Luxembourg, C=LU",
        "a76a11dkgb644": "CN=40886CD1-D5C5-48D6-B914-AB6E72010FFC",
        "6bhtb546zcxnj": "CN=BBC567E9-A52C-43A3-A890-F8B17D68310E",
        "46hhcags7zat8": "CN=ABF01D82-FF53-447D-B7E8-61B6F2105F68",
        "pd2za7f9waemw": "CN=B408A06D-44F7-4860-A12E-644DD44FA740",
        "h0ed56e8a88dc": "CN=B408A06D-44F7-4860-A12E-644DD44FA741",
        "wcvtzcf7freyj": "CN=B408A06D-44F7-4860-A12E-644DD44FA742",
        "f08ys7xx9zb3y": "CN=B408A06D-44F7-4860-A12E-644DD44FA743",
        "85zvc56jp30ec": "CN=C408A06D-44F7-4860-A12E-644DD44FA743",
        "x4nmjqajw9mv6": "CN=D408A06D-44F7-4860-A12E-644DD44FA743",
        "qrhphajnj16d4": "CN=E408A06D-44F7-4860-A12E-644DD44FA743",
    }

    def test_publisher_id(self):
        for expected_id, publisher in self.TEST_DATA.items():
            with self.subTest(publisher=publisher):
                self.assertEqual(get_publisher_id_from_publisher(publisher), expected_id)


if __name__ == "__main__":
    if len(sys.argv) == 2:
        publisher = sys.argv[1]
        print(get_publisher_id_from_publisher(publisher))
    else:
        unittest.main()
