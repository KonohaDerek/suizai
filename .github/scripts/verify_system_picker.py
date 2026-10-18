"""Verify provider discovery in the stock API 33 CI image; retain UI evidence."""

from pathlib import Path
import re
import shlex
import subprocess
import time
import xml.etree.ElementTree as ET


def adb(*args, check=True):
    if args[0] == "shell":
        args = ("shell", shlex.join(args[1:]))
    return subprocess.run(["adb", *args], check=check, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, timeout=30).stdout


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
# The Gradle test runner owns installation/teardown. Establish a separate manual
# user session instead of assuming its target APK remains installed and started.
evidence.joinpath("package-before.txt").write_bytes(
    adb("shell", "pm", "path", "tw.suizai.app", check=False)
    + adb("shell", "dumpsys", "package", "tw.suizai.app"))
assert b"Success" in adb("install", "-r", "app/build/outputs/apk/debug/app-debug.apk")
launch = adb("shell", "am", "start", "-W", "-n", "tw.suizai.app/.MainActivity")
evidence.joinpath("app-launch.txt").write_bytes(launch)
assert b"Status: ok" in launch, "App did not launch before picker verification"
evidence.joinpath("package-after.txt").write_bytes(adb("shell", "dumpsys", "package", "tw.suizai.app"))
snapshot("app-initial")
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
if not any(title in ("SUIZAI", "SUIZAI 隨載") for title in titles):
    evidence.joinpath("picker-logcat.txt").write_bytes(adb("logcat", "-d", "-t", "500"))
assert any(title in ("SUIZAI", "SUIZAI 隨載") for title in titles), f"SUIZAI missing from system picker: {titles}"
print("PASS: SUIZAI is listed in the API 33 system file picker.")
