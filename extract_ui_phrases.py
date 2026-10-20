import re, json

with open('dashboard.html', 'r', encoding='utf-8', errors='ignore') as f:
    text = f.read()

# Strip <script> and <style>
html_no_scripts = re.sub(r'<(script|style)\b[^>]*>[\s\S]*?</\1>', '', text, flags=re.IGNORECASE)

raw_texts = re.findall(r'>([^<]+)<', html_no_scripts)
attrs = re.findall(r'(?:placeholder|title|aria-label)="([^"]+)"', html_no_scripts)

phrases = set()
for t in raw_texts + attrs:
    cleaned = t.strip()
    # Check if contains at least 3 letters
    letters = sum(1 for c in cleaned if c.isalpha())
    if letters >= 3 and not any(ord(c) > 127 for c in cleaned):
        # Ignore CSS or hex or IDs
        if not cleaned.startswith('#') and not cleaned.startswith('rgba') and not cleaned.startswith('var('):
            phrases.add(cleaned)

print(f"Total candidate English phrases: {len(phrases)}")

# Let's inspect phrases that have multiple words or significant UI importance
ui_phrases = sorted(list(phrases), key=lambda x: (len(x.split()), len(x)), reverse=True)

with open('candidate_phrases.json', 'w', encoding='utf-8') as f:
    json.dump(ui_phrases, f, ensure_ascii=False, indent=2)

print("Saved candidate_phrases.json")
