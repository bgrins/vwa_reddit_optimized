#!/bin/bash

# Subreddit Cleanup Script
# Removes unwanted subreddits from database and filesystem

set -e

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-forum}"
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --container)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        --execute)
            DRY_RUN=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run|--execute] [--container CONTAINER_NAME]"
            exit 1
            ;;
    esac
done

# Subreddits to remove (based on slim image recommendations)
REMOVE_SUBREDDITS=(
    # Large unused subreddits (6.75GB)
    "funny"
    "creepy"
    "Washington"
    "BuyItForLife"
    "GetMotivated"

    # Unused location subreddits (2.3GB)
    "vermont"
    "Maine"
    "newjersey"
    "philadelphia"
    "massachusetts"
    "Pennsylvania"
    "RhodeIsland"
    "Connecticut"
    "rva"
    "baltimore"
    "providence"
    "WorcesterMA"
    "CambridgeMA"
    "newhaven"
    "ColumbiaMD"
    "LowellMA"
    "Hartford"
    "StamfordCT"
    "ManchesterNH"
    "lakewood"
    "BridgeportCT"
    "yonkers"
    "allentown"
    "WaterburyCT"
    "Paterson"

    # Optional: Add these for more aggressive cleanup (additional 4GB saved)
    # "gifs"                # 2.00 GB - only 1 VWA task
    # "mildlyinteresting"   # 2.00 GB - only 3 VWA tasks
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Subreddit Cleanup Script${NC}"
echo "===================================="
echo "Container: ${CONTAINER_NAME}"
if [ "$DRY_RUN" = true ]; then
    echo -e "Mode: ${YELLOW}DRY RUN${NC} (no changes will be made)"
else
    echo -e "Mode: ${RED}EXECUTE${NC} (changes will be permanent)"
fi
echo "Subreddits to remove: ${#REMOVE_SUBREDDITS[@]}"
echo ""

# Check if container exists and is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}Error: Container '${CONTAINER_NAME}' is not running${NC}"
    exit 1
fi

# Database connection info (from Postmill defaults)
DB_NAME="postmill"
DB_USER="db_user"
SUBMISSION_IMAGES_DIR="/var/www/html/public/submission_images"

# Step 1: Analyze what will be deleted
echo -e "${YELLOW}Analyzing subreddits to remove...${NC}"
echo ""

# Create SQL query to get statistics
STATS_QUERY="
SELECT
    f.name as forum_name,
    COUNT(DISTINCT s.id) as submission_count,
    COUNT(DISTINCT c.id) as comment_count,
    COUNT(DISTINCT s.image_id) FILTER (WHERE s.image_id IS NOT NULL) as image_count
FROM forums f
LEFT JOIN submissions s ON s.forum_id = f.id
LEFT JOIN comments c ON c.submission_id = s.id
WHERE f.name IN ($(printf "'%s'," "${REMOVE_SUBREDDITS[@]}" | sed 's/,$//'))
GROUP BY f.name
ORDER BY f.name;
"

echo "Subreddit statistics:"
echo "--------------------"
docker exec $CONTAINER_NAME su - postgres -c "psql -U $DB_USER -d $DB_NAME -c \"$STATS_QUERY\"" 2>/dev/null || {
    echo -e "${RED}Error: Could not query database${NC}"
    exit 1
}

echo ""
echo -e "${YELLOW}Getting total counts...${NC}"

TOTAL_QUERY="
SELECT
    COUNT(DISTINCT f.id) as forum_count,
    COUNT(DISTINCT s.id) as total_submissions,
    COUNT(DISTINCT c.id) as total_comments
FROM forums f
LEFT JOIN submissions s ON s.forum_id = f.id
LEFT JOIN comments c ON c.submission_id = s.id
WHERE f.name IN ($(printf "'%s'," "${REMOVE_SUBREDDITS[@]}" | sed 's/,$//'));
"

docker exec $CONTAINER_NAME su - postgres -c "psql -U $DB_USER -d $DB_NAME -c \"$TOTAL_QUERY\"" 2>/dev/null

echo ""

# Step 2: Check filesystem space
echo -e "${YELLOW}Checking filesystem usage...${NC}"

for subreddit in "${REMOVE_SUBREDDITS[@]}"; do
    SIZE=$(docker exec $CONTAINER_NAME sh -c "du -sh $SUBMISSION_IMAGES_DIR/$subreddit 2>/dev/null | cut -f1" || echo "N/A")
    if [ "$SIZE" != "N/A" ] && [ -n "$SIZE" ]; then
        echo "  r/$subreddit: $SIZE"
    fi
done

echo ""

# Step 3: Confirm deletion (if not dry run)
if [ "$DRY_RUN" = false ]; then
    echo -e "${RED}WARNING: This will permanently delete the above subreddits!${NC}"
    echo -e "${RED}This action cannot be undone.${NC}"
    echo ""
    read -p "Type 'DELETE' to confirm: " CONFIRM

    if [ "$CONFIRM" != "DELETE" ]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
fi

# Step 4: Perform deletion
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN: Would delete the following...${NC}"
    echo ""

    for subreddit in "${REMOVE_SUBREDDITS[@]}"; do
        echo "  - Database records for r/$subreddit"
        echo "  - Image files in $SUBMISSION_IMAGES_DIR/$subreddit"
    done

    echo ""
    echo -e "${GREEN}DRY RUN COMPLETE${NC}"
    echo "Run with --execute to actually perform the deletion"
else
    echo -e "${YELLOW}Deleting subreddits...${NC}"
    echo ""

    for subreddit in "${REMOVE_SUBREDDITS[@]}"; do
        echo -e "${BLUE}Processing r/$subreddit...${NC}"

        # Get forum ID first
        FORUM_ID=$(docker exec $CONTAINER_NAME su - postgres -c "psql -U $DB_USER -d $DB_NAME -t -c \"SELECT id FROM forums WHERE name = '$subreddit';\"" 2>/dev/null | tr -d ' ')

        if [ -z "$FORUM_ID" ]; then
            echo "  - Forum not found in database"
            echo ""
            continue
        fi

        # Step 1: Get list of images BEFORE deleting from database
        echo "  Getting image list..."
        docker exec $CONTAINER_NAME su - postgres -c "psql -U $DB_USER -d $DB_NAME -t -c \"
            SELECT i.file_name FROM submissions s
            JOIN images i ON i.id = s.image_id
            WHERE s.forum_id = $FORUM_ID AND s.image_id IS NOT NULL;
        \"" 2>/dev/null | tr -d ' ' | grep -v '^$' > /tmp/images_to_delete_$subreddit.txt

        IMAGE_COUNT=$(wc -l < /tmp/images_to_delete_$subreddit.txt)

        # Step 2: Delete images from filesystem
        if [ "$IMAGE_COUNT" -gt 0 ]; then
            echo "  Deleting $IMAGE_COUNT images..."
            # Copy list to container and delete in batch
            docker cp /tmp/images_to_delete_$subreddit.txt $CONTAINER_NAME:/tmp/delete_list.txt

            docker exec $CONTAINER_NAME sh -c "
                cd $SUBMISSION_IMAGES_DIR
                deleted=0
                while read filename; do
                    if [ -f \"\$filename\" ]; then
                        rm -f \"\$filename\" && deleted=\$((deleted + 1))
                    fi
                done < /tmp/delete_list.txt
                echo \$deleted
            " > /tmp/deleted_count.txt

            DELETED=$(cat /tmp/deleted_count.txt)
            echo "  ✓ Deleted $DELETED images"

            rm -f /tmp/images_to_delete_$subreddit.txt /tmp/deleted_count.txt
            docker exec $CONTAINER_NAME rm -f /tmp/delete_list.txt
        else
            echo "  - No images to delete"
        fi

        # Step 3: Delete from database AFTER images are deleted
        echo "  Deleting database records..."
        docker exec $CONTAINER_NAME su - postgres -c "psql -U $DB_USER -d $DB_NAME -c \"
            DELETE FROM comments WHERE submission_id IN (SELECT id FROM submissions WHERE forum_id = $FORUM_ID);
            DELETE FROM submission_votes WHERE submission_id IN (SELECT id FROM submissions WHERE forum_id = $FORUM_ID);
            DELETE FROM forum_subscriptions WHERE forum_id = $FORUM_ID;
            DELETE FROM moderators WHERE forum_id = $FORUM_ID;
            DELETE FROM forum_bans WHERE forum_id = $FORUM_ID;
            DELETE FROM submissions WHERE forum_id = $FORUM_ID;
            DELETE FROM forums WHERE id = $FORUM_ID;
        \"" 2>&1 | grep -v "^DELETE" || true
        echo "  ✓ Deleted database records"

        echo ""
    done

    # Step 5: Vacuum database to reclaim space
    echo -e "${YELLOW}Vacuuming database to reclaim space...${NC}"
    docker exec $CONTAINER_NAME su - postgres -c "psql -U $DB_USER -d $DB_NAME -c 'VACUUM FULL;'" 2>/dev/null || {
        echo -e "${YELLOW}Warning: Could not vacuum database${NC}"
    }

    echo ""
    echo -e "${GREEN}========== CLEANUP COMPLETE ==========${NC}"

    # Show final statistics
    echo ""
    echo -e "${YELLOW}Remaining forums:${NC}"
    docker exec $CONTAINER_NAME su - postgres -c "psql -U $DB_USER -d $DB_NAME -c 'SELECT COUNT(*) as remaining_forums FROM forums;'" 2>/dev/null

    echo ""
    echo -e "${YELLOW}Disk space usage:${NC}"
    docker exec $CONTAINER_NAME sh -c "du -sh $SUBMISSION_IMAGES_DIR 2>/dev/null | cut -f1"
fi

echo ""
echo -e "${YELLOW}Usage:${NC}"
echo "  Dry run (preview):  ./cleanup_subreddits.sh --dry-run"
echo "  Execute deletion:   ./cleanup_subreddits.sh --execute"
echo "  Custom container:   ./cleanup_subreddits.sh --execute --container mycontainer"
echo ""
echo -e "${GREEN}Done!${NC}"
