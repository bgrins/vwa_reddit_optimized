# Visual Web Arena Reddit Test Dataset - Subreddit Analysis

**Analysis Date:** 2025-11-05  
**Source:** `test_reddit.raw.json` from [visualwebarena](https://github.com/web-arena-x/visualwebarena)

---

## Executive Summary

The Visual Web Arena (VWA) Reddit test dataset contains **210 test cases**, of which **139 tasks (66.2%)** reference specific subreddits. These tasks evaluate AI agents on their ability to navigate Reddit, understand visual content, and perform various web automation tasks.

### Key Statistics

- **Unique Subreddits:** 34
- **Total Subreddit Mentions:** 140
- **Task Difficulty:** 39% Hard, 40% Medium, 22% Easy
- **Most Used Subreddit:** r/dataisbeautiful (28 tasks, 20%)

---

## Top 10 Most Used Subreddits

| Rank | Subreddit | Tasks | Percentage |
|------|-----------|-------|------------|
| 1 | r/dataisbeautiful | 28 | 20.0% |
| 2 | r/food | 15 | 10.71% |
| 3 | r/pics | 12 | 8.57% |
| 4 | r/memes | 11 | 7.86% |
| 5 | r/MechanicalKeyboards | 6 | 4.29% |
| 6 | r/wallstreetbets | 6 | 4.29% |
| 7 | r/gaming | 5 | 3.57% |
| 8 | r/Art | 5 | 3.57% |
| 9 | r/movies | 4 | 2.86% |
| 10 | r/OldSchoolCool | 4 | 2.86% |

---

## All Subreddits (Alphabetical)

| r/Art | r/EarthPorn | r/Jokes |
| --- | --- | --- |
| r/MechanicalKeyboards | r/Music | r/Newark |
| r/OldSchoolCool | r/arlingtonva | r/aww |
| r/boston | r/consoles | r/dataisbeautiful |
| r/explainlikeimfive | r/food | r/funny |
| r/gadgets | r/gaming | r/gifs |
| r/headphones | r/iphone | r/jerseycity |
| r/memes | r/mildlyinteresting | r/monitor |
| r/movies | r/newhampshire | r/nyc |
| r/photoshopbattles | r/pics | r/pittsburgh |
| r/space | r/springfieldMO | r/wallstreetbets |
| r/washingtondc |

---

## Category Breakdown

The subreddits can be grouped into the following categories:

### 📰 Content & Media (45 tasks)
Visual content, entertainment, and creative communities
- **Top:** r/pics (12), r/memes (11), r/Art (5)
- **Full list:** pics, memes, Art, EarthPorn, OldSchoolCool, movies, photoshopbattles, Music, funny, gifs, Jokes

### 📊 Data & Visualization (34 tasks)
Data analysis and financial communities
- **Top:** r/dataisbeautiful (28), r/wallstreetbets (6)

### 🎮 Technology & Gaming (17 tasks)
Tech products, gaming, and hardware communities
- **Top:** r/MechanicalKeyboards (6), r/gaming (5)
- **Full list:** MechanicalKeyboards, gaming, consoles, gadgets, headphones, iphone, monitor

### 🍔 Food (15 tasks)
Culinary content
- **Only:** r/food (15)

### 📍 Location-Based (15 tasks)
US city and state communities
- **Cities:** nyc, boston, pittsburgh, Newark, jerseycity, washingtondc, arlingtonva, springfieldMO
- **States:** newhampshire

### 🐾 Animals & Nature (8 tasks)
Cute animals and space/nature content
- **Equal split:** r/aww (4), r/space (4)

### 📚 Educational (6 tasks)
Learning and interesting content
- **Top:** r/mildlyinteresting (3), r/explainlikeimfive (2), r/Jokes (1)

---

## Task Difficulty Distribution

- **Easy:** 30 tasks (21.6%)
- **Medium:** 55 tasks (39.6%)
- **Hard:** 54 tasks (38.8%)

---

## Task Type Patterns

Based on analysis of task intents, the following patterns emerge:

| Task Type | Count | Percentage | Description |
|-----------|-------|------------|-------------|
| Comment Creation | 77 | 55.4% | Creating comments on posts |
| Post Creation | 80 | 57.6% | Making new posts |
| Navigation/Finding | 47 | 33.8% | Finding and navigating to posts |
| Research (Multi-site) | 32 | 23.0% | Cross-site tasks (Reddit + Wikipedia) |
| Counting/Analysis | 17 | 12.2% | Counting elements or analyzing content |
| Upvote/Downvote | 13 | 9.4% | Voting on posts |

*Note: Tasks can fall into multiple categories*

---

## Key Insights

### 1. r/dataisbeautiful Dominance
With 28 tasks (20% of all mentions), r/dataisbeautiful is by far the most used subreddit. These tasks primarily involve:
- Interpreting data visualizations
- Cross-referencing with Wikipedia for additional data
- Complex multi-step reasoning combining visual and textual information

### 2. Visual Understanding Requirements
Many tasks require sophisticated visual understanding:
- Image matching and similarity detection
- Object counting (animals, people, objects)
- Content classification (food, technology, etc.)
- Chart and graph interpretation
- Geographic location identification

### 3. Complexity & Multi-Step Reasoning
78% of tasks are Medium or Hard difficulty, often requiring:
- Navigation through multiple pages
- Understanding post context and metadata
- Cross-site research (Reddit + Wikipedia)
- User profile navigation
- Conditional logic based on visual content

### 4. Geographic Diversity
9 location-based subreddits test agents' ability to:
- Identify locations from images
- Navigate to city-specific communities
- Understand geographic references
- Filter content by location

### 5. Diverse Task Types
The dataset tests a comprehensive range of web automation skills:
- **Reading:** Finding posts, understanding content
- **Writing:** Creating posts and comments
- **Interaction:** Upvoting, downvoting
- **Navigation:** Multi-page workflows, user profiles
- **Analysis:** Counting, data extraction, comparison

---

## Usage Recommendations

### For Researchers
- Focus on r/dataisbeautiful, r/food, and r/pics for most coverage
- Test visual understanding capabilities extensively
- Ensure multi-site navigation support (Reddit + Wikipedia)
- Prepare for complex, multi-step reasoning tasks

### For Development
Priority subreddits to support (covers 70% of tasks):
1. r/dataisbeautiful (28 tasks)
2. r/food (15 tasks)
3. r/pics (12 tasks)
4. r/memes (11 tasks)
5. r/MechanicalKeyboards (6 tasks)
6. r/wallstreetbets (6 tasks)

### Task Difficulty Planning
- **Easy (22%):** Good for initial testing and debugging
- **Medium (40%):** Core evaluation tasks
- **Hard (39%):** Advanced capability assessment

---

## Files Generated

### 📄 subreddit_analysis.txt
Comprehensive text report with detailed breakdown of all subreddits, task patterns, and examples.

### 📄 subreddit_analysis.json
Structured JSON data containing:
- Metadata and statistics
- Subreddit counts and rankings
- Difficulty distributions
- Detailed task mappings per subreddit
- Category groupings

### 📄 README.md (this file)
User-friendly summary and analysis.

---

## Detailed Subreddit Information

Below is the complete breakdown of all 34 subreddits with task counts and difficulty levels:

| Rank | Subreddit | Tasks | Easy | Medium | Hard |
|------|-----------|-------|------|--------|------|
| 1 | r/dataisbeautiful | 28 | 0 | 12 | 16 |
| 2 | r/food | 15 | 6 | 3 | 6 |
| 3 | r/pics | 12 | 0 | 3 | 9 |
| 4 | r/memes | 11 | 3 | 5 | 3 |
| 5 | r/MechanicalKeyboards | 6 | 1 | 4 | 1 |
| 6 | r/wallstreetbets | 6 | 3 | 1 | 2 |
| 7 | r/gaming | 5 | 0 | 2 | 3 |
| 8 | r/Art | 5 | 1 | 2 | 2 |
| 9 | r/movies | 4 | 3 | 1 | 0 |
| 10 | r/OldSchoolCool | 4 | 4 | 0 | 0 |
| 11 | r/aww | 4 | 0 | 3 | 1 |
| 12 | r/space | 4 | 4 | 0 | 0 |
| 13 | r/pittsburgh | 3 | 0 | 1 | 2 |
| 14 | r/photoshopbattles | 3 | 0 | 1 | 2 |
| 15 | r/mildlyinteresting | 3 | 2 | 1 | 0 |
| 16 | r/EarthPorn | 3 | 1 | 1 | 1 |
| 17 | r/Newark | 2 | 0 | 1 | 1 |
| 18 | r/consoles | 2 | 0 | 1 | 1 |
| 19 | r/nyc | 2 | 0 | 1 | 1 |
| 20 | r/washingtondc | 2 | 0 | 1 | 1 |
| 21 | r/jerseycity | 2 | 0 | 1 | 1 |
| 22 | r/explainlikeimfive | 2 | 2 | 0 | 0 |
| 23 | r/boston | 1 | 0 | 1 | 0 |
| 24 | r/gadgets | 1 | 0 | 0 | 1 |
| 25 | r/newhampshire | 1 | 0 | 1 | 0 |
| 26 | r/funny | 1 | 0 | 1 | 0 |
| 27 | r/headphones | 1 | 0 | 1 | 0 |
| 28 | r/monitor | 1 | 0 | 0 | 1 |
| 29 | r/Music | 1 | 0 | 1 | 0 |
| 30 | r/Jokes | 1 | 0 | 1 | 0 |
| 31 | r/gifs | 1 | 0 | 1 | 0 |
| 32 | r/springfieldMO | 1 | 0 | 1 | 0 |
| 33 | r/arlingtonva | 1 | 0 | 1 | 0 |
| 34 | r/iphone | 1 | 0 | 1 | 0 |

---

## Conclusion

The VWA Reddit test dataset provides a comprehensive evaluation of AI agents' web automation capabilities, with particular emphasis on:

1. **Visual Intelligence:** Strong focus on image understanding and matching
2. **Complex Reasoning:** Multi-step tasks requiring planning and context awareness
3. **Real-world Diversity:** 34 different communities spanning multiple interests
4. **Cross-platform Skills:** Integration with Wikipedia and e-commerce sites
5. **Comprehensive Actions:** Reading, writing, navigation, and interaction

The dataset's difficulty distribution (39% hard tasks) and diverse task types make it suitable for rigorous evaluation of advanced web agents.

---

*Generated by automated analysis of the VWA Reddit test dataset*
