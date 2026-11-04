"""Self-contained release identity and direct Efinity build records (stdlib only)."""
from pathlib import Path
import argparse,hashlib,json,re,shutil,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
VERSION='V4'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,value):p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def inputs():
    paths=[p for d in ('rtl','ip','tools') for p in (ROOT/d).rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    paths += [ROOT/n for n in ('ti60f225_oob.xml','ti60f225_oob.sdc','ti60f225_oob.peri.xml','debug_top.v',
        'debug_profile.wizard.json','Panel_1080p_reg.mem','build.ps1','flash.ps1','config/model.json','config/source-files.json')]
    return {p.relative_to(ROOT).as_posix():sha(p) for p in sorted(set(paths))}
def audit():
    tree=ET.parse(ROOT/'ti60f225_oob.xml');files=[n.attrib['name'] for n in tree.iter() if n.tag.split('}')[-1]=='design_file']
    assert len(files)==89 and all((ROOT/n).is_file() for n in files),'Production source missing'
    origin=read(ROOT/'config/source-files.json')
    revised=origin.get('revision',{}).get('source_sha256',{})
    assert set(revised)<=set(origin['source_sha256'])
    for name,digest in origin['source_sha256'].items():assert sha(ROOT/name)==revised.get(name,digest),name
    assert not any('otsu' in n.lower() for n in files)
    active='\n'.join((ROOT/n).read_text(encoding='utf-8',errors='replace') for n in files)
    assert not re.search(r'\b(canny_otsu_2px|g_otsu|u_otsu|ADAPTIVE_THRESHOLD)\b',active)
    core=(ROOT/'rtl/edge/hand_cnn_core.v').read_text();assert "gap>=64" in core
    # Compiler inputs/ROM/header dependencies are checked without model or score suites.
    for name in files:
        p=ROOT/name;text=re.sub(r'/\*.*?\*/|//[^\n]*','',p.read_text(encoding='utf-8',errors='replace'),flags=re.S)
        for ref in re.findall(r'`include\s*"([^"]+)"',text):
            assert any(q.is_file() for q in (p.parent/ref,ROOT/ref,ROOT/'rtl'/ref,ROOT/'ip/csi_rx_controller'/ref)),(name,ref)
    for name in ('rtl/edge/cnn/weights.mem','rtl/edge/cnn/parameters.mem','rtl/edge/digit_features_v14.mem',
                 'rtl/edge/printed_digit_templates.mem','rtl/gamma_conrrection/2P2.mem','Panel_1080p_reg.mem'):
        assert (ROOT/name).is_file(),name
    return {'production_source_files':len(files),'source_identity_verified':True,'automatic_threshold':False,
            'fixed_margin_q6':64,'dependency_audit':'pass','old_metric_suites_run':[]}
def timing(text):
    setup=text.split('Setup (Max) Clock Relationship',1)[1].split('Hold (Min) Clock Relationship',1)[0]
    hold=text.split('Hold (Min) Clock Relationship',1)[1].split('Clock Relationship Summary (end)',1)[0]
    pattern=r'^\s*(\S+)\s+(\S+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+\('
    return [[float(v[3]) for v in re.findall(pattern,part,re.M)] for part in (setup,hold)]
def main():
    ap=argparse.ArgumentParser();ap.add_argument('phase',choices=('begin','finish','seal'));args=ap.parse_args();build=ROOT/'.build'
    if args.phase=='begin':
        assert not (build/'manifest.json').exists(),'Existing completed build retained'
        build.mkdir(exist_ok=True);write(build/'inputs-before.json',inputs());write(build/'dependency-audit.json',audit());print('Production dependency audit PASS; no metric suites.')
    elif args.phase=='finish':
        before=read(build/'inputs-before.json');assert before==inputs(),'Build inputs changed'
        for stage in ('map','interface','pnr','pgm'):
            assert re.search(stage+r'\s*:\s*PASS',(build/(stage+'.log')).read_text(encoding='utf-8',errors='replace')),stage
        setup,hold=timing((build/'ti60f225_oob.timing.rpt').read_text(encoding='utf-8',errors='replace'))
        assert setup and hold and min(setup+hold)>=0,'Timing did not close'
        info=(build/'ti60f225_oob.info.log').read_text(encoding='utf-8',errors='replace')
        resources={n:int(re.findall(r'\b'+n+r'\s*:\s*(\d+)',info)[-1]) for n in ('EFX_LUT4','EFX_FF','EFX_RAM10','EFX_DPRAM10','EFX_DSP48','EFX_DSP24')}
        manifest={'version':VERSION,'date':'2026-11-04','tool':'Efinity 2026.1.132','device':'Ti60F225I3','stages':{s:'pass' for s in ('map','interface','pnr','pgm')},
            'timing_status':'pass','worst_setup_slack_ns':min(setup),'worst_hold_slack_ns':min(hold),'resources':resources,
            'input_sha256':before,'source_audit':audit(),'metric_suites_run':[],'automatic_threshold':False,
            'metrics_scope':'V4 production build',
            'artifacts':{ext:{'path':'.build/ti60f225_oob.'+ext,'bytes':(build/('ti60f225_oob.'+ext)).stat().st_size,'sha256':sha(build/('ti60f225_oob.'+ext))} for ext in ('bit','hex')}}
        write(build/'inputs-after.json',inputs());write(build/'manifest.json',manifest)
        print(json.dumps({k:manifest[k] for k in ('version','resources','worst_setup_slack_ns','worst_hold_slack_ns','artifacts')},indent=2))
    else:
        m=read(build/'manifest.json');assert inputs()==m['input_sha256'];dst=ROOT/'firmware';assert not dst.exists(),'Sealed release retained';dst.mkdir()
        for ext,item in m['artifacts'].items():
            p=ROOT/item['path'];assert sha(p)==item['sha256'];q=dst/('ti60f225_oob.'+ext);shutil.copy2(p,q);item['path']=q.relative_to(ROOT).as_posix()
        write(dst/'manifest.json',m);evidence=ROOT/'artifacts/build';evidence.mkdir(parents=True)
        for name in ('map.log','interface.log','pnr.log','pgm.log','ti60f225_oob.timing.rpt','dependency-audit.json'):
            shutil.copy2(build/name,evidence/name)
        print('Final firmware sealed; proceed directly to normal Flash flow.')
if __name__=='__main__':main()
