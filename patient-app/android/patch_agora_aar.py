"""
Regenerates android/app/libs/agora-special-full-patched.aar.

io.agora.rtc:agora-special-full and io.agora.rtc:iris-rtc (both pulled in by
the agora_rtc_engine plugin) declare the same manifest package ("io.agora.rtc"),
which recent AGP versions reject as a duplicate namespace during manifest
merging. agora-special-full carries no Java code or resources of its own
(just native .so libraries — verified: its classes.jar and R.txt are empty),
so renaming its manifest package is a safe, no-op-functionally patch.

Run this before `flutter build apk` / `flutter build appbundle`. Not committed
to git because the artifact is ~140MB, over GitHub's per-file push limit.
"""

import os
import shutil
import tempfile
import urllib.request
import zipfile

GROUP_PATH = "io/agora/rtc/agora-special-full"
ARTIFACT_ID = "agora-special-full"
VERSION = "4.5.3.70"
SOURCE_URL = (
    f"https://repo1.maven.org/maven2/{GROUP_PATH}/{VERSION}/"
    f"{ARTIFACT_ID}-{VERSION}.aar"
)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_PATH = os.path.join(SCRIPT_DIR, "app", "libs", "agora-special-full-patched.aar")
NEW_PACKAGE = "io.agora.rtc.specialfull"


def main() -> None:
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        original_aar = os.path.join(tmp, "original.aar")
        print(f"Downloading {SOURCE_URL} ...")
        urllib.request.urlretrieve(SOURCE_URL, original_aar)

        extract_dir = os.path.join(tmp, "extracted")
        with zipfile.ZipFile(original_aar) as zf:
            zf.extractall(extract_dir)

        manifest_path = os.path.join(extract_dir, "AndroidManifest.xml")
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest = f.read()

        patched = manifest.replace('package="io.agora.rtc"', f'package="{NEW_PACKAGE}"')
        if patched == manifest:
            raise RuntimeError(
                "Expected package=\"io.agora.rtc\" in the manifest but did not find it "
                "— the upstream artifact may have changed, check manually."
            )

        with open(manifest_path, "w", encoding="utf-8") as f:
            f.write(patched)

        if os.path.exists(OUTPUT_PATH):
            os.remove(OUTPUT_PATH)

        with zipfile.ZipFile(OUTPUT_PATH, "w", zipfile.ZIP_DEFLATED) as zf:
            for root, _dirs, files in os.walk(extract_dir):
                for name in files:
                    full = os.path.join(root, name)
                    arcname = os.path.relpath(full, extract_dir)
                    zf.write(full, arcname)

    print(f"Wrote {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
