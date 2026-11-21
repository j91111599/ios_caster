import pathlib
p = pathlib.Path(r"D:\RemotePro_Workspace\ios_caster\.github\workflows\build.yml")
t = p.read_text(encoding="utf-8")
t = t.replace("runs-on: macos-14", "runs-on: macos-13")
p.write_bytes(t.encode("utf-8"))
print("runs-on ->", [l for l in t.splitlines() if "runs-on" in l])
print("BOM:", p.read_bytes()[:3].hex())
