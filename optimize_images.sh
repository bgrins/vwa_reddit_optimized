#!/bin/bash

# Simple Forum Image Optimization Script
# Processes images one-by-one into a new directory

set -e

# Parse command line arguments
AGGRESSIVE=false
CONTAINER_NAME="${CONTAINER_NAME:-forum}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --aggressive)
            AGGRESSIVE=true
            shift
            ;;
        --container)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--aggressive] [--container CONTAINER_NAME]"
            exit 1
            ;;
    esac
done

# Configuration
SOURCE_DIR="/var/www/html/public/submission_images"
if [ "$AGGRESSIVE" = true ]; then
    OUTPUT_DIR="/var/www/html/public/submission_images_optimized_aggressive"
else
    OUTPUT_DIR="/var/www/html/public/submission_images_optimized"
fi

# Optimization settings based on mode
if [ "$AGGRESSIVE" = true ]; then
    JPEG_QUALITY=30
    GIF_LOSSY=100
    GIF_COLORS=64
    PNG_LEVEL=3
    PNG_STRIP="all"
    MODE_DESC="AGGRESSIVE"
else
    JPEG_QUALITY_LARGE=80
    JPEG_QUALITY_SMALL=85
    GIF_LOSSY=0
    GIF_COLORS=256
    PNG_LEVEL=2
    PNG_STRIP="preserve"
    MODE_DESC="STANDARD"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Simple Image Optimization Script${NC}"
echo "===================================="
echo "Container: ${CONTAINER_NAME}"
echo "Mode: ${MODE_DESC}"
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
                if [ $GIF_LOSSY -gt 0 ]; then
                    gifsicle -O3 --lossy=$GIF_LOSSY --colors $GIF_COLORS \"\$img\" -o \"/tmp/\$img.tmp\" 2>/dev/null || cp \"\$img\" \"/tmp/\$img.tmp\"
                else
                    gifsicle -O3 --colors $GIF_COLORS \"\$img\" -o \"/tmp/\$img.tmp\" 2>/dev/null || cp \"\$img\" \"/tmp/\$img.tmp\"
                fi
                ;;
            png|PNG)
                # Copy first, then optimize in place
                cp \"\$img\" \"/tmp/\$img.tmp\"
                if [ \"$PNG_STRIP\" = \"all\" ]; then
                    optipng -quiet -o$PNG_LEVEL -strip all \"/tmp/\$img.tmp\" 2>/dev/null || true
                else
                    optipng -quiet -o$PNG_LEVEL -preserve \"/tmp/\$img.tmp\" 2>/dev/null || true
                fi
                ;;
            jpg|jpeg|JPG|JPEG)
                # Copy first, then optimize
                cp \"\$img\" \"/tmp/\$img.tmp\"
                if [ \"$AGGRESSIVE\" = true ]; then
                    jpegoptim -m$JPEG_QUALITY --strip-all \"/tmp/\$img.tmp\" 2>/dev/null || true
                else
                    if [ \$original_size -gt 1048576 ]; then
                        jpegoptim -m$JPEG_QUALITY_LARGE --strip-all \"/tmp/\$img.tmp\" 2>/dev/null || true
                    else
                        jpegoptim -m$JPEG_QUALITY_SMALL --strip-all \"/tmp/\$img.tmp\" 2>/dev/null || true
                    fi
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
echo "Optimization mode: ${MODE_DESC}"
if [ "$AGGRESSIVE" = true ]; then
    echo "  JPEG quality: ${JPEG_QUALITY}%"
    echo "  GIF: lossy=${GIF_LOSSY}, colors=${GIF_COLORS}"
    echo "  PNG: level=${PNG_LEVEL}, strip=${PNG_STRIP}"
else
    echo "  JPEG quality: ${JPEG_QUALITY_LARGE}% (large), ${JPEG_QUALITY_SMALL}% (small)"
    echo "  GIF: colors=${GIF_COLORS}"
    echo "  PNG: level=${PNG_LEVEL}, preserve metadata"
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
echo -e "${YELLOW}Usage:${NC}"
echo "  Standard mode:    ./optimize_images.sh"
echo "  Aggressive mode:  ./optimize_images.sh --aggressive"
echo "  Custom container: ./optimize_images.sh --container mycontainer"
echo "  Environment var:  CONTAINER_NAME=mycontainer ./optimize_images.sh --aggressive"
echo ""
echo -e "${GREEN}Done!${NC}"