"""Shared TRex import bootstrap.

Puts the vendored scapy 2.4.3 and the interactive control-plane library on
sys.path so `from trex.stl.api import ...` and `import scapy...` resolve inside
the TRex container.  Import this BEFORE any trex/scapy import:

    import _trex_env  # noqa: F401  (sys.path bootstrap)
    from trex.stl.api import STLClient

TREX_DIR overrides the install dir (default /opt/trex).
"""
import os
import sys

TREX_DIR = os.environ.get("TREX_DIR", "/opt/trex")
sys.path.insert(0, os.path.join(TREX_DIR, "external_libs/scapy-2.4.3"))
import scapy.modules.six as _six
sys.modules.setdefault("scapy.modules.six.moves", _six.moves)
sys.path.insert(
    0, os.path.join(TREX_DIR, "automation/trex_control_plane/interactive"))
