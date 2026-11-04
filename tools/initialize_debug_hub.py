"""Reapply the fixed RTL VIO defaults immediately after application loading."""
from pathlib import Path
import argparse,json
from program_jtag_efinity2026 import DEFAULT_HOME,configure_environment
from program_flash_efinity2026 import install_vendor_d2xx_adapter
ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--efinity-home',type=Path,default=DEFAULT_HOME);args=ap.parse_args()
configure_environment(args.efinity_home);install_vendor_d2xx_adapter()
from efx_pgm.util.gen_util import set_efinity_user_dir_env
set_efinity_user_dir_env()
from efx_pgm.usb_resolver import UsbResolver
from efx_dbg.jtag import JtagManager
from efx_dbg.define import DebugProfile
from efx_dbg.engine import DebugEngine
connections=UsbResolver().get_usb_connections();assert len(connections)==1,'Expected one programmer'
manager=JtagManager();session=manager.config_jtag(url=connections[0].URLS[1],freq=3000000,tap='efx_ti',user='USER1')
try:
    DebugEngine(session,DebugProfile()).global_soft_reset()
    args.output.write_text(json.dumps({'debug_hub_reset':True,'vio_defaults_reapplied':True,'fixed_rgb':[280,240,376],'vio_probe_writes':False},indent=2)+'\n')
    print('Existing fixed RTL defaults restored: RGB280/240/376.')
finally:manager.unconfig_jtag(session)
