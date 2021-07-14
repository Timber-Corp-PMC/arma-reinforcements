/*
	author: Geelik
	description:
	    Manage waypoints for reinfiorcment
    parameters:
        _reinforcement: Hashmap coming from registerReinforcement
	returns: nothing
*/
scriptName "TimberCorpReinforcements\callReinforcement";
if (!isServer) exitWith {};

params ["_reinforcement"];

//retrieve all configurations
private _name = _reinforcement get "name";
private _vehicle = missionNamespace getVariable (_reinforcement get "vehicleName");
private _infantryLeader = missionNamespace getVariable (_reinforcement get "infantryLeaderName");
private _insertionMethod = _reinforcement get "insertionMethod";
private _teleportUnits = _reinforcement get "teleportUnits";

private _isAir = _vehicle isKindOf "Air";

private _vehicleGroup = group driver _vehicle;
private _infantryGroup = group _infantryLeader;

if (_teleportUnits) then {
    //Teleport infantry inside the vehicle
    {
        _x moveInCargo _vehicle;
    } forEach units _infantryGroup;
    //Remove the move waypoint auto added by arma
    deleteWaypoint [_infantryGroup, 1];
}
else {
    //Add GET IN waypoint for infantry
    private _mountWP = _infantryGroup addWaypoint [getPos _vehicle, 0, 1];
    _mountWP setWaypointType "GETIN";
    _mountWP waypointAttachVehicle  _vehicle;

    //Remove the move waypoint auto added by arma
    deleteWaypoint [_infantryGroup, 2];

    //Add LOAD waypoint for the vehicle and synchronize it the GET IN so the vehicle don't before the infantry is loaded
    private _loadWP = _vehicleGroup addWaypoint [getPos _vehicle, 0, 1];
    _loadWP setWaypointType "LOAD";
    _loadWP synchronizeWaypoint [_mountWP];
};

// Use normal transport unload if fastroping is not available
if (_insertionMethod == 2 && {!isClass (configFile >> "CfgPatches" >> "ace_fastroping")}) then {
    _insertionMethod = 1;
};

//Remove HOLD waypoint added by the registerReinforcement script
deleteWaypoint [_infantryGroup, 0];
deleteWaypoint [_vehicleGroup, 0];

//Detect the LZ waypoint and modify it accordingly with the insertion method
{
    if (["LZ_", waypointName _x, true] call BIS_fnc_inString) then {
        if (_isAir && {_insertionMethod > 1}) then {
            private _script = "";

            if (_insertionMethod == 2) then {
                _script = "x\zen\addons\ai\functions\fnc_waypointFastrope.sqf";
            };

            if (_insertionMethod == 3) then {
                 _script = "x\zen\addons\ai\functions\fnc_waypointParadrop.sqf";
            };

             _x setWaypointType "SCRIPTED";
             _x setWaypointScript _script;
        }
        else {
            _x setWaypointType "TR UNLOAD";
        };
    };

} forEach waypoints _vehicleGroup;

//Remove from pool
private _reinforcements = missionNamespace getVariable ["TimberCorpReinforcements_reinforcements", createHashMap];
if (_name in _reinforcements) then {
    _reinforcements deleteAt _name;
};

missionNamespace setVariable ["TimberCorpReinforcements_reinforcements", _reinforcements];