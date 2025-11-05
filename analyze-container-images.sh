#!/bin/bash
set -e

# Configuration
IMAGE_NAME="ghcr.io/bgrins/vwa-reddit-optimized-bundled:latest"
CONTAINER_NAME="vwa-reddit-analysis-temp"
DB_USER="db_user"
DB_NAME="postmill"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Reddit Container Image Analysis ===${NC}"
echo ""

# Check if container is already running
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${YELLOW}Container ${CONTAINER_NAME} already exists. Removing...${NC}"
    docker stop ${CONTAINER_NAME} 2>/dev/null || true
    docker rm ${CONTAINER_NAME} 2>/dev/null || true
fi

# Pull latest image
echo -e "${BLUE}Step 1: Pulling Docker image...${NC}"
docker pull ${IMAGE_NAME}

# Start container
echo -e "${BLUE}Step 2: Starting container...${NC}"
CONTAINER_ID=$(docker run -d --name ${CONTAINER_NAME} ${IMAGE_NAME})
echo "Container started: ${CONTAINER_ID:0:12}"

# Wait for database to be ready
echo -e "${BLUE}Step 3: Waiting for database to be ready...${NC}"
for i in {1..30}; do
    if docker exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "SELECT 1" &>/dev/null; then
        echo -e "${GREEN}Database is ready!${NC}"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# Check if DB is ready
if ! docker exec ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME} -c "SELECT 1" &>/dev/null; then
    echo -e "${RED}ERROR: Database did not become ready in time${NC}"
    docker stop ${CONTAINER_NAME}
    docker rm ${CONTAINER_NAME}
    exit 1
fi

# Get total image directory size
echo -e "${BLUE}Step 4: Analyzing image storage...${NC}"
TOTAL_SIZE=$(docker exec ${CONTAINER_NAME} du -sh /var/www/html/public/submission_images | cut -f1)
echo "Total image directory size: ${TOTAL_SIZE}"
echo ""

# Export subreddit-image mapping
echo -e "${BLUE}Step 5: Extracting subreddit-image mappings from database...${NC}"
docker exec ${CONTAINER_NAME} bash -c "
psql -U ${DB_USER} -d ${DB_NAME} -t -c \"
SELECT f.name, i.file_name
FROM submissions s
JOIN forums f ON s.forum_id = f.id
JOIN images i ON s.image_id = i.id
WHERE s.image_id IS NOT NULL
\" | awk -F\"|\" '{
    subreddit = \$1
    gsub(/^[ \t]+|[ \t]+$/, \"\", subreddit)
    filename = \$2
    gsub(/^[ \t]+|[ \t]+$/, \"\", filename)
    if (subreddit != \"\" && filename != \"\") {
        print subreddit \"|\" filename
    }
}' > /tmp/subreddit_images.txt
"

# Extract subreddit statistics (posts, comments, commenters)
echo -e "${BLUE}Step 6: Extracting subreddit statistics (posts, comments, commenters)...${NC}"
docker exec ${CONTAINER_NAME} bash -c "
psql -U ${DB_USER} -d ${DB_NAME} -t -c \"
SELECT
    f.name,
    COUNT(DISTINCT s.id) as post_count,
    COUNT(DISTINCT c.id) as comment_count,
    COUNT(DISTINCT c.user_id) as unique_commenters
FROM forums f
LEFT JOIN submissions s ON f.id = s.forum_id
LEFT JOIN comments c ON s.id = c.submission_id
GROUP BY f.name
\" | awk -F\"|\" '{
    subreddit = \$1
    gsub(/^[ \t]+|[ \t]+$/, \"\", subreddit)
    posts = \$2
    gsub(/^[ \t]+|[ \t]+$/, \"\", posts)
    comments = \$3
    gsub(/^[ \t]+|[ \t]+$/, \"\", comments)
    commenters = \$4
    gsub(/^[ \t]+|[ \t]+$/, \"\", commenters)
    if (subreddit != \"\") {
        print subreddit \"|\" posts \"|\" comments \"|\" commenters
    }
}' > /tmp/subreddit_stats.txt
"

# Calculate file sizes
echo -e "${BLUE}Step 7: Calculating disk usage per file...${NC}"
docker exec ${CONTAINER_NAME} bash -c '
while IFS="|" read subreddit filename; do
    if [ -f "/var/www/html/public/submission_images/$filename" ]; then
        size=$(stat -c %s "/var/www/html/public/submission_images/$filename" 2>/dev/null || echo 0)
        echo "$subreddit|$size"
    fi
done < /tmp/subreddit_images.txt > /tmp/subreddit_sizes.txt
'

# Generate comprehensive report
echo -e "${BLUE}Step 8: Generating report...${NC}"
echo ""
docker exec ${CONTAINER_NAME} bash -c '
# Combine size data with stats data
awk -F"|" "{
    subreddit[\$1] += \$2
    images[\$1]++
} END {
    for (s in subreddit) {
        printf \"%s|%d|%d\\n\", s, subreddit[s], images[s]
    }
}" /tmp/subreddit_sizes.txt > /tmp/subreddit_combined.txt

# Join with stats
while IFS="|" read subreddit posts comments commenters; do
    if grep -q "^${subreddit}|" /tmp/subreddit_combined.txt 2>/dev/null; then
        size_images=$(grep "^${subreddit}|" /tmp/subreddit_combined.txt | head -1)
        size=$(echo "$size_images" | cut -d"|" -f2)
        images=$(echo "$size_images" | cut -d"|" -f3)
        echo "${subreddit}|${size}|${images}|${posts}|${comments}|${commenters}"
    else
        echo "${subreddit}|0|0|${posts}|${comments}|${commenters}"
    fi
done < /tmp/subreddit_stats.txt > /tmp/subreddit_full.txt

echo "==================================================================================="
echo "                      SUBREDDIT STATISTICS - TOP 20 BY SIZE"
echo "==================================================================================="
echo ""
printf "%-25s %10s %7s %7s %9s %9s\n" "Subreddit" "Size" "Images" "Posts" "Comments" "Users"
echo "-----------------------------------------------------------------------------------"
sort -t"|" -k2 -n -r /tmp/subreddit_full.txt | head -20 | awk -F"|" "{
    gb = \$2 / 1024 / 1024 / 1024
    printf \"%-25s %9.2f GB %6d %7d %9d %9d\\n\", \$1, gb, \$3, \$4, \$5, \$6
}"

echo ""
echo "================================================================"
echo "                  SPACE SAVINGS SCENARIOS"
echo "================================================================"
echo ""

echo "Scenario 1: Remove Top 5 Subreddits"
echo "------------------------------------"
awk -F"|" "{
    subreddit[\$1] += \$2
    count[\$1]++
} END {
    for (s in subreddit) {
        printf \"%s|%d|%d\\n\", s, subreddit[s], count[s]
    }
}" /tmp/subreddit_sizes.txt | sort -t"|" -k2 -n -r | head -5 | awk -F"|" "{
    gb = \$2 / 1024 / 1024 / 1024
    cumulative += gb
    images += \$3
    printf \"  - %-23s %8.2f GB (%5d images)\\n\", \$1, gb, \$3
} END {
    printf \"  TOTAL SAVINGS:              %8.2f GB (%5d images)\\n\", cumulative, images
}"

echo ""
echo "Scenario 2: Remove Top 10 Subreddits"
echo "-------------------------------------"
awk -F"|" "{
    subreddit[\$1] += \$2
    count[\$1]++
} END {
    for (s in subreddit) {
        printf \"%s|%d|%d\\n\", s, subreddit[s], count[s]
    }
}" /tmp/subreddit_sizes.txt | sort -t"|" -k2 -n -r | head -10 | awk -F"|" "{
    gb = \$2 / 1024 / 1024 / 1024
    cumulative += gb
    images += \$3
} END {
    printf \"  TOTAL SAVINGS:              %8.2f GB (%5d images)\\n\", cumulative, images
}"

echo ""
echo "Scenario 3: Remove Top 20 Subreddits"
echo "-------------------------------------"
awk -F"|" "{
    subreddit[\$1] += \$2
    count[\$1]++
} END {
    for (s in subreddit) {
        printf \"%s|%d|%d\\n\", s, subreddit[s], count[s]
    }
}" /tmp/subreddit_sizes.txt | sort -t"|" -k2 -n -r | head -20 | awk -F"|" "{
    gb = \$2 / 1024 / 1024 / 1024
    cumulative += gb
    images += \$3
} END {
    printf \"  TOTAL SAVINGS:              %8.2f GB (%5d images)\\n\", cumulative, images
}"

echo ""
echo "Scenario 4: Remove All Regional/City Subreddits"
echo "------------------------------------------------"
awk -F"|" "{
    subreddit[\$1] += \$2
    count[\$1]++
} END {
    for (s in subreddit) {
        printf \"%s|%d|%d\\n\", s, subreddit[s], count[s]
    }
}" /tmp/subreddit_sizes.txt | grep -E "Washington|newjersey|vermont|Maine|philadelphia|boston|newhampshire|Pennsylvania|nyc|massachusetts|pittsburgh|jerseycity|washingtondc|RhodeIsland|Connecticut|rva|baltimore|providence|springfieldMO|WorcesterMA|Newark|CambridgeMA|newhaven|ColumbiaMD|LowellMA|Hartford|StamfordCT|ManchesterNH|lakewood|arlingtonva|BridgeportCT|yonkers" | awk -F"|" "{
    gb = \$2 / 1024 / 1024 / 1024
    cumulative += gb
    images += \$3
} END {
    printf \"  TOTAL SAVINGS:              %8.2f GB (%5d images)\\n\", cumulative, images
}"

echo ""
echo "================================================================"
echo "                     SUMMARY STATISTICS"
echo "================================================================"
echo ""
awk -F"|" "{
    gb = \$2 / 1024 / 1024 / 1024
    total_gb += gb
    total_images += \$3
    total_posts += \$4
    total_comments += \$5
    total_commenters += \$6
    subreddit_count++
} END {
    printf \"  Total Subreddits:           %8d\\n\", subreddit_count
    printf \"  Total Posts:                %8d\\n\", total_posts
    printf \"  Total Comments:             %8d\\n\", total_comments
    printf \"  Total Unique Commenters:    %8d\\n\", total_commenters
    printf \"  Total Images:               %8d\\n\", total_images
    printf \"  Total Size:                 %8.2f GB\\n\", total_gb
    printf \"  Average per Subreddit:      %8.2f GB\\n\", total_gb / subreddit_count
    printf \"  Average per Image:          %8.2f MB\\n\", (total_gb * 1024) / total_images
}" /tmp/subreddit_full.txt
echo ""
echo "================================================================"
'

# Offer to save full report
echo ""
echo -e "${YELLOW}Do you want to save the full subreddit list to a file? (y/n)${NC}"
read -r SAVE_FULL
if [[ "$SAVE_FULL" == "y" || "$SAVE_FULL" == "Y" ]]; then
    OUTPUT_FILE="docs/subreddit_analysis.txt"
    docker exec ${CONTAINER_NAME} bash -c '
    echo "==================================================================================="
    echo "                           FULL SUBREDDIT ANALYSIS"
    echo "==================================================================================="
    echo ""
    printf "%-30s %12s %8s %8s %10s %10s\n" "Subreddit" "Size" "Images" "Posts" "Comments" "Users"
    echo "-----------------------------------------------------------------------------------"
    sort -t"|" -k2 -n -r /tmp/subreddit_full.txt | awk -F"|" "{
        gb = \$2 / 1024 / 1024 / 1024
        printf \"%-30s %11.2f GB %7d %8d %10d %10d\\n\", \$1, gb, \$3, \$4, \$5, \$6
    }"
    ' > "${OUTPUT_FILE}"
    echo -e "${GREEN}Full report saved to: ${OUTPUT_FILE}${NC}"
fi

# Cleanup
echo ""
echo -e "${BLUE}Step 9: Cleaning up...${NC}"
docker stop ${CONTAINER_NAME}
docker rm ${CONTAINER_NAME}

echo -e "${GREEN}Analysis complete!${NC}"
