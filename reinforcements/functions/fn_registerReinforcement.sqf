/*
    author: Geelik
    description:
        Help you setup your reinforcements (QRF) for calling them later.
        Automatic usage of murk for performance
    parameters:
        _name: name of your reinforcement. This is used for calling the reinforcement
        _vehicle: Variable name of the vehicle used
        _infantryLeader: Variable name of the infantry group leader that will be deployed
        _options :
            insertionMethod: (default 1)
                1 = land
                2 = fast rope (ace fast rope need to be enabled if not default to land)
                3 = parachute
            teleportUnits: (default false)
                if true teleport directly the infantry inside the vehicle (suggested for planes)
                if false waypoints will be created to let infantry mount inside the vehicle
    return: nothing
*/

scriptName "TimberCorpReinforcements\registerReinforcement";

if (!isServer) exitWith {};

params ["_name", "_vehicle", "_infantryLeader", ["_options", []]];

_options = createHashMapFromArray _options;

private _insertionMethod = _options getOrDefault ["insertionMethod", 1];
private _teleportUnits = _options getOrDefault ["teleportUnits", false];

private _reinforcements = missionNamespace getVariable ["TimberCorpReinforcements_reinforcements", createHashMap];

//Store variable name so we can detect the murk spawn later
private _reinforcementsMurkUnits = missionNamespace getVariable ["TimberCorpReinforcements_reinforcementsMurkUnits", []];
_reinforcementsMurkUnits pushBack vehicleVarName _vehicle;
_reinforcementsMurkUnits pushBack vehicleVarName _infantryLeader;
missionNamespace setVariable ["TimberCorpReinforcements_reinforcementsMurkUnits", _reinforcementsMurkUnits];

private _vehicleGroup = group driver _vehicle;
private _vehicleGroupLeader = leader _vehicle;

//Create vehicle trigger for murk
private _vehicleTrigger = createTrigger ["EmptyDetector", getPos _vehicle];
_vehicleTrigger setTriggerType "NONE";
_vehicleTrigger setTriggerActivation ["NONE", "NONE", false];
_vehicleTrigger setTriggerStatements [
    "missionNamespace getVariable ['TimberCorpReinforcements_reinforcement_"+_name+"_spawn', false];",
    "thisTrigger setVariable ['murk_spawn', true, true];",
    ""
];
_vehicleGroupLeader synchronizeObjectsAdd [_vehicleTrigger];
[_vehicleGroupLeader, false, "once"] execVM "murk\murk_spawn.sqf";

//Create infantry trigger for murk
private _infantryTrigger = createTrigger ["EmptyDetector", getPos _infantryLeader];
_infantryTrigger setTriggerType "NONE";
_infantryTrigger setTriggerActivation ["NONE", "NONE", false];
_infantryTrigger setTriggerStatements [
    "missionNamespace getVariable ['TimberCorpReinforcements_reinforcement_"+_name+"_spawn', false];",
    "thisTrigger setVariable ['murk_spawn', true, true];",
    ""
];
_infantryLeader synchronizeObjectsAdd [_infantryTrigger];
[_infantryLeader, false, "once"] execVM "murk\murk_spawn.sqf";

private _reinforcement = createHashMap;

//set all needed variables
_reinforcement set ["name", _name];
_reinforcement set ["vehicleName", vehicleVarName _vehicle];
_reinforcement set ["infantryLeaderName", vehicleVarName _infantryLeader];
_reinforcement set ["insertionMethod", _insertionMethod];
_reinforcement set ["teleportUnits", _teleportUnits];

//Add to the pool
_reinforcements set [_name, _reinforcement];
missionNamespace setVariable ["TimberCorpReinforcements_reinforcements", _reinforcements];


private _TimberCorpReinforcements_callReinforcementEventId = missionNamespace getVariable "TimberCorpReinforcements_callReinforcementEventId";
//Add events handlers only once
if (isNil "_TimberCorpReinforcements_callReinforcementEventId") then {

    //Event called when we call a reinforcement
    _TimberCorpReinforcements_callReinforcementEventId = ["TimberCorpReinforcements_callReinforcement", {
        params ["_name"];
        private _reinforcements = missionNamespace getVariable ["TimberCorpReinforcements_reinforcements", createHashMap];
        //Check if this reinforcement exist
        if (_name in _reinforcements) exitWith {
            private _reinforcements = missionNamespace getVariable ["TimberCorpReinforcements_reinforcements", createHashMap];
            private _reinforcement = _reinforcements get _name;
            //Trigger both murk trigger for this reinforcement
            missionNamespace setVariable ["TimberCorpReinforcements_reinforcement_"+_name+"_spawn", true];

            //Wait for both group to be spawned
            [_reinforcement] spawn {
                params ["_reinforcement"];
                waitUntil {
                    sleep 1;
                    private _vehicle = missionNamespace getVariable (_reinforcement get "vehicleName");
                    private _infantryLeader = missionNamespace getVariable (_reinforcement get "infantryLeaderName");
                    private _expression = (!isNil "_infantryLeader" && !isNil "_vehicle" && _vehicle getVariable "TimberCorpReinforcements_reinforcement_spawned") isEqualTo true && (_infantryLeader getVariable "TimberCorpReinforcements_reinforcement_spawned") isEqualTo true;
                    !isNil "_expression" && { _expression }
                };

                //call the script that will take care of waypoints and do the actual insertion of infantry
                [_reinforcement] call TimberCorpReinforcements_fnc_callReinforcement;
            }
        };
    }] call CBA_fnc_addEventHandler;

    //Look for spawned murk units
    ["mc_murk_spawned", {
        params ["_spawnedUnit"];

        private _unitGroup = group _spawnedUnit;
        private _unit = nil;
        private _name = nil;
        private _reinforcementsMurkUnits = missionNamespace getVariable ["TimberCorpReinforcements_reinforcementsMurkUnits", []];

        //Detect if murk spawn one of reinforcement infantry group
        if (vehicleVarName leader _unitGroup in _reinforcementsMurkUnits) then {
           _unit = leader _unitGroup;
           _name = vehicleVarName leader _unitGroup;
        };

        //Detect if murk spawn one of reinforcement vehicle group
        if (vehicleVarName vehicle leader _unitGroup in _reinforcementsMurkUnits) then {
           _unit = vehicle leader _unitGroup;
           _name = vehicleVarName vehicle leader _unitGroup;
        };

        if (!isNil "_unit" && !isNil "_name") then {
            //Add an hold waypoint to lock units in place while we detected both infantr and vehicle are spawned
            private _holdWP = _unitGroup addWaypoint [getPos _unit, 0, 0];
            _holdWP setWaypointType "HOLD";

            //Prevent a plane to fall directly from the sky
            if (vehicle _unit isKindOf "Plane" && (getPos _unit select 2) > 10) then {
               vehicle _unit engineOn true;
               vehicle _unit setVelocity [50 * (sin (getDir vehicle _unit)), 50 * (cos (getDir vehicle _unit)), 40];
            };

            //Add a variable to detected the group is spawned
            _unit setVariable ["TimberCorpReinforcements_reinforcement_spawned", true];
            //Remove from pool
            _reinforcementsMurkUnits deleteAt (_reinforcementsMurkUnits find _name);
        };

    }] call CBA_fnc_addEventHandler;

    //flag to prevent to init events handlers multiple times
    missionNamespace setVariable ["TimberCorpReinforcements_callReinforcementEventId", _TimberCorpReinforcements_callReinforcementEventId];
};