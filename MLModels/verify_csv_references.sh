#!/bin/bash

echo "🔍 Checking for references to old CSV file..."
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Search for old CSV references
echo "Searching for 'Models_Masterlist_Fixed.csv'..."

# Find in all text files (exclude binary and git files)
results=$(find . -type f \
    -not -path "./.git/*" \
    -not -path "./.build/*" \
    -not -path "./build/*" \
    -not -path "./DerivedData/*" \
    -not -name "*.png" \
    -not -name "*.jpg" \
    -not -name "*.pdf" \
    -not -name "*.backup" \
    -not -name "CSV_REFERENCE_UPDATE.md" \
    -not -name "verify_csv_references.sh" \
    -exec grep -l "Models_Masterlist_Fixed" {} \; 2>/dev/null)

if [ -z "$results" ]; then
    echo -e "${GREEN}✅ No references to old CSV found!${NC}"
    echo ""
    echo "All references now point to: Models_Masterlist_Final.csv"
else
    echo -e "${RED}❌ Found references in:${NC}"
    echo "$results"
    echo ""
    echo -e "${YELLOW}⚠️  Please update these files manually.${NC}"
    exit 1
fi

echo ""
echo "🔍 Verifying new CSV file exists..."

if [ -f "Models_Masterlist_Final.csv" ]; then
    echo -e "${GREEN}✅ Models_Masterlist_Final.csv found${NC}"
    
    # Check file size
    file_size=$(wc -c < "Models_Masterlist_Final.csv")
    echo "   File size: $file_size bytes"
    
    # Count lines (categories)
    line_count=$(wc -l < "Models_Masterlist_Final.csv")
    echo "   Line count: $line_count lines"
    
    # Check header
    header=$(head -n 1 "Models_Masterlist_Final.csv")
    echo "   Header: ${header:0:80}..."
else
    echo -e "${RED}❌ Models_Masterlist_Final.csv NOT found${NC}"
    echo "   Please ensure the file is in the project root."
    exit 1
fi

echo ""
echo "🔍 Checking Package.swift..."

if grep -q "Models_Masterlist_Final.csv" Package.swift 2>/dev/null; then
    echo -e "${GREEN}✅ Package.swift references correct CSV${NC}"
else
    echo -e "${RED}❌ Package.swift does not reference Models_Masterlist_Final.csv${NC}"
    exit 1
fi

echo ""
echo "🔍 Checking old CSV file..."

if [ -f "Models_Masterlist_Fixed.csv" ]; then
    echo -e "${YELLOW}⚠️  Old CSV still exists: Models_Masterlist_Fixed.csv${NC}"
    echo "   Consider removing or renaming it to avoid confusion:"
    echo "   $ mv Models_Masterlist_Fixed.csv Models_Masterlist_Fixed.csv.backup"
    echo "   $ rm Models_Masterlist_Fixed.csv"
else
    echo -e "${GREEN}✅ Old CSV file not found (cleaned up)${NC}"
fi

echo ""
echo "=============================================="
echo -e "${GREEN}✅ Verification complete!${NC}"
echo ""
echo "Summary:"
echo "  • No references to old CSV: ✅"
echo "  • New CSV file exists: ✅"
echo "  • Package.swift updated: ✅"
echo ""
echo "You can now safely build the project."
echo ""
