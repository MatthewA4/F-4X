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
        # Simple counting (not perfect but catches obvious issues)
        brace_count += line.count('{') - line.count('}')
        paren_count += line.count('(') - line.count(')')
        bracket_count += line.count('[') - line.count(']')
        
        # Check for incomplete statements
        stripped = line.strip()
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
        "InletControl.nas",
        "AfterburnerDynamics.nas",
        "BleedAirSystem.nas",
        "TransonicShockEffects.nas",
        "FuelCGManagement.nas",
        "ElectricalLoadShedding.nas",
        "FireDetectionSuppression.nas",
        "HydraulicLoadShedding.nas",
        "LandingGearDamping.nas",
        "TrimDragEffects.nas"
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
