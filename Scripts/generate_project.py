"""Deterministic Xcode project generator; Python 3 standard library only."""
from pathlib import Path
import hashlib,json,plistlib
ROOT=Path(__file__).resolve().parents[1]
objects={}
def uid(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def add(key,isa,**fields):
 i=uid(key); objects[i]={'isa':isa,**fields}; return i
def emit(x):
 if isinstance(x,dict): return '{ '+ ' '.join(f'{k} = {emit(v)};' for k,v in x.items())+' }'
 if isinstance(x,list): return '( '+', '.join(emit(v) for v in x)+ (' ,' if x else '')+' )'
 return json.dumps(str(x),ensure_ascii=False)
def file(path,kind): return add('file:'+path,'PBXFileReference',lastKnownFileType=kind,path=path,sourceTree='<group>')
def build(ref): return add('build:'+ref,'PBXBuildFile',fileRef=ref)
app=uid('target:DUO'); unit=uid('target:AppTests'); ui=uid('target:UITests'); project=uid('project')
app_product=add('product:DUO','PBXFileReference',explicitFileType='wrapper.application',path='DUO.app',sourceTree='BUILT_PRODUCTS_DIR',includeInIndex=0)
ui_product=add('product:UITests','PBXFileReference',explicitFileType='wrapper.cfbundle',path='DUOUITests.xctest',sourceTree='BUILT_PRODUCTS_DIR',includeInIndex=0)
app_refs=[file(str(p.relative_to(ROOT)),'sourcecode.swift') for p in sorted((ROOT/'App').glob('*.swift'))]
unit_product=add('product:AppTests','PBXFileReference',explicitFileType='wrapper.cfbundle',path='DUOAppTests.xctest',sourceTree='BUILT_PRODUCTS_DIR',includeInIndex=0)
unit_refs=[file('AppTests/AppStoreTests.swift','sourcecode.swift')]
ui_refs=[file('UITests/DUOUITests.swift','sourcecode.swift')]
assets=file('Resources/Assets.xcassets','folder.assetcatalog'); privacy=file('Resources/PrivacyInfo.xcprivacy','text.xml'); info=file('Resources/Info.plist','text.plist.xml'); config=file('Config.xcconfig','text.xcconfig')
products=add('products','PBXGroup',children=[app_product,ui_product,unit_product],name='Products',sourceTree='<group>')
main=add('main','PBXGroup',children=app_refs+ui_refs+unit_refs+[assets,privacy,info,config,products],sourceTree='<group>')
local=add('package','XCLocalSwiftPackageReference',relativePath='.')
product=add('dependency:core','XCSwiftPackageProductDependency',package=local,productName='DUOCore')
core_build=add('build:core','PBXBuildFile',productRef=product)
def phase(name,isa,files): return add(name,isa,buildActionMask=2147483647,files=files,runOnlyForDeploymentPostprocessing=0)
app_sources=phase('sources:app','PBXSourcesBuildPhase',[build(r) for r in app_refs]); app_res=phase('resources:app','PBXResourcesBuildPhase',[build(assets),build(privacy)]); app_frameworks=phase('frameworks:app','PBXFrameworksBuildPhase',[core_build])
unit_sources=phase('sources:unit','PBXSourcesBuildPhase',[build(r) for r in unit_refs]); unit_core_build=add('build:unit-core','PBXBuildFile',productRef=product); unit_frameworks=phase('frameworks:unit','PBXFrameworksBuildPhase',[unit_core_build]); unit_res=phase('resources:unit','PBXResourcesBuildPhase',[])
ui_sources=phase('sources:ui','PBXSourcesBuildPhase',[build(r) for r in ui_refs]); ui_frameworks=phase('frameworks:ui','PBXFrameworksBuildPhase',[]); ui_res=phase('resources:ui','PBXResourcesBuildPhase',[])
def configs(prefix,base):
 refs=[]
 for name in ['Debug','Release']:
  settings=dict(base)
  settings['SWIFT_OPTIMIZATION_LEVEL']='-Onone' if name=='Debug' else '-O'
  if name=='Debug': settings['ENABLE_TESTABILITY']='YES'; settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG $(inherited)'
  refs.append(add(prefix+name,'XCBuildConfiguration',baseConfigurationReference=config,buildSettings=settings,name=name))
 return add(prefix+'list','XCConfigurationList',buildConfigurations=refs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
shared={'IPHONEOS_DEPLOYMENT_TARGET':'17.0','SDKROOT':'iphoneos','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','DEVELOPMENT_TEAM':'$(DUO_DEVELOPMENT_TEAM)'}
proj_conf=configs('project:',shared)
app_conf=configs('app:',{'PRODUCT_NAME':'DUO','PRODUCT_BUNDLE_IDENTIFIER':'$(DUO_BUNDLE_ID)','GENERATE_INFOPLIST_FILE':'NO','INFOPLIST_FILE':'Resources/Info.plist','INFOPLIST_KEY_SUPABASE_URL':'$(SUPABASE_URL)','INFOPLIST_KEY_SUPABASE_PUBLISHABLE_KEY':'$(SUPABASE_PUBLISHABLE_KEY)','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','MARKETING_VERSION':'0.5.0','CURRENT_PROJECT_VERSION':'3','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','INFOPLIST_KEY_ITSAppUsesNonExemptEncryption':'NO'})
unit_conf=configs('unit:',{'PRODUCT_NAME':'DUOAppTests','PRODUCT_BUNDLE_IDENTIFIER':'$(DUO_BUNDLE_ID).apptests','GENERATE_INFOPLIST_FILE':'YES','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/DUO.app/DUO','BUNDLE_LOADER':'$(TEST_HOST)','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator'})
ui_conf=configs('ui:',{'PRODUCT_NAME':'DUOUITests','PRODUCT_BUNDLE_IDENTIFIER':'$(DUO_BUNDLE_ID).uitests','GENERATE_INFOPLIST_FILE':'YES','TEST_TARGET_NAME':'DUO','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator'})
proxy=add('proxy','PBXContainerItemProxy',containerPortal=project,proxyType=1,remoteGlobalIDString=app,remoteInfo='DUO')
dep=add('ui-app-dep','PBXTargetDependency',target=app,targetProxy=proxy)
add('target:DUO','PBXNativeTarget',buildConfigurationList=app_conf,buildPhases=[app_sources,app_frameworks,app_res],buildRules=[],dependencies=[],name='DUO',packageProductDependencies=[product],productName='DUO',productReference=app_product,productType='com.apple.product-type.application')
add('target:AppTests','PBXNativeTarget',buildConfigurationList=unit_conf,buildPhases=[unit_sources,unit_frameworks,unit_res],buildRules=[],dependencies=[dep],name='DUOAppTests',packageProductDependencies=[product],productName='DUOAppTests',productReference=unit_product,productType='com.apple.product-type.bundle.unit-test')
add('target:UITests','PBXNativeTarget',buildConfigurationList=ui_conf,buildPhases=[ui_sources,ui_frameworks,ui_res],buildRules=[],dependencies=[dep],name='DUOUITests',productName='DUOUITests',productReference=ui_product,productType='com.apple.product-type.bundle.ui-testing')
add('project','PBXProject',attributes={'LastUpgradeCheck':'1600','TargetAttributes':{app:{'CreatedOnToolsVersion':'16.0'},ui:{'CreatedOnToolsVersion':'16.0','TestTargetID':app}}},buildConfigurationList=proj_conf,compatibilityVersion='Xcode 14.0',developmentRegion='fr',hasScannedForEncodings=0,knownRegions=['fr','en','Base'],mainGroup=main,productRefGroup=products,projectDirPath='',projectRoot='',packageReferences=[local],targets=[app,ui,unit])
out=ROOT/'DUO.xcodeproj';out.mkdir(exist_ok=True)
(out/'project.pbxproj').write_text('// !$*UTF8*$!\n'+emit({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':project})+'\n')
schemes=out/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
def ref(i,name,product): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{i}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:DUO.xcodeproj"/>'
t=ref(unit,'DUOAppTests','DUOAppTests.xctest')
a=ref(app,'DUO','DUO.app');u=ref(ui,'DUOUITests','DUOUITests.xctest')
(schemes/'DUO.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{a}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{t}</TestableReference><TestableReference skipped="NO">{u}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{a}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{a}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print('Project generated with',len(app_refs),'app sources')
