"""Normal Flash identity/backup/vendor-check record, without scoring or extra readback."""
from datetime import datetime,timezone,timedelta
from pathlib import Path
import argparse,hashlib,json,subprocess
from final_project import ROOT,VERSION,sha,read,write,inputs
SESSION=ROOT/'.cache/flash-session.txt'
def decode(path):
    tokens=path.read_text(encoding='ascii').splitlines();assert all(len(t.strip())==2 for t in tokens if t.strip())
    return bytes(int(t,16) for t in tokens if t.strip())
def now():return datetime.now(timezone(timedelta(hours=8)))
def main():
    ap=argparse.ArgumentParser();ap.add_argument('phase',choices=('prepare','backup','finish'));a=ap.parse_args()
    if a.phase=='prepare':
        m=read(ROOT/'firmware/manifest.json');assert m['version']==VERSION and m['timing_status']=='pass'
        assert inputs()==m['input_sha256'],'Source does not match built firmware'
        commit=None
        if (ROOT/'.git').exists():
            assert not subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip(),'Commit before deployment'
            commit=subprocess.check_output(['git','rev-parse','refs/tags/'+VERSION+'^{commit}'],cwd=ROOT,text=True).strip()
        for v in m['artifacts'].values():assert sha(ROOT/v['path'])==v['sha256'] and (ROOT/v['path']).stat().st_size==v['bytes']
        data=decode(ROOT/m['artifacts']['hex']['path']);stamp=now()
        baseline=read(ROOT/'config/deployment-baseline.json')
        folder=ROOT/'artifacts/hardware'/('flash-'+stamp.strftime('%Y%m%d-%H%M%S'));folder.mkdir(parents=True)
        SESSION.parent.mkdir(exist_ok=True);SESSION.write_text(str(folder),encoding='utf-8')
        write(folder/'preflight.json',{'version':VERSION,'timestamp':stamp.isoformat(),'timezone':'Asia/Shanghai','release_commit':commit,
            'release_tag':VERSION,'artifacts':m['artifacts'],'payload_bytes':len(data),'payload_sha256':hashlib.sha256(data).hexdigest(),
            'backup_bytes':max(1048576,((len(data)+65535)//65536)*65536),'previous_version':baseline['version'],
            'previous_payload_bytes':baseline['payload_bytes'],'previous_payload_sha256':baseline['payload_sha256'],
            'automatic_threshold':False,'fixed_rgb':[280,240,376],
            'metric_suites_run':[],'physical_cold_boot':'not performed','live_acceptance':'pending'})
        print(str(folder))
    else:
        folder=Path(SESSION.read_text(encoding='utf-8'));pre=read(folder/'preflight.json')
        if a.phase=='backup':
            result=read(folder/'backup-read-result.json');assert result['success'] and result['jedec']=='0xEF6017' and result['address']==0
            data=decode(ROOT/'.cache/flash-before.hex');assert len(data)==pre['backup_bytes'];p=folder/'flash-before.bin';assert not p.exists();p.write_bytes(data)
            write(folder/'backup.json',{'backup_bytes':len(data),'backup_sha256':sha(p),'matches_release_payload':
                hashlib.sha256(data[:pre['previous_payload_bytes']]).hexdigest()==pre['previous_payload_sha256']})
            print('Coverage backup saved before overwrite.')
        else:
            program=read(folder/'program-result.json');debug=read(folder/'debug-initialization.json');assert program['success'] and program['hostx1_verify_success'] and debug['vio_defaults_reapplied']
            assert 'finished with JTAG programming' in (folder/'activate.log').read_text(encoding='utf-8')
            summary={**pre,'completed_at':now().isoformat(),'flash_written':True,'backup':read(folder/'backup.json'),
                'vendor_hostx1_write_check':'pass','vendor_internal_max_clock_retry':'retry program using max clk' in (folder/'program.log').read_text(encoding='utf-8'),
                'application_loaded':True,'vio_defaults_reapplied':True,'extra_independent_readback':'not performed','camera_capture':'not performed'}
            write(folder/'summary.json',summary)
            (folder/'summary.txt').write_text(f"{VERSION}: Flash write and vendor verification completed. Payload {pre['payload_bytes']} bytes. Backup {pre['backup_bytes']} bytes.\n",encoding='utf-8')
            write(folder/'evidence-sha256.json',{p.name:sha(p) for p in folder.iterdir() if p.is_file() and p.name!='evidence-sha256.json'})
            print(json.dumps({'flash_written':True,'payload_bytes':pre['payload_bytes'],'record':str(folder)},ensure_ascii=False))
if __name__=='__main__':main()
