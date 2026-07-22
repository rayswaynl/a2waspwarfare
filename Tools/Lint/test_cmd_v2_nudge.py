"""Deterministic regression coverage for the COMMAND V2 nudge system (P4).

Design:  docs/design/COMMAND-V2-NUDGE-SYSTEM-DESIGN.md
Rulings: owner decision packet 2026-07-18 (5 items, see DESIGN-DECISIONS below).

There is no SQF interpreter available in CI, so — like every other test in this
directory — these are static source assertions over the maintained mission trees.
They lock the five owner rulings and the flag-off inertness contract in place, and
they prove the three generated terrain copies stay byte-identical.

Run:  python Tools\\Lint\\test_cmd_v2_nudge.py
"""

from __future__ import annotations

import unittest
from pathlib import Path

from check_sqf import mask_comments

ROOT = Path(__file__).resolve().parents[2]

MAINTAINED_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)

CONSTANTS = Path("Common/Init/Init_CommonConstants.sqf")
WEIGHT_FN = Path("Common/Functions/Common_TownNudgeWeight.sqf")
HANDLE = Path("Server/Functions/Server_HandleSpecial.sqf")
SUPPORT_FN = Path("Server/Functions/Server_CmdSupportAir.sqf")
ALLOCATE = Path("Server/AI/Commander/AI_Commander_Allocate.sqf")
INIT_COMMON = Path("Common/Init/Init_Common.sqf")
INIT_SERVER = Path("Server/Init/Init_Server.sqf")
MENU = Path("Client/GUI/GUI_Menu_Command.sqf")
CLIENT_HANDLE = Path("Client/PVFunctions/HandleSpecial.sqf")
DIALOGS = Path("Rsc/Dialogs.hpp")

#: Files that must be byte-identical across all three terrains.
#: Init_Server.sqf is deliberately EXCLUDED: it carries a pre-existing, intended per-map
#: delta (``["SET_MAP", 1|2|3] call WFBE_SE_FNC_CallDatabaseSetMap``). RegistrationTests
#: asserts our own line is present in all three instead.
ALL_TOUCHED = (
    CONSTANTS, WEIGHT_FN, HANDLE, SUPPORT_FN, ALLOCATE,
    INIT_COMMON, MENU, CLIENT_HANDLE, DIALOGS,
)

#: wave0721 arming ruling (owner, 2026-07-21: "everything flags on, no dark new stuff") -
#: every master flag flipped 0->1 EXCEPT WFBE_C_CMD_SUPPORT_JET, deliberately left dark
#: (reserved, no code path yet - see Init_CommonConstants.sqf's own comment on that line).
ARMED_MASTER_FLAGS = (
    "WFBE_C_CMD_TOWN_NUDGE",
    "WFBE_C_CMD_TEAM_DOCTRINE",
    "WFBE_C_CMD_POSTURE_GARRISON",
    "WFBE_C_CMD_SUPPORT_AIR",
)

#: Excluded from the arming ruling on purpose - stays at its pre-arming default.
DARK_MASTER_FLAGS = (
    "WFBE_C_CMD_SUPPORT_JET",
)

MASTER_FLAGS = ARMED_MASTER_FLAGS + DARK_MASTER_FLAGS

#: Tunables. These carry non-zero defaults but are only read once a master flag is on.
TUNABLE_FLAGS = (
    "WFBE_C_CMD_TOWN_NUDGE_WEIGHT",
    "WFBE_C_CMD_TOWN_NUDGE_CAP",
    "WFBE_C_CMD_TOWN_NUDGE_TTL",
    "WFBE_C_CMD_TOWN_NUDGE_COOLDOWN",
    "WFBE_C_CMD_TOWN_NUDGE_RING",
    "WFBE_C_CMD_TEAM_DOCTRINE_COOLDOWN",
    "WFBE_C_CMD_SUPPORT_AIR_TTL",
    "WFBE_C_CMD_SUPPORT_AIR_RANGE",
    "WFBE_C_CMD_SUPPORT_AIR_FOLLOW_INT",
    "WFBE_C_CMD_SUPPORT_AIR_MAX_ACTIVE",
    "WFBE_C_CMD_SUPPORT_AIR_COOLDOWN",
    "WFBE_C_CMD_SUPPORT_AIR_CAS_RANGE",
    "WFBE_C_CMD_SUPPORT_AIR_RECALL",
    "WFBE_C_CMD_SUPPORT_AIR_RECALL_HYST",
    "WFBE_C_CMD_SUPPORT_AIR_MIN_ALT",
)

NEW_VERBS = (
    "aicom-town-nudge",
    "aicom-team-doctrine",
    "aicom-support-air",
    "aicom-support-air-release",
)


def read(root: Path, relative: Path) -> str:
    return (root / relative).read_text(encoding="utf-8")


def read_code(root: Path, relative: Path) -> str:
    """Source with comments blanked out.

    Needed wherever a test asserts the ABSENCE of a token: these files document the A2 OA
    banned-command list and the free-loan ruling in their own header comments, so a raw
    substring scan would match the prose that exists precisely to forbid the thing.
    """
    return mask_comments((root / relative).read_text(encoding="utf-8"))


class FlagContractTests(unittest.TestCase):
    """Flag policy: append-only, masters default 0, tunables present."""

    def test_every_master_flag_is_registered_at_its_armed_default(self) -> None:
        """wave0721 arming ruling (2026-07-21) flipped ARMED_MASTER_FLAGS 0->1; this was
        originally pinned as "every master flag defaults to 0" before that ruling landed -
        DARK_MASTER_FLAGS (just WFBE_C_CMD_SUPPORT_JET) is the sole deliberate holdout still
        pinned at 0."""
        for root in MAINTAINED_ROOTS:
            text = read(root, CONSTANTS)
            for flag in ARMED_MASTER_FLAGS:
                needle = 'if (isNil "%s")' % flag
                with self.subTest(root=root.name, flag=flag):
                    self.assertIn(needle, text)
                    self.assertIn("{%s = 1}" % flag, text)
            for flag in DARK_MASTER_FLAGS:
                needle = 'if (isNil "%s")' % flag
                with self.subTest(root=root.name, flag=flag):
                    self.assertIn(needle, text)
                    self.assertIn("{%s = 0}" % flag, text)

    def test_every_tunable_flag_is_registered(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, CONSTANTS)
            for flag in TUNABLE_FLAGS:
                with self.subTest(root=root.name, flag=flag):
                    self.assertIn('if (isNil "%s")' % flag, text)

    def test_town_nudge_weight_stays_below_grudge_bonus(self) -> None:
        """Design section 3 sizing rule: a suggestion breaks a tie, it never forces a target.

        Ceiling is WEIGHT * sqrt(CAP); it must stay under WFBE_C_AICOM_GRUDGE_BONUS (400).
        """
        for root in MAINTAINED_ROOTS:
            text = read(root, CONSTANTS)
            with self.subTest(root=root.name):
                self.assertIn("{WFBE_C_CMD_TOWN_NUDGE_WEIGHT = 120}", text)
                self.assertIn("{WFBE_C_CMD_TOWN_NUDGE_CAP = 3}", text)
                self.assertLess(120 * (3 ** 0.5), 400)


class Ruling2AggregationTests(unittest.TestCase):
    """Owner ruling 2: sqrt(n) aggregation AND a hard safety ceiling."""

    def test_hard_ceiling_is_applied_before_the_sqrt(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, WEIGHT_FN)
            with self.subTest(root=root.name):
                self.assertIn("_units = _raw min _cap;", text)
                self.assertIn("sqrt (_units)", text)
                self.assertLess(
                    text.index("_units = _raw min _cap;"),
                    text.index("sqrt (_units)"),
                    "the hard ceiling must clamp the raw sum BEFORE sqrt",
                )

    def test_weight_decays_linearly_across_the_ttl(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, WEIGHT_FN)
            with self.subTest(root=root.name):
                self.assertIn("_dec = 1 - (_age / _ttl);", text)
                self.assertIn("if (_age >= 0 && {_age < _ttl}) then {", text)

    def test_expired_and_zero_ttl_records_contribute_nothing(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, WEIGHT_FN)
            with self.subTest(root=root.name):
                self.assertIn('if (_ttl <= 0) exitWith {0};', text)
                self.assertIn('if (_cap <= 0) exitWith {0};', text)
                self.assertIn('if (_raw <= 0) exitWith {0};', text)

    def test_nil_holes_in_the_ring_are_guarded(self) -> None:
        """A2 OA trap: forEach over an array with nil holes must guard with isNil."""
        for root in MAINTAINED_ROOTS:
            text = read(root, WEIGHT_FN)
            with self.subTest(root=root.name):
                self.assertIn('if (!isNil "_x") then {', text)


class Ruling3DoctrineEligibilityTests(unittest.TestCase):
    """Owner ruling 3: NO leader-only gate; any eligible nearby player, with anti-spam + receipts."""

    def test_doctrine_gate_is_proximity_not_rank(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, HANDLE)
            with self.subTest(root=root.name):
                self.assertIn('case "aicom-team-doctrine":', text)
                # proximity gate present
                self.assertIn(
                    'if (isNull (leader _tdTeam) || {(_tdPlayer distance (leader _tdTeam)) > _tdRange}) then {',
                    text,
                )
                # and NO rank/leader-of-own-squad gate on the issuer
                self.assertNotIn('_tdPlayer == leader (group _tdPlayer)', text)
                self.assertNotIn('wfbe_teamleader', text.split('case "aicom-team-doctrine":')[1].split('case "aicom-support-air":')[0])

    def test_doctrine_has_cooldown_and_receipt(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, HANDLE)
            block = text.split('case "aicom-team-doctrine":')[1].split('case "aicom-support-air":')[0]
            with self.subTest(root=root.name):
                self.assertIn('WFBE_C_CMD_TEAM_DOCTRINE_COOLDOWN', block)
                self.assertIn('"wfbe_cmd_doctrine_" + _tdUID', block)
                self.assertIn('cmdv2-receipt', block)
                self.assertIn('AICOM2|v1|ORDER|TEAM_DOCTRINE|', block)

    def test_doctrine_never_manual_pins_a_team(self) -> None:
        """Advisory only — a soft nudge must not pin a team away from the allocator."""
        for root in MAINTAINED_ROOTS:
            text = read(root, HANDLE)
            block = text.split('case "aicom-team-doctrine":')[1].split('case "aicom-support-air":')[0]
            with self.subTest(root=root.name):
                self.assertNotIn('wfbe_aicom_manualpin', block)

    def test_player_led_squads_are_rejected(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, HANDLE)
            block = text.split('case "aicom-team-doctrine":')[1].split('case "aicom-support-air":')[0]
            with self.subTest(root=root.name):
                self.assertIn('if (isPlayer (leader _tdTeam)) then {', block)
                self.assertIn('why=playerLedTeam', block)


class Ruling1FreeLoanTests(unittest.TestCase):
    """Owner ruling 1: FREE loan of an already-owned airframe — no fee, so no refund path."""

    def test_support_air_moves_no_funds(self) -> None:
        forbidden = (
            "ChangeFunds",
            "changeplayerfunds",
            "QUERYUNITPRICE",
            "wfbe_funds",
            "refund",
        )
        for root in MAINTAINED_ROOTS:
            text = read_code(root, HANDLE)
            block = text.split('case "aicom-support-air":')[1].split('case "aicom-support-air-release":')[0]
            support = read_code(root, SUPPORT_FN)
            for token in forbidden:
                with self.subTest(root=root.name, token=token):
                    self.assertNotIn(token.lower(), block.lower())
                    self.assertNotIn(token.lower(), support.lower())

    def test_grant_reuses_an_existing_team_airframe(self) -> None:
        """It lends a hull the side already owns — it must never createVehicle a new one."""
        for root in MAINTAINED_ROOTS:
            text = read(root, HANDLE)
            block = text.split('case "aicom-support-air":')[1].split('case "aicom-support-air-release":')[0]
            support = read(root, SUPPORT_FN)
            with self.subTest(root=root.name):
                self.assertNotIn("createVehicle", block)
                self.assertNotIn("createVehicle", support)
                self.assertIn('_saTeams = _saLogik getVariable ["wfbe_teams", []];', block)
                self.assertIn('(vehicle _x) isKindOf "Helicopter"', block)

    def test_cooldown_starts_on_none_as_well_as_on_grant(self) -> None:
        """A denied request must not be re-spammable (design section 5.2 step 1)."""
        for root in MAINTAINED_ROOTS:
            text = read(root, HANDLE)
            block = text.split('case "aicom-support-air":')[1].split('case "aicom-support-air-release":')[0]
            with self.subTest(root=root.name):
                self.assertIn("why=noEligibleHeli", block)
                none_at = block.index("why=noEligibleHeli")
                stamp_at = block.index("_saLogik setVariable [_saKey, _saNow];", none_at)
                self.assertGreater(stamp_at, none_at)


class Ruling4CasRoeTests(unittest.TestCase):
    """Owner ruling 4: escort/orbit + DIRECT-threat response only. No free-hunting."""

    def test_default_escort_mode_is_orbit_on_the_holder(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, SUPPORT_FN)
            with self.subTest(root=root.name):
                self.assertIn("_pos  = getPos _holder;", text)
                self.assertIn("_tPos = _pos;", text)
                self.assertIn('_mode = "move";', text)

    def test_threat_scan_is_centred_on_the_holder_and_bounded_by_cas_range(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, SUPPORT_FN)
            with self.subTest(root=root.name):
                self.assertIn(
                    '_near = _pos nearEntities [["Man","LandVehicle","Air"], _casRange];',
                    text,
                    "the CAS scan must be centred on the HOLDER, not the heli or the map",
                )
                self.assertIn(
                    '_casRange = missionNamespace getVariable ["WFBE_C_CMD_SUPPORT_AIR_CAS_RANGE", 500];',
                    text,
                )

    def test_sad_sweep_only_happens_when_a_threat_was_actually_found(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, SUPPORT_FN)
            with self.subTest(root=root.name):
                self.assertIn("if (!isNull _best) then {", text)
                sad = text.index('_mode = "patrol";')
                guard = text.index("if (!isNull _best) then {")
                self.assertLess(guard, sad, "the SAD switch must sit inside the threat-found guard")

    def test_friendly_and_civilian_contacts_are_excluded(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, SUPPORT_FN)
            with self.subTest(root=root.name):
                self.assertIn('{(side _x) != _side} && {(side _x) != civilian}', text)


class Ruling5RecallHysteresisTests(unittest.TestCase):
    """Owner ruling 5: AICOM may recall for last-stand/HQ emergency, with hysteresis + reason telemetry."""

    def test_recall_requires_a_continuous_dwell(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, SUPPORT_FN)
            with self.subTest(root=root.name):
                self.assertIn("if ((time - _emergSince) >= _hyst) then {_running = false; _reason = \"recall-emergency\"};", text)
                self.assertIn("_emergSince = -1;", text)

    def test_hysteresis_resets_when_the_emergency_clears(self) -> None:
        """If the flag flaps, the dwell must restart from scratch rather than accumulate."""
        for root in MAINTAINED_ROOTS:
            text = read(root, SUPPORT_FN)
            with self.subTest(root=root.name):
                arm = text.index("if (_emergSince < 0) then {")
                clear = text.index("state=cleared")
                reset = text.index("_emergSince = -1;", clear)
                self.assertLess(arm, clear)
                self.assertGreater(reset, clear)

    def test_emergency_is_laststand_or_dead_hq(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, SUPPORT_FN)
            with self.subTest(root=root.name):
                self.assertIn(
                    '_emerg = ((_logik getVariable ["wfbe_aicom_strat_mode", "spearhead"]) == "laststand");',
                    text,
                )
                self.assertIn("if (isNull _hq || {!alive _hq}) then {_emerg = true};", text)

    def test_recall_emits_reason_telemetry(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, SUPPORT_FN)
            with self.subTest(root=root.name):
                self.assertIn("AICOM2|v1|ORDER|CMD_SUPPORT|RECALL|", text)
                self.assertIn('"|reason=" + _reason', text)

    def test_a_recall_blocks_regrants_for_the_same_dwell(self) -> None:
        for root in MAINTAINED_ROOTS:
            support = read(root, SUPPORT_FN)
            handle = read(root, HANDLE)
            with self.subTest(root=root.name):
                self.assertIn('_logik setVariable ["wfbe_cmd_support_recall_until", time + _hyst];', support)
                self.assertIn("why=recall-hysteresis", handle)


class FlagOffInertnessTests(unittest.TestCase):
    """With every master flag at 0 the mission must behave exactly as HEAD."""

    def test_each_new_verb_is_wrapped_in_its_master_flag_guard(self) -> None:
        expected = {
            "aicom-town-nudge": "WFBE_C_CMD_TOWN_NUDGE",
            "aicom-team-doctrine": "WFBE_C_CMD_TEAM_DOCTRINE",
            "aicom-support-air": "WFBE_C_CMD_SUPPORT_AIR",
            "aicom-support-air-release": "WFBE_C_CMD_SUPPORT_AIR",
        }
        for root in MAINTAINED_ROOTS:
            text = read(root, HANDLE)
            for verb, flag in expected.items():
                with self.subTest(root=root.name, verb=verb):
                    case_at = text.index('case "%s": {' % verb)
                    guard = '(missionNamespace getVariable ["%s", 0]) > 0' % flag
                    guard_at = text.index(guard, case_at)
                    # the guard must be the FIRST branch inside the case, before any state write
                    self.assertLess(guard_at - case_at, 2600)

    def test_allocator_reads_the_nudge_ring_only_behind_the_flag(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, ALLOCATE)
            with self.subTest(root=root.name):
                init_at = text.index("_tnOn = false; _tnTeamOn = false; _tnRing = []; _tnWeight = 0;")
                guard_at = text.index('if ((missionNamespace getVariable ["WFBE_C_CMD_TOWN_NUDGE", 0]) > 0) then {', init_at)
                ring_at = text.index('_tnRing   = _logik getVariable ["wfbe_aicom_town_nudges", []];', guard_at)
                scorer_at = text.index("if (_tnOn) then {", ring_at)
                self.assertLess(init_at, guard_at)
                self.assertLess(guard_at, ring_at)
                self.assertLess(ring_at, scorer_at)

    def test_garrison_posture_is_unreachable_at_flag_off(self) -> None:
        """The verb whitelist only admits GARRISON behind the flag, so the consumer can never see it."""
        for root in MAINTAINED_ROOTS:
            handle = read(root, HANDLE)
            allocate = read(root, ALLOCATE)
            with self.subTest(root=root.name):
                self.assertIn(
                    'if (!_pOk && {(missionNamespace getVariable ["WFBE_C_CMD_POSTURE_GARRISON", 0]) > 0}) then {_pOk = (_pPos == "GARRISON")};',
                    handle,
                )
                self.assertIn('if (_psPair == "GARRISON") then {_engageMin = _engageMin + _psDelta};', allocate)

    def test_new_ui_controls_are_structurally_hidden(self) -> None:
        """show = 0 plus flag-gated _adviseCtrls admission == invisible at flag-off."""
        for root in MAINTAINED_ROOTS:
            dialogs = read(root, DIALOGS)
            menu = read(root, MENU)
            with self.subTest(root=root.name):
                self.assertIn("class CA_Cmd_TownNudge : CA_Cmd_PosturePush {", dialogs)
                head = dialogs.index("class CA_Cmd_TownNudge : CA_Cmd_PosturePush {")
                tail = dialogs.index("class CA_Cmd_RosterTitle", head)
                self.assertIn("show = 0;", dialogs[head:tail])
                for idc, flag in (
                    ("14631", "WFBE_C_CMD_TOWN_NUDGE"),
                    ("14632, 14633", "WFBE_C_CMD_SUPPORT_AIR"),
                    ("14634", "WFBE_C_CMD_TEAM_DOCTRINE"),
                ):
                    self.assertIn(
                        'if ((missionNamespace getVariable ["%s", 0]) > 0)' % flag,
                        menu,
                    )
                    self.assertIn("_adviseCtrls + [%s]};" % idc, menu)

    def test_jet_kinds_are_parsed_and_explicitly_rejected(self) -> None:
        """No jet grant path exists; the reject must be loud so the UI can grey the option."""
        for root in MAINTAINED_ROOTS:
            text = read(root, HANDLE)
            with self.subTest(root=root.name):
                self.assertIn('{_saKind in ["cas-jet","transport-jet"]}) then {_saRej = "jet-disabled"};', text)
                # the reject reason is interpolated into the telemetry line, and the caller gets a receipt
                self.assertIn('|why=" + _saRej', text)
                self.assertIn('if (_saRej == "jet-disabled"', text)
                # and there is genuinely no jet grant path to fall through to
                block = text.split('case "aicom-support-air":')[1].split('case "aicom-support-air-release":')[0]
                self.assertNotIn('isKindOf "Plane"', block)


class PvfDisciplineTests(unittest.TestCase):
    """Design section 2.1: the new verbs ride the already-allowlisted RequestSpecial bus."""

    def test_no_new_top_level_pv_name_was_introduced(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, Path("Common/Init/Init_PublicVariables.sqf"))
            with self.subTest(root=root.name):
                for verb in NEW_VERBS:
                    self.assertNotIn(verb, text)

    def test_every_new_verb_validates_side_issuer_and_payload(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, HANDLE)
            for verb in ("aicom-town-nudge", "aicom-team-doctrine", "aicom-support-air"):
                block = text.split('case "%s":' % verb)[1][:9000]
                with self.subTest(root=root.name, verb=verb):
                    self.assertIn("in [west, east]", block)
                    self.assertIn("isPlayer", block)
                    self.assertIn("side (group ", block)
                    self.assertIn("getPlayerUID", block)

    def test_every_new_verb_emits_accept_and_reject_telemetry(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, HANDLE)
            with self.subTest(root=root.name):
                for token in (
                    "AICOM2|v1|ORDER|TOWN_NUDGE|accept|",
                    "AICOM2|v1|ORDER|TOWN_NUDGE|reject|",
                    "AICOM2|v1|ORDER|TOWN_NUDGE|cooldown|",
                    "AICOM2|v1|ORDER|TEAM_DOCTRINE|",
                    "AICOM2|v1|ORDER|CMD_SUPPORT|REQUEST|",
                    "AICOM2|v1|ORDER|CMD_SUPPORT|GRANT|",
                    "AICOM2|v1|ORDER|CMD_SUPPORT|NONE|",
                    "AICOM2|v1|ORDER|CMD_SUPPORT|REJECT|",
                    "AICOM2|v1|ORDER|CMD_SUPPORT|RELEASE|",
                ):
                    self.assertIn(token, text)


class RegistrationTests(unittest.TestCase):
    """New function files are not auto-loaded — they must be compiled in an init file."""

    def test_town_nudge_weight_is_registered(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, INIT_COMMON)
            with self.subTest(root=root.name):
                self.assertIn(
                    'WFBE_CO_FNC_TownNudgeWeight = Compile preprocessFileLineNumbers "Common\\Functions\\Common_TownNudgeWeight.sqf";',
                    text,
                )

    def test_support_air_worker_is_registered(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, INIT_SERVER)
            with self.subTest(root=root.name):
                self.assertIn(
                    'WFBE_SE_FNC_CmdSupportAir = Compile preprocessFileLineNumbers "Server\\Functions\\Server_CmdSupportAir.sqf";',
                    text,
                )

    def test_client_receipt_handler_exists(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, CLIENT_HANDLE)
            with self.subTest(root=root.name):
                self.assertIn('case "cmdv2-receipt": {', text)


class LifecycleHandbackTests(unittest.TestCase):
    """The AI commander must always get the team back cleanly."""

    def test_every_exit_path_restores_towns_mode_and_autonomy(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, SUPPORT_FN)
            with self.subTest(root=root.name):
                self.assertIn('[_team, "towns"] Call SetTeamMoveMode;', text)
                self.assertIn("[_team, true]    Call SetTeamAutonomous;", text)
                self.assertIn('_team setVariable ["wfbe_aicom_support_holder", nil, true];', text)
                # the handback must come AFTER the single while loop, i.e. on every exit path
                loop_end = text.index("//--- ---------- RETURN ----------")
                self.assertGreater(text.index('[_team, "towns"] Call SetTeamMoveMode;'), loop_end)

    def test_lifecycle_never_manual_pins(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, SUPPORT_FN)
            with self.subTest(root=root.name):
                self.assertNotIn("wfbe_aicom_manualpin", text)

    def test_hull_goes_home_through_the_shared_return_path(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, SUPPORT_FN)
            with self.subTest(root=root.name):
                self.assertIn("[_hull, _team, _side] Call WFBE_CO_FNC_AICOMAirReturn;", text)

    def test_escort_interval_has_a_floor(self) -> None:
        """A mistuned flag must never turn the escort into a hot loop."""
        for root in MAINTAINED_ROOTS:
            text = read(root, SUPPORT_FN)
            with self.subTest(root=root.name):
                self.assertIn("if (_int < 5) then {_int = 5};", text)

    def test_release_verb_only_stamps_and_lets_the_worker_tear_down(self) -> None:
        """One teardown site — the release verb must not duplicate it."""
        for root in MAINTAINED_ROOTS:
            text = read(root, HANDLE)
            block = text.split('case "aicom-support-air-release":')[1][:4000]
            with self.subTest(root=root.name):
                self.assertIn('_tm setVariable ["wfbe_aicom_support_release", true, true];', block)
                self.assertNotIn("AICOMAirReturn", block)
                self.assertNotIn("SetTeamMoveMode", block)

    def test_release_is_restricted_to_the_actual_holder(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read(root, HANDLE)
            block = text.split('case "aicom-support-air-release":')[1][:4000]
            with self.subTest(root=root.name):
                self.assertIn("{(_hol select 0) == _srPlayer}", block)


class A2TrapTests(unittest.TestCase):
    """A2 OA 1.64 engine traps that the linter cannot always see."""

    def test_no_two_arg_getvariable_on_group_receivers_in_new_code(self) -> None:
        """GROUP receivers must use the 1-arg + isNil form (or WFBE_CO_FNC_GroupGetBool)."""
        banned = (
            '_tm getVariable ["',
            '_team getVariable ["',
            '_tdTeam getVariable ["',
            '_saTeam getVariable ["',
        )
        for root in MAINTAINED_ROOTS:
            for relative in (HANDLE, SUPPORT_FN, MENU):
                text = read(root, relative)
                for token in banned:
                    with self.subTest(root=root.name, file=relative.name, token=token):
                        self.assertNotIn(token, text)

    def test_outer_x_is_captured_before_the_inner_units_loop(self) -> None:
        """The heli search nests forEach over units inside forEach over teams."""
        for root in MAINTAINED_ROOTS:
            text = read(root, HANDLE)
            block = text.split('case "aicom-support-air":')[1].split('case "aicom-support-air-release":')[0]
            with self.subTest(root=root.name):
                capture = block.index("_tm = _x;")
                inner = block.index("} forEach (units _tm);")
                self.assertLess(capture, inner)
                # nothing after the inner loop may still read the outer _x
                tail = block[inner:block.index("} forEach _saTeams;")]
                self.assertNotIn("_x", tail.replace("forEach", ""))

    def test_support_air_kind_flag_is_boolean_initialized_and_guarded_before_unit_scan(self) -> None:
        """A nested forEach must never compare transportSoldier against an undefined type flag.

        OA reports this as ``Type Bool, expected Number`` and terminates the request handler.
        Keep a Boolean default at case scope plus a defensive pre-scan recovery guard.
        """
        for root in MAINTAINED_ROOTS:
            text = read_code(root, HANDLE)
            block = text.split('case "aicom-support-air":')[1].split('case "aicom-support-air-release":')[0]
            with self.subTest(root=root.name):
                default_at = block.index("_saWantTrans = false;")
                derive_at = block.index('_saWantTrans = (_saKind == "transport");')
                guard_at = block.index('if (isNil "_saWantTrans") then {_saWantTrans = false;')
                scan_at = block.index("} forEach (units _tm);")
                self.assertLess(default_at, derive_at)
                self.assertLess(derive_at, guard_at)
                self.assertLess(guard_at, scan_at)
                self.assertIn("AICOM2|v1|ORDER|CMD_SUPPORT|FULFIL|", block)

    def test_no_banned_a3_commands_in_new_files(self) -> None:
        banned = (
            "isEqualType", "isEqualTo", "pushBack", "findIf", "selectRandom",
            "remoteExec", "distance2D", "joinGroup", "getPosVisual", "worldSize",
            "params [", "deleteAt", "getOrDefault",
        )
        for root in MAINTAINED_ROOTS:
            for relative in (WEIGHT_FN, SUPPORT_FN):
                text = read_code(root, relative)
                for token in banned:
                    with self.subTest(root=root.name, file=relative.name, token=token):
                        self.assertNotIn(token, text)


class AllocatorScopeRegressionTests(unittest.TestCase):
    """Codex review 2026-07-19 (PR #1156 round 1 rejection): _tnOn/_tnTeamOn/_tnRing/_tnWeight
    were declared ``private`` INSIDE the ``if (!_fromFocus)`` scorer block but _tnTeamOn/_tnRing
    are read in the top-level ASSIGN team loop. OA private scoping destroys a block-local var when
    its block closes, so the ASSIGN-loop read was an undefined-variable script error EVERY tick -
    including all-flags-0 (broke the flag-off inertness contract). Pins the hoist-to-top-level fix
    so this cannot regress: the four names must appear in the file's TOP-LEVEL private list, and
    must NOT be re-declared private anywhere else in the file (a re-declaration inside a nested
    block would shadow the outer var and reintroduce the exact same bug)."""

    NUDGE_LOCALS = ("_tnOn", "_tnTeamOn", "_tnRing", "_tnWeight")

    def test_nudge_locals_are_declared_in_the_top_level_private_list(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read_code(root, ALLOCATE)
            top_level_private_end = text.index("];")
            top_level_private = text[: top_level_private_end + 2]
            for name in self.NUDGE_LOCALS:
                with self.subTest(root=root.name, name=name):
                    self.assertIn(f'"{name}"', top_level_private)

    def test_nudge_locals_have_exactly_one_private_declaration(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read_code(root, ALLOCATE)
            for name in self.NUDGE_LOCALS:
                # A second ``private [... "_tnOn" ...]`` anywhere in the file would shadow the
                # top-level declaration inside whatever block it appears in - exactly the bug.
                private_decls = [
                    line for line in text.splitlines()
                    if "private [" in line and f'"{name}"' in line
                ]
                with self.subTest(root=root.name, name=name):
                    self.assertEqual(len(private_decls), 1, private_decls)

    def test_nudge_locals_default_initialized_before_the_focus_branch(self) -> None:
        for root in MAINTAINED_ROOTS:
            text = read_code(root, ALLOCATE)
            first_default = text.index("_tnOn = false; _tnTeamOn = false; _tnRing = []; _tnWeight = 0;")
            focus_branch = text.index("if (!_fromFocus) then {")
            with self.subTest(root=root.name):
                self.assertLess(
                    first_default, focus_branch,
                    "nudge locals must be defaulted before the _fromFocus branch that may skip them",
                )


class MirrorParityTests(unittest.TestCase):
    """Chernarus is the source; TK and ZG are generated copies and must match byte-for-byte."""

    def test_every_touched_file_is_identical_across_the_three_terrains(self) -> None:
        for relative in ALL_TOUCHED:
            copies = [(root / relative).read_bytes() for root in MAINTAINED_ROOTS]
            with self.subTest(path=str(relative)):
                self.assertEqual(len(set(copies)), 1)

    def test_new_files_exist_in_every_terrain(self) -> None:
        for relative in (WEIGHT_FN, SUPPORT_FN):
            for root in MAINTAINED_ROOTS:
                with self.subTest(root=root.name, path=str(relative)):
                    self.assertTrue((root / relative).is_file())


if __name__ == "__main__":
    unittest.main()
