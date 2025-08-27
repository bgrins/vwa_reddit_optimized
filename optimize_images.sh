#!/bin/bash

# Simple Forum Image Optimization Script
# Processes images one-by-one into a new directory

set -e

# Configuration
CONTAINER_NAME="forum"
SOURCE_DIR="/var/www/html/public/submission_images"
OUTPUT_DIR="/var/www/html/public/submission_images_optimized"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Simple Image Optimization Script${NC}"
echo "===================================="
echo "Processing images into new directory"
echo ""

# Check if container exists and is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}Error: Container '${CONTAINER_NAME}' is not running${NC}"
    exit 1
fi

# Step 1: Install required tools
echo -e "${YELLOW}Installing optimization tools...${NC}"
docker exec $CONTAINER_NAME sh -c "
    if ! which gifsicle >/dev/null 2>&1; then
        echo 'Installing gifsicle...'
        apk add --no-cache gifsicle 2>/dev/null || apt-get update && apt-get install -y gifsicle
    fi
    
    if ! which optipng >/dev/null 2>&1; then
        echo 'Installing optipng...'
        apk add --no-cache optipng 2>/dev/null || apt-get update && apt-get install -y optipng
    fi
    
    if ! which jpegoptim >/dev/null 2>&1; then
        echo 'Installing jpegoptim...'
        apk add --no-cache jpegoptim 2>/dev/null || apt-get update && apt-get install -y jpegoptim
    fi
    
    echo 'Tools ready.'
"

# Step 2: Create output directory
echo -e "${YELLOW}Setting up output directory...${NC}"
docker exec $CONTAINER_NAME sh -c "mkdir -p '$OUTPUT_DIR'"

# Step 3: Get initial stats
echo -e "${YELLOW}Analyzing files...${NC}"
TOTAL_FILES=$(docker exec $CONTAINER_NAME sh -c "cd $SOURCE_DIR && ls -1 2>/dev/null | wc -l")
EXISTING_OUTPUT=$(docker exec $CONTAINER_NAME sh -c "cd $OUTPUT_DIR && ls -1 2>/dev/null | wc -l")
SOURCE_SIZE=$(docker exec $CONTAINER_NAME sh -c "du -sh $SOURCE_DIR 2>/dev/null | cut -f1")

echo "Source directory: $SOURCE_SIZE"
echo "Total files: $TOTAL_FILES"
if [ "$EXISTING_OUTPUT" -gt 0 ]; then
    echo -e "${BLUE}Already processed: $EXISTING_OUTPUT files (resuming)${NC}"
fi
echo ""

# Step 4: Process all files
echo -e "${YELLOW}Processing files...${NC}"
docker exec $CONTAINER_NAME sh -c "
    cd $SOURCE_DIR
    
    processed=0
    skipped=0
    optimized=0
    total_saved=0
    
    # Process all files
    for file in *; do
        if [ ! -f \"\$file\" ]; then
            continue
        fi
        
        # Skip if already processed (exists in output dir)
        if [ -f \"$OUTPUT_DIR/\$file\" ]; then
            skipped=\$((skipped + 1))
            continue
        fi
        
        # Check if it's an image file
        ext=\${file##*.}
        is_image=0
        case \"\$ext\" in
            gif|GIF|png|PNG|jpg|jpeg|JPG|JPEG)
                is_image=1
                ;;
        esac
        
        # If not an image, just copy it
        if [ \$is_image -eq 0 ]; then
            cp \"\$file\" \"$OUTPUT_DIR/\$file\"
            processed=\$((processed + 1))
            echo \"  Copied non-image file: \$file\"
            continue
        fi
        
        # Continue with image optimization
        img=\"\$file\"
        
        processed=\$((processed + 1))
        original_size=\$(stat -c %s \"\$img\" 2>/dev/null || stat -f %z \"\$img\" 2>/dev/null)
        
        # Determine file type and optimize
        ext=\${img##*.}
        case \"\$ext\" in
            gif|GIF)
                # Try to optimize GIF
                gifsicle -O3 --colors 256 \"\$img\" -o \"/tmp/\$img.tmp\" 2>/dev/null || cp \"\$img\" \"/tmp/\$img.tmp\"
                ;;
            png|PNG)
                # Copy first, then optimize in place
                cp \"\$img\" \"/tmp/\$img.tmp\"
                optipng -quiet -o2 -preserve \"/tmp/\$img.tmp\" 2>/dev/null || true
                ;;
            jpg|jpeg|JPG|JPEG)
                # Copy first, then optimize
                cp \"\$img\" \"/tmp/\$img.tmp\"
                if [ \$original_size -gt 1048576 ]; then
                    jpegoptim -m80 --strip-all \"/tmp/\$img.tmp\" 2>/dev/null || true
                else
                    jpegoptim -m85 --strip-all \"/tmp/\$img.tmp\" 2>/dev/null || true
                fi
                ;;
        esac
        
        # Check if optimization saved space
        if [ -f \"/tmp/\$img.tmp\" ]; then
            new_size=\$(stat -c %s \"/tmp/\$img.tmp\" 2>/dev/null || stat -f %z \"/tmp/\$img.tmp\" 2>/dev/null)
            
            if [ \$new_size -lt \$original_size ]; then
                # Use optimized version
                mv \"/tmp/\$img.tmp\" \"$OUTPUT_DIR/\$img\"
                saved=\$((original_size - new_size))
                total_saved=\$((total_saved + saved))
                optimized=\$((optimized + 1))
                
                # Show significant savings
                if [ \$saved -gt 524288 ]; then
                    echo \"  ✓ \$img: saved \$((saved / 1024))KB\"
                fi
            else
                # Use original
                cp \"\$img\" \"$OUTPUT_DIR/\$img\"
                rm -f \"/tmp/\$img.tmp\"
            fi
        else
            # Optimization failed, use original
            cp \"\$img\" \"$OUTPUT_DIR/\$img\"
        fi
        
        # Progress indicator every 10% or at specific milestones
        if [ \$processed -eq 1 ] || [ \$processed -eq 10 ] || [ \$processed -eq 50 ] || [ \$processed -eq 100 ] || [ \$((processed % 100)) -eq 0 ]; then
            echo \"  Progress: \$processed processed, \$skipped skipped, \$optimized optimized\"
        fi
    done
    
    echo \"\"
    echo \"Complete: \$processed processed, \$skipped skipped, \$optimized optimized\"
    echo \"Total space saved: \$((total_saved / 1024 / 1024))MB\"
"

# Step 5: Final statistics
echo ""
echo -e "${GREEN}========== OPTIMIZATION COMPLETE ==========${NC}"
OUTPUT_SIZE=$(docker exec $CONTAINER_NAME sh -c "du -sh $OUTPUT_DIR 2>/dev/null | cut -f1")
OUTPUT_COUNT=$(docker exec $CONTAINER_NAME sh -c "ls -1 $OUTPUT_DIR 2>/dev/null | wc -l")

echo "Source directory: $SOURCE_SIZE"
echo "Output directory: $OUTPUT_SIZE ($OUTPUT_COUNT files)"

# Calculate percentage saved
SOURCE_MB=$(echo $SOURCE_SIZE | sed 's/[^0-9.]//g')
OUTPUT_MB=$(echo $OUTPUT_SIZE | sed 's/[^0-9.]//g')
if [[ $SOURCE_SIZE == *G* ]]; then SOURCE_MB=$(echo "$SOURCE_MB * 1024" | bc); fi
if [[ $OUTPUT_SIZE == *G* ]]; then OUTPUT_MB=$(echo "$OUTPUT_MB * 1024" | bc); fi
SAVED_MB=$(echo "$SOURCE_MB - $OUTPUT_MB" | bc 2>/dev/null || echo "0")
if [ "$SAVED_MB" != "0" ] && [ "$SOURCE_MB" != "0" ]; then
    PERCENT=$(echo "scale=1; ($SAVED_MB / $SOURCE_MB) * 100" | bc 2>/dev/null || echo "0")
    echo -e "${GREEN}Space saved: ${SAVED_MB}MB (${PERCENT}%)${NC}"
fi

echo ""
echo "Commands:"
echo "  Compare dirs:    docker exec $CONTAINER_NAME sh -c 'du -sh $SOURCE_DIR $OUTPUT_DIR'"
echo "  Swap to optimized: docker exec $CONTAINER_NAME sh -c 'mv $SOURCE_DIR ${SOURCE_DIR}_old && mv $OUTPUT_DIR $SOURCE_DIR'"
echo "  Restore original: docker exec $CONTAINER_NAME sh -c 'mv $SOURCE_DIR $OUTPUT_DIR && mv ${SOURCE_DIR}_old $SOURCE_DIR'"
echo ""
echo -e "${YELLOW}Note:${NC} Original files remain in $SOURCE_DIR"
echo "Optimized files are in $OUTPUT_DIR"
echo "Script is resumable - run again to continue processing"
echo ""
echo -e "${GREEN}Done!${NC}"