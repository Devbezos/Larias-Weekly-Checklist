path = r'c:\Users\Devastation\source\repos\Larias-Weekly-Midnight-Checklist\Modules\LariasWeeklyChecklist_CharPicker.lua'
with open(path, encoding='utf-8') as f:
    content = f.read()

# The file stores the literal 6-char escape sequences \u2716 / \u2714 (not real codepoints).
old_x     = r'        btn:SetText("|cffff4040\u2716|r")'
new_x     =  '        btn:SetText("|TInterface\\\\RaidFrame\\\\ReadyCheck-NotReady:12:12|t")'
old_check = r'        local CHECK = "|cff00ff00\u2714|r"'
new_check =  '        local CHECK = "|TInterface\\\\RaidFrame\\\\ReadyCheck-Ready:12:12|t"'

print('X found:',     old_x     in content)
print('CHECK found:', old_check in content)

content = content.replace(old_x,     new_x)
content = content.replace(old_check, new_check)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Done.')
