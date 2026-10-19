"""Exercise native window selection without opening windows or moving the cursor."""
import ctypes
from ctypes import wintypes
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import check_editor_input as runner


class WindowAPI:
    def __init__(self, windows, enumeration_ok=True):
        # handle -> (pid, visible, width, height, readable client rectangle)
        self.windows = windows
        self.enumeration_ok = enumeration_ok

    def EnumWindows(self, callback, _):
        for handle in self.windows:
            callback(handle, 0)
        return self.enumeration_ok

    def GetWindowThreadProcessId(self, handle, pid):
        ctypes.cast(pid, ctypes.POINTER(wintypes.DWORD)).contents.value = self.windows[handle][0]
        return 1

    def IsWindowVisible(self, handle):
        return self.windows[handle][1]

    def GetClientRect(self, handle, rect):
        _, _, width, height, readable = self.windows[handle]
        client = ctypes.cast(rect, ctypes.POINTER(wintypes.RECT)).contents
        client.right, client.bottom = width, height
        return readable


class WindowSelectionTests(unittest.TestCase):
    def setUp(self):
        # CFUNCTYPE also lets these non-native tests run on headless Unix hosts.
        callback = patch.object(ctypes, "WINFUNCTYPE", ctypes.CFUNCTYPE, create=True)
        callback.start()
        self.addCleanup(callback.stop)
        self.api = WindowAPI({
            1: (42, True, 600, 450, True),  # First eligible window, but smaller.
            2: (42, True, 1500, 900, True),
            3: (43, True, 2000, 2000, True),  # Other process.
            4: (42, False, 2000, 2000, True),
            5: (42, True, 500, 2000, True),  # Splash/tool size boundary.
            6: (42, True, 2000, 400, True),
            7: (42, True, 2000, 2000, False),  # Failed rectangle read.
        })

    def test_largest_eligible_window_in_any_enumeration_order(self):
        self.assertEqual(runner.select_editor_window(self.api, 42), 2)
        self.api.windows = dict(reversed(list(self.api.windows.items())))
        self.assertEqual(runner.select_editor_window(self.api, 42), 2)

    def test_equal_areas_have_a_stable_handle_tiebreak(self):
        self.api.windows[8] = (42, True, 1500, 900, True)
        self.assertEqual(runner.select_editor_window(self.api, 42), 8)
        self.api.windows = dict(reversed(list(self.api.windows.items())))
        self.assertEqual(runner.select_editor_window(self.api, 42), 8)

    def test_no_eligible_window(self):
        self.assertIsNone(runner.select_editor_window(self.api, 99))
        self.api.windows = {5: self.api.windows[5], 7: self.api.windows[7]}
        self.assertIsNone(runner.select_editor_window(self.api, 42))

    def test_failed_enumeration_aborts_instead_of_using_partial_results(self):
        self.api.enumeration_ok = False
        with self.assertRaisesRegex(SystemExit, "INPUT_SETUP"):
            runner.select_editor_window(self.api, 42)


if __name__ == "__main__":
    unittest.main()
