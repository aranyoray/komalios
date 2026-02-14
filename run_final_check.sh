#!/bin/bash

# KOMALIOS - FINAL CHECK AND BUILD MASTER SCRIPT
# Run this to verify everything and build

clear

cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║        KOMALIOS - FINAL CHECK & BUILD                    ║
║        Complete Diagnostic & Build Tool                  ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF

echo ""
echo "This script will:"
echo "  1. Run comprehensive diagnostics"
echo "  2. Verify all files and configuration"
echo "  3. Test package resolution"
echo "  4. Attempt build"
echo "  5. Provide detailed report"
echo ""
read -p "Press ENTER to continue..."
echo ""

# Make all scripts executable
chmod +x final_check_debug.sh 2>/dev/null
chmod +x build_fix_final.sh 2>/dev/null

# Run diagnostics
if [ -f "final_check_debug.sh" ]; then
    echo "Running diagnostics..."
    echo ""
    ./final_check_debug.sh
    
    result=$?
    
    if [ $result -eq 0 ]; then
        echo ""
        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║                                                          ║"
        echo "║            ✅ DIAGNOSTICS PASSED ✅                      ║"
        echo "║                                                          ║"
        echo "╚══════════════════════════════════════════════════════════╝"
        echo ""
        echo "Your project is ready to build!"
        echo ""
        echo "Choose an option:"
        echo ""
        echo "  1) Open in Xcode (recommended)"
        echo "  2) Build from command line"
        echo "  3) View detailed report"
        echo "  4) Exit"
        echo ""
        read -p "Enter choice (1-4): " choice
        
        case $choice in
            1)
                echo ""
                echo "Opening in Xcode..."
                open Package.swift
                echo ""
                echo "In Xcode:"
                echo "  • Wait for package resolution"
                echo "  • Product → Build (⌘B)"
                echo "  • Product → Run (⌘R)"
                ;;
            2)
                echo ""
                echo "Building from command line..."
                swift build
                ;;
            3)
                echo ""
                if [ -f "FINAL_DEBUG_REPORT.md" ]; then
                    cat FINAL_DEBUG_REPORT.md | less
                else
                    echo "Report file not found."
                fi
                ;;
            4)
                echo "Exiting."
                exit 0
                ;;
            *)
                echo "Invalid choice. Opening in Xcode..."
                open Package.swift
                ;;
        esac
    else
        echo ""
        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║                                                          ║"
        echo "║         ⚠️  DIAGNOSTICS FOUND ISSUES ⚠️                 ║"
        echo "║                                                          ║"
        echo "╚══════════════════════════════════════════════════════════╝"
        echo ""
        echo "Please review the errors above and fix them."
        echo ""
        echo "Common fixes:"
        echo "  • Ensure all required files exist"
        echo "  • Check Package.swift is valid"
        echo "  • Verify internet connection for packages"
        echo ""
        exit 1
    fi
else
    echo "Diagnostic script not found. Running basic checks..."
    echo ""
    
    # Basic checks
    errors=0
    
    if [ ! -f "Package.swift" ]; then
        echo "❌ Package.swift not found"
        ((errors++))
    else
        echo "✅ Package.swift found"
    fi
    
    if [ ! -f "KomaliosApp.swift" ]; then
        echo "❌ KomaliosApp.swift not found"
        ((errors++))
    else
        echo "✅ KomaliosApp.swift found"
    fi
    
    if [ ! -f "Config.swift" ]; then
        echo "❌ Config.swift not found"
        ((errors++))
    else
        echo "✅ Config.swift found"
    fi
    
    if [ $errors -gt 0 ]; then
        echo ""
        echo "❌ $errors critical files missing"
        echo "Cannot proceed with build."
        exit 1
    else
        echo ""
        echo "✅ Basic checks passed"
        echo ""
        echo "Opening in Xcode..."
        open Package.swift
    fi
fi
