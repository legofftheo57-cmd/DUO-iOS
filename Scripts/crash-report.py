import json, sys
raw = open(sys.argv[1]).read().split('\n', 1)
d = json.loads(raw[1]) if len(raw) > 1 else {}
print(d.get('exception'), '\n', d.get('termination'))
imgs = d.get('usedImages', [])
for t in [t for t in d.get('threads', []) if t.get('triggered')]:
    for f in t.get('frames', [])[:40]:
        i = f.get('imageIndex')
        name = imgs[i]['name'] if i is not None and i < len(imgs) else '?'
        print(name, f.get('symbol'), f.get('sourceFile'), f.get('sourceLine'))
