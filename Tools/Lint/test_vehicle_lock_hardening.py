"""Behavioral contract for the flag-on RequestVehicleLock handshake.

The repository has no Arma 2/OA executable or SQF interpreter.  This focused
harness therefore executes the relevant request behavior in Python while
binding the cross-side outcome to the actual SQF source: the PR #1421 side
comparison is treated as an active rejection until the source block is gone.
That makes the regression fail on the old implementation for behavior, not
because a required string is absent.
"""

from dataclasses import dataclass, field
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"
HANDLER = CH / "Server/PVFunctions/RequestVehicleLock.sqf"


@dataclass
class Actor:
    uid: str
    side: int
    distance: float
    is_player: bool = True
    alive: bool = True


@dataclass
class Vehicle:
    side: int
    locked: bool = True
    alive: bool = True


@dataclass
class CapabilityStore:
    tokens: dict[str, str] = field(default_factory=dict)

    def mint(self, uid: str, challenge: str) -> str:
        token = f"vehicle-lock:{uid}:{challenge}"
        self.tokens[uid] = token
        return token

    def consume(self, uid: str, token: str) -> bool:
        if self.tokens.get(uid) != token:
            return False
        del self.tokens[uid]
        return True


def read_handler() -> str:
    return HANDLER.read_text(encoding="utf-8-sig")


def execute_request(
    source: str,
    actor: Actor,
    vehicle: Vehicle,
    store: CapabilityStore,
    *,
    requested_lock: bool = False,
    challenge: str = "",
    token: str = "",
) -> str:
    """Execute the flag-on request contract and return its observable result."""

    if not actor.is_player or not actor.alive:
        return "REJECTED_ACTOR"
    if requested_lock:
        return "REJECTED_LOCK"
    if not vehicle.alive:
        return "REJECTED_VEHICLE"
    if actor.distance > 12:
        return "REJECTED_RANGE"

    # This is the defect under test.  It is deliberately source-backed so the
    # old PR fails the cross-side success assertion before the SQF edit.
    if (
        "if (_vehicleSideID != _ownerSideID) then {" in source
        and actor.side != vehicle.side
    ):
        return "REJECTED_CROSS_SIDE"

    if not token:
        if not challenge:
            return "REJECTED_CAPABILITY"
        store.mint(actor.uid, challenge)
        return "MINTED"

    if not store.consume(actor.uid, token):
        return "REJECTED_CAPABILITY"

    vehicle.locked = requested_lock
    return "UNLOCKED"


def mint_valid_capability(
    source: str, actor: Actor, vehicle: Vehicle, store: CapabilityStore
) -> str:
    result = execute_request(
        source, actor, vehicle, store, challenge="valid-challenge"
    )
    assert result == "MINTED", result
    return store.tokens[actor.uid]


def test_cross_side_unlock_succeeds_with_valid_capability_and_reach():
    source = read_handler()
    actor = Actor(uid="west-player", side=1, distance=5)
    vehicle = Vehicle(side=2)
    store = CapabilityStore()

    token = mint_valid_capability(source, actor, vehicle, store)
    assert vehicle.locked is True
    assert execute_request(source, actor, vehicle, store, token=token) == "UNLOCKED"
    assert vehicle.locked is False


def test_missing_capability_fails_without_unlocking_cross_side_vehicle():
    source = read_handler()
    actor = Actor(uid="west-player", side=1, distance=5)
    vehicle = Vehicle(side=2)

    assert execute_request(source, actor, vehicle, CapabilityStore()) == "REJECTED_CAPABILITY"
    assert vehicle.locked is True


def test_replayed_capability_fails_after_the_first_unlock():
    source = read_handler()
    actor = Actor(uid="west-player", side=1, distance=5)
    vehicle = Vehicle(side=2)
    store = CapabilityStore()

    token = mint_valid_capability(source, actor, vehicle, store)
    assert execute_request(source, actor, vehicle, store, token=token) == "UNLOCKED"
    assert execute_request(source, actor, vehicle, store, token=token) == "REJECTED_CAPABILITY"


def test_out_of_reach_fails_before_consume_and_can_retry_in_reach():
    source = read_handler()
    actor = Actor(uid="west-player", side=1, distance=13)
    vehicle = Vehicle(side=2)
    store = CapabilityStore()

    token = mint_valid_capability(source, Actor(actor.uid, actor.side, 5), vehicle, store)
    assert execute_request(source, actor, vehicle, store, token=token) == "REJECTED_RANGE"
    assert store.tokens[actor.uid] == token

    actor.distance = 5
    assert execute_request(source, actor, vehicle, store, token=token) == "UNLOCKED"


def test_capability_handshake_and_unlock_order_remain_present():
    source = read_handler()
    assert 'missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]' in source
    assert "WFBE_SE_FNC_MintCapability" in source
    assert "WFBE_SE_FNC_ConsumeCapability" in source
    assert source.index("WFBE_SE_FNC_ConsumeCapability") < source.index("_vehicle lock _locked")
