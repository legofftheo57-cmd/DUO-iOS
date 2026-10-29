"""Portable, dependency-free DUO packaging checks (not an iPhone build)."""
from pathlib import Path
import plistlib, json, hashlib, sys
ROOT=Path(__file__).resolve().parents[1]
checks=[]
def check(name,ok):
    checks.append({'name':name,'status':'PASS' if ok else 'FAIL'})
    print(('OK  ' if ok else 'FAIL ')+name)
info=plistlib.loads((ROOT/'Resources/Info.plist').read_bytes())
check('DUO URL scheme',any('duo' in entry.get('CFBundleURLSchemes',[]) for entry in info.get('CFBundleURLTypes',[])))
check('Information plist bundle keys',all(k in info for k in ('CFBundleIdentifier','CFBundleExecutable','CFBundleVersion','CFBundleShortVersionString')))
check('Explicit plist in project', 'Resources/Info.plist' in (ROOT/'DUO.xcodeproj/project.pbxproj').read_text())
check('No advertising ID declared', 'NSUserTrackingUsageDescription' not in info)
check('No embedded secret key',all(s not in (ROOT/'Config.xcconfig').read_text() for s in ('sb_secret_', 'service_role', 'sk-proj-')))
check('Invitation UI and URL entry',all(s in (ROOT/'App/SettingsView.swift').read_text() for s in ('ShareLink','Inviter Lilou','Accepter l’invitation')))
check('Deep link handling', '.onOpenURL' in (ROOT/'App/DUOApp.swift').read_text())
check('AI requires direct action', 'Demander à l’IA en ligne' in (ROOT/'App/AssistantView.swift').read_text())
check('AI provider key only server-side','OPENAI_API_KEY' not in ''.join(x.read_text() for x in (ROOT/'App').glob('*.swift')))
check('AI model server-configurable','DUO_AI_MODEL' in (ROOT/'Backend/functions/duo-assistant/index.ts').read_text())
check('AI server does not send snapshot', 'snapshot' not in (ROOT/'Backend/functions/duo-assistant/index.ts').read_text().lower())
check('AI cap and deletion counter purge', all(s in (ROOT/'Backend/003_ai_quota.sql').read_text() for s in ('count<5','remove_ai_usage_on_account_deletion')))
check('Account erasure files preserved', all((ROOT/path).exists() for path in ['Backend/002_account_privacy.sql','Backend/functions/delete-account/index.ts']))
check('All 10 Swift app sources registered', all('App/'+p.name in (ROOT/'DUO.xcodeproj/project.pbxproj').read_text() for p in (ROOT/'App').glob('*.swift')))
for p in (ROOT/'Resources/Assets.xcassets').rglob('Contents.json'):
    check('JSON '+p.parent.name, isinstance(json.loads(p.read_text()),dict))
check('Privacy manifest parses', isinstance(plistlib.loads((ROOT/'Resources/PrivacyInfo.xcprivacy').read_bytes()),dict))
result={'scope':'Dependency-free static checks. Not a simulator build, cloud deployment, or SQL execution.','passed':sum(x['status']=='PASS' for x in checks),'failed':sum(x['status']=='FAIL' for x in checks),'results':checks}
(ROOT/'Docs/check-essentials-0.4.0.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
print(json.dumps({'passed':result['passed'],'failed':result['failed']}))
sys.exit(1 if result['failed'] else 0)
