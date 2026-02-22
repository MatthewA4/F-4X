#!/usr/bin/env python3
# QuickValidation.py - Syntax validation for all Nasal modules
# Checks for basic Nasal syntax errors by parsing file structures

import os
import re
import sys

def check_nasal_syntax(filepath):
    """Basic Nasal syntax validation"""
    errors = []
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    # Check for unclosed braces/parens
    brace_count = 0
    paren_count = 0
    bracket_count = 0
    
    for i, line in enumerate(lines, 1):
        # strip comments and string literals before counting to avoid false
        # positives (e.g. emoticons, URLs, comments containing braces/paren)
        code = line
        # remove quoted strings (single and double) first so '#' inside them is safe
        code = re.sub(r"'[^']*'", '', code)
        code = re.sub(r'\"[^\"]*\"', '', code)
        # remove comments beginning with '#' only when '#' is at start of line
        # or preceded by whitespace; this avoids stripping '#' used for string
        # concatenation (e.g. '/foo/'#var).  Uses regex lookbehind for whitespace.
        code = re.sub(r'(?m)(?<!\S)#.*', '', code)

        # Simple counting on sanitized code
        brace_count += code.count('{') - code.count('}')
        paren_count += code.count('(') - code.count(')')
        bracket_count += code.count('[') - code.count(']')
        
        # Check for incomplete statements
        stripped = code.strip()
        if stripped and not stripped.startswith('#'):
            if stripped.endswith(',') and not ('{' in stripped or '[' in stripped):
                pass  # OK, comma continuation
    
    if brace_count != 0:
        errors.append(f"Brace mismatch: {brace_count:+d}")
    if paren_count != 0:
        errors.append(f"Paren mismatch: {paren_count:+d}")
    if bracket_count != 0:
        errors.append(f"Bracket mismatch: {bracket_count:+d}")
    
    return errors

def main():
    src_dir = "/home/matt/Dev/F-4X/src"
    modules = [
        "AFCS.nas",
        "AfterburnerDynamics.nas",
        "AirConditioning.nas",
        "AirDataComputer.nas",
        "Avionics.nas",
        "BleedAirSystem.nas",
        "CockpitBindings.nas",
        "CockpitInstruments.nas",
        "damage.nas",
        "DeparturePreventionSystem.nas",
        "ElectricalBuses.nas",
        "ElectricalGenerators.nas",
        "ElectricalLoadShedding.nas",
        "electrical.nas",
        "Electrical.nas",
        "EngineSurge.nas",
        "Environmental.nas",
        "f-4.nas",
        "FCSTuning.nas",
        "FDM.nas",
        "FireDetectionSuppression.nas",
        "FuelCGManagement.nas",
        "FuelManager.nas",
        "fuel.nas",
        "GustAlleviation.nas",
        "HydraulicLoadShedding.nas",
        "hydraulics.nas",
        "Hydraulics.nas",
        "InletControl.nas",
        "J79.nas",
        "LandingAnalysis.nas",
        "LandingGearDamping.nas",
        "LandingGear.nas",
        "OrdnanceDatabase.nas",
        "PilotPhysiology.nas",
        "PitchUpPrevention.nas",
        "RadarManager.nas",
        "RefuelingProbe.nas",
        "RegressionTests.nas",
        "SpinRecoveryChute.nas",
        "StartupSequencer.nas",
        "StoresManager.nas",
        "TestHarness.nas",
        "TransonicShockEffects.nas",
        "TrimDragEffects.nas",
        "views.nas",
        "WeaponsBallistics.nas",
        "WeaponsDemo.nas",
        "Weapons.nas",
        "zoom-views.nas"
    ]
    
    print("=" * 60)
    print("NASAL MODULE SYNTAX VALIDATION")
    print("=" * 60)
    
    all_ok = True
    for module in modules:
        filepath = os.path.join(src_dir, module)
        if not os.path.exists(filepath):
            print(f"❌ {module}: FILE NOT FOUND")
            all_ok = False
            continue
        
        errors = check_nasal_syntax(filepath)
        if errors:
            print(f"❌ {module}:")
            for err in errors:
                print(f"   - {err}")
            all_ok = False
        else:
            # Count lines
            with open(filepath) as f:
                lines = len(f.readlines())
            print(f"✓ {module} ({lines} lines)")
    
    print("=" * 60)
    if all_ok:
        print("✓ All modules passed basic syntax validation!")
        return 0
    else:
        print("❌ Some modules have syntax issues")
        return 1

if __name__ == "__main__":
    sys.exit(main())
