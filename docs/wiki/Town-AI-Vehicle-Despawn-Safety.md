# Town AI Vehicle Despawn Safety

This route is kept for older links. Current town-AI and cleanup routing lives in [AI, headless and performance](AI-Headless-And-Performance), [Gameplay systems atlas](Gameplay-Systems-Atlas) and [Deep-review findings](Deep-Review-Findings).

Before changing town-AI despawn logic, source-check player occupancy, AI-only cleanup and HC ownership assumptions.

**DR-45 anchor:** [Deep-review findings](Deep-Review-Findings) Round 36 promoted this playbook to DR-45. Current source still deletes town-AI vehicles at Server/FSM/server_town_ai.sqf:213-216 when !(isPlayer leader group _x), which misses player cargo/turret occupants. The patch shape remains: preserve empty AI-only cleanup, but skip/delete-transfer any vehicle only after checking full player occupancy, not just the group leader.

