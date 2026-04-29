with open("lib/features/members/screens/member_dashboard_screen.dart", "r") as f:
    text = f.read()

# We need to take out:
# 1) `if (_memberData != null && _memberData!['is_multisport'] == false && _memberData!['is_meditopia'] == false) ...[` block
# 2) `const SizedBox(height: 32),`
# 3) `if (_streak != null) ...[` block
# 4) `if (_badges.isNotEmpty) ...[` block
# 5) `DailyTipWidget(memberData: _memberData),`
# 6) `const SizedBox(height: 32),`
import re

start_str = r"            if \(_memberData != null &&[\s\S]*?const SizedBox\(height: 32\),"
match = re.search(start_str, text)
if match:
    block = match.group()
    text = text.replace(block, "")
    
    # insert before `          ],` of Column
    # The last `GridView.count` ends at:
    # `              ],`
    # `            ),`
    # `          ],`
    insert_target = "            ),\n          ],\n        ),"
    text = text.replace(insert_target, "            ),\n" + "            const SizedBox(height: 32),\n" + block + "\n          ],\n        ),")

with open("lib/features/members/screens/member_dashboard_screen.dart", "w") as f:
    f.write(text)
