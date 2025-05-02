import os
import sys
import shutil

sys.path.append('Export')
from lumen_utils import *

lines = []

if ("--export" in sys.argv or "-e" in sys.argv):
    for file in os.listdir("Resources/Translation"):
        target = ""
        if file == "ja.po":
            target = "Japanese.po"
        elif file == "de.po":
            target = "German.po"
        elif file == "ko.po":
            target = "Korean.po"
        elif file == "zh.po":
            target = "Chinese.po"
        elif file == "ru.po":
            target = "Russian.po"
        elif file == "fr.po":
            target = "French.po"
        elif file == "es.po":
            target = "Spanish.po"
        elif file == "uk.po":
            target = "Ukrainian.po"
        
        if target == "":
            continue
        
        shutil.copy("Resources/Translation/" + file, "Resources/Translation/Output/" + target)
    exit()

f = open("Resources\Data\Technology.cfg", "r")
for line in f.readlines():
    if line.startswith("name"):
        lines.append(line.removeprefix("name = \"").removesuffix("\"\n"))
    elif line.startswith("description"):
        lines.append(line.removeprefix("description = \"").removesuffix("\"\n"))
    elif line.startswith(";name"): ## TODO: Tymczasowe
        lines.append(line.removeprefix(";name = \"").removesuffix("\"\n"))
    elif line.startswith(";description"):
        lines.append(line.removeprefix(";description = \"").removesuffix("\"\n"))

lines = list(dict.fromkeys(lines))
f = open("Resources/Translation/Source/Technology.txt", "w")
f.write("\n".join(lines))

lines = ["Empty", "Lumen", "Bullets", "Rockets",]

f = open("Resources\Data\Items.cfg", "r")
for line in f.readlines():
    if line.endswith(";\n"):
        continue

    if line.startswith("default_name"):
        lines.append(line.removeprefix("default_name = \"").removesuffix("\"\n"))
    elif line.startswith("description"):
        lines.append(line.removeprefix("description = \"").removesuffix("\"\n"))

f = open("Resources/Translation/Source/Items.txt", "w")
f.write("\n".join(lines))

lines = ["Hint\n"]

f = open("Resources\Data\Hints.txt", "r")
for line in f.readlines():
    lines.append(line)

f = open("Resources/Translation/Source/Hints.txt", "w")
f.write("".join(lines))

config = load_config()
os.system(config["godot_path"] + "/godot.windows.opt.tools.64.exe --no-window res://Tools/CampaignTranslation.tscn")

lines = []

lines.append(
"""#, fuzzy
msgid ""
msgstr ""
"Language: "
"MIME-Version: 1.0"
"Content-Type: text/plain; charset=UTF-8"
"Content-Transfer-Encoding: 8bit"

""")

used_lines = {}
dupes = []

for file in os.listdir("Resources/Translation/Source"):
    lines.append("# Group: " + os.path.splitext(file)[0] + "\n")
    lines.append("\n")

    f = open("Resources/Translation/Source/" + file, 'r')
    for line in f.readlines():
        if line.startswith("#") or line == "\n":
            continue
        
        if line in used_lines:
            dupes.append("Duplikat: %s (%s, %s)" % (line.rstrip(), used_lines[line], file))
        else:
            used_lines[line] = file
        
        if line == "English\n":
            lines.append("# This is the current language name. It says English in English, Deutsch in German etc.\n")

        lines.append("""msgid "%s"
msgstr ""

""" % line.rstrip())

lines = list(dict.fromkeys(lines))
f = open("Resources/Translation/Lumencraft.pot", "w")
f.write("".join(lines))

for file in os.listdir("Resources/Translation"):
    if ("--template" in sys.argv or "-t" in sys.argv) and file != "pl.po":
        continue
    
    if file.endswith(".po"):
        os.system("msgmerge --update --backup=off Resources/Translation/%s Resources\Translation\Lumencraft.pot" % (file))

for dupe in dupes:
    print(dupe)