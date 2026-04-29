with open("lib/features/members/screens/member_dashboard_screen.dart", "r") as f:
    text = f.read()

# We need to extract the block correctly
start_str = """            if (_memberData != null &&
                _memberData!['is_multisport'] == false &&
                _memberData!['is_meditopia'] == false) ...["""

import re
# The block ends after the second SizedBox(height: 32),
pattern = re.compile(re.escape(start_str) + r".*?DailyTipWidget\(memberData: _memberData\),\n            const SizedBox\(height: 32\),", re.DOTALL)
match = pattern.search(text)
if match:
    block = match.group()
    # remove it
    text = text.replace(block, "")
    
    # insert it after GridView
    target_end = """                ),
              ],
            ),"""
    
    new_end = target_end + "\n            const SizedBox(height: 32),\n" + block
    text = text.replace(target_end, new_end)

with open("lib/features/members/screens/member_dashboard_screen.dart", "w") as f:
    f.write(text)
