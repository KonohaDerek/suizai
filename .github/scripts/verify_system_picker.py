"""Verify provider discovery in the stock API 33 CI image; retain UI evidence."""

from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET


def adb(*args):
    return subprocess.check_output(["adb", *args], timeout=30)


def snapshot(name):
    # UIAutomator can briefly fail while the picker is opening or animating.
    for attempt in range(5):
        try:
            adb("shell", "uiautomator", "dump", "/sdcard/suizai-picker.xml")
            xml = adb("shell", "cat", "/sdcard/suizai-picker.xml")
            tree = ET.fromstring(xml)
            evidence.joinpath(f"{name}.xml").write_bytes(xml)
            evidence.joinpath(f"{name}.png").write_bytes(adb("exec-out", "screencap", "-p"))
            return tree
        except (subprocess.SubprocessError, ET.ParseError):
            if attempt == 4:
                raise
            time.sleep(1)


def roots_list(tree):
    return next((node for node in tree.iter("node")
                 if node.get("resource-id", "").endswith(":id/roots_list")), None)


evidence = Path("build/picker-verification")
evidence.mkdir(parents=True, exist_ok=True)
assert adb("shell", "getprop", "ro.build.version.sdk").strip() == b"33", "This smoke check targets the API 33 CI image"
adb("shell", "am", "start", "-W", "-a", "android.intent.action.OPEN_DOCUMENT",
    "-c", "android.intent.category.OPENABLE", "-t", "*/*")
tree = snapshot("picker-initial")
if roots_list(tree) is None:
    # The stock CI system language is English; the app's language is independent.
    drawer = next((node for node in tree.iter("node")
                   if node.get("content-desc") == "Show roots"), None)
    assert drawer is not None, "Storage-location menu not found; inspect picker-initial.xml/png"
    coordinates = list(map(int, re.findall(r"\d+", drawer.attrib["bounds"])))
    assert len(coordinates) == 4, "Invalid drawer bounds"
    left, top, right, bottom = coordinates
    adb("shell", "input", "tap", str((left + right) // 2), str((top + bottom) // 2))
    tree = snapshot("picker-roots")

roots = roots_list(tree)
assert roots is not None, "Storage-location list did not open"
titles = [node.get("text", "") for node in roots.iter("node")]
assert any(title in ("SUIZAI", "SUIZAI 隨載") for title in titles), f"SUIZAI missing from system picker: {titles}"
print("PASS: SUIZAI is listed in the API 33 system file picker.")
