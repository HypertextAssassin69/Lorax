#!/usr/bin/env python3
# trunk-ignore-all(ruff/F821)
# trunk-ignore-all(flake8/F821): For SConstruct imports
Import("env")
platform = env.PioPlatform()

if platform.name == "native":
    env.Replace(PROGNAME="meshtasticd")
else:
    from readprops import readProps
    prefsLoc = env["PROJECT_DIR"] + "/version.properties"
    verObj = readProps(prefsLoc)
    env.Replace(PROGNAME=f"firmware-{env.get('PIOENV')}-{verObj['long']}")
    env.Replace(ESP32_FS_IMAGE_NAME=f"littlefs-{env.get('PIOENV')}-{verObj['long']}")

# Print the new program name for verification
print(f"PROGNAME: {env.get('PROGNAME')}")
if platform.name == "espressif32":
    print(f"ESP32_FS_IMAGE_NAME: {env.get('ESP32_FS_IMAGE_NAME')}")

# Auto-patch RadioLib SX126x chip detection for SX1262 silicon returning "SX1262" instead of "SX1261"
import glob, os
for radiolib_cpp in glob.glob(os.path.join(env["PROJECT_DIR"], ".pio", "libdeps", "*", "RadioLib", "src", "modules", "SX126x", "SX126x.cpp")):
    try:
        with open(radiolib_cpp, "r", encoding="utf-8") as f:
            content = f.read()
        target = "if(strncmp(verStr, version, 6) == 0)"
        replacement = 'if(strncmp(verStr, version, 6) == 0 || strncmp(version, "SX126", 5) == 0)'
        if target in content and replacement not in content:
            content = content.replace(target, replacement)
            with open(radiolib_cpp, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"[RadioLib Patch] Applied SX1262 silicon compatibility patch to {radiolib_cpp}")
    except Exception as e:
        print(f"[RadioLib Patch Error] {e}")

