"""Program an Efinix bitstream through Efinity 2026 HiFTDI/JTAG.

Efinity 2026.1.132 calls every JTAG provider with (url, init), while its
HiFtdiJtagEngine accepts only (url).  This wrapper adapts that call in the
current Python process and leaves the Efinity installation unchanged.
"""

from __future__ import annotations

import argparse
import inspect
import os
from pathlib import Path
import runpy
import sys


DEFAULT_HOME = Path(r"E:\Efinity 2026")
DEFAULT_PROFILE = "Generic Board Profile Using FT4232H"


def configure_environment(home: Path) -> Path:
    home = home.resolve()
    if not home.is_dir():
        raise FileNotFoundError(f"Efinity home does not exist: {home}")

    os.environ["EFINITY_HOME"] = home.as_posix()
    os.environ["EFXPT_HOME"] = (home / "pt").as_posix()
    os.environ["EFXPGM_HOME"] = (home / "pgm").as_posix()
    os.environ["EFXDBG_HOME"] = (home / "debugger").as_posix()
    os.environ["EFX_HIFTDI_ENABLE"] = "1"

    pgm_bin = home / "pgm" / "bin"
    dbg_bin = home / "debugger" / "bin"
    for directory in (str(pgm_bin), str(dbg_bin)):
        if directory not in sys.path:
            sys.path.insert(0, directory)

    script = pgm_bin / "efx_pgm" / "ftdi_program.py"
    if not script.is_file():
        raise FileNotFoundError(f"Efinity programmer script not found: {script}")
    return script


def install_hiftdi_compatibility_patch() -> None:
    from efx_dbg.jcf import JtagChainEngine

    original_configure = JtagChainEngine.configure

    def configure_compatible(self, url):
        provider_configure = self._engine_provider.configure
        parameter_count = len(inspect.signature(provider_configure).parameters)
        if parameter_count == 1:
            clean_url, _init = self._get_url_init(url)
            provider_configure(clean_url)
            self._url = clean_url
            return None
        return original_configure(self, url)

    JtagChainEngine.configure = configure_compatible


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Program a .bit file using the Efinity 2026 HiFTDI backend"
    )
    parser.add_argument("bitstream", type=Path)
    parser.add_argument("--efinity-home", type=Path, default=DEFAULT_HOME)
    parser.add_argument("--jtag-frequency", type=int, default=6_000_000)
    parser.add_argument("--board-profile", default=DEFAULT_PROFILE)
    args = parser.parse_args()

    bitstream = args.bitstream.resolve()
    if not bitstream.is_file():
        raise FileNotFoundError(f"Bitstream does not exist: {bitstream}")

    programmer_script = configure_environment(args.efinity_home)
    install_hiftdi_compatibility_patch()
    sys.argv = [
        str(programmer_script),
        str(bitstream),
        "--mode",
        "jtag",
        "--board_profile",
        args.board_profile,
        "--jtag_clock_freq",
        str(args.jtag_frequency),
    ]
    runpy.run_path(str(programmer_script), run_name="__main__")


if __name__ == "__main__":
    main()
