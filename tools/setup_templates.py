"""Optionally install a downloaded, checksum-locked official template archive."""
import argparse
from pathlib import Path
from setup_toolchain import ROOT, checked_directory, extract_templates, load_lock


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    extract_templates(args.archive, checked_directory(ROOT / ".tools"), load_lock())
    print("Verified and installed single-threaded web templates")


if __name__ == "__main__":
    main()
