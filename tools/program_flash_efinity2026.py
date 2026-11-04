"""Program or read SPI flash through Efinity 2026's JTAG2SPI bridge.

The FT4232H on this board can use Efinity's vendor JTAG engines, but the
installed Python transport needs a process-local D2XX compatibility adapter.
The adapter below is the same method previously proven on this Ti60F225 board.
No files in the Efinity installation are modified.
"""

from __future__ import annotations

import argparse
from contextlib import redirect_stderr, redirect_stdout
from datetime import datetime
import hashlib
import io
import json
import os
from pathlib import Path
import runpy
import sys
import traceback

from program_jtag_efinity2026 import DEFAULT_HOME, DEFAULT_PROFILE, configure_environment


EXPECTED_FLASH = "Winbond W25Q64 8 MiB"
EXPECTED_JEDEC = "0xEF6017"


class Tee(io.TextIOBase):
    """Mirror vendor output to the terminal while retaining it for validation."""

    def __init__(self, stream: io.TextIOBase) -> None:
        self.stream = stream
        self.buffer = io.StringIO()

    def write(self, text: str) -> int:
        self.stream.write(text)
        self.stream.flush()
        self.buffer.write(text)
        return len(text)

    def flush(self) -> None:
        self.stream.flush()

    def getvalue(self) -> str:
        return self.buffer.getvalue()


def install_vendor_d2xx_adapter() -> None:
    """Route the vendor JTAG engines through the installed Windows D2XX DLL."""

    os.environ["EFX_HIFTDI_ENABLE"] = "1"

    from efx_pgm.efx_hw_common.manager import EfxFTDIHwConnectionManager as Manager
    from efx_pgm.hiftdi.ftdi import Ftdi as D2xxFtdi
    from efx_pgm.jtag2SpiDriver import JtagFineGrainEngine
    from pyftdi.jtag import JtagEngine

    class CompatibleD2xx(D2xxFtdi):
        def close(self, freeze: bool = False):
            if freeze:
                raise ValueError("Freezing D2XX pins is unsupported")
            return super().close()

    original_controller = Manager.get_controller

    def controller(url, conn_type, **kwargs):
        if url.startswith("hiftdi://") and conn_type in (
            Manager.ConnectionType.JTAG,
            Manager.ConnectionType.JTAGFINEGRAIN,
        ):
            engine_type = (
                JtagFineGrainEngine
                if conn_type == Manager.ConnectionType.JTAGFINEGRAIN
                else JtagEngine
            )
            engine = engine_type(**kwargs)
            engine._ctrl._ftdi = CompatibleD2xx()
            return engine
        return original_controller(url, conn_type, **kwargs)

    Manager.get_controller = staticmethod(controller)
    print("Process-local adapter: vendor JTAG engines + vendor D2XX transport", flush=True)


def write_result(path: Path | None, result: dict) -> None:
    if path is None:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Program/verify or independently read SPI flash via JTAG2SPI"
    )
    parser.add_argument("hex_image", type=Path)
    parser.add_argument("--operation", choices=("program", "read"), default="program")
    parser.add_argument("--efinity-home", type=Path, default=DEFAULT_HOME)
    parser.add_argument("--jtag-frequency", type=int, default=6_000_000)
    parser.add_argument("--address", type=lambda value: int(value, 0), default=0)
    parser.add_argument("--board-profile", default=DEFAULT_PROFILE)
    parser.add_argument("--expected-sha256")
    parser.add_argument("--output-file", type=Path)
    parser.add_argument("--num-bytes", type=int)
    parser.add_argument("--result-file", type=Path)
    args = parser.parse_args()

    result_path = args.result_file.resolve() if args.result_file else None
    if result_path and result_path.exists():
        result_path.unlink()

    image = args.hex_image.resolve()
    if not image.is_file():
        raise FileNotFoundError(f"Flash image does not exist: {image}")
    if image.suffix.lower() != ".hex":
        raise ValueError(f"JTAG2SPI programming requires a .hex image: {image}")
    if args.address < 0:
        raise ValueError("Flash address cannot be negative")

    digest = hashlib.sha256(image.read_bytes()).hexdigest().upper()
    print(f"HEX SHA-256: {digest}")
    if args.expected_sha256 and digest != args.expected_sha256.upper():
        raise ValueError(
            f"Flash image hash mismatch: expected {args.expected_sha256.upper()}, got {digest}"
        )

    output_file: Path | None = None
    if args.operation == "read":
        if args.output_file is None or args.num_bytes is None or args.num_bytes <= 0:
            raise ValueError("Read operation requires --output-file and positive --num-bytes")
        output_file = args.output_file.resolve()
        output_file.parent.mkdir(parents=True, exist_ok=True)
        if output_file.exists():
            output_file.unlink()

    programmer_script = configure_environment(args.efinity_home)
    install_vendor_d2xx_adapter()

    vendor_args = [
        str(programmer_script),
        str(image),
        "--mode",
        "jtag_bridge",
        "--board_profile",
        args.board_profile,
        "--jtag_clock_freq",
        str(args.jtag_frequency),
        "--address",
        hex(args.address),
        "--jtag_bridge_mode",
        "all" if args.operation == "program" else "read",
    ]
    if args.operation == "program":
        vendor_args.extend(("--verify_method", "hostx1"))
    else:
        vendor_args.extend(
            (
                "--num_bytes",
                str(args.num_bytes),
                "--output_file",
                str(output_file),
            )
        )

    tee = Tee(sys.stdout)
    exit_code = 0
    exception_text = None
    original_argv = sys.argv
    sys.argv = vendor_args
    with redirect_stdout(tee), redirect_stderr(tee):
        try:
            runpy.run_path(str(programmer_script), run_name="__main__")
        except SystemExit as exc:
            exit_code = int(exc.code or 0)
        except Exception as exc:  # Vendor code raises transport-specific exceptions.
            exception_text = f"{type(exc).__name__}: {exc}"
            traceback.print_exc()
            exit_code = 1
        finally:
            sys.argv = original_argv

    output = tee.getvalue()
    flash_identified = EXPECTED_FLASH in output and EXPECTED_JEDEC in output
    output_size = output_file.stat().st_size if output_file and output_file.exists() else None
    readback_format = None
    if args.operation == "read" and output_size is not None:
        if output_size == args.num_bytes:
            readback_format = "binary"
        elif output_size == args.num_bytes * 3:
            # Efinity 2026 writes one two-digit byte plus LF per line.
            readback_format = "hex_lines"
    if args.operation == "program":
        success = (
            exit_code == 0
            and exception_text is None
            and flash_identified
            and "Flash verify successful" in output
            and "JTAG2SPI programming...done" in output
        )
    else:
        success = (
            exit_code == 0
            and exception_text is None
            and flash_identified
            and output_file is not None
            and output_file.is_file()
            and readback_format is not None
            and "Finished read" in output
        )

    result = {
        "timestamp": datetime.now().astimezone().isoformat(),
        "operation": args.operation,
        "success": success,
        "vendor_exit_code": exit_code,
        "vendor_exception": exception_text,
        "image": str(image),
        "image_file_sha256": digest,
        "address": args.address,
        "jtag_frequency_hz": args.jtag_frequency,
        "board_profile": args.board_profile,
        "flash_identified": flash_identified,
        "flash_model": EXPECTED_FLASH if flash_identified else None,
        "jedec": EXPECTED_JEDEC if flash_identified else None,
        "hostx1_verify_success": "Flash verify successful" in output,
        "jtag2spi_completed": "JTAG2SPI programming...done" in output,
        "output_file": str(output_file) if output_file else None,
        "output_size": output_size,
        "readback_format": readback_format,
    }
    write_result(result_path, result)

    if not success:
        print(f"FLASH_{args.operation.upper()}=FAIL")
        return 1
    print(f"FLASH_{args.operation.upper()}=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
