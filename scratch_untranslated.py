import re

with open('dashboard.html', 'r', encoding='utf-8', errors='ignore') as f:
    text = f.read()

# Strip <script> and <style>
html_no_scripts = re.sub(r'<(script|style)\b[^>]*>[\s\S]*?</\1>', '', text, flags=re.IGNORECASE)

# Extract text between tags >text<
raw_texts = re.findall(r'>([^<]+)<', html_no_scripts)

# Extract placeholders and titles
attrs = re.findall(r'(?:placeholder|title|aria-label)="([^"]+)"', html_no_scripts)

all_strings = set()
for t in raw_texts + attrs:
    cleaned = t.strip()
    # Filter out pure numbers, short symbols, empty
    if len(cleaned) > 2 and not cleaned.isdigit() and not re.match(r'^[\d\s.,:;%/\-+=_!@#$^&*(){}\[\]|\\<>?~`]+$', cleaned):
        all_strings.add(cleaned)

print(f"Total unique visible text strings in HTML markup: {len(all_strings)}")

# Read existing translated labels from dashboard.html
labels_match = re.search(r'const labels = \{([\s\S]*?)\};', text)
existing_labels = set()
if labels_match:
    for k in re.findall(r"'([^']+)'\s*:", labels_match.group(1)):
        existing_labels.add(k)

print(f"Existing translated keys: {len(existing_labels)}")

# Find untranslated English strings
untranslated = []
for s in sorted(list(all_strings)):
    if s not in existing_labels and not any(ord(c) > 127 for c in s): # pure ASCII = likely English
        if len(s.split()) >= 1 and any(c.isalpha() for c in s):
            untranslated.append(s)

print(f"Untranslated English strings: {len(untranslated)}")
print("Sample of untranslated:")
for s in untranslated[:60]:
    print("  ", s)
