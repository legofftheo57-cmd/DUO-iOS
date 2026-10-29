"""Static checks only. Does not replace Xcode builds, UI or server execution."""
from pathlib import Path
import json,plistlib,re,sys
from tree_sitter import Language,Parser
import tree_sitter_swift
from pglast import parse_sql
from openstep_parser import OpenStepDecoder
root=Path(__file__).resolve().parents[1]
results=[]
def test(name,fn):
 try: fn();results.append({'name':name,'status':'PASS'})
 except Exception as e: results.append({'name':name,'status':'FAIL','error':str(e)})
def require(value,message='assertion failed'):
 if not value:raise AssertionError(message)
parser=Parser(Language(tree_sitter_swift.language()))
for p in list((root/'App').glob('*.swift'))+list((root/'Core').glob('*.swift'))+list((root/'Tests').glob('*.swift'))+list((root/'UITests').glob('*.swift')):
 test('Swift syntax '+str(p.relative_to(root)),lambda p=p:require(not parser.parse(p.read_bytes()).root_node.has_error))
test('PostgreSQL 001 syntax',lambda:require(len(parse_sql((root/'Backend/001_schema.sql').read_text()))>=25))
test('PostgreSQL 002 syntax',lambda:require(len(parse_sql((root/'Backend/002_account_privacy.sql').read_text()))>=8))
test('Deletion RPC checks caller identity',lambda:require('uid uuid := auth.uid()' in (root/'Backend/002_account_privacy.sql').read_text()))
test('Server sets creator, not client',lambda:require('new.created_by := auth.uid()' in (root/'Backend/002_account_privacy.sql').read_text()))
test('Deleted identity cannot join household',lambda:require('block_deleted_member' in (root/'Backend/002_account_privacy.sql').read_text()))
test('Account deletion endpoint does not read requested user ID',lambda:require('ctx.userClaims?.id' in (root/'Backend/functions/delete-account/index.ts').read_text()))
project=OpenStepDecoder.ParseFromString((root/'DUO.xcodeproj/project.pbxproj').read_text())
objects=project['objects']
for obj in objects.values():
 if obj['isa']=='PBXFileReference' and obj.get('sourceTree')=='<group>':test('Xcode path '+obj['path'],lambda obj=obj:require((root/obj['path']).exists()))
for p in (root/'Resources').rglob('*.json'):test('JSON asset '+str(p.relative_to(root)),lambda p=p:json.loads(p.read_text()))
test('Privacy manifest plist',lambda:plistlib.loads((root/'Resources/PrivacyInfo.xcprivacy').read_bytes()))
light=['F5F6F8','E5EAF1','C4D0E0','9AAEC8','202632','60728C','697F9E'];dark=['0B0D12','222936','5A6D89','B6C9E5','F1F5FC','B6C9E5','B6C9E5']
names=['Background','Surface','Ice','Accent','Text','Secondary','SecondaryAccent']
def hexvalue(c):return ''.join(f'{round(float(c["color"]["components"][key])*255):02X}' for key in ['red','green','blue'])
for i,name in enumerate(names):
 c=json.loads((root/f'Resources/Assets.xcassets/{name}.colorset/Contents.json').read_text())['colors']
 test('Exact palette '+name,lambda i=i,c=c:require([hexvalue(x) for x in c]==[light[i],dark[i]]))
def luminance(h):
 s=[int(h[i:i+2],16)/255 for i in [0,2,4]]
 return sum(v*w for v,w in zip([c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in s],[.2126,.7152,.0722]))
contrasts=[]
for mode,backgrounds,foregrounds in [('light',['F5F6F8','E5EAF1'],['202632','53657D','465D7B','A12C36']),('dark',['0B0D12','222936'],['F1F5FC','B6C9E5','FFADB5'])]:
 for bg in backgrounds:
  for fg in foregrounds:
   a,b=sorted([luminance(bg),luminance(fg)]);ratio=(b+.05)/(a+.05);contrasts.append({'mode':mode,'foreground':fg,'background':bg,'ratio':round(ratio,3)})
   test(f'Contrast {fg}/{bg}',lambda ratio=ratio:require(ratio>=4.5))
text='\n'.join(p.read_text() for p in (root/'App').glob('*.swift'))
for name in set(re.findall(r'Color\("([^"]+)"\)',text)):test('Color reference '+name,lambda name=name:require((root/f'Resources/Assets.xcassets/{name}.colorset').exists()))
report={'scope':'Static syntax, project references, palette and opaque-background contrasts; not iOS execution','results':results,'contrastRatios':contrasts,'passed':sum(r['status']=='PASS' for r in results),'failed':sum(r['status']=='FAIL' for r in results)}
(root/'Docs/static-checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps({k:report[k] for k in ['passed','failed']}));sys.exit(bool(report['failed']))
